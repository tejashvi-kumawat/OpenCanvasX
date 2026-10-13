import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Supported provider protocols (P5.1.2–P5.1.4).
enum AiProviderKind {
  openAiCompatible('OpenAI-compatible', 'https://api.openai.com/v1'),
  anthropic('Anthropic', 'https://api.anthropic.com'),
  ollama('Ollama (local)', 'http://localhost:11434');

  const AiProviderKind(this.label, this.defaultEndpoint);

  final String label;
  final String defaultEndpoint;
}

/// Provider settings (P5.1.5). Never contains the API key: keys live in
/// the OS credential store and are passed per request.
@immutable
final class AiConfig {
  const AiConfig({
    required this.kind,
    required this.endpoint,
    required this.model,
    this.temperature = 0.7,
    this.maxTokens = 1200,
    this.timeoutSeconds = 60,
  });

  factory AiConfig.fromJson(Map<String, Object?> json) {
    final kind = AiProviderKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => AiProviderKind.openAiCompatible,
    );
    return AiConfig(
      kind: kind,
      endpoint:
          json['endpoint'] is String
              ? json['endpoint']! as String
              : kind.defaultEndpoint,
      model: json['model'] is String ? json['model']! as String : '',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: (json['max_tokens'] as num?)?.toInt() ?? 1200,
      timeoutSeconds: (json['timeout'] as num?)?.toInt() ?? 60,
    );
  }

  final AiProviderKind kind;
  final String endpoint;
  final String model;
  final double temperature;
  final int maxTokens;
  final int timeoutSeconds;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'endpoint': endpoint,
    'model': model,
    'temperature': temperature,
    'max_tokens': maxTokens,
    'timeout': timeoutSeconds,
  };

  /// Whether requests stay on this computer or the local network
  /// (P5.2.3): localhost, private IPv4 ranges and `.local` hosts.
  bool get isLocal {
    final host = Uri.tryParse(endpoint)?.host.toLowerCase() ?? '';
    if (host == 'localhost' || host == '::1' || host.endsWith('.local')) {
      return true;
    }
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length == 4 && parts.every((p) => p != null)) {
      final (a, b) = (parts[0]!, parts[1]!);
      return a == 127 ||
          a == 10 ||
          (a == 192 && b == 168) ||
          (a == 172 && b >= 16 && b <= 31);
    }
    return false;
  }

  /// Short name for disclosures, e.g. "Anthropic (claude-…)".
  String get displayName => '${kind.label}${model.isEmpty ? '' : ' · $model'}';
}

/// One model reply and its usage when the provider reports it (P5.2.4).
typedef AiReply = ({String text, int? inputTokens, int? outputTokens});

/// A failed AI request with a message for the user.
final class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sends [prompt] (with [system] instructions) to the provider in
/// [config] and returns the reply. [apiKey] comes from secure storage and
/// is never logged or stored by this function.
Future<AiReply> complete(
  AiConfig config, {
  required String system,
  required String prompt,
  String? apiKey,
  HttpClient Function()? clientFactory,
}) async {
  if (config.model.trim().isEmpty) {
    throw const AiException('Choose a model in AI settings first.');
  }
  final base = config.endpoint.replaceFirst(RegExp(r'/+$'), '');
  final (
    Uri url,
    Map<String, String> headers,
    Map<String, Object?> body,
  ) = switch (config.kind) {
    AiProviderKind.openAiCompatible => (
      Uri.parse('$base/chat/completions'),
      {
        if (apiKey != null && apiKey.isNotEmpty)
          'authorization': 'Bearer $apiKey',
      },
      {
        'model': config.model,
        'temperature': config.temperature,
        'max_tokens': config.maxTokens,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': prompt},
        ],
      },
    ),
    AiProviderKind.anthropic => (
      Uri.parse('$base/v1/messages'),
      {
        if (apiKey != null) 'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      {
        'model': config.model,
        'max_tokens': config.maxTokens,
        'temperature': config.temperature,
        'system': system,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
    ),
    AiProviderKind.ollama => (
      Uri.parse('$base/api/chat'),
      const <String, String>{},
      {
        'model': config.model,
        'stream': false,
        'options': {
          'temperature': config.temperature,
          'num_predict': config.maxTokens,
        },
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': prompt},
        ],
      },
    ),
  };
  if (url.scheme != 'https' && !config.isLocal) {
    throw const AiException('Cloud providers must use https.');
  }

  final client =
      (clientFactory ?? HttpClient.new)()
        ..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.postUrl(url);
    request.headers.contentType = ContentType.json;
    headers.forEach(request.headers.set);
    request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close().timeout(
      Duration(seconds: config.timeoutSeconds),
    );
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(
      Duration(seconds: config.timeoutSeconds),
    )) {
      bytes.add(chunk);
      if (bytes.length > 8 * 1024 * 1024) {
        throw const AiException('The reply was too large.');
      }
    }
    final text = utf8.decode(bytes.takeBytes(), allowMalformed: true);
    if (response.statusCode != 200) {
      throw AiException(
        '${config.kind.label} answered ${response.statusCode}: '
        '${_errorMessage(text)}',
      );
    }
    final json = jsonDecode(text);
    if (json is! Map<String, Object?>) {
      throw const AiException('The provider sent an unexpected reply.');
    }
    return _parse(config.kind, json);
  } on TimeoutException {
    throw const AiException('The AI provider did not answer in time.');
  } on SocketException catch (e) {
    throw AiException('Could not reach ${config.endpoint} (${e.message}).');
  } on FormatException {
    throw const AiException('The provider sent an unreadable reply.');
  } finally {
    client.close(force: true);
  }
}

AiReply _parse(AiProviderKind kind, Map<String, Object?> json) {
  int? n(Object? v) => v is int ? v : null;
  switch (kind) {
    case AiProviderKind.openAiCompatible:
      final choices = json['choices'];
      final message =
          choices is List && choices.isNotEmpty && choices.first is Map
              ? (choices.first as Map)['message']
              : null;
      final content = message is Map ? message['content'] : null;
      final usage = json['usage'];
      return (
        text: content is String ? content : '',
        inputTokens: usage is Map ? n(usage['prompt_tokens']) : null,
        outputTokens: usage is Map ? n(usage['completion_tokens']) : null,
      );
    case AiProviderKind.anthropic:
      final content = json['content'];
      final text =
          [
            if (content is List)
              for (final block in content)
                if (block is Map &&
                    block['type'] == 'text' &&
                    block['text'] is String)
                  block['text']! as String,
          ].join();
      final usage = json['usage'];
      return (
        text: text,
        inputTokens: usage is Map ? n(usage['input_tokens']) : null,
        outputTokens: usage is Map ? n(usage['output_tokens']) : null,
      );
    case AiProviderKind.ollama:
      final message = json['message'];
      return (
        text:
            message is Map && message['content'] is String
                ? message['content']! as String
                : '',
        inputTokens: n(json['prompt_eval_count']),
        outputTokens: n(json['eval_count']),
      );
  }
}

String _errorMessage(String body) {
  try {
    final json = jsonDecode(body);
    if (json is Map) {
      final error = json['error'];
      if (error is Map && error['message'] is String) {
        return error['message']! as String;
      }
      if (error is String) return error;
    }
  } on FormatException {
    // fall through
  }
  return body.length > 200 ? '${body.substring(0, 200)}…' : body;
}

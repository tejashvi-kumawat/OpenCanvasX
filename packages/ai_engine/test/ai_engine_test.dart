import 'dart:convert';
import 'dart:io';

import 'package:ai_engine/ai_engine.dart';
import 'package:test/test.dart';

void main() {
  group('config', () {
    test('local vs cloud', () {
      AiConfig at(String endpoint) => AiConfig(
        kind: AiProviderKind.openAiCompatible,
        endpoint: endpoint,
        model: 'm',
      );
      expect(at('http://localhost:11434').isLocal, isTrue);
      expect(at('http://192.168.1.20:8080').isLocal, isTrue);
      expect(at('http://10.0.0.5').isLocal, isTrue);
      expect(at('https://api.openai.com/v1').isLocal, isFalse);
      expect(at('https://172.40.0.1').isLocal, isFalse);
    });

    test('round-trips without any key', () {
      const config = AiConfig(
        kind: AiProviderKind.anthropic,
        endpoint: 'https://api.anthropic.com',
        model: 'claude-x',
      );
      final json = config.toJson();
      expect(json.keys, isNot(contains('key')));
      expect(AiConfig.fromJson(json).model, 'claude-x');
      expect(AiConfig.fromJson(json).kind, AiProviderKind.anthropic);
    });
  });

  group('adapters', () {
    late HttpServer server;
    final seen = <(String, Map<String, String>, Object?)>[];

    setUp(() async {
      seen.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final body = jsonDecode(await utf8.decodeStream(request));
        seen.add((
          request.uri.path,
          {
            for (final h in ['authorization', 'x-api-key', 'anthropic-version'])
              if (request.headers.value(h) case final v?) h: v,
          },
          body,
        ));
        final reply = switch (request.uri.path) {
          '/v1/chat/completions' => {
            'choices': [
              {
                'message': {'content': 'Hello from OpenAI-compatible'},
              },
            ],
            'usage': {'prompt_tokens': 10, 'completion_tokens': 5},
          },
          '/v1/messages' => {
            'content': [
              {'type': 'text', 'text': 'Hello from Anthropic'},
            ],
            'usage': {'input_tokens': 12, 'output_tokens': 4},
          },
          '/api/chat' => {
            'message': {'content': 'Hello from Ollama'},
            'eval_count': 3,
          },
          _ => {
            'error': {'message': 'nope'},
          },
        };
        if (request.uri.path == '/fail/chat/completions') {
          request.response.statusCode = 401;
        }
        request.response.write(jsonEncode(reply));
        await request.response.close();
      });
    });
    tearDown(() => server.close(force: true));

    String base() => 'http://localhost:${server.port}';

    test('OpenAI-compatible', () async {
      final reply = await complete(
        AiConfig(
          kind: AiProviderKind.openAiCompatible,
          endpoint: '${base()}/v1',
          model: 'gpt-x',
        ),
        system: 'sys',
        prompt: 'hi',
        apiKey: 'sk-test',
      );
      expect(reply.text, 'Hello from OpenAI-compatible');
      expect((reply.inputTokens, reply.outputTokens), (10, 5));
      final (path, headers, body) = seen.single;
      expect(path, '/v1/chat/completions');
      expect(headers['authorization'], 'Bearer sk-test');
      expect((body! as Map)['messages'], hasLength(2));
    });

    test('Anthropic', () async {
      final reply = await complete(
        AiConfig(kind: AiProviderKind.anthropic, endpoint: base(), model: 'c'),
        system: 'sys',
        prompt: 'hi',
        apiKey: 'key',
      );
      expect(reply.text, 'Hello from Anthropic');
      final (_, headers, body) = seen.single;
      expect(headers['x-api-key'], 'key');
      expect(headers['anthropic-version'], '2023-06-01');
      expect((body! as Map)['system'], 'sys');
    });

    test('Ollama', () async {
      final reply = await complete(
        AiConfig(kind: AiProviderKind.ollama, endpoint: base(), model: 'llama'),
        system: 'sys',
        prompt: 'hi',
      );
      expect(reply.text, 'Hello from Ollama');
      expect(reply.outputTokens, 3);
    });

    test('errors and missing models are reported', () async {
      await expectLater(
        complete(
          AiConfig(
            kind: AiProviderKind.openAiCompatible,
            endpoint: '${base()}/fail',
            model: 'm',
          ),
          system: 's',
          prompt: 'p',
        ),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('nope'),
          ),
        ),
      );
      await expectLater(
        complete(
          const AiConfig(kind: AiProviderKind.ollama, endpoint: 'x', model: ''),
          system: 's',
          prompt: 'p',
        ),
        throwsA(isA<AiException>()),
      );
      await expectLater(
        complete(
          const AiConfig(
            kind: AiProviderKind.openAiCompatible,
            endpoint: 'http://example.org/v1',
            model: 'm',
          ),
          system: 's',
          prompt: 'p',
        ),
        throwsA(isA<AiException>()),
      );
    });
  });

  group('tasks', () {
    test('text prompts fence the content', () {
      final prompt = textTaskPrompt(
        TextTask.translate,
        'Hola',
        language: 'German',
      );
      expect(prompt, contains('German'));
      expect(prompt, contains('<text>\nHola\n</text>'));
      expect(cleanTextReply('"Hello"'), 'Hello');
      expect(cleanTextReply('```\nHi there\n```'), 'Hi there');
    });

    test('JSON is pulled out of chatty replies', () {
      expect(
        extractJsonObject(
          'Sure! Here you go:\n```json\n{"operations": [{"op": "notify", "message": "a } b"}]}\n```',
        ),
        {
          'operations': [
            {'op': 'notify', 'message': 'a } b'},
          ],
        },
      );
      expect(extractJsonObject('no json'), isNull);
      expect(
        designSystemPrompt(width: 1080, height: 1080, unit: 'px'),
        contains('1080'),
      );
    });
  });
}

/// Redacts common secret patterns before logs leave the process.
class SecretRedactor {
  SecretRedactor({List<RegExp>? extraPatterns})
      : _patterns = [..._defaultPatterns, ...?extraPatterns];

  static final List<RegExp> _defaultPatterns = [
    RegExp(
      '(api[_-]?key|secret|password|passwd|token|private[_-]?key'
      '|authorization|bearer)\\s*[:=]\\s*\\S+',
      caseSensitive: false,
    ),
    RegExp(
      'bearer\\s+[a-z0-9\\-._~+/]+=*',
      caseSensitive: false,
    ),
    RegExp(
      r'-----BEGIN [A-Z ]+-----[\s\S]*?-----END [A-Z ]+-----',
      multiLine: true,
    ),
    // OpenAI- and Anthropic-style keys (sk-…, sk-proj-…, sk-ant-…).
    RegExp(r'sk-[a-zA-Z0-9_\-]{20,}'),
    RegExp(
      'ocx://join/[^\\s]+',
      caseSensitive: false,
    ),
  ];

  final List<RegExp> _patterns;

  /// Returns [message] with sensitive substrings replaced.
  String redact(String message) {
    var out = message;
    for (final pattern in _patterns) {
      out = out.replaceAll(pattern, '[REDACTED]');
    }
    return out;
  }
}

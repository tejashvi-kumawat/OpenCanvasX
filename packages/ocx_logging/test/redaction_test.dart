import 'package:ocx_logging/ocx_logging.dart';
import 'package:test/test.dart';

void main() {
  group('SecretRedactor', () {
    final redactor = SecretRedactor();

    test('redacts api_key assignments', () {
      const raw = 'Failed with api_key=sk-abcdefghijklmnopqrstuvwxyz123456';
      expect(redactor.redact(raw), contains('[REDACTED]'));
      expect(redactor.redact(raw), isNot(contains('sk-abc')));
    });

    test('redacts bearer tokens', () {
      const raw = 'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload';
      final out = redactor.redact(raw);
      expect(out, contains('[REDACTED]'));
    });

    test('redacts PEM blocks', () {
      const raw = '''
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7
-----END PRIVATE KEY-----''';
      expect(redactor.redact(raw), '[REDACTED]');
    });
  });

  group('OcxLogger', () {
    test('redacts before sink', () {
      final lines = <String>[];
      final logger = OcxLogger(
        minLevel: LogLevel.trace,
        sink: (level, message, {error, stackTrace}) => lines.add(message),
      );
      logger.info('password=supersecret');
      expect(lines.single, '[REDACTED]');
    });
  });
}

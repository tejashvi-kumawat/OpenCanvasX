import 'dart:math';

/// Stable identifier of a `DesignObject`; unchanged for the object's lifetime.
extension type const ObjectId(String value) {
  /// Creates a new random id (UUID v4).
  ObjectId.generate([Random? random]) : value = generateUuidV4(random);
}

/// Stable identifier of a `DesignPage`.
extension type const PageId(String value) {
  /// Creates a new random id (UUID v4).
  PageId.generate([Random? random]) : value = generateUuidV4(random);
}

/// Returns a random RFC 4122 version 4 UUID in lowercase canonical form.
///
/// Uses [Random.secure] unless [random] is given (tests pass a seeded one).
String generateUuidV4([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

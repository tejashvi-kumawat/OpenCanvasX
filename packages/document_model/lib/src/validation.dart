// Shared argument checks for model constructors. Not exported.

void checkFinite(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'must be finite');
  }
}

void checkNonNegative(double value, String name) {
  checkFinite(value, name);
  if (value < 0) {
    throw ArgumentError.value(value, name, 'must be >= 0');
  }
}

void checkPositive(double value, String name) {
  checkFinite(value, name);
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'must be > 0');
  }
}

void checkUnitInterval(double value, String name) {
  checkFinite(value, name);
  if (value < 0 || value > 1) {
    throw ArgumentError.value(value, name, 'must be between 0 and 1');
  }
}

final _sha256Hex = RegExp(r'^[0-9a-f]{64}$');

bool isSha256Hex(String value) => _sha256Hex.hasMatch(value);

/// Asset references are lowercase hex SHA-256 digests (see file-format.md).
void checkSha256Hex(String value, String name) {
  if (!isSha256Hex(value)) {
    throw ArgumentError.value(
      value,
      name,
      'must be a lowercase hex SHA-256 digest',
    );
  }
}

bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final MapEntry(:key, :value) in a.entries) {
    if (!b.containsKey(key) || b[key] != value) return false;
  }
  return true;
}

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// Windows Credential Manager (advapi32) bindings for API keys. Generic
// credentials are stored per user and protected by Windows; no native
// build step is needed.

const int _credTypeGeneric = 1;
const int _credPersistLocalMachine = 2;

final class _Credential extends Struct {
  @Uint32()
  external int flags;
  @Uint32()
  external int type;
  external Pointer<Utf16> targetName;
  external Pointer<Utf16> comment;
  @Uint32()
  external int lastWrittenLow;
  @Uint32()
  external int lastWrittenHigh;
  @Uint32()
  external int credentialBlobSize;
  external Pointer<Uint8> credentialBlob;
  @Uint32()
  external int persist;
  @Uint32()
  external int attributeCount;
  external Pointer<Void> attributes;
  external Pointer<Utf16> targetAlias;
  external Pointer<Utf16> userName;
}

final DynamicLibrary _advapi32 = DynamicLibrary.open('advapi32.dll');
final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');

final int Function(Pointer<Utf16>, int, int, Pointer<Pointer<_Credential>>)
_credRead = _advapi32.lookupFunction<
  Int32 Function(Pointer<Utf16>, Uint32, Uint32, Pointer<Pointer<_Credential>>),
  int Function(Pointer<Utf16>, int, int, Pointer<Pointer<_Credential>>)
>('CredReadW');

final int Function(Pointer<_Credential>, int) _credWrite = _advapi32
    .lookupFunction<
      Int32 Function(Pointer<_Credential>, Uint32),
      int Function(Pointer<_Credential>, int)
    >('CredWriteW');

final int Function(Pointer<Utf16>, int, int) _credDelete = _advapi32
    .lookupFunction<
      Int32 Function(Pointer<Utf16>, Uint32, Uint32),
      int Function(Pointer<Utf16>, int, int)
    >('CredDeleteW');

final void Function(Pointer<Void>) _credFree = _advapi32
    .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
      'CredFree',
    );

final int Function() _getLastError = _kernel32
    .lookupFunction<Uint32 Function(), int Function()>('GetLastError');

/// Reads generic credential [name], or `null` when there is none.
String? readWindowsCredential(String name) => using((arena) {
  final out = arena<Pointer<_Credential>>();
  if (_credRead(
        name.toNativeUtf16(allocator: arena),
        _credTypeGeneric,
        0,
        out,
      ) ==
      0) {
    // Not found (or unreadable): treated as no saved key.
    return null;
  }
  try {
    final cred = out.value.ref;
    final bytes = Uint8List.fromList(
      cred.credentialBlob.asTypedList(cred.credentialBlobSize),
    );
    return utf8.decode(bytes);
  } finally {
    _credFree(out.value.cast());
  }
});

/// Saves [value] as generic credential [name] for the current user.
void writeWindowsCredential(String name, String value) => using((arena) {
  final bytes = utf8.encode(value);
  final blob = arena<Uint8>(bytes.length)
    ..asTypedList(bytes.length).setAll(0, bytes);
  final cred = arena<_Credential>();
  cred.ref
    ..flags = 0
    ..type = _credTypeGeneric
    ..targetName = name.toNativeUtf16(allocator: arena)
    ..comment = nullptr
    ..lastWrittenLow = 0
    ..lastWrittenHigh = 0
    ..credentialBlobSize = bytes.length
    ..credentialBlob = blob
    ..persist = _credPersistLocalMachine
    ..attributeCount = 0
    ..attributes = nullptr
    ..targetAlias = nullptr
    ..userName = 'OpenCanvasX'.toNativeUtf16(allocator: arena);
  if (_credWrite(cred, 0) == 0) {
    throw StateError('Could not save the key (error ${_getLastError()}).');
  }
});

/// Deletes generic credential [name] if it exists.
void deleteWindowsCredential(String name) => using((arena) {
  _credDelete(name.toNativeUtf16(allocator: arena), _credTypeGeneric, 0);
});

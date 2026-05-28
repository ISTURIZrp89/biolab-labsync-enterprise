import 'dart:convert';
import 'dart:math';

String generateUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  return '${_hex(bytes, 0, 4)}-${_hex(bytes, 4, 2)}-${_hex(bytes, 6, 2)}-${_hex(bytes, 8, 2)}-${_hex(bytes, 10, 6)}';
}

String _hex(List<int> bytes, int start, int length) {
  return bytes.sublist(start, start + length).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String toJson(dynamic value) => jsonEncode(value);
dynamic fromJson(String value) => jsonDecode(value);

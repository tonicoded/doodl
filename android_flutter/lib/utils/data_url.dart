import 'dart:convert';
import 'dart:typed_data';

Uint8List decodeDataUrlToBytes(String value) {
  final trimmed = value.trim();
  final comma = trimmed.indexOf(',');
  final base64Part = comma >= 0 ? trimmed.substring(comma + 1) : trimmed;
  return base64Decode(base64Part);
}

String pngBytesToDataUrl(Uint8List pngBytes) {
  return 'data:image/png;base64,${base64Encode(pngBytes)}';
}

import 'dart:io';
import 'dart:typed_data';

/// `dart:io` [WavFileWriter]. Creates parent directories and throws on failure.
/// Resolve production paths via `path_provider`, never a hardcoded absolute path.
Future<void> writeWavToFile(String path, Uint8List bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

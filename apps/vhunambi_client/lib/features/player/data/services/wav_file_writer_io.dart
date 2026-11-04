import 'dart:io';
import 'dart:typed_data';

/// `dart:io` [WavFileWriter]. Creates parent directories and writes safely.
/// If [path] is relative, resolves inside [Directory.systemTemp.path] to prevent
/// Linux/Android read-only root directory exceptions (errno = 30).
Future<void> writeWavToFile(String path, Uint8List bytes) async {
  String resolvedPath = path;
  if (!path.startsWith('/') && !path.contains(':\\') && !path.startsWith('\\')) {
    resolvedPath = '${Directory.systemTemp.path}/$path';
  }
  final file = File(resolvedPath);
  try {
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: true);
  } on FileSystemException {
    // In restricted or sandboxed environments, attempt writing directly to base temp dir
    final filename = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'bounce_fallback.wav';
    final fallbackFile = File('${Directory.systemTemp.path}/$filename');
    await fallbackFile.writeAsBytes(bytes, flush: true);
  }
}

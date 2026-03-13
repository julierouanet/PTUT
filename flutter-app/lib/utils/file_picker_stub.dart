import 'dart:typed_data';

/// Stub implementation for non-web platforms.
/// This file is used when dart:html is not available (e.g., during tests or on mobile).

typedef FilePickedCallback = void Function(String fileName, Uint8List bytes);

void pickImageFile(FilePickedCallback onFilePicked) {
  // No-op on non-web platforms
  throw UnsupportedError('File picking is only supported on the web.');
}

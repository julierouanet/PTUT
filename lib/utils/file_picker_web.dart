import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

typedef FilePickedCallback = void Function(String fileName, Uint8List bytes);

/// Web implementation using dart:html for file picking.
void pickImageFile(FilePickedCallback onFilePicked) {
  final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
  uploadInput.click();

  uploadInput.onChange.listen((event) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();

      reader.onLoadEnd.listen((event) {
        if (reader.result != null) {
          final bytes = reader.result as Uint8List;
          onFilePicked(file.name, bytes);
        }
      });

      reader.readAsArrayBuffer(file);
    }
  });
}

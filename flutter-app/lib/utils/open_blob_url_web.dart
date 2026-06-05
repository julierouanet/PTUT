// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Implémentation web : ouvre les octets via une blob URL dans un nouvel onglet.
void openBytesInBrowser(Uint8List bytes, String mime, String name) {
  final blob    = html.Blob([bytes], mime);
  final blobUrl = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(blobUrl, '_blank');
  // Libération mémoire différée (délai généreux pour l'ouverture de l'onglet)
  Future.delayed(const Duration(minutes: 2),
      () => html.Url.revokeObjectUrl(blobUrl));
}

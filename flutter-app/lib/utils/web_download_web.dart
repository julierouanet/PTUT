// Implémentation web uniquement — ne jamais importer directement.
// Passer par la facade web_download.dart.
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html show AnchorElement, Blob, Url;

/// Déclenche le téléchargement d'un fichier dans le navigateur.
Future<void> triggerWebDownload(List<int> bytes, String filename) async {
  final blob = html.Blob([bytes]);
  final url  = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

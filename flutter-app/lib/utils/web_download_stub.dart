/// Stub non-web : le téléchargement navigateur n'est pas disponible sur VM/mobile.
/// Aucune action requise — l'appelant gère le cas non-web séparément.
Future<void> triggerWebDownload(List<int> bytes, String filename) async {
  // Pas d'action sur les plateformes non-web (VM, Android, iOS).
}

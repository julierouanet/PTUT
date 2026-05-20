// ── Façade Web Push — export conditionnel ────────────────────────────────────
// Sur web (dart.library.js_interop disponible) → utilise l'implémentation réelle.
// Sur VM / tests / mobile → utilise le stub no-op.
//
// Les imports dans le reste du code ne doivent viser que CE fichier.

export 'push_notification_web_service_stub.dart'
    if (dart.library.js_interop) 'push_notification_web_service_impl.dart';

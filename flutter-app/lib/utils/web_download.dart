// Facade d'import conditionnel pour le téléchargement web.
// Sur navigateur : utilise dart:html (via web_download_web.dart).
// Sur VM / mobile : no-op (via web_download_stub.dart).
export 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart';

/// Import conditionnel : stub sur VM/natif, implémentation html sur web.
export 'open_blob_url_stub.dart'
    if (dart.library.html) 'open_blob_url_web.dart';

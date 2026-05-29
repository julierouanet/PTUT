// Sélecteur d'implémentation : web réel ou stub selon la plateforme.
export 'csv_export_stub.dart' if (dart.library.html) 'csv_export_web.dart';

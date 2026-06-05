import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// Compression d'images avant upload.
///
/// Sur web : flutter_image_compress n'est pas disponible — les bytes originaux
/// sont retournés directement (le serveur impose une limite à 5 Mo par fichier).
/// Sur natif : placeholder (la feature de compression peut être activée en
/// décommentant le bloc flutter_image_compress une fois le package ajouté au natif).
class ImageCompressor {
  /// Compresse une image JPEG/PNG.
  /// Retourne toujours un résultat non-null : bytes originaux si compression
  /// échoue ou si le résultat compressé est plus lourd.
  static Future<Uint8List> compress(
    Uint8List originalBytes, {
    int quality   = 70,
    int maxWidth  = 1920,
    int maxHeight = 1080,
  }) async {
    if (kIsWeb) {
      // flutter_image_compress ne supporte pas le web — bypass direct.
      return originalBytes;
    }

    try {
      // Sur natif : compression via flutter_image_compress si disponible.
      // Pour activer, décommenter le bloc ci-dessous et ajouter
      // flutter_image_compress: ^2.2.0 dans pubspec.yaml (natif uniquement).
      //
      // final result = await FlutterImageCompress.compressWithList(
      //   originalBytes,
      //   quality:   quality,
      //   minWidth:  1,
      //   minHeight: 1,
      // );
      // if (result.length < originalBytes.length) {
      //   debugPrint('[ImageCompressor] ${originalBytes.length ~/ 1024} Ko → ${result.length ~/ 1024} Ko');
      //   return result;
      // }
      return originalBytes;
    } catch (e) {
      debugPrint('[ImageCompressor] Échec : $e');
      return originalBytes;
    }
  }
}

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:image/image.dart' as img;

/// Compression d'images avant upload.
///
/// Le serveur impose une limite de 5 Mo par photo (`MAX_PHOTO_MB` dans
/// `db-service/src/middleware/upload.js`). Sans compression réelle, une photo
/// brute prise depuis un smartphone (souvent 3 à 12 Mo) dépasse cette limite et
/// l'upload échoue côté Multer — c'était la cause racine des photos jamais
/// jointes à un incident. `package:image` est pur Dart : fonctionne identique
/// sur web et natif (contrairement à flutter_image_compress, indisponible web).
///
/// Le décodage/redimensionnement/ré-encodage est CPU-bound : `compute()` le
/// déporte sur un isolate séparé pour ne pas geler l'UI pendant la soumission
/// du formulaire d'incident (jusqu'à 5 photos par signalement).
class ImageCompressor {
  /// Compresse une image JPEG/PNG : redimensionne si elle dépasse [maxWidth]/
  /// [maxHeight] (ratio préservé) et ré-encode en JPEG à [quality]. Retourne
  /// toujours les bytes originaux + leur [originalMimeType] si le décodage
  /// échoue ou si le résultat compressé est plus lourd que l'original — le
  /// mimeType retourné reflète toujours l'encodage réel des bytes, jamais
  /// déduit du nom de fichier d'origine.
  static Future<({Uint8List bytes, String mimeType})> compress(
    Uint8List originalBytes,
    String originalMimeType, {
    int quality   = 70,
    int maxWidth  = 1920,
    int maxHeight = 1080,
  }) {
    return compute(
      _compressSync,
      _CompressInput(originalBytes, originalMimeType, quality, maxWidth, maxHeight),
    );
  }
}

class _CompressInput {
  final Uint8List bytes;
  final String mimeType;
  final int quality;
  final int maxWidth;
  final int maxHeight;
  const _CompressInput(this.bytes, this.mimeType, this.quality, this.maxWidth, this.maxHeight);
}

/// Fonction top-level (requise par `compute()`) exécutée sur l'isolate dédié.
({Uint8List bytes, String mimeType}) _compressSync(_CompressInput input) {
  try {
    final decoded = img.decodeImage(input.bytes);
    if (decoded == null) return (bytes: input.bytes, mimeType: input.mimeType);

    final scale = [
      input.maxWidth  / decoded.width,
      input.maxHeight / decoded.height,
      1.0, // jamais d'agrandissement
    ].reduce((a, b) => a < b ? a : b);
    final resized = scale < 1.0
        ? img.copyResize(decoded, width: (decoded.width * scale).round())
        : decoded;

    final encoded = img.encodeJpg(resized, quality: input.quality);
    if (encoded.length >= input.bytes.length) {
      return (bytes: input.bytes, mimeType: input.mimeType);
    }

    debugPrint('[ImageCompressor] ${input.bytes.length ~/ 1024} Ko → ${encoded.length ~/ 1024} Ko');
    return (bytes: Uint8List.fromList(encoded), mimeType: 'image/jpeg');
  } catch (e) {
    debugPrint('[ImageCompressor] Échec : $e');
    return (bytes: input.bytes, mimeType: input.mimeType);
  }
}

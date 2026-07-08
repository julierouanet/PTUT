import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:equipment_management/services/api_client.dart';

/// Construit un JWT factice (signature bidon, non vérifiée par decodeExpiry)
/// avec le claim `exp` donné, au format 3 segments base64Url séparés par '.'.
String _fakeJwt(num expSeconds) {
  String b64(Map<String, dynamic> json) {
    final encoded = base64Url.encode(utf8.encode(jsonEncode(json)));
    return encoded.replaceAll('=', '');
  }

  final header = b64({'alg': 'RS256', 'typ': 'JWT'});
  final payload = b64({'exp': expSeconds, 'sub': 'test-user'});
  return '$header.$payload.fake-signature';
}

void main() {
  group('ApiClient.decodeExpiry', () {
    test('décode correctement un claim exp entier valide', () {
      final expSeconds = DateTime.utc(2030, 1, 1).millisecondsSinceEpoch ~/ 1000;
      final jwt = _fakeJwt(expSeconds);

      final decoded = ApiClient.decodeExpiry(jwt);

      expect(decoded, isNotNull);
      expect(decoded!.millisecondsSinceEpoch, expSeconds * 1000);
    });

    test('décode correctement un claim exp de type double (JSON avec décimale)', () {
      final expSeconds = DateTime.utc(2030, 6, 1).millisecondsSinceEpoch ~/ 1000;
      final jwt = _fakeJwt(expSeconds.toDouble());

      final decoded = ApiClient.decodeExpiry(jwt);

      expect(decoded, isNotNull);
      expect(decoded!.millisecondsSinceEpoch, expSeconds * 1000);
    });

    test('retourne null pour un token avec moins de 3 segments', () {
      expect(ApiClient.decodeExpiry('deux.segments'), isNull);
    });

    test('retourne null pour un payload non-JSON', () {
      final malformed = 'header.${base64Url.encode(utf8.encode('pas-du-json'))}.sig';
      expect(ApiClient.decodeExpiry(malformed), isNull);
    });

    test('retourne null si le claim exp est absent', () {
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'RS256'})));
      final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': 'x'})));
      expect(ApiClient.decodeExpiry('$header.$payload.sig'), isNull);
    });

    test('retourne null si le claim exp est une chaîne', () {
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'RS256'})));
      final payload = base64Url.encode(utf8.encode(jsonEncode({'exp': 'pas-un-nombre'})));
      expect(ApiClient.decodeExpiry('$header.$payload.sig'), isNull);
    });
  });
}

/// Modèle immuable des paramètres applicatifs (auth-service → table app_settings).
class AppSettings {
  final String loginContactTitle;
  final String loginContactEmail;
  final String loginContactPhone;
  final bool   brevoKeyConfigured;
  final String? brevoKeyHint;
  final String brevoSenderEmail;
  final String brevoSenderName;

  const AppSettings({
    required this.loginContactTitle,
    required this.loginContactEmail,
    required this.loginContactPhone,
    required this.brevoKeyConfigured,
    this.brevoKeyHint,
    required this.brevoSenderEmail,
    required this.brevoSenderName,
  });

  /// Construit depuis la réponse admin (tableau de clés, secrets masqués).
  factory AppSettings.fromAdminJson(List<dynamic> rows) {
    final map = {
      for (final row in rows)
        if (row is Map<String, dynamic>) row['key'] as String: row,
    };

    String val(String key) => (map[key]?['value'] as String?) ?? '';

    final brevoRow = map['brevo_api_key'];

    return AppSettings(
      loginContactTitle: val('login_contact_title'),
      loginContactEmail: val('login_contact_email'),
      loginContactPhone: val('login_contact_phone'),
      brevoKeyConfigured: (brevoRow?['configured'] as bool?) ?? false,
      brevoKeyHint: brevoRow?['hint'] as String?,
      brevoSenderEmail: val('brevo_sender_email'),
      brevoSenderName: val('brevo_sender_name'),
    );
  }

  /// Construit depuis la réponse publique (objet clé → valeur).
  factory AppSettings.fromPublicJson(Map<String, dynamic> json) {
    return AppSettings(
      loginContactTitle: (json['login_contact_title'] as String?) ?? '',
      loginContactEmail: (json['login_contact_email'] as String?) ?? '',
      loginContactPhone: (json['login_contact_phone'] as String?) ?? '',
      brevoKeyConfigured: false,
      brevoKeyHint: null,
      brevoSenderEmail: '',
      brevoSenderName: '',
    );
  }

  AppSettings copyWith({
    String? loginContactTitle,
    String? loginContactEmail,
    String? loginContactPhone,
    bool?   brevoKeyConfigured,
    String? brevoKeyHint,
    String? brevoSenderEmail,
    String? brevoSenderName,
  }) {
    return AppSettings(
      loginContactTitle: loginContactTitle  ?? this.loginContactTitle,
      loginContactEmail: loginContactEmail  ?? this.loginContactEmail,
      loginContactPhone: loginContactPhone  ?? this.loginContactPhone,
      brevoKeyConfigured: brevoKeyConfigured ?? this.brevoKeyConfigured,
      brevoKeyHint:      brevoKeyHint       ?? this.brevoKeyHint,
      brevoSenderEmail:  brevoSenderEmail   ?? this.brevoSenderEmail,
      brevoSenderName:   brevoSenderName    ?? this.brevoSenderName,
    );
  }
}

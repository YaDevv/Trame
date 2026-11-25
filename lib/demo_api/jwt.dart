import 'dart:convert';

/// Ce que contient un jeton JWT emis par LexikJWT (partie centrale).
/// Le jeton n'est pas verifie ici : seule l'API peut le faire, avec sa cle.
class JwtClaims {
  const JwtClaims({
    required this.username,
    required this.roles,
    this.issuedAt,
    this.expiresAt,
  });

  /// Identifiant de connexion (l'email pour cette API).
  final String? username;
  final List<String> roles;
  final DateTime? issuedAt;
  final DateTime? expiresAt;

  /// Lit la partie centrale « header.payload.signature » du jeton.
  static JwtClaims decode(String token) {
    // Un JWT a 3 parties séparées par des points : en-tête.contenu.signature.
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException('Jeton JWT mal formé.');
    }
    // On décode la partie du milieu : Base64 → texte → JSON.
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Contenu du jeton illisible.');
    }

    // Les dates du jeton sont en secondes depuis 1970 : on les convertit en DateTime.
    DateTime? date(Object? seconds) => seconds is num
        ? DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000)
        : null;

    return JwtClaims(
      username: payload['username'] as String?,
      roles: [
        for (final role in payload['roles'] as List? ?? const []) '$role',
      ],
      issuedAt: date(payload['iat']),
      expiresAt: date(payload['exp']),
    );
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'jwt.dart';

/// Resultat d'une connexion : le jeton et ce que l'API dit de l'utilisateur.
class ApiSession {
  const ApiSession({
    required this.token,
    required this.userId,
    required this.roles,
    required this.prenom,
    required this.nom,
  });

  final String token;
  final int userId;

  /// Roles renvoyes par l'API a la connexion (ROLE_USER, ROLE_ADMIN...).
  final List<String> roles;
  final String prenom;
  final String nom;

  // Contenu du jeton décodé (email, rôles, dates).
  JwtClaims get claims => JwtClaims.decode(token);
  // Sert à afficher le badge « Administrateur » dans le profil.
  bool get isAdmin => roles.contains('ROLE_ADMIN');
}

/// Fiche utilisateur lue sur GET /api/users/{id}.
class ApiUser {
  const ApiUser({
    required this.id,
    required this.email,
    required this.prenom,
    required this.nom,
  });

  final int id;
  final String email;
  final String prenom;
  final String nom;
}

/// Un message lu sur GET /api/messages.
class ApiMessage {
  const ApiMessage({
    required this.id,
    required this.titre,
    required this.contenu,
    required this.auteur,
    this.datePoste,
    this.parentId,
  });

  final int id;

  /// Message auquel celui-ci repond ; null pour un message qui ouvre
  /// une discussion.
  final int? parentId;
  final String titre;
  final String contenu;

  /// « Prénom Nom » de l'auteur, tel que l'API l'envoie.
  final String auteur;
  final DateTime? datePoste;

  // Transforme un message JSON reçu de l'API en objet Dart.
  // Les « ?? » donnent une valeur par défaut si un champ manque.
  factory ApiMessage.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    // L'API envoie l'auteur sous forme d'objet user { prenom, nom }.
    final auteur = user is Map
        ? '${user['prenom'] ?? ''} ${user['nom'] ?? ''}'.trim()
        : '';
    final date = json['datePoste'];
    // parent peut être un objet { id } ou une adresse « /forum/api/messages/12 » :
    // on gère les deux cas pour retrouver l'id du message parent.
    final parent = json['parent'];
    int? parentId;
    if (parent is Map) parentId = (parent['id'] as num?)?.toInt();
    if (parent is String) parentId = int.tryParse(parent.split('/').last);
    return ApiMessage(
      parentId: parentId,
      id: (json['id'] as num?)?.toInt() ?? 0,
      titre: json['titre'] as String? ?? '',
      contenu: json['contenu'] as String? ?? '',
      auteur: auteur.isEmpty ? 'Membre' : auteur,
      datePoste: date is String ? DateTime.tryParse(date)?.toLocal() : null,
    );
  }
}

/// Une discussion de l'accueil : son premier message et ses reponses.
class ApiDiscussion {
  const ApiDiscussion({required this.message, required this.replyCount});

  final ApiMessage message;
  final int replyCount;
}

/// Regroupe les messages : chaque message sans parent ouvre une discussion,
/// les autres sont comptes comme ses reponses. L'ordre recu est conserve.
List<ApiDiscussion> discussionsFrom(List<ApiMessage> messages) {
  // 1er passage : on compte les réponses de chaque message (id du parent → nombre).
  final replies = <int, int>{};
  for (final m in messages) {
    final parent = m.parentId;
    if (parent != null) replies[parent] = (replies[parent] ?? 0) + 1;
  }
  return [
    for (final m in messages)
      // 2e passage : on ne garde que les messages sans parent (ceux qui ouvrent
      // une discussion), avec leur nombre de réponses.
      if (m.parentId == null)
        ApiDiscussion(message: m, replyCount: replies[m.id] ?? 0),
  ];
}

/// Email ou mot de passe refuse par l'API (401 a la connexion).
class InvalidCredentialsException implements Exception {}

/// Jeton absent, expire ou refuse (401 sur une route protegee).
class UnauthorizedException implements Exception {}

/// Donnees refusees par les regles de validation de l'API (422).
class ValidationException implements Exception {
  const ValidationException(this.messages);

  /// Champ de l'API -> message d'erreur, tels que renvoyes par Symfony.
  final Map<String, String> messages;
}

/// Reseau, CORS ou serveur indisponible.
class ApiUnavailableException implements Exception {
  const ApiUnavailableException([this.detail]);

  final String? detail;
}

/// Ce dont la demo a besoin de l'API Symfony `forum`.
// Interface : la liste des actions possibles avec le serveur, sans leur code.
// L'appli utilise HttpForumApi (vraies requêtes) ; les tests, une fausse API.
abstract interface class ForumApi {
  /// POST /api/authentication_token
  Future<ApiSession> login({required String email, required String password});

  /// POST /api/users
  Future<void> register({
    required String prenom,
    required String nom,
    required String email,
    required String password,
  });

  /// GET /api/users/{id}, avec le jeton dans l'en-tete Authorization.
  Future<ApiUser> fetchUser({required int id, required String token});

  /// GET /api/messages : tous les messages, les plus recents d'abord.
  /// Lisible sans connexion ; le jeton est joint s'il existe.
  Future<List<ApiMessage>> fetchMessages({String? token});

  /// POST /api/messages. Seuls le titre et le contenu sont envoyes :
  /// l'API determine l'auteur avec le jeton, et la date elle-meme.
  Future<void> createMessage({
    required String titre,
    required String contenu,
    required String token,
  });
}

// Version réelle de ForumApi : envoie de vraies requêtes HTTP à l'API Symfony.
class HttpForumApi implements ForumApi {
  HttpForumApi({required String baseUrl, http.Client? client})
    : _base = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      _client = client ?? http.Client();

  final String _base;
  final http.Client _client;

  // Format JSON utilisé par API Platform (JSON-LD).
  static const _jsonLd = 'application/ld+json';

  Uri _uri(String path) => Uri.parse('$_base$path');

  // Enveloppe commune à toutes les requêtes : 15 secondes maximum, et toute
  // erreur réseau devient une ApiUnavailableException.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 15));
    } catch (error) {
      throw ApiUnavailableException('$error');
    }
  }

  // Lit le corps de la réponse (en UTF-8 pour les accents) et le décode en JSON.
  Map<String, dynamic> _json(http.Response response) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is Map<String, dynamic>) return body;
    throw const ApiUnavailableException('Réponse inattendue de l’API.');
  }

  // Réponse inattendue : on lève une erreur générique.
  Never _fail(http.Response response) {
    throw ApiUnavailableException('Erreur ${response.statusCode}');
  }

  @override
  Future<ApiSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _send(
      () => _client.post(
        _uri('/api/authentication_token'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ),
    );
    // 401 à la connexion = email ou mot de passe incorrect.
    if (response.statusCode == 401) throw InvalidCredentialsException();
    if (response.statusCode != 200) _fail(response);

    final body = _json(response);
    // La réponse contient le jeton JWT, à renvoyer ensuite avec chaque requête protégée.
    final token = body['token'];
    if (token is! String) _fail(response);
    // Ajoute par AuthenticationSuccessListener cote API.
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    final claims = JwtClaims.decode(token);
    return ApiSession(
      token: token,
      userId: (data['id'] as num?)?.toInt() ?? 0,
      roles: [
        for (final role in data['roles'] as List? ?? claims.roles) '$role',
      ],
      prenom: data['prenom'] as String? ?? '',
      nom: data['nom'] as String? ?? '',
    );
  }

  @override
  Future<void> register({
    required String prenom,
    required String nom,
    required String email,
    required String password,
  }) async {
    final response = await _send(
      () => _client.post(
        _uri('/api/users'),
        headers: const {'Content-Type': _jsonLd, 'Accept': _jsonLd},
        body: jsonEncode({
          // Corps de la requête : les champs de l'entité User côté Symfony.
          'prenom': prenom.trim(),
          'nom': nom.trim(),
          'email': email.trim(),
          'password': password,
        }),
      ),
    );
    if (response.statusCode == 201) return;
    if (response.statusCode == 401) throw UnauthorizedException();
    if (response.statusCode == 422) {
      final violations = _json(response)['violations'] as List? ?? const [];
      throw ValidationException({
        for (final v in violations.whereType<Map>())
          '${v['propertyPath'] ?? ''}': '${v['message'] ?? ''}',
      });
    }
    _fail(response);
  }

  @override
  Future<ApiUser> fetchUser({required int id, required String token}) async {
    final response = await _send(
      () => _client.get(
        _uri('/api/users/$id'),
        // Le jeton part dans l'en-tête Authorization pour prouver qui on est.
        headers: {'Accept': _jsonLd, 'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode == 401) throw UnauthorizedException();
    if (response.statusCode != 200) _fail(response);

    final body = _json(response);
    return ApiUser(
      id: (body['id'] as num?)?.toInt() ?? id,
      email: body['email'] as String? ?? '',
      prenom: body['prenom'] as String? ?? '',
      nom: body['nom'] as String? ?? '',
    );
  }

  /// Nombre maximal de pages lues (10 messages par page cote API).
  static const _maxPages = 10;

  @override
  Future<List<ApiMessage>> fetchMessages({String? token}) async {
    final messages = <ApiMessage>[];
    // L'API renvoie 10 messages par page : on lit page après page,
    // tant qu'elle annonce une page suivante (view.next).
    Uri? next = _uri('/api/messages');
    for (var page = 0; next != null && page < _maxPages; page++) {
      final url = next;
      final response = await _send(
        () => _client.get(
          url,
          headers: {
            'Accept': _jsonLd,
            // Un visiteur n'a pas de jeton : la lecture des messages est publique.
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.statusCode == 401) throw UnauthorizedException();
      if (response.statusCode != 200) _fail(response);

      final body = _json(response);
      // API Platform 4 : « member » ; versions plus anciennes : « hydra:member ».
      final members = body['member'] ?? body['hydra:member'] ?? const [];
      for (final item in members as List) {
        if (item is Map<String, dynamic>) {
          messages.add(ApiMessage.fromJson(item));
        }
      }
      // Page suivante annoncee par l'API, s'il y en a une.
      final view = body['view'] ?? body['hydra:view'];
      final nextIri = view is Map ? (view['next'] ?? view['hydra:next']) : null;
      next = nextIri is String ? Uri.parse(_base).resolve(nextIri) : null;
    }
    return messages;
  }

  @override
  Future<void> createMessage({
    required String titre,
    required String contenu,
    required String token,
  }) async {
    final response = await _send(
      () => _client.post(
        _uri('/api/messages'),
        headers: {
          'Content-Type': _jsonLd,
          'Accept': _jsonLd,
          'Authorization': 'Bearer $token',
        },
        // Volontairement ni « user » ni « datePoste » : c'est le serveur
        // qui les fixe a partir du JWT.
        body: jsonEncode({'titre': titre.trim(), 'contenu': contenu.trim()}),
      ),
    );
    if (response.statusCode == 201) return;
    if (response.statusCode == 401) throw UnauthorizedException();
    if (response.statusCode == 422) {
      final violations = _json(response)['violations'] as List? ?? const [];
      throw ValidationException({
        for (final v in violations.whereType<Map>())
          '${v['propertyPath'] ?? ''}': '${v['message'] ?? ''}',
      });
    }
    _fail(response);
  }
}

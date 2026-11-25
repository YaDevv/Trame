import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forum_app/demo_api/demo_app.dart';
import 'package:forum_app/demo_api/demo_session.dart';
import 'package:forum_app/demo_api/forum_api.dart';
import 'package:forum_app/demo_api/jwt.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Un JWT au format de LexikJWT (la signature n'est pas verifiee ici).
String _jwt({List<String> roles = const ['ROLE_USER']}) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'typ': 'JWT', 'alg': 'RS256'})}.'
      '${part({'iat': 1794990000, 'exp': 1794993600, 'roles': roles, 'username': 'lea@forum.fr'})}'
      '.signature';
}

void main() {
  group('client HTTP de l’API', () {
    late List<http.Request> sent;

    HttpForumApi apiAnswering(http.Response Function(http.Request) reply) {
      sent = [];
      return HttpForumApi(
        baseUrl: 'https://api.test/forum/',
        client: MockClient((request) async {
          sent.add(request);
          return reply(request);
        }),
      );
    }

    test('la connexion envoie email et mot de passe et reçoit un JWT', () async {
      final token = _jwt(roles: ['ROLE_ADMIN', 'ROLE_USER']);
      final api = apiAnswering(
        (_) => http.Response(
          jsonEncode({
            'token': token,
            'data': {
              'id': 7,
              'roles': ['ROLE_ADMIN', 'ROLE_USER'],
              'nom': 'Martin',
              'prenom': 'Léa',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      final session = await api.login(email: ' lea@forum.fr ', password: 'x');

      expect(sent.single.method, 'POST');
      expect(
        sent.single.url.toString(),
        'https://api.test/forum/api/authentication_token',
      );
      expect(jsonDecode(sent.single.body), {
        'email': 'lea@forum.fr',
        'password': 'x',
      });
      expect(session.token, token);
      expect(session.userId, 7);
      expect(session.prenom, 'Léa');
      expect(session.isAdmin, isTrue);
      expect(session.claims.username, 'lea@forum.fr');
    });

    test('un mauvais mot de passe est signalé', () async {
      final api = apiAnswering(
        (_) => http.Response('{"code":401,"message":"Invalid credentials."}', 401),
      );
      expect(
        api.login(email: 'a@b.fr', password: 'faux'),
        throwsA(isA<InvalidCredentialsException>()),
      );
    });

    test('le profil est demandé avec le jeton Bearer', () async {
      final api = apiAnswering(
        (_) => http.Response(
          jsonEncode({
            '@id': '/forum/api/users/7',
            'id': 7,
            'email': 'lea@forum.fr',
            'nom': 'Martin',
            'prenom': 'Léa',
          }),
          200,
          headers: {'content-type': 'application/ld+json; charset=utf-8'},
        ),
      );

      final user = await api.fetchUser(id: 7, token: 'abc.def.ghi');

      expect(sent.single.method, 'GET');
      expect(sent.single.url.path, '/forum/api/users/7');
      expect(sent.single.headers['Authorization'], 'Bearer abc.def.ghi');
      expect(user.email, 'lea@forum.fr');
      expect(user.prenom, 'Léa');
    });

    test('un jeton refusé lève UnauthorizedException', () async {
      final api = apiAnswering(
        (_) => http.Response('{"code":401,"message":"Expired JWT Token"}', 401),
      );
      expect(
        api.fetchUser(id: 7, token: 'vieux'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('l’inscription envoie les champs de l’entité User', () async {
      final api = apiAnswering((_) => http.Response('{}', 201));

      await api.register(
        prenom: 'Léa',
        nom: 'Martin',
        email: 'lea@forum.fr',
        password: 'MotDePasse!2026',
      );

      expect(sent.single.url.path, '/forum/api/users');
      expect(sent.single.headers['Content-Type'], contains('application/ld+json'));
      expect(jsonDecode(sent.single.body), {
        'prenom': 'Léa',
        'nom': 'Martin',
        'email': 'lea@forum.fr',
        'password': 'MotDePasse!2026',
      });
    });

    test('les erreurs de validation de l’API sont remontées', () async {
      final api = apiAnswering(
        (_) => http.Response(
          jsonEncode({
            'violations': [
              {'propertyPath': 'email', 'message': 'L\'email n\'est pas valide.'},
            ],
          }),
          422,
        ),
      );
      try {
        await api.register(prenom: 'A', nom: 'B', email: 'x', password: 'y');
        fail('une ValidationException était attendue');
      } on ValidationException catch (e) {
        expect(e.messages['email'], 'L\'email n\'est pas valide.');
      }
    });

    test('une API injoignable est signalée', () async {
      sent = [];
      final api = HttpForumApi(
        baseUrl: 'https://api.test/forum',
        client: MockClient((_) async => throw http.ClientException('CORS')),
      );
      expect(
        api.login(email: 'a@b.fr', password: 'x'),
        throwsA(isA<ApiUnavailableException>()),
      );
    });

    test('les messages sont lus avec le jeton, au format API Platform', () async {
      final api = apiAnswering(
        (_) => http.Response(
          jsonEncode({
            'member': [
              {
                'id': 31,
                'titre': 'Bienvenue',
                'contenu': 'Premier message',
                'datePoste': '2026-11-18T10:00:00+00:00',
                'user': {'nom': 'Martin', 'prenom': 'Léa'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/ld+json; charset=utf-8'},
        ),
      );

      final messages = await api.fetchMessages(token: 'abc');

      expect(sent.single.method, 'GET');
      expect(sent.single.url.path, '/forum/api/messages');
      expect(sent.single.headers['Authorization'], 'Bearer abc');
      expect(messages.single.titre, 'Bienvenue');
      expect(messages.single.auteur, 'Léa Martin');
      expect(messages.single.datePoste!.toUtc(), DateTime.utc(2026, 11, 18, 10));
    });

    test('l’ancien format hydra:member est aussi compris', () async {
      final api = apiAnswering(
        (_) => http.Response(
          jsonEncode({
            'hydra:member': [
              {'id': 1, 'titre': 'A', 'contenu': 'B'},
            ],
          }),
          200,
        ),
      );
      final messages = await api.fetchMessages(token: 'abc');
      expect(messages.single.auteur, 'Membre');
    });

    test('un message envoyé ne contient ni auteur ni date', () async {
      final api = apiAnswering((_) => http.Response('{}', 201));

      await api.createMessage(
        titre: ' Mon titre ',
        contenu: 'Mon texte',
        token: 'abc',
      );

      expect(sent.single.method, 'POST');
      expect(sent.single.url.path, '/forum/api/messages');
      expect(sent.single.headers['Authorization'], 'Bearer abc');
      // L'auteur vient du JWT côté serveur : jamais du client.
      expect(jsonDecode(sent.single.body), {
        'titre': 'Mon titre',
        'contenu': 'Mon texte',
      });
    });

    test('un visiteur lit les messages sans jeton', () async {
      final api = apiAnswering(
        (_) => http.Response(jsonEncode({'member': []}), 200),
      );
      await api.fetchMessages();
      expect(sent.single.headers.containsKey('Authorization'), isFalse);
    });

    test('toutes les pages de messages sont lues', () async {
      final api = apiAnswering((request) {
        final page = request.url.queryParameters['page'] ?? '1';
        return http.Response(
          jsonEncode({
            'member': [
              {'id': page == '1' ? 1 : 2, 'titre': 'T$page', 'contenu': 'C'},
            ],
            if (page == '1') 'view': {'next': '/forum/api/messages?page=2'},
          }),
          200,
        );
      });

      final messages = await api.fetchMessages();

      expect(sent.map((r) => r.url.toString()), [
        'https://api.test/forum/api/messages',
        'https://api.test/forum/api/messages?page=2',
      ]);
      expect(messages.map((m) => m.id), [1, 2]);
    });

    test('les réponses sont comptées sous leur discussion', () {
      ApiMessage message(int id, {int? parent}) => ApiMessage(
        id: id,
        titre: 'T$id',
        contenu: 'C',
        auteur: 'A',
        parentId: parent,
      );
      final discussions = discussionsFrom([
        message(5),
        message(4, parent: 1),
        message(3, parent: 1),
        message(2, parent: 5),
        message(1),
      ]);
      expect(discussions.map((d) => d.message.id), [5, 1]);
      expect(discussions.map((d) => d.replyCount), [1, 2]);
    });

    test('le parent est lu sous ses deux formes', () {
      expect(
        ApiMessage.fromJson({'id': 2, 'parent': {'id': 1}}).parentId,
        1,
      );
      expect(
        ApiMessage.fromJson({'id': 2, 'parent': '/forum/api/messages/7'})
            .parentId,
        7,
      );
      expect(ApiMessage.fromJson({'id': 2}).parentId, isNull);
    });

    test('le contenu du JWT est lisible', () {
      final claims = JwtClaims.decode(_jwt(roles: ['ROLE_USER']));
      expect(claims.roles, ['ROLE_USER']);
      expect(claims.username, 'lea@forum.fr');
      expect(claims.expiresAt!.difference(claims.issuedAt!).inHours, 1);
    });
  });

  group('parcours de la démo', () {
    late _FakeApi api;
    late DemoSession session;

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      session = DemoSession();
      await tester.pumpWidget(DemoApp(api: api, session: session));
      await tester.pumpAndSettle();
    }

    Finder tab(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

    Future<void> goTo(WidgetTester tester, String label) async {
      await tester.tap(tab(label));
      await tester.pumpAndSettle();
    }

    Future<void> tapButton(WidgetTester tester, String label) async {
      final button = find.widgetWithText(FilledButton, label);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    /// Ouvre l'onglet Connexion si besoin, puis se connecte.
    Future<void> signIn(WidgetTester tester, {String password = 'bon'}) async {
      if (tab('Connexion').evaluate().isNotEmpty) {
        await goTo(tester, 'Connexion');
      }
      await tester.enterText(find.byType(TextFormField).at(0), 'lea@forum.fr');
      await tester.enterText(find.byType(TextFormField).at(1), password);
      await tapButton(tester, 'Se connecter');
    }

    Future<void> signOut(WidgetTester tester) async {
      await goTo(tester, 'Profil');
      final button = find.text('Se déconnecter');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    /// Aucun vocabulaire technique ne doit apparaître à l'écran.
    void expectNoTechnicalWords() {
      final technical = RegExp(
        r'JWT|jeton|token|ROLE_|Bearer|endpoint|/api|\bAPI\b|'
        r'\bGET\b|\bPOST\b|HTTP|Identifiant|Expire|\b401\b|\b422\b',
      );
      final shown = find.byWidgetPredicate((widget) {
        final text = switch (widget) {
          Text(:final data?) => data,
          RichText(:final text) => text.toPlainText(),
          _ => null,
        };
        return text != null &&
            (technical.hasMatch(text) ||
                RegExp(r'jeton|token', caseSensitive: false).hasMatch(text));
      });
      expect(shown, findsNothing);
    }

    setUp(() => api = _FakeApi());

    testWidgets('un visiteur lit l’accueil mais ne peut pas écrire', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Discussions récentes'), findsOneWidget);
      expect(find.text('Bienvenue sur le forum'), findsOneWidget);
      expect(tab('Accueil'), findsOneWidget);
      expect(tab('Connexion'), findsOneWidget);
      expect(tab('Écrire'), findsNothing);
      expect(tab('Profil'), findsNothing);
      // Lecture sans jeton, et aucun profil demandé.
      expect(api.lastMessagesToken, isNull);
      expect(api.fetchCalls, 0);
      expectNoTechnicalWords();
    });

    testWidgets('le bandeau du visiteur mène à la connexion', (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
      await tester.pumpAndSettle();
      expect(find.text('Adresse email'), findsOneWidget);
    });

    testWidgets('la connexion ouvre l’espace membre', (tester) async {
      await pump(tester);
      await signIn(tester);

      expect(session.isSignedIn, isTrue);
      expect(tab('Accueil'), findsOneWidget);
      expect(tab('Écrire'), findsOneWidget);
      expect(tab('Profil'), findsOneWidget);
      expect(tab('Connexion'), findsNothing);
      // L'accueil est chargé avec le jeton de la session.
      expect(api.lastMessagesToken, session.current!.token);
      expectNoTechnicalWords();
    });

    testWidgets('l’accueil montre les discussions et leurs réponses', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Bienvenue sur le forum'), findsOneWidget);
      expect(find.text('Alex Admin'), findsOneWidget);
      expect(find.text('2 réponses'), findsOneWidget);
      // Les réponses ne sont pas listées comme des discussions.
      expect(find.text('Une réponse'), findsNothing);
    });

    testWidgets('un mauvais mot de passe reste sur la connexion', (
      tester,
    ) async {
      await pump(tester);
      await signIn(tester, password: 'faux');

      expect(
        find.text('Adresse email ou mot de passe incorrect.'),
        findsOneWidget,
      );
      expect(session.isSignedIn, isFalse);
      expectNoTechnicalWords();
    });

    testWidgets('le profil d’un membre est lisible et sans détail technique', (
      tester,
    ) async {
      await pump(tester);
      await signIn(tester);
      await goTo(tester, 'Profil');

      expect(find.text('Mon profil'), findsOneWidget);
      expect(find.text('Léa Martin'), findsOneWidget);
      expect(find.text('lea@forum.fr'), findsNWidgets(2));
      expect(find.text('Membre'), findsNWidgets(2));
      expect(find.text('Administrateur'), findsNothing);
      expect(find.text('Se déconnecter'), findsOneWidget);
      // Le profil a bien été lu avec le jeton de la session.
      expect(api.fetchCalls, 1);
      expect(api.lastToken, session.current!.token);
      expectNoTechnicalWords();
    });

    testWidgets('un compte admin affiche « Administrateur »', (tester) async {
      api.roles = ['ROLE_ADMIN', 'ROLE_USER'];
      await pump(tester);
      await signIn(tester);
      await goTo(tester, 'Profil');

      expect(find.text('Administrateur'), findsNWidgets(2));
      expect(find.text('Membre'), findsNothing);
      expectNoTechnicalWords();
    });

    testWidgets('se déconnecter revient au visiteur, puis on se reconnecte', (
      tester,
    ) async {
      await pump(tester);
      await signIn(tester);
      await signOut(tester);

      expect(session.current, isNull);
      expect(find.textContaining('Tu es déconnecté'), findsOneWidget);
      expect(tab('Écrire'), findsNothing);
      expect(tab('Profil'), findsNothing);
      expectNoTechnicalWords();

      await signIn(tester);
      expect(session.isSignedIn, isTrue);
      expect(tab('Écrire'), findsOneWidget);
    });

    testWidgets('une session expirée ramène à la connexion', (tester) async {
      api.tokenRejected = true;
      await pump(tester);
      await signIn(tester);

      expect(session.isSignedIn, isFalse);
      expect(find.textContaining('Ta session a expiré'), findsOneWidget);
      expectNoTechnicalWords();
    });

    testWidgets('écrire un message l’ajoute en haut de l’accueil', (
      tester,
    ) async {
      await pump(tester);
      await signIn(tester);

      await goTo(tester, 'Écrire');
      expect(find.text('Nouveau message'), findsOneWidget);
      expect(find.text('Titre'), findsOneWidget);
      expect(find.text('Votre message'), findsOneWidget);
      expectNoTechnicalWords();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Mon premier message');
      await tester.enterText(fields.at(1), 'Bonjour à tous !');
      await tapButton(tester, 'Publier');

      expect(api.created, [('Mon premier message', 'Bonjour à tous !')]);
      expect(find.text('Nouveau message'), findsNothing);
      expect(find.text('Message publié.'), findsOneWidget);
      expect(find.text('Mon premier message'), findsOneWidget);
      // L'auteur affiché est le compte connecté (fixé par le serveur).
      expect(find.text('Léa Martin'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Mon premier message')).dy,
        lessThan(tester.getTopLeft(find.text('Bienvenue sur le forum')).dy),
      );
    });

    testWidgets('un message sans titre n’est pas envoyé', (tester) async {
      await pump(tester);
      await signIn(tester);
      await goTo(tester, 'Écrire');

      await tester.enterText(find.byType(TextFormField).at(1), 'Texte seul');
      await tapButton(tester, 'Publier');

      expect(api.created, isEmpty);
      expect(find.text('Donne un titre à ton message.'), findsOneWidget);
    });

    testWidgets('après déconnexion, on ne peut plus écrire', (tester) async {
      await pump(tester);
      await signIn(tester);
      expect(tab('Écrire'), findsOneWidget);

      session.signOut();
      await tester.pumpAndSettle();

      expect(tab('Écrire'), findsNothing);
      expect(tab('Connexion'), findsOneWidget);
    });

    group('inscription', () {
      Future<void> openRegister(WidgetTester tester) async {
        await pump(tester);
        await goTo(tester, 'Connexion');
        final link = find.widgetWithText(TextButton, 'Créer un compte');
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pumpAndSettle();
      }

      Future<void> fill(
        WidgetTester tester, {
        String password = 'MotDePasse!2026',
      }) async {
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Léa');
        await tester.enterText(fields.at(1), 'Martin');
        await tester.enterText(fields.at(2), 'lea@forum.fr');
        await tester.enterText(fields.at(3), password);
        await tester.enterText(fields.at(4), password);
      }

      testWidgets('un compte créé renvoie à la connexion', (tester) async {
        await openRegister(tester);
        expectNoTechnicalWords();
        await fill(tester);
        await tapButton(tester, 'S’inscrire');

        expect(api.registered, ['lea@forum.fr']);
        expect(find.textContaining('Ton compte est créé'), findsOneWidget);
        final email = tester.widget<TextFormField>(
          find.byType(TextFormField).at(0),
        );
        expect(email.controller!.text, 'lea@forum.fr');
      });

      testWidgets('la règle de mot de passe est vérifiée', (tester) async {
        await openRegister(tester);
        await fill(tester, password: 'court');
        await tapButton(tester, 'S’inscrire');

        expect(api.registered, isEmpty);
        expect(find.textContaining('Au moins 12 caractères'), findsOneWidget);
      });

      testWidgets('un refus du serveur est affiché simplement', (
        tester,
      ) async {
        api.registerError = const ValidationException({
          'email': 'Cet email est déjà utilisé.',
        });
        await openRegister(tester);
        await fill(tester);
        await tapButton(tester, 'S’inscrire');

        expect(find.text('Cet email est déjà utilisé.'), findsOneWidget);
      });

      testWidgets('des inscriptions fermées sont expliquées sans jargon', (
        tester,
      ) async {
        api.registerError = UnauthorizedException();
        await openRegister(tester);
        await fill(tester);
        await tapButton(tester, 'S’inscrire');

        expect(
          find.textContaining('inscriptions sont momentanément fermées'),
          findsOneWidget,
        );
        expectNoTechnicalWords();
      });
    });
  });
}

class _FakeApi implements ForumApi {
  List<String> roles = const ['ROLE_USER'];
  bool tokenRejected = false;
  Exception? registerError;
  final registered = <String>[];
  int fetchCalls = 0;
  String? lastToken;
  int messageCalls = 0;
  String? lastMessagesToken;
  final created = <(String, String)>[];
  final messages = <ApiMessage>[
    ApiMessage(
      id: 3,
      titre: 'Réponse',
      contenu: 'Une réponse',
      auteur: 'Sam Demo',
      datePoste: DateTime(2026, 11, 18, 10),
      parentId: 1,
    ),
    ApiMessage(
      id: 2,
      titre: 'Réponse',
      contenu: 'Une autre réponse',
      auteur: 'Sam Demo',
      datePoste: DateTime(2026, 11, 18, 9, 30),
      parentId: 1,
    ),
    ApiMessage(
      id: 1,
      titre: 'Bienvenue sur le forum',
      contenu: 'Premier message de démonstration.',
      auteur: 'Alex Admin',
      datePoste: DateTime(2026, 11, 18, 9),
    ),
  ];

  @override
  Future<List<ApiMessage>> fetchMessages({String? token}) async {
    messageCalls++;
    lastMessagesToken = token;
    return List.of(messages);
  }

  @override
  Future<void> createMessage({
    required String titre,
    required String contenu,
    required String token,
  }) async {
    created.add((titre, contenu));
    messages.insert(
      0,
      ApiMessage(
        id: 100 + messages.length,
        titre: titre,
        contenu: contenu,
        auteur: 'Léa Martin',
        datePoste: DateTime.now(),
      ),
    );
  }

  @override
  Future<ApiSession> login({
    required String email,
    required String password,
  }) async {
    if (password != 'bon') throw InvalidCredentialsException();
    return ApiSession(
      token: _jwt(roles: roles),
      userId: 7,
      roles: roles,
      prenom: 'Léa',
      nom: 'Martin',
    );
  }

  @override
  Future<void> register({
    required String prenom,
    required String nom,
    required String email,
    required String password,
  }) async {
    final error = registerError;
    if (error != null) throw error;
    registered.add(email);
  }

  @override
  Future<ApiUser> fetchUser({required int id, required String token}) async {
    fetchCalls++;
    lastToken = token;
    if (tokenRejected) throw UnauthorizedException();
    return const ApiUser(
      id: 7,
      email: 'lea@forum.fr',
      prenom: 'Léa',
      nom: 'Martin',
    );
  }
}

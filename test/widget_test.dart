import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forum_app/app/app.dart';
import 'package:forum_app/core/session.dart';
import 'package:forum_app/core/time_ago.dart';
import 'package:forum_app/models/discussion.dart';
import 'package:forum_app/models/message.dart';
import 'package:forum_app/models/user.dart';
import 'package:forum_app/repositories/demo/demo_auth_repository.dart';
import 'package:forum_app/repositories/discussion_repository.dart';

const _author = User(id: '1', displayName: 'Marc', role: UserRole.member);
const _admin = User(id: '2', displayName: 'Inès', role: UserRole.admin);
const _lea = User(id: '3', displayName: 'Léa', role: UserRole.member);

Discussion _discussion({
  String id = '1',
  MessageDeletion? deletion,
  String? title = 'Un titre',
  String? content = 'Le contenu écrit',
  User author = _author,
}) {
  final date = DateTime(2026, 1, 1);
  return Discussion(
    id: id,
    title: title,
    opening: Message(
      id: 'm$id',
      author: author,
      content: content,
      createdAt: date,
      deletion: deletion,
    ),
    replyCount: 3,
    lastActivityAt: date,
  );
}

class _FakeRepository implements DiscussionRepository {
  _FakeRepository({
    List<Discussion> items = const [],
    this.fails = false,
    Map<String, List<Message>>? replies,
  }) : items = List.of(items),
       replies = replies ?? {};

  final List<Discussion> items;
  final Map<String, List<Message>> replies;
  bool fails;
  final filters = <DiscussionFilter>[];

  @override
  Future<List<Discussion>> fetchDiscussions(DiscussionFilter filter) async {
    filters.add(filter);
    if (fails) throw Exception('réseau');
    return items;
  }

  @override
  Future<List<Discussion>> searchDiscussions(String query) async {
    return items.where((d) => (d.title ?? '').contains(query)).toList();
  }

  @override
  Future<List<Discussion>> fetchMyDiscussions(String userId) async {
    return items.where((d) => d.opening.author.id == userId).toList();
  }

  @override
  Future<Discussion> createDiscussion({
    required String title,
    required String content,
    required User author,
  }) async {
    final discussion = Discussion(
      id: 'nouvelle',
      title: title.trim(),
      opening: Message(
        id: 'm-nouvelle',
        author: author,
        content: content.trim(),
        createdAt: DateTime.now(),
      ),
      replyCount: 0,
      lastActivityAt: DateTime.now(),
    );
    items.insert(0, discussion);
    return discussion;
  }

  @override
  Future<DiscussionThread> fetchThread(String discussionId) async {
    return DiscussionThread(
      discussion: items.firstWhere((d) => d.id == discussionId),
      replies: List.of(replies[discussionId] ?? const []),
    );
  }

  @override
  Future<Message> postReply({
    required String discussionId,
    required String content,
    required User author,
  }) async {
    final reply = Message(
      id: 'nouvelle',
      author: author,
      content: content,
      createdAt: DateTime(2026, 1, 3),
    );
    replies.putIfAbsent(discussionId, () => []).add(reply);
    return reply;
  }

  /// Textes gardes apres une suppression douce.
  final archived = <String, String>{};
  bool failsChanges = false;

  /// Remplace un message, apres la meme verification d'auteur que l'API.
  Message _change(
    String discussionId,
    String messageId,
    User author,
    Message Function(Message) update,
  ) {
    if (failsChanges) throw Exception('réseau');
    final index = items.indexWhere((d) => d.id == discussionId);
    final discussion = items[index];
    if (discussion.opening.id == messageId) {
      if (discussion.opening.author.id != author.id) {
        throw MessageActionForbiddenException();
      }
      final updated = update(discussion.opening);
      items[index] = discussion.withOpening(updated);
      return updated;
    }
    final list = replies[discussionId]!;
    final i = list.indexWhere((m) => m.id == messageId);
    if (list[i].author.id != author.id) throw MessageActionForbiddenException();
    return list[i] = update(list[i]);
  }

  @override
  Future<Message> editMessage({
    required String discussionId,
    required String messageId,
    required String content,
    required User author,
  }) async {
    return _change(
      discussionId,
      messageId,
      author,
      (m) => m.edited(content, DateTime(2026, 1, 4)),
    );
  }

  @override
  Future<Message> deleteMessage({
    required String discussionId,
    required String messageId,
    required User author,
  }) async {
    return _change(discussionId, messageId, author, (m) {
      archived[m.id] = m.content ?? '';
      return m.deleted(
        MessageDeletion(
          source: DeletionSource.author,
          deletedAt: DateTime(2026, 1, 4),
        ),
      );
    });
  }

  /// Le message tel qu'il est stocke.
  Message message(String discussionId, String messageId) {
    final discussion = items.firstWhere((d) => d.id == discussionId);
    if (discussion.opening.id == messageId) return discussion.opening;
    return replies[discussionId]!.firstWhere((m) => m.id == messageId);
  }
}

Future<void> _pumpApp(
  WidgetTester tester,
  DiscussionRepository repository,
  SessionController session,
) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ForumApp(
      discussions: repository,
      auth: DemoAuthRepository(),
      session: session,
    ),
  );
  await tester.pumpAndSettle();
}

/// Un onglet de la barre du bas.
Finder _tab(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

int _selectedTab(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

Future<void> _goTo(WidgetTester tester, String label) async {
  await tester.tap(_tab(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('un visiteur n a que trois onglets', (tester) async {
    await _pumpApp(
      tester,
      _FakeRepository(items: [_discussion()]),
      SessionController(),
    );

    expect(find.text('Un titre'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(_tab('Connexion'), findsOneWidget);
    expect(_tab('Écrire'), findsNothing);
    expect(_tab('Profil'), findsNothing);
    expect(_tab('Modération'), findsNothing);
  });

  testWidgets('un utilisateur a Écrire, Mes fils et Profil', (tester) async {
    final session = SessionController()..signIn(_author);
    await _pumpApp(tester, _FakeRepository(items: [_discussion()]), session);

    expect(_tab('Écrire'), findsOneWidget);
    expect(_tab('Mes fils'), findsOneWidget);
    expect(_tab('Profil'), findsOneWidget);
    expect(_tab('Connexion'), findsNothing);
    expect(_tab('Modération'), findsNothing);
  });

  group('écrire', () {
    Future<void> openComposer(WidgetTester tester, _FakeRepository repo) async {
      await _pumpApp(tester, repo, SessionController()..signIn(_author));
      await _goTo(tester, 'Écrire');
    }

    Finder field(int index) => find.byType(TextField).at(index);

    testWidgets('fermer un écran vide ne demande rien', (tester) async {
      await openComposer(tester, _FakeRepository());
      expect(find.text('Nouvelle discussion'), findsOneWidget);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle discussion'), findsNothing);
      expect(_selectedTab(tester), 0);
    });

    testWidgets('un brouillon demande confirmation', (tester) async {
      await openComposer(tester, _FakeRepository());
      await tester.enterText(field(0), 'Un brouillon');
      // Laisse passer la recherche de discussions similaires.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(find.text('Abandonner ce brouillon ?'), findsOneWidget);

      await tester.tap(find.text('Continuer à écrire'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle discussion'), findsOneWidget);
    });

    testWidgets('un titre trop court est refusé', (tester) async {
      final repo = _FakeRepository();
      await openComposer(tester, repo);
      await tester.enterText(field(0), 'Oui');
      await tester.enterText(field(1), 'Un message assez long.');
      await tester.tap(find.text('Publier'));
      await tester.pumpAndSettle();

      expect(find.textContaining('au moins 5 caractères'), findsOneWidget);
      expect(repo.items, isEmpty);
    });

    testWidgets('propose les discussions similaires', (tester) async {
      final repo = _FakeRepository(
        items: [_discussion(title: 'Débuter avec Flutter')],
      );
      await openComposer(tester, repo);
      await tester.enterText(field(0), 'Débuter avec Flutter');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Discussions similaires'), findsOneWidget);
    });

    testWidgets('l aperçu montre la discussion comme dans le fil', (
      tester,
    ) async {
      await openComposer(tester, _FakeRepository());
      await tester.enterText(field(0), 'Titre test');
      await tester.enterText(field(1), 'Un message de test.');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Aperçu'));
      await tester.pumpAndSettle();

      expect(find.text('Aperçu dans le fil'), findsOneWidget);
      expect(find.text('Un message de test.'), findsWidgets);
    });

    testWidgets('publier ouvre la discussion et l ajoute à l accueil', (
      tester,
    ) async {
      final repo = _FakeRepository(items: [_discussion()]);
      await openComposer(tester, repo);
      await tester.enterText(field(0), 'Ma nouvelle question');
      await tester.enterText(field(1), 'Voici le détail de ma question.');
      await tester.tap(find.text('Publier'));
      await tester.pumpAndSettle();

      // La discussion publiee s'ouvre directement.
      expect(find.text('Discussion'), findsOneWidget);
      expect(find.text('Voici le détail de ma question.'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Ma nouvelle question'), findsOneWidget);
    });
  });

  testWidgets('seul un admin a la Modération, et se déconnecte', (
    tester,
  ) async {
    final session = SessionController()..signIn(_admin);
    await _pumpApp(tester, _FakeRepository(), session);

    expect(_tab('Modération'), findsOneWidget);
    expect(_tab('Mes fils'), findsNothing);

    await _goTo(tester, 'Profil');
    // La liste du profil ne construit pas les lignes hors de l'ecran.
    final signOut = find.text('Se déconnecter');
    await tester.dragUntilVisible(
      signOut,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();
    // Confirmation avant la deconnexion.
    expect(find.text('Se déconnecter ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Se déconnecter'));
    await tester.pumpAndSettle();
    expect(_tab('Connexion'), findsOneWidget);
    expect(_selectedTab(tester), 0);
  });

  testWidgets('le profil montre les chiffres et les sections', (tester) async {
    final session = SessionController()..signIn(_author);
    await _pumpApp(
      tester,
      _FakeRepository(
        items: [_discussion(), _discussion(id: '2', title: 'Autre')],
      ),
      session,
    );

    await _goTo(tester, 'Profil');
    expect(find.text('Membre'), findsOneWidget);
    expect(find.text('Discussions ouvertes'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Paramètres'), findsOneWidget);
    // Un membre ne voit pas l administration.
    expect(find.text('Utilisateurs'), findsNothing);
  });

  testWidgets('un message supprimé par son auteur n affiche que la mention', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      _FakeRepository(
        items: [
          _discussion(
            deletion: MessageDeletion(
              source: DeletionSource.author,
              deletedAt: DateTime(2026, 1, 2),
            ),
          ),
        ],
      ),
      SessionController(),
    );

    expect(find.text('Message supprimé par l’utilisateur.'), findsOneWidget);
    expect(find.text('Discussion supprimée par l’utilisateur'), findsOneWidget);
    // Meme si le contenu arrivait, il n'est jamais affiche.
    expect(find.text('Le contenu écrit'), findsNothing);
    expect(find.text('Un titre'), findsNothing);
  });

  testWidgets('un contenu modéré remplace le titre', (tester) async {
    await _pumpApp(
      tester,
      _FakeRepository(
        items: [
          _discussion(
            title: null,
            content: null,
            deletion: MessageDeletion(
              source: DeletionSource.moderation,
              deletedAt: DateTime(2026, 1, 2),
            ),
          ),
        ],
      ),
      SessionController(),
    );

    expect(find.text('Discussion retirée par la modération'), findsOneWidget);
    expect(find.text('Message supprimé par la modération.'), findsOneWidget);
  });

  testWidgets('la dernière activité nomme la personne', (tester) async {
    await _pumpApp(
      tester,
      _FakeRepository(
        items: [
          Discussion(
            id: '2',
            title: 'Actif',
            opening: Message(
              id: 'm2',
              author: _author,
              content: 'x',
              createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            ),
            replyCount: 12,
            lastReplier: _admin,
            lastActivityAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        ],
      ),
      SessionController(),
    );

    expect(
      find.textContaining('dernière de Inès il y a 5 min', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Nouveau'), findsOneWidget);
  });

  testWidgets('un filtre recharge la liste', (tester) async {
    final repository = _FakeRepository(items: [_discussion()]);
    await _pumpApp(tester, repository, SessionController());

    await tester.ensureVisible(find.text('Sans réponse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sans réponse'));
    await tester.pumpAndSettle();

    expect(repository.filters.last, DiscussionFilter.unanswered);
  });

  testWidgets('une erreur propose de réessayer', (tester) async {
    final repository = _FakeRepository(items: [_discussion()], fails: true);
    await _pumpApp(tester, repository, SessionController());
    expect(find.widgetWithText(FilledButton, 'Réessayer'), findsOneWidget);

    repository.fails = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Un titre'), findsOneWidget);
  });

  testWidgets('la recherche filtre les discussions', (tester) async {
    await _pumpApp(
      tester,
      _FakeRepository(
        items: [
          _discussion(title: 'Flutter et Dart'),
          _discussion(id: '2', title: 'Autre sujet'),
        ],
      ),
      SessionController(),
    );

    await _goTo(tester, 'Rechercher');
    await tester.enterText(find.byType(TextField), 'Flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Flutter et Dart'), findsOneWidget);
    expect(find.text('Autre sujet'), findsNothing);
  });

  testWidgets('Mes fils ne montre que mes discussions', (tester) async {
    final session = SessionController()..signIn(_author);
    await _pumpApp(
      tester,
      _FakeRepository(
        items: [
          _discussion(),
          _discussion(id: '2', title: 'Sujet d Inès', author: _admin),
        ],
      ),
      session,
    );

    await _goTo(tester, 'Mes fils');
    expect(find.text('Un titre'), findsOneWidget);
    expect(find.text('Sujet d Inès'), findsNothing);
  });

  group('discussion', () {
    final firstReply = Message(
      id: 'r1',
      author: _admin,
      content: 'Première réponse',
      createdAt: DateTime(2026, 1, 2),
    );

    Future<void> openFirst(WidgetTester tester, SessionController session) async {
      await _pumpApp(
        tester,
        _FakeRepository(
          items: [_discussion()],
          replies: {
            '1': [firstReply],
          },
        ),
        session,
      );
      await tester.tap(find.text('Un titre'));
      await tester.pumpAndSettle();
    }

    testWidgets('montre le message principal et les réponses', (tester) async {
      await openFirst(tester, SessionController());
      expect(find.text('Le contenu écrit'), findsOneWidget);
      expect(find.text('Première réponse'), findsOneWidget);
      expect(find.text('1 réponse'), findsOneWidget);
    });

    testWidgets('les réponses récentes sont en haut', (tester) async {
      await _pumpApp(
        tester,
        _FakeRepository(
          items: [_discussion()],
          replies: {
            '1': [
              firstReply,
              Message(
                id: 'r2',
                author: _author,
                content: 'Réponse récente',
                createdAt: DateTime(2026, 1, 5),
              ),
              Message(
                id: 'r3',
                author: _admin,
                content: 'Texte retiré',
                createdAt: DateTime(2026, 1, 4),
                deletion: MessageDeletion(
                  source: DeletionSource.author,
                  deletedAt: DateTime(2026, 1, 6),
                ),
              ),
            ],
          },
        ),
        SessionController(),
      );
      await tester.tap(find.text('Un titre'));
      await tester.pumpAndSettle();

      final recent = tester.getTopLeft(find.text('Réponse récente')).dy;
      final deleted =
          tester.getTopLeft(find.text('Message supprimé par l’utilisateur.')).dy;
      final oldest = tester.getTopLeft(find.text('Première réponse')).dy;
      expect(recent, lessThan(deleted));
      expect(deleted, lessThan(oldest));
      expect(find.text('Texte retiré'), findsNothing);
    });

    testWidgets('un visiteur est invité à se connecter', (tester) async {
      await openFirst(tester, SessionController());
      expect(
        find.text('Connecte-toi pour répondre à cette discussion.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('un utilisateur répond et voit sa réponse', (tester) async {
      await openFirst(tester, SessionController()..signIn(_author));
      await tester.enterText(find.byType(TextField), 'Ma réponse');
      await tester.pump();
      await tester.tap(find.byTooltip('Envoyer la réponse'));
      await tester.pumpAndSettle();

      expect(find.text('Ma réponse'), findsOneWidget);
      expect(find.text('2 réponses'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('se connecter depuis la discussion y ramène', (tester) async {
      await openFirst(tester, SessionController());
      await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'yanis@trame.demo');
      await tester.enterText(find.byType(TextFormField).at(1), 'demo-yanis-2026');
      await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Première réponse'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('une discussion modérée est fermée', (tester) async {
      await _pumpApp(
        tester,
        _FakeRepository(
          items: [
            _discussion(
              title: null,
              content: null,
              deletion: MessageDeletion(
                source: DeletionSource.moderation,
                deletedAt: DateTime(2026, 1, 2),
              ),
            ),
          ],
        ),
        SessionController()..signIn(_author),
      );
      await tester.tap(find.text('Discussion retirée par la modération'));
      await tester.pumpAndSettle();

      expect(
        find.text('Cette discussion a été fermée par la modération.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('modifier et supprimer ses messages', () {
    // Marc a ouvert la discussion et y a répondu ; Inès aussi a répondu.
    late _FakeRepository repository;

    Future<SessionController> openThread(
      WidgetTester tester, {
      User? user = _author,
    }) async {
      repository = _FakeRepository(
        items: [_discussion()],
        replies: {
          '1': [
            Message(
              id: 'r1',
              author: _author,
              content: 'Ma première réponse',
              createdAt: DateTime(2026, 1, 2),
            ),
            Message(
              id: 'r2',
              author: _admin,
              content: 'Réponse d Inès',
              createdAt: DateTime(2026, 1, 3),
            ),
          ],
        },
      );
      final session = SessionController();
      if (user != null) session.signIn(user);
      await _pumpApp(tester, repository, session);
      await tester.tap(find.text('Un titre'));
      await tester.pumpAndSettle();
      return session;
    }

    Finder actions(String messageId) => find.byKey(ValueKey('actions-$messageId'));

    Future<void> choose(WidgetTester tester, String messageId, String action) async {
      await tester.ensureVisible(actions(messageId));
      await tester.pumpAndSettle();
      await tester.tap(actions(messageId));
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
    }

    Finder editField() => find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        );

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
      await tester.pumpAndSettle();
    }

    Future<void> confirmDeletion(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();
    }

    testWidgets('le menu ⋯ apparaît sur ses propres messages', (tester) async {
      await openThread(tester);
      expect(actions('m1'), findsOneWidget);
      expect(actions('r1'), findsOneWidget);

      await tester.tap(actions('r1'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
    });

    testWidgets('pas de menu sur le message d un autre', (tester) async {
      final session = await openThread(tester);
      expect(actions('r2'), findsNothing);

      // Léa n'a rien écrit ici : aucun menu.
      session.signIn(_lea);
      await tester.pumpAndSettle();
      expect(find.text('Réponse d Inès'), findsOneWidget);
      expect(find.byTooltip('Options du message'), findsNothing);

      // Un visiteur non plus.
      session.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Réponse d Inès'), findsOneWidget);
      expect(find.byTooltip('Options du message'), findsNothing);
    });

    testWidgets('pas de menu sur un message déjà supprimé', (tester) async {
      await openThread(tester);
      await choose(tester, 'r1', 'Supprimer');
      await confirmDeletion(tester);
      expect(actions('r1'), findsNothing);
      expect(actions('m1'), findsOneWidget);
    });

    testWidgets('Modifier ouvre le formulaire prérempli', (tester) async {
      await openThread(tester);
      await choose(tester, 'r1', 'Modifier');

      expect(find.text('Modifier ta réponse'), findsOneWidget);
      final field = tester.widget<TextField>(editField());
      expect(field.controller!.text, 'Ma première réponse');
    });

    testWidgets('une modification met à jour le message', (tester) async {
      await openThread(tester);
      await choose(tester, 'r1', 'Modifier');
      await tester.enterText(editField(), '  Réponse corrigée ');
      await save(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Réponse corrigée'), findsOneWidget);
      expect(find.text('Ma première réponse'), findsNothing);
      expect(find.textContaining('· modifié'), findsOneWidget);
      expect(repository.message('1', 'r1').content, 'Réponse corrigée');
      // La réponse d'Inès n'a pas bougé.
      expect(find.text('Réponse d Inès'), findsOneWidget);
    });

    testWidgets('une réponse vide est refusée', (tester) async {
      await openThread(tester);
      await choose(tester, 'r1', 'Modifier');
      await tester.enterText(editField(), '   ');
      await save(tester);

      expect(find.text('Ta réponse ne peut pas être vide.'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(repository.message('1', 'r1').content, 'Ma première réponse');
    });

    testWidgets('le message principal garde la règle des 10 caractères', (
      tester,
    ) async {
      await openThread(tester);
      await choose(tester, 'm1', 'Modifier');
      expect(find.text('Modifier ton message'), findsOneWidget);
      expect(tester.widget<TextField>(editField()).controller!.text,
          'Le contenu écrit');

      await tester.enterText(editField(), 'Court');
      await save(tester);
      expect(
        find.text('Ton message doit faire au moins 10 caractères.'),
        findsOneWidget,
      );
      expect(repository.message('1', 'm1').content, 'Le contenu écrit');

      await tester.enterText(editField(), 'Un message principal corrigé');
      await save(tester);
      expect(find.text('Un message principal corrigé'), findsOneWidget);
      expect(find.text('Un titre'), findsOneWidget);
    });

    testWidgets('un échec d enregistrement garde le formulaire', (tester) async {
      await openThread(tester);
      repository.failsChanges = true;
      await choose(tester, 'r1', 'Modifier');
      await tester.enterText(editField(), 'Texte qui ne passera pas');
      await save(tester);

      expect(
        find.text('La modification n’a pas pu être enregistrée. Réessaie.'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(editField()).controller!.text,
          'Texte qui ne passera pas');
    });

    testWidgets('Supprimer demande confirmation', (tester) async {
      await openThread(tester);
      await choose(tester, 'r1', 'Supprimer');

      expect(find.text('Supprimer ce message\u00a0?'), findsOneWidget);
      expect(
        find.textContaining('Message supprimé par l’utilisateur'),
        findsOneWidget,
      );
    });

    testWidgets('annuler la confirmation ne supprime rien', (tester) async {
      await openThread(tester);
      await choose(tester, 'r1', 'Supprimer');
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer ce message\u00a0?'), findsNothing);
      expect(find.text('Ma première réponse'), findsOneWidget);
      expect(find.text('Message supprimé par l’utilisateur.'), findsNothing);
      expect(repository.message('1', 'r1').isDeleted, isFalse);
    });

    testWidgets('confirmer remplace le message par la mention', (tester) async {
      await openThread(tester);
      await choose(tester, 'r1', 'Supprimer');
      await confirmDeletion(tester);

      expect(find.text('Message supprimé par l’utilisateur.'), findsOneWidget);
      expect(find.text('Ma première réponse'), findsNothing);
      expect(find.text('Réponse d Inès'), findsOneWidget);

      // Suppression douce : le message existe toujours, sans texte public,
      // et son texte est conservé.
      final stored = repository.message('1', 'r1');
      expect(stored.content, isNull);
      expect(stored.deletion!.source, DeletionSource.author);
      expect(repository.replies['1'], hasLength(2));
      expect(repository.archived['r1'], 'Ma première réponse');
    });

    testWidgets('l état reste correct en rouvrant la discussion', (tester) async {
      await openThread(tester);
      await choose(tester, 'r1', 'Supprimer');
      await confirmDeletion(tester);
      await choose(tester, 'm1', 'Modifier');
      await tester.enterText(editField(), 'Message principal mis à jour');
      await save(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Un titre'));
      await tester.pumpAndSettle();

      expect(find.text('Message supprimé par l’utilisateur.'), findsOneWidget);
      expect(find.text('Ma première réponse'), findsNothing);
      expect(find.text('Message principal mis à jour'), findsOneWidget);
      expect(find.textContaining('· modifié'), findsOneWidget);
      expect(actions('r1'), findsNothing);
    });

    testWidgets('supprimer son message principal retire la discussion', (
      tester,
    ) async {
      await openThread(tester);
      await choose(tester, 'm1', 'Supprimer');
      expect(find.text('Supprimer ta discussion\u00a0?'), findsOneWidget);
      await confirmDeletion(tester);

      expect(find.text('Discussion supprimée par l’utilisateur'), findsOneWidget);
      expect(find.text('Le contenu écrit'), findsNothing);
      // Les réponses restent visibles.
      expect(find.text('Ma première réponse'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Un titre'), findsNothing);
      expect(find.text('Discussion supprimée par l’utilisateur'), findsOneWidget);
    });
  });

  group('connexion', () {
    Future<void> openLogin(WidgetTester tester) async {
      await _pumpApp(tester, _FakeRepository(), SessionController());
      await _goTo(tester, 'Connexion');
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
      await tester.pumpAndSettle();
    }

    testWidgets('les champs vides sont signalés', (tester) async {
      await openLogin(tester);
      await submit(tester);
      expect(find.text('Saisis ton adresse email.'), findsOneWidget);
      expect(find.text('Saisis ton mot de passe.'), findsOneWidget);
    });

    testWidgets('un mauvais mot de passe reste sur la page', (tester) async {
      await openLogin(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'yanis@trame.demo');
      await tester.enterText(find.byType(TextFormField).at(1), 'faux');
      await submit(tester);
      expect(find.text('Email ou mot de passe incorrect.'), findsOneWidget);
    });

    testWidgets('une connexion réussie revient à l accueil', (tester) async {
      await openLogin(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'yanis@trame.demo');
      await tester.enterText(find.byType(TextFormField).at(1), 'demo-yanis-2026');
      await submit(tester);
      expect(_tab('Écrire'), findsOneWidget);
      expect(_tab('Profil'), findsOneWidget);
      expect(_selectedTab(tester), 0);
    });

    testWidgets('le mot de passe oublié ne simule aucun envoi', (tester) async {
      await openLogin(tester);
      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'yanis@trame.demo');
      await tester.tap(find.text('Envoyer le lien'));
      await tester.pumpAndSettle();
      expect(find.textContaining("Aucun email n'a été envoyé"), findsOneWidget);
      expect(find.textContaining('vient de lui être envoyé'), findsNothing);
    });
  });

  group('inscription', () {
    Finder field(int index) => find.byType(TextFormField).at(index);

    Future<void> openRegister(WidgetTester tester) async {
      await _pumpApp(tester, _FakeRepository(), SessionController());
      await _goTo(tester, 'Connexion');
      final link = find.widgetWithText(TextButton, "S'inscrire");
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester) async {
      final button = find.text('Créer mon compte');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    Future<void> fill(
      WidgetTester tester, {
      String username = 'Camille',
      String email = 'camille@exemple.fr',
      String password = 'motdepasse12',
      String? confirmation,
    }) async {
      await tester.enterText(field(0), username);
      await tester.enterText(field(1), email);
      await tester.enterText(field(2), password);
      await tester.enterText(field(3), confirmation ?? password);
    }

    testWidgets('les règles de saisie sont vérifiées', (tester) async {
      await openRegister(tester);
      await fill(
        tester,
        username: 'ab',
        email: 'pas-un-email',
        password: 'court',
        confirmation: 'autre',
      );
      await submit(tester);

      expect(find.textContaining('entre 3 et 20'), findsOneWidget);
      expect(find.textContaining('email valide'), findsOneWidget);
      expect(find.textContaining('au moins 10 caractères'), findsOneWidget);
      expect(find.textContaining('différents'), findsOneWidget);
    });

    testWidgets('un compte créé renvoie à la connexion', (tester) async {
      await openRegister(tester);
      await fill(tester);
      await submit(tester);

      expect(find.textContaining('Compte créé'), findsOneWidget);
      expect(find.text('camille@exemple.fr'), findsOneWidget);
      expect(_tab('Écrire'), findsNothing);
    });

    testWidgets('un email déjà utilisé est signalé', (tester) async {
      await openRegister(tester);
      await fill(tester, email: 'yanis@trame.demo');
      await submit(tester);
      expect(find.textContaining('déjà un compte'), findsOneWidget);
    });

    testWidgets('Se connecter ramène à la connexion', (tester) async {
      await openRegister(tester);
      final toLogin = find.widgetWithText(TextButton, 'Se connecter');
      await tester.ensureVisible(toLogin);
      await tester.pumpAndSettle();
      await tester.tap(toLogin);
      await tester.pumpAndSettle();
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    });
  });

  test('timeAgo affiche une date relative en français', () {
    final now = DateTime(2026, 11, 4, 12);
    expect(
      timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
      'il y a 5 min',
    );
    expect(timeAgo(now.subtract(const Duration(hours: 30)), now: now), 'hier');
    expect(timeAgo(DateTime(2026, 3, 12), now: now), '12 mars');
  });
}

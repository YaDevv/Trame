import '../../models/discussion.dart';
import '../../models/message.dart';
import '../../models/user.dart';

const _marc = User(id: 'u1', displayName: 'Marc', role: UserRole.member);
const _sara = User(id: 'u2', displayName: 'Sara', role: UserRole.member);
const _lea = User(id: 'u3', displayName: 'Léa', role: UserRole.member);
const _tom = User(id: 'u4', displayName: 'Tom', role: UserRole.member);
const _yanis = User(id: 'u5', displayName: 'Yanis', role: UserRole.member);
const _ines = User(id: 'u6', displayName: 'Inès', role: UserRole.admin);
const _nora = User(id: 'u7', displayName: 'Nora', role: UserRole.member);

class DemoAccount {
  const DemoAccount({
    required this.email,
    required this.password,
    required this.user,
  });

  final String email;
  final String password;
  final User user;
}

/// Comptes de test, jamais affiches dans l'interface.
const demoAccounts = [
  DemoAccount(
    email: 'yanis@trame.demo',
    password: 'demo-yanis-2026',
    user: _yanis,
  ),
  DemoAccount(
    email: 'ines@trame.demo',
    password: 'demo-ines-2026',
    user: _ines,
  ),
];

Discussion _discussion(
  DateTime now, {
  required String id,
  required String? title,
  required String? content,
  required User author,
  required Duration age,
  int replies = 0,
  User? lastReplier,
  Duration? lastReplyAge,
  MessageDeletion? deletion,
}) {
  return Discussion(
    id: id,
    title: deletion == null ? title : null,
    opening: Message(
      id: 'm$id',
      author: author,
      content: deletion == null ? content : null,
      createdAt: now.subtract(age),
      deletion: deletion,
    ),
    replyCount: replies,
    lastReplier: lastReplier,
    lastActivityAt: now.subtract(lastReplyAge ?? age),
  );
}

List<Discussion> buildDemoDiscussions(DateTime now) {
  return [
    _discussion(
      now,
      id: '1',
      title: 'Par où commencer avec Flutter quand on vient du web ?',
      content:
          'Je fais du HTML et du JavaScript depuis deux ans et je me lance '
          'sur Flutter pour un projet de cours. Les widgets imbriqués me '
          'perdent un peu. Vous avez suivi quelle méthode pour structurer '
          'votre premier projet sans tout réécrire au bout de trois semaines ?',
      author: _marc,
      age: const Duration(hours: 2),
      replies: 12,
      lastReplier: _lea,
      lastReplyAge: const Duration(minutes: 5),
    ),
    _discussion(
      now,
      id: '2',
      title: 'API maison ou Firebase pour un TP ?',
      content:
          'Le prof note surtout la conception. Une API maison me semble plus '
          'formatrice, mais je crains de manquer de temps.',
      author: _sara,
      age: const Duration(days: 2),
      replies: 4,
      lastReplier: _tom,
      lastReplyAge: const Duration(hours: 30),
    ),
    _discussion(
      now,
      id: '3',
      title: 'Quelqu’un a un bon cours sur les tokens ?',
      content: 'Je cherche quelque chose de clair, en français si possible.',
      author: _tom,
      age: const Duration(minutes: 38),
    ),
    _discussion(
      now,
      id: '4',
      title: 'Mon stage a été annulé deux semaines avant le début',
      content:
          'L’entreprise vient de me prévenir par mail. Je cherche une '
          'solution de secours rapidement, et je ne sais pas à qui en parler '
          'en premier à l’école.',
      author: _yanis,
      age: const Duration(days: 1, hours: 3),
      replies: 7,
      lastReplier: _sara,
      lastReplyAge: const Duration(hours: 6),
      deletion: MessageDeletion(
        source: DeletionSource.author,
        deletedAt: now.subtract(const Duration(hours: 4)),
      ),
    ),
    _discussion(
      now,
      id: '5',
      title: 'Vos raccourcis préférés dans VS Code',
      content:
          'Partagez ceux que vous auriez aimé connaître plus tôt. Je commence : '
          'la sélection multiple avec Ctrl+D a changé ma façon de renommer.',
      author: _lea,
      age: const Duration(days: 4),
      replies: 23,
      lastReplier: _marc,
      lastReplyAge: const Duration(days: 1),
    ),
    _discussion(
      now,
      id: '6',
      title: 'Tester sur un vrai téléphone : ça change quoi ?',
      content:
          'Tout marche dans le navigateur, mais on me dit que le clavier et '
          'les performances réservent des surprises sur Android.',
      author: _nora,
      age: const Duration(days: 12),
      replies: 1,
      lastReplier: _yanis,
      lastReplyAge: const Duration(days: 9),
    ),
    // Comme l'API : ni titre ni contenu pour un message supprime.
    _discussion(
      now,
      id: '7',
      title: null,
      content: null,
      author: _tom,
      age: const Duration(days: 3),
      replies: 2,
      lastReplier: _sara,
      lastReplyAge: const Duration(days: 2),
      deletion: MessageDeletion(
        source: DeletionSource.moderation,
        deletedAt: now.subtract(const Duration(days: 2)),
      ),
    ),
  ];
}

const _replyPool = [_lea, _tom, _sara, _marc, _yanis, _nora, _ines];

const _replyTexts = [
  'Je suis passé par la même chose l’an dernier, je te raconte en détail.',
  'Bonne question. Commence petit : un seul écran, puis ajoute au fur et à mesure.',
  'La documentation officielle est très bien faite, surtout les exemples.',
  'Je ne suis pas d’accord : mieux vaut poser l’architecture dès le début.',
  'Merci pour le partage, ça m’aide beaucoup.',
  'Tu as essayé de découper en petits widgets réutilisables ?',
  'Pareil pour moi, et ça a fini par marcher après quelques essais.',
  'Je mets un lien vers mon projet dès que je l’ai rangé.',
];

/// Reponses coherentes avec le compteur et la derniere activite.
List<Message> buildDemoReplies(Discussion discussion) {
  final count = discussion.replyCount;
  final start = discussion.opening.createdAt;
  final span = discussion.lastActivityAt.difference(start);
  final seed = discussion.id.codeUnits.fold<int>(0, (a, b) => a + b);

  return List.generate(count, (k) {
    final isLast = k == count - 1;
    final author = isLast && discussion.lastReplier != null
        ? discussion.lastReplier!
        : _replyPool[(k * 3 + seed) % _replyPool.length];
    final createdAt = isLast
        ? discussion.lastActivityAt
        : start.add(span * ((k + 1) / count));

    // Discussion 1 : montre une reponse retiree par son auteur et une
    // reponse moderee (dont l'API n'envoie pas le contenu).
    MessageDeletion? deletion;
    String? content = _replyTexts[(k + seed) % _replyTexts.length];
    if (discussion.id == '1' && k == 3) {
      content = null;
      deletion = MessageDeletion(
        source: DeletionSource.author,
        deletedAt: createdAt.add(const Duration(minutes: 10)),
      );
    }
    if (discussion.id == '1' && k == 6) {
      content = null;
      deletion = MessageDeletion(
        source: DeletionSource.moderation,
        deletedAt: createdAt.add(const Duration(minutes: 30)),
      );
    }

    return Message(
      id: 'r${discussion.id}-$k',
      author: author,
      content: content,
      createdAt: createdAt,
      deletion: deletion,
    );
  });
}

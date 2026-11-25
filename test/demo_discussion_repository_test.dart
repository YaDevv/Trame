import 'package:flutter_test/flutter_test.dart';
import 'package:forum_app/models/message.dart';
import 'package:forum_app/models/user.dart';
import 'package:forum_app/repositories/demo/demo_discussion_repository.dart';
import 'package:forum_app/repositories/discussion_repository.dart';

// Dans les donnees de demo, Yanis a ecrit la seule reponse de la
// discussion 6, ouverte par Nora.
const _yanis = User(id: 'u5', displayName: 'Yanis', role: UserRole.member);
const _nora = User(id: 'u7', displayName: 'Nora', role: UserRole.member);
const _discussionId = '6';
const _yanisReply = 'r6-0';
const _noraOpening = 'm6';

void main() {
  late DemoDiscussionRepository repository;

  setUp(() => repository = DemoDiscussionRepository());

  Future<Message> reply(String id) async {
    final thread = await repository.fetchThread(_discussionId);
    return thread.replies.firstWhere((m) => m.id == id);
  }

  test('l auteur modifie sa réponse', () async {
    await repository.editMessage(
      discussionId: _discussionId,
      messageId: _yanisReply,
      content: '  Nouveau texte  ',
      author: _yanis,
    );
    final stored = await reply(_yanisReply);
    expect(stored.content, 'Nouveau texte');
    expect(stored.isEdited, isTrue);
  });

  test('personne ne change le message d un autre', () async {
    final before = (await reply(_yanisReply)).content;
    await expectLater(
      repository.editMessage(
        discussionId: _discussionId,
        messageId: _yanisReply,
        content: 'Piraté',
        author: _nora,
      ),
      throwsA(isA<MessageActionForbiddenException>()),
    );
    await expectLater(
      repository.deleteMessage(
        discussionId: _discussionId,
        messageId: _noraOpening,
        author: _yanis,
      ),
      throwsA(isA<MessageActionForbiddenException>()),
    );
    expect((await reply(_yanisReply)).content, before);
  });

  test('les règles d écriture s appliquent', () async {
    await expectLater(
      repository.editMessage(
        discussionId: _discussionId,
        messageId: _yanisReply,
        content: '   ',
        author: _yanis,
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.editMessage(
        discussionId: _discussionId,
        messageId: _noraOpening,
        content: 'Court',
        author: _nora,
      ),
      throwsArgumentError,
    );
  });

  test('la suppression est douce et le texte est conservé', () async {
    final original = (await reply(_yanisReply)).content;
    await repository.deleteMessage(
      discussionId: _discussionId,
      messageId: _yanisReply,
      author: _yanis,
    );

    final thread = await repository.fetchThread(_discussionId);
    expect(thread.replies, hasLength(1));
    final stored = thread.replies.single;
    expect(stored.content, isNull);
    expect(stored.deletion!.source, DeletionSource.author);
    expect(repository.archivedContentOf(_yanisReply), original);

    // Un message supprimé ne se modifie plus.
    await expectLater(
      repository.editMessage(
        discussionId: _discussionId,
        messageId: _yanisReply,
        content: 'Je reviens',
        author: _yanis,
      ),
      throwsA(isA<MessageActionForbiddenException>()),
    );
  });

  test('supprimer le message principal retire titre et recherche', () async {
    await repository.deleteMessage(
      discussionId: _discussionId,
      messageId: _noraOpening,
      author: _nora,
    );

    final thread = await repository.fetchThread(_discussionId);
    expect(thread.discussion.title, isNull);
    expect(thread.discussion.opening.content, isNull);
    expect(thread.replies, hasLength(1));
    expect(
      repository.archivedTitleOf(_discussionId),
      'Tester sur un vrai téléphone : ça change quoi ?',
    );
    final found = await repository.searchDiscussions('téléphone');
    expect(found.where((d) => d.id == _discussionId), isEmpty);
  });
}

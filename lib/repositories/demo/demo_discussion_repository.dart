import 'package:flutter/foundation.dart';

import '../../core/validators.dart';
import '../../models/discussion.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../discussion_repository.dart';
import 'demo_data.dart';

/// Temporaire : a remplacer par la version API, sans toucher aux ecrans.
/// Garde en memoire les reponses publiees jusqu'au redemarrage.
class DemoDiscussionRepository implements DiscussionRepository {
  DemoDiscussionRepository() {
    _discussions = buildDemoDiscussions(DateTime.now());
    for (final discussion in _discussions) {
      _replies[discussion.id] = buildDemoReplies(discussion);
    }
  }

  late final List<Discussion> _discussions;
  final _replies = <String, List<Message>>{};

  /// Textes et titres des messages supprimes, gardes comme ils le seront
  /// en base. Ils ne sont jamais renvoyes aux ecrans.
  final _archivedContents = <String, String>{};
  final _archivedTitles = <String, String>{};

  /// Texte conserve d'un message supprime (verification des tests).
  @visibleForTesting
  String? archivedContentOf(String messageId) => _archivedContents[messageId];

  /// Titre conserve d'une discussion supprimee (verification des tests).
  @visibleForTesting
  String? archivedTitleOf(String discussionId) =>
      _archivedTitles[discussionId];

  Future<void> _latency([int milliseconds = 400]) {
    return Future<void>.delayed(Duration(milliseconds: milliseconds));
  }

  int _indexOf(String discussionId) {
    final index = _discussions.indexWhere((d) => d.id == discussionId);
    if (index < 0) throw StateError('Discussion introuvable : $discussionId');
    return index;
  }

  @override
  Future<List<Discussion>> fetchDiscussions(DiscussionFilter filter) async {
    await _latency();
    final all = List.of(_discussions);

    switch (filter) {
      case DiscussionFilter.recent:
        return all
          ..sort((a, b) => b.opening.createdAt.compareTo(a.opening.createdAt));
      case DiscussionFilter.active:
        return all.where((d) => d.replyCount > 0).toList()
          ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
      case DiscussionFilter.unanswered:
        return all
            .where((d) => d.replyCount == 0 && !d.opening.isDeleted)
            .toList();
    }
  }

  /// Mots trop courants pour aider a trouver une discussion.
  static const _stopWords = {
    'pour', 'avec', 'dans', 'quand', 'comment', 'quel', 'quelle', 'quels',
    'quelles', 'sont', 'mais', 'plus', 'vous', 'nous', 'faire', 'cette',
  };

  @override
  Future<List<Discussion>> searchDiscussions(String query) async {
    await _latency(300);
    final words = query
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.length >= 3 && !_stopWords.contains(w))
        .toSet();
    if (words.isEmpty) return const [];

    // Un message supprime n'est jamais envoye : il ne peut pas etre trouve.
    // Classement : les discussions qui partagent le plus de mots d'abord.
    final scored = <(Discussion, int)>[];
    for (final d in _discussions.where((d) => !d.opening.isDeleted)) {
      final text = '${d.title ?? ''} ${d.opening.content ?? ''}'.toLowerCase();
      final score = words.where(text.contains).length;
      if (score > 0) scored.add((d, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final (d, _) in scored) d];
  }

  @override
  Future<List<Discussion>> fetchMyDiscussions(String userId) async {
    await _latency(300);
    return _discussions
        .where(
          (d) =>
              d.opening.author.id == userId ||
              (_replies[d.id] ?? const []).any((r) => r.author.id == userId),
        )
        .toList()
      ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
  }

  @override
  Future<Discussion> createDiscussion({
    required String title,
    required String content,
    required User author,
  }) async {
    await _latency(400);
    final now = DateTime.now();
    final discussion = Discussion(
      id: 'd${now.microsecondsSinceEpoch}',
      title: title.trim(),
      opening: Message(
        id: 'm${now.microsecondsSinceEpoch}',
        author: author,
        content: content.trim(),
        createdAt: now,
      ),
      replyCount: 0,
      lastActivityAt: now,
    );
    _discussions.insert(0, discussion);
    _replies[discussion.id] = [];
    return discussion;
  }

  @override
  Future<DiscussionThread> fetchThread(String discussionId) async {
    await _latency(300);
    return DiscussionThread(
      discussion: _discussions[_indexOf(discussionId)],
      replies: List.unmodifiable(_replies[discussionId] ?? const []),
    );
  }

  @override
  Future<Message> postReply({
    required String discussionId,
    required String content,
    required User author,
  }) async {
    await _latency(300);
    final text = content.trim();
    if (text.isEmpty) throw ArgumentError('Réponse vide');

    final index = _indexOf(discussionId);
    final reply = Message(
      id: 'r$discussionId-${DateTime.now().microsecondsSinceEpoch}',
      author: author,
      content: text,
      createdAt: DateTime.now(),
    );
    _replies.putIfAbsent(discussionId, () => []).add(reply);
    _discussions[index] = _discussions[index].withReply(reply);
    return reply;
  }

  /// Retrouve un message et verifie que [author] peut le changer.
  _Located _locateOwned(String discussionId, String messageId, User author) {
    final index = _indexOf(discussionId);
    final discussion = _discussions[index];
    final replies = _replies[discussionId] ?? const <Message>[];
    final replyIndex = discussion.opening.id == messageId
        ? null
        : replies.indexWhere((r) => r.id == messageId);
    if (replyIndex == -1) {
      throw StateError('Message introuvable : $messageId');
    }
    final message =
        replyIndex == null ? discussion.opening : replies[replyIndex];

    if (message.author.id != author.id ||
        message.isDeleted ||
        discussion.opening.isModerated) {
      throw MessageActionForbiddenException();
    }
    return _Located(index, replyIndex, message);
  }

  void _replace(_Located at, Message updated) {
    final replyIndex = at.replyIndex;
    if (replyIndex == null) {
      _discussions[at.discussionIndex] =
          _discussions[at.discussionIndex].withOpening(updated);
    } else {
      final id = _discussions[at.discussionIndex].id;
      _replies[id]![replyIndex] = updated;
    }
  }

  @override
  Future<Message> editMessage({
    required String discussionId,
    required String messageId,
    required String content,
    required User author,
  }) async {
    await _latency(300);
    final at = _locateOwned(discussionId, messageId, author);
    final error = at.isOpening
        ? validateOpeningContent(content)
        : validateReplyContent(content);
    if (error != null) throw ArgumentError(error);

    final updated = at.message.edited(content.trim(), DateTime.now());
    _replace(at, updated);
    return updated;
  }

  @override
  Future<Message> deleteMessage({
    required String discussionId,
    required String messageId,
    required User author,
  }) async {
    await _latency(300);
    final at = _locateOwned(discussionId, messageId, author);

    // Suppression douce : on garde le texte, on ne l'envoie plus.
    _archivedContents[messageId] = at.message.content ?? '';
    if (at.isOpening) {
      final title = _discussions[at.discussionIndex].title;
      if (title != null) _archivedTitles[discussionId] = title;
    }
    final updated = at.message.deleted(
      MessageDeletion(source: DeletionSource.author, deletedAt: DateTime.now()),
    );
    _replace(at, updated);
    return updated;
  }
}

/// Position d'un message dans le stockage de demo.
class _Located {
  const _Located(this.discussionIndex, this.replyIndex, this.message);

  final int discussionIndex;

  /// null = le message principal de la discussion.
  final int? replyIndex;
  final Message message;

  bool get isOpening => replyIndex == null;
}

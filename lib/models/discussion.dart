import 'message.dart';
import 'user.dart';

class Discussion {
  const Discussion({
    required this.id,
    required this.title,
    required this.opening,
    required this.replyCount,
    required this.lastActivityAt,
    this.lastReplier,
  });

  final String id;

  /// null quand la discussion entiere est moderee.
  final String? title;

  /// Le message principal, celui qui ouvre la discussion.
  final Message opening;
  final int replyCount;
  final DateTime lastActivityAt;
  final User? lastReplier;

  /// Copie apres une nouvelle reponse.
  Discussion withReply(Message reply) {
    return Discussion(
      id: id,
      title: title,
      opening: opening,
      replyCount: replyCount + 1,
      lastActivityAt: reply.createdAt,
      lastReplier: reply.author,
    );
  }

  /// Copie apres modification ou suppression du message principal.
  /// Comme l'API, une discussion supprimee n'a plus de titre.
  Discussion withOpening(Message newOpening) {
    return Discussion(
      id: id,
      title: newOpening.isDeleted ? null : title,
      opening: newOpening,
      replyCount: replyCount,
      lastActivityAt: lastActivityAt,
      lastReplier: lastReplier,
    );
  }
}

/// Une discussion complete : le message principal et toutes ses reponses.
class DiscussionThread {
  const DiscussionThread({required this.discussion, required this.replies});

  final Discussion discussion;
  final List<Message> replies;
}

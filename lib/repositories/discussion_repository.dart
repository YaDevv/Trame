import '../models/discussion.dart';
import '../models/message.dart';
import '../models/user.dart';

enum DiscussionFilter { recent, active, unanswered }

/// Refus de modifier ou supprimer un message : la personne n'en est pas
/// l'auteur, le message est deja supprime, ou la discussion est fermee
/// par la moderation. L'API fera la meme verification de son cote.
class MessageActionForbiddenException implements Exception {}

/// Contrat connu des ecrans. L'API reelle en sera une autre implementation.
abstract interface class DiscussionRepository {
  Future<List<Discussion>> fetchDiscussions(DiscussionFilter filter);

  /// Discussions dont le titre ou le message contient [query].
  Future<List<Discussion>> searchDiscussions(String query);

  /// Discussions ouvertes par l'utilisateur ou auxquelles il a repondu.
  Future<List<Discussion>> fetchMyDiscussions(String userId);

  /// Cree une discussion. Avec l'API, l'auteur viendra du token de session.
  Future<Discussion> createDiscussion({
    required String title,
    required String content,
    required User author,
  });

  /// Le message principal et ses reponses (fonctionnalite n° 11).
  Future<DiscussionThread> fetchThread(String discussionId);

  /// Publie une reponse. Avec l'API, l'auteur viendra du token de session.
  Future<Message> postReply({
    required String discussionId,
    required String content,
    required User author,
  });

  /// Modifie le texte d'un message de [discussionId] (message principal ou
  /// reponse). Memes regles qu'a l'ecriture. Seul l'auteur peut le faire ;
  /// avec l'API, il viendra du token de session.
  Future<Message> editMessage({
    required String discussionId,
    required String messageId,
    required String content,
    required User author,
  });

  /// Suppression douce par l'auteur : le texte reste en base mais n'est plus
  /// envoye. Renvoie le message tel que le public le voit desormais.
  Future<Message> deleteMessage({
    required String discussionId,
    required String messageId,
    required User author,
  });
}

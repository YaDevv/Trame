import 'user.dart';

enum DeletionSource { author, moderation }

/// Une suppression est logique : le message reste en base.
class MessageDeletion {
  const MessageDeletion({
    required this.source,
    required this.deletedAt,
    this.reason,
  });

  final DeletionSource source;
  final DateTime deletedAt;

  /// Motif de moderation, envoye par l'API aux administrateurs uniquement.
  final String? reason;
}

class Message {
  const Message({
    required this.id,
    required this.author,
    required this.content,
    required this.createdAt,
    this.editedAt,
    this.deletion,
  });

  final String id;
  final User author;

  /// null quand le message est supprime : l'API conserve le texte en base
  /// mais ne l'envoie pas au public. L'interface ne l'affiche jamais.
  final String? content;
  final DateTime createdAt;

  /// Date de la derniere modification par l'auteur ; null = jamais modifie.
  final DateTime? editedAt;

  /// null = message actif.
  final MessageDeletion? deletion;

  bool get isDeleted => deletion != null;
  bool get isModerated => deletion?.source == DeletionSource.moderation;
  bool get isEdited => editedAt != null;

  /// Copie apres modification du texte par son auteur.
  Message edited(String newContent, DateTime at) {
    return Message(
      id: id,
      author: author,
      content: newContent,
      createdAt: createdAt,
      editedAt: at,
    );
  }

  /// Copie telle que le public la voit apres suppression : sans le texte.
  Message deleted(MessageDeletion deletion) {
    return Message(
      id: id,
      author: author,
      content: null,
      createdAt: createdAt,
      editedAt: editedAt,
      deletion: deletion,
    );
  }
}

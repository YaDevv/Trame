import 'message.dart';

/// Ce qu'affiche l'interface a la place d'un message supprime :
/// seule cette phrase, jamais le contenu.
String deletionNotice(Message message) {
  return message.isModerated
      ? 'Message supprimé par la modération.'
      : 'Message supprimé par l’utilisateur.';
}

/// Titre d'une discussion dont le message principal est supprime.
String deletedDiscussionTitle(Message opening) {
  return opening.isModerated
      ? 'Discussion retirée par la modération'
      : 'Discussion supprimée par l’utilisateur';
}

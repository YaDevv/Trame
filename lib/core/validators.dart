final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _usernamePattern = RegExp(r'^[\p{L}\p{N}_-]+$', unicode: true);

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Saisis ton adresse email.';
  if (!_emailPattern.hasMatch(email)) {
    return 'Saisis une adresse email valide, comme nom@exemple.fr.';
  }
  return null;
}

String? validateRequiredPassword(String? value) {
  if (value == null || value.isEmpty) return 'Saisis ton mot de passe.';
  return null;
}

String? validateUsername(String? value) {
  final username = value?.trim() ?? '';
  if (username.isEmpty) return 'Choisis un pseudo.';
  if (username.length < 3 || username.length > 20) {
    return 'Ton pseudo doit contenir entre 3 et 20 caractères.';
  }
  if (!_usernamePattern.hasMatch(username)) {
    return 'Utilise seulement des lettres, des chiffres, _ ou -.';
  }
  return null;
}

String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Choisis un mot de passe.';
  if (password.length < 10 ||
      !password.contains(RegExp(r'\p{L}', unicode: true)) ||
      !password.contains(RegExp(r'\p{N}', unicode: true))) {
    return 'Utilise au moins 10 caractères, avec une lettre et un chiffre.';
  }
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if (value == null || value.isEmpty) return 'Confirme ton mot de passe.';
  if (value != password) return 'Les deux mots de passe sont différents.';
  return null;
}

/// Longueur minimale du message qui ouvre une discussion.
const openingContentMinLength = 10;

/// Message principal : meme regle a l'ecriture et a la modification.
String? validateOpeningContent(String? value) {
  if ((value?.trim() ?? '').length < openingContentMinLength) {
    return 'Ton message doit faire au moins $openingContentMinLength caractères.';
  }
  return null;
}

/// Reponse : comme dans la barre de reponse, elle ne peut pas etre vide.
String? validateReplyContent(String? value) {
  if ((value?.trim() ?? '').isEmpty) return 'Ta réponse ne peut pas être vide.';
  return null;
}

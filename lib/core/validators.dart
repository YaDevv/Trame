// Verifications communes aux formulaires de connexion et d'inscription.
// Chaque fonction renvoie un message d'erreur, ou null si la valeur est bonne.

// Forme « quelque-chose@domaine.ext », sans espace.
final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

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

String? validatePasswordConfirmation(String? value, String password) {
  if (value == null || value.isEmpty) return 'Confirme ton mot de passe.';
  if (value != password) return 'Les deux mots de passe sont différents.';
  return null;
}

// Memes regles que l'entite User de l'API Symfony, pour prevenir l'erreur
// avant l'envoi. L'API reste juge : ses messages sont affiches s'il refuse.

// Lettres (accents compris), espaces, apostrophes et tirets.
final _namePattern = RegExp(r"^[a-zA-ZÀ-ÿ '-]+$");
// (?=.*[A-Z]) une majuscule, (?=.*[a-z]) une minuscule, (?=.*\d) un chiffre,
// (?=.*[^A-Za-z0-9]) un caractère spécial, .{12,} au moins 12 caractères.
final _passwordPattern = RegExp(
  r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{12,}$',
);

String? validateApiName(String? value, {required String label}) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Le $label est obligatoire.';
  if (name.length > 30) return 'Le $label fait 30 caractères au maximum.';
  if (!_namePattern.hasMatch(name)) {
    return 'Le $label ne doit contenir que des lettres.';
  }
  return null;
}

String? validateApiPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Le mot de passe est obligatoire.';
  if (!_passwordPattern.hasMatch(password)) {
    return 'Au moins 12 caractères, avec une majuscule, une minuscule, '
        'un chiffre et un caractère spécial.';
  }
  return null;
}

import '../models/user.dart';

class InvalidCredentialsException implements Exception {}

class EmailAlreadyUsedException implements Exception {}

class UsernameAlreadyUsedException implements Exception {}

/// La fonctionnalite demande le serveur, qui n'est pas encore branche.
class FeatureUnavailableException implements Exception {}

/// Contrat de l'authentification. L'API en sera une autre implementation.
abstract interface class AuthRepository {
  Future<User> signIn({required String email, required String password});

  Future<void> register({
    required String username,
    required String email,
    required String password,
  });

  /// Demande l'envoi d'un lien de reinitialisation par email.
  Future<void> requestPasswordReset({required String email});
}

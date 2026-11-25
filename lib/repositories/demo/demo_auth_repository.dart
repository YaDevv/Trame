import '../../models/user.dart';
import '../auth_repository.dart';
import 'demo_data.dart';

/// Temporaire : comptes en memoire, perdus au redemarrage de l'application.
class DemoAuthRepository implements AuthRepository {
  final _accounts = {
    for (final account in demoAccounts) account.email: account,
  };

  Future<void> _latency() {
    return Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<User> signIn({required String email, required String password}) async {
    await _latency();
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      throw InvalidCredentialsException();
    }
    return account.user;
  }

  @override
  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    await _latency();
    final normalizedEmail = email.trim().toLowerCase();
    if (_accounts.containsKey(normalizedEmail)) {
      throw EmailAlreadyUsedException();
    }
    final name = username.trim();
    final taken = _accounts.values.any(
      (account) => account.user.displayName.toLowerCase() == name.toLowerCase(),
    );
    if (taken) throw UsernameAlreadyUsedException();

    _accounts[normalizedEmail] = DemoAccount(
      email: normalizedEmail,
      password: password,
      user: User(
        id: 'new-$normalizedEmail',
        displayName: name,
        role: UserRole.member,
      ),
    );
  }

  /// Aucun email ne peut partir sans serveur : on ne simule pas de succes.
  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _latency();
    throw FeatureUnavailableException();
  }
}

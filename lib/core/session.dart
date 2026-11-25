import 'package:flutter/widgets.dart';

import '../models/user.dart';

/// Qui utilise l'application : null = visiteur.
/// Le token de l'API sera gere ici quand l'authentification existera.
class SessionController extends ChangeNotifier {
  User? _currentUser;

  User? get currentUser => _currentUser;

  void signIn(User user) {
    _currentUser = user;
    notifyListeners();
  }

  void signOut() {
    _currentUser = null;
    notifyListeners();
  }
}

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController super.notifier,
    required super.child,
  });

  static SessionController of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;
  }
}

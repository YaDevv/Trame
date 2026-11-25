import 'package:flutter/foundation.dart';

import 'forum_api.dart';

/// Session de la demo : le jeton reste en memoire, jamais sur le disque.
/// Fermer l'onglet ou se deconnecter l'efface.
// ChangeNotifier : cet objet prévient les widgets qui l'écoutent (ici DemoApp)
// à chaque changement, grâce à notifyListeners().
class DemoSession extends ChangeNotifier {
  // Session en cours (jeton + infos du compte). null = personne n'est connecté.
  ApiSession? _current;

  /// Message a afficher sur l'ecran de connexion (deconnexion, expiration).
  String? notice;

  ApiSession? get current => _current;
  bool get isSignedIn => _current != null;

  // Appelée après une connexion réussie (voir DemoLoginScreen).
  void signIn(ApiSession session) {
    _current = session;
    notice = null;
    notifyListeners();
  }

  // Appelée au clic sur « Se déconnecter » ou quand le jeton a expiré.
  // Avec un JWT, inutile de prévenir le serveur : il suffit d'oublier le jeton.
  void signOut({String? notice}) {
    _current = null;
    this.notice = notice;
    notifyListeners();
  }
}

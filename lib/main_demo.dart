import 'package:flutter/material.dart';

import 'demo_api/api_config.dart';
import 'demo_api/demo_app.dart';
import 'demo_api/demo_session.dart';
import 'demo_api/forum_api.dart';

/// Point d'entree de la demo API. La version complete de Trame
/// reste lancee par lib/main.dart, sans changement.
// main() est la première fonction exécutée au lancement de l'application.
void main() {
  // runApp affiche le widget racine. On lui donne le client API (pour parler
  // au serveur) et la session (pour savoir qui est connecté).
  runApp(
    DemoApp(
      api: HttpForumApi(baseUrl: forumApiBaseUrl),
      session: DemoSession(),
    ),
  );
}

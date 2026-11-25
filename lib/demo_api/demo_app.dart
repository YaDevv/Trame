import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'demo_session.dart';
import 'demo_shell.dart';
import 'demo_visitor_shell.dart';
import 'forum_api.dart';

/// Trame (version demo reliee a l'API Symfony).
/// Visiteur : Accueil | Connexion. Membre : Accueil | Ecrire | Profil.
/// Les ecrans de membre n'existent que si une session est ouverte.
class DemoApp extends StatelessWidget {
  const DemoApp({super.key, required this.api, required this.session});

  final ForumApi api;
  final DemoSession session;

  @override
  Widget build(BuildContext context) {
    // MaterialApp : la racine de l'application (titre, thème, premier écran).
    return MaterialApp(
      title: 'Trame',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // ListenableBuilder reconstruit ce qui suit à chaque notifyListeners() de la
      // session : c'est ce qui bascule l'écran entre visiteur et membre.
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final current = session.current;
          // Personne de connecté : version visiteur (Accueil | Connexion).
          if (current == null) {
            return DemoVisitorShell(
              // Nouvelle clé à chaque nouveau message (ex. après une déconnexion) :
              // les écrans visiteur sont recréés à neuf.
              key: ObjectKey(session.notice),
              api: api,
              session: session,
            );
          }
          // Quelqu'un est connecté : version membre (Accueil | Écrire | Profil).
          // ValueKey(token) recrée les écrans à neuf si un autre compte se connecte.
          return DemoShell(
            key: ValueKey(current.token),
            api: api,
            session: session,
            apiSession: current,
          );
        },
      ),
    );
  }
}

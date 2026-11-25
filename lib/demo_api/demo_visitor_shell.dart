import 'package:flutter/material.dart';

import 'demo_home_screen.dart';
import 'demo_login_screen.dart';
import 'demo_session.dart';
import 'forum_api.dart';

/// Application d'un visiteur : Accueil | Connexion.
/// Il peut lire les discussions, mais pas en publier.
class DemoVisitorShell extends StatefulWidget {
  const DemoVisitorShell({super.key, required this.api, required this.session});

  final ForumApi api;
  final DemoSession session;

  @override
  State<DemoVisitorShell> createState() => _DemoVisitorShellState();
}

class _DemoVisitorShellState extends State<DemoVisitorShell> {
  // Apres une deconnexion, on montre directement l'ecran de connexion
  // avec son message.
  late int _index = widget.session.notice == null ? 0 : 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack garde les deux écrans en mémoire et n'affiche que celui de l'onglet choisi.
      body: IndexedStack(
        index: _index,
        children: [
          DemoHomeScreen(
            api: widget.api,
            session: widget.session,
            // Le bouton « Se connecter » de l'accueil bascule sur l'onglet Connexion.
            onSignIn: () => setState(() => _index = 1),
          ),
          DemoLoginScreen(api: widget.api, session: widget.session),
        ],
      ),
      // Barre d'onglets en bas de l'écran.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.login),
            label: 'Connexion',
          ),
        ],
      ),
    );
  }
}

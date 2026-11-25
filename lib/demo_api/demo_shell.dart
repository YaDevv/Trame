import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'demo_account_screen.dart';
import 'demo_compose_screen.dart';
import 'demo_home_screen.dart';
import 'demo_session.dart';
import 'forum_api.dart';

/// Application une fois connecte : Accueil | Ecrire | Profil.
/// N'existe que si une session est ouverte (voir DemoApp).
class DemoShell extends StatefulWidget {
  const DemoShell({
    super.key,
    required this.api,
    required this.session,
    required this.apiSession,
  });

  final ForumApi api;
  final DemoSession session;
  final ApiSession apiSession;

  @override
  State<DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<DemoShell> {
  // Clé qui permet d'appeler reload() sur l'accueil après une publication.
  final _home = GlobalKey<DemoHomeScreenState>();
  int _index = 0;

  // Onglet « Écrire » : ouvre l'écran Nouveau message par-dessus l'application.
  Future<void> _write() async {
    final messenger = ScaffoldMessenger.of(context);
    // On attend la fermeture de l'écran : il renvoie true si le message a été publié.
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DemoComposeScreen(
          api: widget.api,
          token: widget.apiSession.token,
        ),
      ),
    );
    // Annulé (retour arrière) ou écran disparu : rien à faire.
    if (published != true || !mounted) return;
    // Retour a l'accueil, ou le nouveau message apparait en haut.
    setState(() => _index = 0);
    await _home.currentState?.reload();
    messenger.showSnackBar(const SnackBar(content: Text('Message publié.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        // L'onglet « Ecrire » ouvre un ecran : il n'a pas de page ici.
        index: _index == 2 ? 1 : 0,
        children: [
          DemoHomeScreen(
            key: _home,
            api: widget.api,
            session: widget.session,
            apiSession: widget.apiSession,
          ),
          DemoAccountScreen(
            api: widget.api,
            session: widget.session,
            apiSession: widget.apiSession,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          // Index 1 = « Écrire » : on ouvre l'écran au lieu de changer d'onglet.
          if (index == 1) {
            _write();
          } else {
            setState(() => _index = index);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: _WriteIcon(),
            label: 'Écrire',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _WriteIcon extends StatelessWidget {
  const _WriteIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.add, size: 22, color: Colors.white),
    );
  }
}

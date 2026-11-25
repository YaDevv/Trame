import 'package:flutter/material.dart';

import '../core/session.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/discussion_repository.dart';
import '../screens/auth/login_screen.dart';
import '../screens/compose/compose_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/my_threads/my_threads_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/search/search_screen.dart';
import 'theme.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon, this.page);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// null : bouton d'action "Ecrire", qui ouvre un ecran sans changer d'onglet.
  final Widget? page;
}

/// Navigation principale : une barre en bas, adaptee au role.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.discussions, required this.auth});

  final DiscussionRepository discussions;
  final AuthRepository auth;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  String? _identity;

  List<_Tab> _tabsFor(User? user) {
    final home = _Tab(
      'Accueil',
      Icons.home_outlined,
      Icons.home,
      HomeScreen(discussions: widget.discussions),
    );
    final search = _Tab(
      'Rechercher',
      Icons.search,
      Icons.search,
      SearchScreen(discussions: widget.discussions),
    );

    if (user == null) {
      return [
        home,
        search,
        _Tab('Connexion', Icons.login, Icons.login, LoginScreen(auth: widget.auth)),
      ];
    }

    return [
      home,
      search,
      const _Tab('Écrire', Icons.add, Icons.add, null),
      user.isAdmin
          ? const _Tab(
              'Modération',
              Icons.shield_outlined,
              Icons.shield,
              PlaceholderScreen(title: 'Modération'),
            )
          : _Tab(
              'Mes fils',
              Icons.forum_outlined,
              Icons.forum,
              MyThreadsScreen(discussions: widget.discussions, user: user),
            ),
      _Tab(
        'Profil',
        Icons.person_outline,
        Icons.person,
        ProfileScreen(user: user, discussions: widget.discussions),
      ),
    ];
  }

  void _openComposer(User author) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ComposeScreen(
          author: author,
          repository: widget.discussions,
          auth: widget.auth,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionScope.of(context).currentUser;

    // Connexion ou deconnexion : on repart de l'accueil.
    final identity = user?.id ?? 'visiteur';
    if (identity != _identity) {
      _identity = identity;
      _index = 0;
    }

    final tabs = _tabsFor(user);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (final tab in tabs) tab.page ?? const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) {
            if (tabs[index].page == null) {
              _openComposer(user!);
              return;
            }
            setState(() => _index = index);
          },
          destinations: [
            for (final tab in tabs)
              tab.page == null
                  ? NavigationDestination(
                      icon: const _ComposeIcon(),
                      label: tab.label,
                    )
                  : NavigationDestination(
                      icon: Icon(tab.icon),
                      selectedIcon: Icon(tab.selectedIcon),
                      label: tab.label,
                    ),
          ],
        ),
      ),
    );
  }
}

/// Le "+" central, plein, comme sur les applications sociales.
class _ComposeIcon extends StatelessWidget {
  const _ComposeIcon();

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

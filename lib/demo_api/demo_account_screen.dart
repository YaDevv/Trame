import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../widgets/auth_form.dart';
import 'demo_session.dart';
import 'forum_api.dart';

/// Mon profil : les informations du compte connecte, lues sur le serveur.
class DemoAccountScreen extends StatefulWidget {
  const DemoAccountScreen({
    super.key,
    required this.api,
    required this.session,
    required this.apiSession,
  });

  final ForumApi api;
  final DemoSession session;
  final ApiSession apiSession;

  @override
  State<DemoAccountScreen> createState() => _DemoAccountScreenState();
}

class _DemoAccountScreenState extends State<DemoAccountScreen> {
  ApiUser? _user;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Charge le profil depuis l'API (GET /api/users/{id}, avec le jeton).
  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final user = await widget.api.fetchUser(
        id: widget.apiSession.userId,
        token: widget.apiSession.token,
      );
      if (mounted) setState(() => _user = user);
    } on UnauthorizedException {
      widget.session.signOut(
        notice: 'Ta session a expiré. Reconnecte-toi pour continuer.',
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  // Déconnexion : la session oublie le jeton, et DemoApp réaffiche la version visiteur.
  void _signOut() {
    widget.session.signOut(notice: 'Tu es déconnecté. À bientôt sur Trame.');
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.apiSession;
    final user = _user;
    // Tant que le profil charge, on affiche le nom reçu à la connexion.
    final prenom = user?.prenom ?? session.prenom;
    final nom = user?.nom ?? session.nom;
    final name = '$prenom $nom'.trim();
    // Le badge dépend du rôle ROLE_ADMIN renvoyé par l'API à la connexion.
    final role = session.isAdmin ? 'Administrateur' : 'Membre';

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Mon profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Header(
            name: name.isEmpty ? 'Mon compte' : name,
            email: user?.email,
            isAdmin: session.isAdmin,
          ),
          const SizedBox(height: 16),
          if (_failed) ...[
            const FormNotice(
              text: 'Impossible d’afficher ton profil pour le moment. '
                  'Réessaie dans un instant.',
              kind: FormNoticeKind.error,
            ),
            TextButton(onPressed: _load, child: const Text('Réessayer')),
          ] else if (user == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _InfoCard(
              rows: [
                ('Prénom', user.prenom),
                ('Nom', user.nom),
                ('Adresse email', user.email),
                ('Statut', role),
              ],
            ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.border),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Se déconnecter'),
            ),
          ),
        ],
      ),
    );
  }
}

// En-tête du profil : avatar, nom, email et badge.
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.isAdmin, this.email});

  final String name;
  final String? email;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final color = isAdmin ? AppColors.accent : AppColors.primary;
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            name.characters.first.toUpperCase(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          textAlign: TextAlign.center,
          style: threadTitleStyle.copyWith(fontSize: 24),
        ),
        if (email != null) ...[
          const SizedBox(height: 2),
          Text(
            email!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAdmin
                    ? Icons.admin_panel_settings_outlined
                    : Icons.person_outline,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                isAdmin ? 'Administrateur' : 'Membre',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Carte « Prénom, Nom, Adresse email, Statut ».
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      rows[i].$1,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].$2.isEmpty ? '—' : rows[i].$2,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

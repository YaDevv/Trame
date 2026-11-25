import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/session.dart';
import '../../models/user.dart';
import '../../repositories/discussion_repository.dart';
import '../../widgets/user_avatar.dart';
import '../my_threads/my_threads_screen.dart';
import '../placeholder_screen.dart';
import 'rules_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.discussions,
  });

  final User user;
  final DiscussionRepository discussions;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int? _opened;
  int? _joined;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final mine = await widget.discussions.fetchMyDiscussions(widget.user.id);
      if (!mounted) return;
      final opened = mine.where((d) => d.opening.author.id == widget.user.id);
      setState(() {
        _opened = opened.length;
        _joined = mine.length - opened.length;
      });
    } catch (_) {
      // Sans chiffres, le profil reste utilisable : on affiche un tiret.
    }
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _soon(String title) => _push(PlaceholderScreen(title: title));

  Future<void> _confirmSignOut() async {
    final session = SessionScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Tu pourras toujours lire le forum, mais plus publier ni répondre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed == true) session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _ProfileHeader(user: user, opened: _opened, joined: _joined),
          const SizedBox(height: 20),
          _Section(
            title: 'Mon compte',
            tiles: [
              _Tile(
                icon: Icons.person_outline,
                label: 'Modifier mon profil',
                detail: 'Pseudo et présentation',
                soon: true,
                onTap: () => _soon('Modifier mon profil'),
              ),
              _Tile(
                icon: Icons.lock_outline,
                label: 'Email et mot de passe',
                soon: true,
                onTap: () => _soon('Email et mot de passe'),
              ),
              if (user.isAdmin)
                _Tile(
                  icon: Icons.forum_outlined,
                  label: 'Mes discussions',
                  onTap: () => _push(
                    MyThreadsScreen(discussions: widget.discussions, user: user),
                  ),
                ),
            ],
          ),
          if (user.isAdmin)
            _Section(
              title: 'Administration',
              tiles: [
                _Tile(
                  icon: Icons.group_outlined,
                  label: 'Utilisateurs',
                  detail: 'Liste, ajout, modification, suppression',
                  soon: true,
                  onTap: () => _soon('Utilisateurs'),
                ),
              ],
            ),
          _Section(
            title: 'Paramètres',
            tiles: [
              _Tile(
                icon: Icons.notifications_none,
                label: 'Notifications',
                soon: true,
                onTap: () => _soon('Notifications'),
              ),
              _Tile(
                icon: Icons.dark_mode_outlined,
                label: 'Apparence',
                detail: 'Thème clair ou sombre',
                soon: true,
                onTap: () => _soon('Apparence'),
              ),
              _Tile(
                icon: Icons.shield_outlined,
                label: 'Confidentialité et données',
                soon: true,
                onTap: () => _soon('Confidentialité et données'),
              ),
            ],
          ),
          _Section(
            title: 'Aide',
            tiles: [
              _Tile(
                icon: Icons.gavel_outlined,
                label: 'Règles de la communauté',
                onTap: () => _push(const RulesScreen()),
              ),
              _Tile(
                icon: Icons.info_outline,
                label: 'À propos de Trame',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Trame',
                  applicationVersion: 'Version 1.0.0',
                  applicationLegalese: 'Forum réalisé avec Flutter.',
                ),
              ),
            ],
          ),
          _Section(
            tiles: [
              _Tile(
                icon: Icons.logout,
                label: 'Se déconnecter',
                color: AppColors.danger,
                showChevron: false,
                onTap: _confirmSignOut,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, this.opened, this.joined});

  final User user;
  final int? opened;
  final int? joined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          UserAvatar(user: user, size: 72),
          const SizedBox(height: 10),
          Text(user.displayName, style: threadTitleStyle.copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: user.isAdmin
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user.isAdmin ? 'Administrateur' : 'Membre',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: user.isAdmin ? AppColors.accent : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Stat(value: opened, label: 'Discussions ouvertes')),
              Container(width: 1, height: 32, color: AppColors.border),
              Expanded(child: _Stat(value: joined, label: 'Discussions rejointes')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value?.toString() ?? '–',
          style: threadTitleStyle.copyWith(fontSize: 22, color: AppColors.primary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

/// Groupe de lignes dans une carte arrondie, comme les reglages d'un telephone.
class _Section extends StatelessWidget {
  const _Section({this.title, required this.tiles});

  final String? title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 6),
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
          Material(
            color: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 52),
                  tiles[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.soon = false,
    this.color,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final String? detail;

  /// Fonction prevue mais pas encore construite : signalee honnetement.
  final bool soon;
  final Color? color;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: (color ?? AppColors.primary).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color ?? AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: tint,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                ],
              ),
            ),
            if (soon)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.skeleton,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Bientôt',
                  style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
                ),
              ),
            if (showChevron)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.chevron_right, color: AppColors.inkSoft),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/time_ago.dart';
import '../widgets/app_logo.dart';
import '../widgets/auth_form.dart';
import '../widgets/user_avatar.dart';
import 'demo_session.dart';
import 'forum_api.dart';

/// Accueil : les discussions les plus recentes, lisibles par tous.
class DemoHomeScreen extends StatefulWidget {
  const DemoHomeScreen({
    super.key,
    required this.api,
    required this.session,
    this.apiSession,
    this.onSignIn,
  });

  final ForumApi api;
  final DemoSession session;

  /// null pour un visiteur.
  final ApiSession? apiSession;

  /// Visiteur : ouvre l'onglet de connexion.
  final VoidCallback? onSignIn;

  @override
  State<DemoHomeScreen> createState() => DemoHomeScreenState();
}

// État public (sans _ devant) pour que DemoShell puisse appeler reload().
class DemoHomeScreenState extends State<DemoHomeScreen> {
  // null = chargement en cours ; liste vide = aucune discussion.
  List<ApiDiscussion>? _discussions;
  bool _failed = false;

  // Appelée une seule fois à l'ouverture de l'écran : on charge les messages.
  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Recharge la liste (au demarrage, apres une publication, en tirant).
  Future<void> reload() async {
    setState(() => _failed = false);
    try {
      // Jeton null pour un visiteur. await attend la réponse sans bloquer l'écran.
      final messages = await widget.api.fetchMessages(
        token: widget.apiSession?.token,
      );
      // mounted : l'écran existe encore ? discussionsFrom regroupe les réponses
      // sous leur discussion ; setState redessine la liste.
      if (mounted) setState(() => _discussions = discussionsFrom(messages));
    // Jeton expiré : on déconnecte, avec un message sur l'écran de connexion.
    } on UnauthorizedException {
      widget.session.signOut(
        notice: 'Ta session a expiré. Reconnecte-toi pour continuer.',
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const AppLogo()),
      // RefreshIndicator : tirer la liste vers le bas relance reload().
      body: RefreshIndicator(onRefresh: reload, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final discussions = _discussions;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // onSignIn n'est fourni que pour un visiteur : on affiche alors le bandeau d'invitation.
        if (widget.onSignIn != null) ...[
          _JoinBanner(onSignIn: widget.onSignIn!),
          const SizedBox(height: 16),
        ],
        const Text(
          'Discussions récentes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        // Quatre cas : erreur, chargement en cours, liste vide, ou liste des discussions.
        if (_failed) ...[
          const FormNotice(
            text: 'Impossible d’afficher les discussions pour le moment. '
                'Vérifie ta connexion internet, puis réessaie.',
            kind: FormNoticeKind.error,
          ),
          TextButton(onPressed: reload, child: const Text('Réessayer')),
        ] else if (discussions == null)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (discussions.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Text(
              'Aucune discussion pour l’instant. Lance la première !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
            ),
          )
        else
          for (final discussion in discussions) ...[
            DiscussionCard(discussion: discussion),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

/// Invitation a se connecter, affichee aux visiteurs.
class _JoinBanner extends StatelessWidget {
  const _JoinBanner({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Rejoins la discussion : connecte-toi pour publier un message.',
              style: TextStyle(fontSize: 14, height: 1.35, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onSignIn,
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }
}

// Carte d'une discussion : avatar, auteur, date, titre, extrait, nombre de réponses.
class DiscussionCard extends StatelessWidget {
  const DiscussionCard({super.key, required this.discussion});

  final ApiDiscussion discussion;

  @override
  Widget build(BuildContext context) {
    final message = discussion.message;
    final date = message.datePoste;
    final replies = discussion.replyCount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatarColorFor(message.auteur),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    // L'avatar affiche l'initiale de l'auteur.
                    message.auteur.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.auteur,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (date != null) ...[
                const SizedBox(width: 6),
                Text(
                  // « il y a 5 min », « hier »… (voir lib/core/time_ago.dart).
                  timeAgo(date),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ],
          ),
          if (message.titre.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(message.titre, style: threadTitleStyle),
          ],
          const SizedBox(height: 6),
          Text(
            message.contenu,
            // On n'affiche que les 4 premières lignes du message.
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 16,
                color: AppColors.inkSoft,
              ),
              const SizedBox(width: 6),
              Text(
                // Texte selon le nombre de réponses (switch avec motifs, Dart 3).
                switch (replies) {
                  0 => 'Aucune réponse',
                  1 => '1 réponse',
                  final n => '$n réponses',
                },
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: replies > 0 ? FontWeight.w600 : FontWeight.w400,
                  color: replies > 0 ? AppColors.primary : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

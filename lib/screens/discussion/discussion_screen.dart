import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/app_scope.dart';
import '../../core/session.dart';
import '../../core/time_ago.dart';
import '../../models/deletion_labels.dart';
import '../../models/discussion.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/discussion_repository.dart';
import '../../widgets/notice.dart';
import '../../widgets/thread_line.dart';
import '../../widgets/user_avatar.dart';
import '../auth/login_screen.dart';
import 'message_actions.dart';

/// Une discussion : message principal, reponses accrochees au fil,
/// et barre de reponse en bas (fonctionnalite n° 11).
class DiscussionScreen extends StatefulWidget {
  const DiscussionScreen({
    super.key,
    required this.discussion,
    required this.repository,
    required this.auth,
  });

  final Discussion discussion;
  final DiscussionRepository repository;
  final AuthRepository auth;

  @override
  State<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends State<DiscussionScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  DiscussionThread? _thread;
  bool _failed = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _composer.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final thread = await widget.repository.fetchThread(widget.discussion.id);
      if (!mounted) return;
      setState(() => _thread = thread);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _send(User author) async {
    final thread = _thread;
    final text = _composer.text.trim();
    if (thread == null || text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final reply = await widget.repository.postReply(
        discussionId: thread.discussion.id,
        content: text,
        author: author,
      );
      if (!mounted) return;
      setState(() {
        _thread = DiscussionThread(
          discussion: thread.discussion.withReply(reply),
          replies: [...thread.replies, reply],
        );
        _composer.clear();
        _sending = false;
      });
      // La nouvelle reponse est en haut de la liste : on y remonte.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ta réponse n’a pas pu être envoyée. Réessaie.'),
        ),
      );
    }
  }

  /// Seul l'auteur d'un message actif peut le modifier ou le supprimer,
  /// et plus personne une fois la discussion fermee par la moderation.
  bool _canChange(Message message, User? user, Discussion discussion) {
    return user != null &&
        message.author.id == user.id &&
        !message.isDeleted &&
        !discussion.opening.isModerated;
  }

  Future<void> _openActions(Message message, User user, bool isOpening) async {
    final action = await showMessageActions(context);
    if (!mounted || action == null) return;
    switch (action) {
      case MessageAction.edit:
        await _edit(message, user, isOpening);
      case MessageAction.delete:
        await _delete(message, user, isOpening);
    }
  }

  Future<void> _edit(Message message, User user, bool isOpening) async {
    final discussionId = widget.discussion.id;
    final messenger = ScaffoldMessenger.of(context);
    final updated = await showEditMessageSheet(
      context,
      initialContent: message.content ?? '',
      isOpening: isOpening,
      onSave: (content) => widget.repository.editMessage(
        discussionId: discussionId,
        messageId: message.id,
        content: content,
        author: user,
      ),
    );
    if (!mounted || updated == null) return;
    _applyChange(updated, isOpening);
    messenger.showSnackBar(const SnackBar(content: Text('Message modifié.')));
  }

  Future<void> _delete(Message message, User user, bool isOpening) async {
    final confirmed = await confirmMessageDeletion(
      context,
      isOpening: isOpening,
    );
    if (!mounted || !confirmed) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final deleted = await widget.repository.deleteMessage(
        discussionId: widget.discussion.id,
        messageId: message.id,
        author: user,
      );
      if (!mounted) return;
      _applyChange(deleted, isOpening);
      messenger.showSnackBar(const SnackBar(content: Text('Message supprimé.')));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Le message n’a pas pu être supprimé. Réessaie.'),
        ),
      );
    }
  }

  /// Remplace le message dans l'ecran, puis previent les listes
  /// (accueil, Mes fils) pour qu'elles se rechargent.
  void _applyChange(Message updated, bool isOpening) {
    final thread = _thread;
    if (thread == null) return;
    setState(() {
      _thread = DiscussionThread(
        discussion: isOpening
            ? thread.discussion.withOpening(updated)
            : thread.discussion,
        replies: [
          for (final reply in thread.replies)
            reply.id == updated.id ? updated : reply,
        ],
      );
    });
    AppScope.of(context).events.discussionsChanged();
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LoginScreen(auth: widget.auth)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionScope.of(context).currentUser;
    final discussion = _thread?.discussion ?? widget.discussion;

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Discussion')),
      body: Column(
        children: [
          Expanded(child: _buildContent(user)),
          _buildBottom(discussion, user),
        ],
      ),
    );
  }

  Widget _buildContent(User? user) {
    if (_failed) {
      return CenteredNotice(
        text: 'Impossible de charger la discussion. '
            'Vérifie ta connexion, puis réessaie.',
        action: FilledButton(onPressed: _load, child: const Text('Réessayer')),
      );
    }
    final thread = _thread;
    if (thread == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Les plus recentes en haut, les plus anciennes en bas.
    final replies = [...thread.replies]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final discussion = thread.discussion;
    final openerId = discussion.opening.author.id;
    VoidCallback? actionsFor(Message message, {required bool isOpening}) {
      if (!_canChange(message, user, discussion)) return null;
      return () => _openActions(message, user!, isOpening);
    }

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _OpeningPost(
          discussion: discussion,
          onActions: actionsFor(discussion.opening, isOpening: true),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(
            switch (replies.length) {
              0 => 'Réponses',
              1 => '1 réponse',
              final n => '$n réponses',
            },
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        if (replies.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Pas encore de réponse. Lance la conversation.',
              style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
            ),
          ),
        for (var i = 0; i < replies.length; i++)
          ThreadLine(
            node: replies[i].isDeleted ? ThreadNode.deleted : ThreadNode.replied,
            isFirst: i == 0,
            isLast: i == replies.length - 1,
            child: _ReplyCard(
              reply: replies[i],
              isOpener: replies[i].author.id == openerId,
              onActions: actionsFor(replies[i], isOpening: false),
            ),
          ),
      ],
    );
  }

  Widget _buildBottom(Discussion discussion, User? user) {
    if (discussion.opening.isModerated) {
      return const _BottomBar(
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 18, color: AppColors.inkSoft),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cette discussion a été fermée par la modération.',
                style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
      );
    }

    if (user == null) {
      return _BottomBar(
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Connecte-toi pour répondre à cette discussion.',
                style: TextStyle(fontSize: 14, color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _openLogin,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              child: const Text('Se connecter'),
            ),
          ],
        ),
      );
    }

    final canSend = _composer.text.trim().isNotEmpty && !_sending;
    return _BottomBar(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _composer,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 15, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Écrire une réponse',
                hintStyle: const TextStyle(color: AppColors.inkSoft),
                isDense: true,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                border: _roundBorder,
                enabledBorder: _roundBorder,
                focusedBorder: _roundBorder,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Envoyer la réponse',
            onPressed: canSend ? () => _send(user) : null,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.skeleton,
            ),
            icon: _sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    Icons.arrow_upward,
                    color: canSend ? Colors.white : AppColors.inkSoft,
                  ),
          ),
        ],
      ),
    );
  }
}

const _roundBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(22)),
  borderSide: BorderSide.none,
);

/// Bandeau fixe en bas ; remonte au-dessus du clavier.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: child,
        ),
      ),
    );
  }
}

/// Le message principal, mis en avant au-dessus des reponses.
class _OpeningPost extends StatelessWidget {
  const _OpeningPost({required this.discussion, this.onActions});

  final Discussion discussion;

  /// Ouvre le menu « ⋯ » ; null quand l'utilisateur n'est pas l'auteur.
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context) {
    final opening = discussion.opening;
    final deleted = opening.isDeleted;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(user: opening.author, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opening.author.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      _dateLabel(opening),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (onActions != null)
                _ActionsButton(messageId: opening.id, onPressed: onActions!),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            deleted ? deletedDiscussionTitle(opening) : (discussion.title ?? ''),
            style: threadTitleStyle.copyWith(
              fontSize: 21,
              color: deleted ? AppColors.inkSoft : AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          if (deleted)
            _DeletionNotice(text: deletionNotice(opening))
          else
            Text(
              opening.content ?? '',
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: AppColors.ink,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    required this.reply,
    required this.isOpener,
    this.onActions,
  });

  final Message reply;

  /// Ouvre le menu « ⋯ » ; null quand l'utilisateur n'est pas l'auteur.
  final VoidCallback? onActions;

  /// La reponse vient de la personne qui a ouvert la discussion.
  final bool isOpener;

  @override
  Widget build(BuildContext context) {
    final deleted = reply.isDeleted;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _replyHeader()),
              if (onActions != null)
                _ActionsButton(messageId: reply.id, onPressed: onActions!),
            ],
          ),
          const SizedBox(height: 6),
          if (deleted)
            _DeletionNotice(text: deletionNotice(reply))
          else
            Text(
              reply.content ?? '',
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: AppColors.ink,
              ),
            ),
        ],
      ),
    );
  }

  Widget _replyHeader() {
    return Row(
      children: [
        UserAvatar(user: reply.author, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            reply.author.displayName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
        if (isOpener) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Auteur',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _dateLabel(reply),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
        ),
      ],
    );
  }
}

/// Date d'un message, avec la mention « modifié » s'il a ete corrige.
String _dateLabel(Message message) {
  final date = timeAgo(message.createdAt);
  return message.isEdited && !message.isDeleted ? '$date · modifié' : date;
}

/// Bouton « ⋯ » d'un message de l'utilisateur connecte.
class _ActionsButton extends StatelessWidget {
  const _ActionsButton({required this.messageId, required this.onPressed});

  final String messageId;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: IconButton(
        key: ValueKey('actions-$messageId'),
        tooltip: 'Options du message',
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: const Icon(Icons.more_horiz, color: AppColors.inkSoft),
      ),
    );
  }
}

class _DeletionNotice extends StatelessWidget {
  const _DeletionNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.block, size: 14, color: AppColors.inkSoft),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

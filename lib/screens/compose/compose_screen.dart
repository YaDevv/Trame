import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/app_scope.dart';
import '../../core/validators.dart';
import '../../models/discussion.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/discussion_repository.dart';
import '../../widgets/discussion_list.dart';
import '../../widgets/discussion_tile.dart';
import '../../widgets/user_avatar.dart';
import '../discussion/discussion_screen.dart';
import '../profile/rules_screen.dart';

const _titleMin = 5;
const _titleMax = 120;
const _contentMin = openingContentMinLength;

/// Longueur de titre a partir de laquelle on cherche des doublons.
const _similarFrom = 8;

/// Ecrire une nouvelle discussion. Inspire des editeurs des forums mobiles
/// (Reddit, Discourse) : compteur de titre, apercu avant publication et
/// discussions similaires pour eviter les doublons.
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({
    super.key,
    required this.author,
    required this.repository,
    required this.auth,
  });

  final User author;
  final DiscussionRepository repository;
  final AuthRepository auth;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _contentFocus = FocusNode();
  Timer? _similarDebounce;
  int _similarRequest = 0;
  List<Discussion> _similar = const [];
  bool _publishing = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(_onTitleChanged);
    _content.addListener(_refresh);
  }

  @override
  void dispose() {
    _similarDebounce?.cancel();
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _onTitleChanged() {
    setState(() {});
    _similarDebounce?.cancel();
    final query = _title.text.trim();
    if (query.length < _similarFrom) {
      if (_similar.isNotEmpty) setState(() => _similar = const []);
      return;
    }
    _similarDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _findSimilar(query),
    );
  }

  Future<void> _findSimilar(String query) async {
    final request = ++_similarRequest;
    try {
      final results = await widget.repository.searchDiscussions(query);
      if (!mounted || request != _similarRequest) return;
      setState(() => _similar = results.take(3).toList());
    } catch (_) {
      // Suggestion facultative : en cas d'erreur, on n'affiche rien.
    }
  }

  bool get _hasDraft =>
      _title.text.trim().isNotEmpty || _content.text.trim().isNotEmpty;

  String? get _titleError {
    if (_title.text.trim().length < _titleMin) {
      return 'Le titre doit faire au moins $_titleMin caractères.';
    }
    return null;
  }

  String? get _contentError {
    if (_content.text.trim().length < _contentMin) {
      return 'Ton message doit faire au moins $_contentMin caractères.';
    }
    return null;
  }

  Future<void> _publish() async {
    if (_publishing) return;
    if (_titleError != null || _contentError != null) {
      setState(() => _showErrors = true);
      return;
    }

    final events = AppScope.of(context).events;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _publishing = true);
    try {
      final discussion = await widget.repository.createDiscussion(
        title: _title.text,
        content: _content.text,
        author: widget.author,
      );
      events.discussionsChanged();
      // On remplace le brouillon par la discussion publiee.
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DiscussionScreen(
            discussion: discussion,
            repository: widget.repository,
            auth: widget.auth,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _publishing = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('La discussion n’a pas pu être publiée. Réessaie.'),
        ),
      );
    }
  }

  Future<void> _confirmDiscard() async {
    final navigator = Navigator.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Abandonner ce brouillon ?'),
        content: const Text('Ton titre et ton message seront perdus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuer à écrire'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    if (discard == true) {
      _title.clear();
      _content.clear();
      navigator.pop();
    }
  }

  void _close() {
    if (_hasDraft) {
      _confirmDiscard();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Montre la discussion telle qu'elle apparaitra dans le fil.
  void _showPreview() {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final draft = Discussion(
      id: 'apercu',
      title: _title.text.trim().isEmpty ? 'Ton titre' : _title.text.trim(),
      opening: Message(
        id: 'apercu',
        author: widget.author,
        content: _content.text.trim().isEmpty
            ? 'Ton message apparaîtra ici.'
            : _content.text.trim(),
        createdAt: now,
      ),
      replyCount: 0,
      lastActivityAt: now,
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Aperçu dans le fil',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
            DiscussionTile(
              discussion: draft,
              isFirst: true,
              isLast: true,
              onTap: () {},
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPublish = _hasDraft && !_publishing;
    final titleLength = _title.text.length;

    return PopScope(
      // Un brouillon n'est jamais perdu par un retour accidentel.
      canPop: !_hasDraft || _publishing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
          title: Text(
            'Nouvelle discussion',
            style: logoStyle.copyWith(fontSize: 19),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: canPublish ? _publish : null,
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: _publishing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Publier'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                children: [
                  _AuthorRow(author: widget.author),
                  const SizedBox(height: 10),
                  _EditorCard(
                    title: _title,
                    content: _content,
                    contentFocus: _contentFocus,
                    titleLength: titleLength,
                    titleError: _showErrors ? _titleError : null,
                    contentError: _showErrors ? _contentError : null,
                  ),
                  if (_similar.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SimilarSection(discussions: _similar),
                  ],
                  if (!_hasDraft) ...[
                    const SizedBox(height: 16),
                    const _TipsCard(),
                  ],
                ],
              ),
            ),
            _Toolbar(
              contentLength: _content.text.trim().length,
              onPreview: _hasDraft ? _showPreview : null,
              onRules: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RulesScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.author});

  final User author;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          UserAvatar(user: author, size: 38),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author.displayName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.public, size: 13, color: AppColors.inkSoft),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Publique · lisible par tous',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ],
      ),
    );
  }
}

/// Le titre et le message dans une seule carte, comme un brouillon.
class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.title,
    required this.content,
    required this.contentFocus,
    required this.titleLength,
    required this.titleError,
    required this.contentError,
  });

  final TextEditingController title;
  final TextEditingController content;
  final FocusNode contentFocus;
  final int titleLength;
  final String? titleError;
  final String? contentError;

  @override
  Widget build(BuildContext context) {
    final nearLimit = titleLength > _titleMax - 15;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: title,
            autofocus: true,
            maxLength: _titleMax,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => contentFocus.requestFocus(),
            style: threadTitleStyle.copyWith(fontSize: 21),
            decoration: _bare(
              hint: 'Titre de ta discussion',
              hintStyle: threadTitleStyle.copyWith(
                fontSize: 21,
                color: AppColors.inkSoft.withValues(alpha: 0.55),
              ),
              error: titleError,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$titleLength/$_titleMax',
              style: TextStyle(
                fontSize: 12,
                color: nearLimit ? AppColors.danger : AppColors.inkSoft,
              ),
            ),
          ),
          const Divider(height: 14),
          TextField(
            controller: content,
            focusNode: contentFocus,
            minLines: 7,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.45,
              color: AppColors.ink,
            ),
            decoration: _bare(
              hint: 'Explique ta question : le contexte, ce que tu as '
                  'déjà essayé, ce que tu attends des autres.',
              hintStyle: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: AppColors.inkSoft,
              ),
              error: contentError,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _bare({
  required String hint,
  required TextStyle hintStyle,
  String? error,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: hintStyle,
    hintMaxLines: 3,
    errorText: error,
    errorMaxLines: 2,
    counterText: '',
    filled: false,
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
  );
}

/// Comme Discourse : on montre les sujets proches avant de publier.
class _SimilarSection extends StatelessWidget {
  const _SimilarSection({required this.discussions});

  final List<Discussion> discussions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 2),
          child: Text(
            'Discussions similaires',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Ta question a peut-être déjà une réponse.',
            style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
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
              for (var i = 0; i < discussions.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 14),
                InkWell(
                  onTap: () => openDiscussion(context, discussions[i]),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                discussions[i].title ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: threadTitleStyle.copyWith(fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                switch (discussions[i].replyCount) {
                                  0 => 'Aucune réponse',
                                  1 => '1 réponse',
                                  final n => '$n réponses',
                                },
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.inkSoft,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  static const _tips = [
    'Un titre qui résume ta question en une phrase.',
    'Le contexte et ce que tu as déjà essayé.',
    'Un ton courtois : on répond mieux à une question bien posée.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: AppColors.accent),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pour obtenir des réponses',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final tip in _tips)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: CircleAvatar(
                      radius: 2.5,
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Barre fixee au-dessus du clavier, comme dans les editeurs mobiles.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.contentLength,
    required this.onPreview,
    required this.onRules,
  });

  final int contentLength;
  final VoidCallback? onPreview;
  final VoidCallback onRules;

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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _ToolButton(
                icon: Icons.visibility_outlined,
                label: 'Aperçu',
                onTap: onPreview,
              ),
              _ToolButton(
                icon: Icons.gavel_outlined,
                label: 'Règles',
                onTap: onRules,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    contentLength <= 1
                        ? '$contentLength caractère'
                        : '$contentLength caractères',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? AppColors.border : AppColors.primary;
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: const StadiumBorder(),
      ),
    );
  }
}

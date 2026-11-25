import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/forum_events.dart';
import '../../models/discussion.dart';
import '../../models/user.dart';
import '../../repositories/discussion_repository.dart';
import '../../widgets/discussion_list.dart';
import '../../widgets/discussion_skeleton.dart';
import '../../widgets/notice.dart';

/// Les discussions ouvertes par l'utilisateur ou auxquelles il a repondu.
class MyThreadsScreen extends StatefulWidget {
  const MyThreadsScreen({
    super.key,
    required this.discussions,
    required this.user,
  });

  final DiscussionRepository discussions;
  final User user;

  @override
  State<MyThreadsScreen> createState() => _MyThreadsScreenState();
}

class _MyThreadsScreenState extends State<MyThreadsScreen> {
  List<Discussion>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ForumEvents? _events;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recharge quand une discussion est publiee ailleurs dans l'application.
    final events = AppScope.of(context).events;
    if (!identical(events, _events)) {
      _events?.removeListener(_onForumChanged);
      _events = events..addListener(_onForumChanged);
    }
  }

  @override
  void dispose() {
    _events?.removeListener(_onForumChanged);
    super.dispose();
  }

  void _onForumChanged() => _load();

  Future<void> _load() async {
    try {
      final items = await widget.discussions.fetchMyDiscussions(widget.user.id);
      if (!mounted) return;
      setState(() {
        _items = items;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Mes fils')),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_failed) {
      return CenteredNotice(
        text: 'Impossible de charger tes discussions. '
            'Vérifie ta connexion, puis réessaie.',
        action: FilledButton(onPressed: _load, child: const Text('Réessayer')),
      );
    }
    final items = _items;
    if (items == null) return const DiscussionSkeletonList();
    if (items.isEmpty) {
      return const CenteredNotice(
        icon: Icons.forum_outlined,
        text: 'Tu n’as encore ouvert ni rejoint aucune discussion. '
            'Appuie sur + pour lancer la première.',
      );
    }
    return DiscussionList(items: items, onRefresh: _load);
  }
}

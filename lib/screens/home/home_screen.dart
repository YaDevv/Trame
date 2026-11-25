import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/forum_events.dart';
import '../../models/discussion.dart';
import '../../repositories/discussion_repository.dart';
import '../../widgets/discussion_skeleton.dart';
import '../../widgets/discussion_list.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/notice.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.discussions});

  final DiscussionRepository discussions;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DiscussionFilter _filter = DiscussionFilter.recent;
  List<Discussion>? _items;
  bool _failed = false;
  int _requestId = 0;

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
    final request = ++_requestId;
    try {
      final items = await widget.discussions.fetchDiscussions(_filter);
      if (!mounted || request != _requestId) return;
      setState(() {
        _items = items;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _items = null;
        _failed = true;
      });
    }
  }

  void _selectFilter(DiscussionFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _items = null;
      _failed = false;
    });
    _load();
  }

  void _retry() {
    setState(() => _failed = false);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: const AppLogo(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              FilterBar(selected: _filter, onSelected: _selectFilter),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_failed) {
      return CenteredNotice(
        text: 'Impossible de charger les discussions. '
            'Vérifie ta connexion, puis réessaie.',
        action: FilledButton(onPressed: _retry, child: const Text('Réessayer')),
      );
    }

    final items = _items;
    if (items == null) {
      return const DiscussionSkeletonList();
    }
    if (items.isEmpty) {
      return CenteredNotice(
        text: _filter == DiscussionFilter.unanswered
            ? 'Toutes les discussions ont déjà une réponse.'
            : 'Aucune discussion pour le moment.',
      );
    }

    return DiscussionList(items: items, onRefresh: _load);
  }
}

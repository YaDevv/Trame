import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/discussion.dart';
import '../screens/discussion/discussion_screen.dart';
import 'discussion_tile.dart';

/// Ouvre une discussion par-dessus la barre du bas.
Future<void> openDiscussion(BuildContext context, Discussion discussion) {
  final scope = AppScope.of(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DiscussionScreen(
        discussion: discussion,
        repository: scope.discussions,
        auth: scope.auth,
      ),
    ),
  );
}

class DiscussionList extends StatelessWidget {
  const DiscussionList({super.key, required this.items, this.onRefresh});

  final List<Discussion> items;
  final RefreshCallback? onRefresh;

  Future<void> _open(BuildContext context, Discussion discussion) async {
    await openDiscussion(context, discussion);
    // Au retour, les compteurs ont pu changer (nouvelle reponse).
    await onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    final list = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: items.length,
      itemBuilder: (context, index) => DiscussionTile(
        discussion: items[index],
        isFirst: index == 0,
        isLast: index == items.length - 1,
        onTap: () => _open(context, items[index]),
      ),
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

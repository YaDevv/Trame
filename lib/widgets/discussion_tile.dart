import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/time_ago.dart';
import '../models/deletion_labels.dart';
import '../models/discussion.dart';
import 'thread_line.dart';
import 'user_avatar.dart';

const _freshWindow = Duration(hours: 24);

/// Une discussion : carte blanche accrochee au fil.
class DiscussionTile extends StatelessWidget {
  const DiscussionTile({
    super.key,
    required this.discussion,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final Discussion discussion;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  bool get _isFresh =>
      !discussion.opening.isDeleted &&
      DateTime.now().difference(discussion.lastActivityAt) < _freshWindow;

  ThreadNode get _node {
    if (discussion.opening.isDeleted) return ThreadNode.deleted;
    if (_isFresh) return ThreadNode.fresh;
    return discussion.replyCount > 0 ? ThreadNode.replied : ThreadNode.empty;
  }

  @override
  Widget build(BuildContext context) {
    final opening = discussion.opening;

    return ThreadLine(
      node: _node,
      isFirst: isFirst,
      isLast: isLast,
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(user: opening.author, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${opening.author.displayName}, '
                        '${timeAgo(opening.createdAt)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                    if (_isFresh) const _NewLabel(),
                  ],
                ),
                const SizedBox(height: 6),
                _Body(discussion: discussion),
                const SizedBox(height: 8),
                _ActivityLine(discussion: discussion),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewLabel extends StatelessWidget {
  const _NewLabel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 8),
      child: Text(
        'Nouveau',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.discussion});

  final Discussion discussion;

  @override
  Widget build(BuildContext context) {
    final opening = discussion.opening;

    // Supprime (par son auteur ou la moderation) : seule la mention reste.
    if (opening.isDeleted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deletedDiscussionTitle(opening),
            style: threadTitleStyle.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 4),
          _DeletionNotice(deletionNotice(opening)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(discussion.title ?? '', style: threadTitleStyle),
        const SizedBox(height: 4),
        Text(
          opening.content ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            height: 1.35,
            color: AppColors.inkSoft,
          ),
        ),
      ],
    );
  }
}

class _DeletionNotice extends StatelessWidget {
  const _DeletionNotice(this.text);

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

class _ActivityLine extends StatelessWidget {
  const _ActivityLine({required this.discussion});

  final Discussion discussion;

  @override
  Widget build(BuildContext context) {
    final count = discussion.replyCount;
    final hasReplies = count > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.chat_bubble_outline,
            size: 14,
            color: hasReplies ? AppColors.primary : AppColors.inkSoft,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(child: hasReplies ? _replies(count) : _noReply()),
      ],
    );
  }

  Widget _noReply() {
    return const Text(
      'Aucune réponse',
      style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
    );
  }

  Widget _replies(int count) {
    final replier = discussion.lastReplier?.displayName;
    final activity = timeAgo(discussion.lastActivityAt);
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
        children: [
          TextSpan(
            text: count == 1 ? '1 réponse' : '$count réponses',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          TextSpan(
            text: replier == null
                ? ', dernière $activity'
                : ', dernière de $replier $activity',
          ),
        ],
      ),
    );
  }
}

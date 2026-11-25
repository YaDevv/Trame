import 'package:flutter/widgets.dart';

import '../repositories/auth_repository.dart';
import 'forum_events.dart';
import '../repositories/discussion_repository.dart';

/// Rend les repositories accessibles aux ecrans ouverts par-dessus la barre.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.discussions,
    required this.auth,
    required this.events,
    required super.child,
  });

  final DiscussionRepository discussions;
  final AuthRepository auth;
  final ForumEvents events;

  static AppScope of(BuildContext context) {
    return context.getInheritedWidgetOfExactType<AppScope>()!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return discussions != oldWidget.discussions ||
        auth != oldWidget.auth ||
        events != oldWidget.events;
  }
}

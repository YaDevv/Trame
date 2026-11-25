import 'package:flutter/foundation.dart';

/// Previent les listes quand le contenu du forum change
/// (nouvelle discussion), pour qu'elles se rechargent.
class ForumEvents extends ChangeNotifier {
  void discussionsChanged() => notifyListeners();
}

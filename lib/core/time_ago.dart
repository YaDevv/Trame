const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
  'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/// Date relative en francais : "il y a 5 min", "hier", "12 mars".
String timeAgo(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final elapsed = current.difference(date);

  if (elapsed.inMinutes < 1) return "à l'instant";
  if (elapsed.inMinutes < 60) return 'il y a ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) return 'il y a ${elapsed.inHours} h';
  if (elapsed.inDays < 2) return 'hier';
  if (elapsed.inDays < 7) return 'il y a ${elapsed.inDays} jours';
  return '${date.day} ${_months[date.month - 1]}';
}

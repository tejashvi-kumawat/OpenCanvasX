import 'dart:io';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "just now", "5 min ago", "3 h ago", "Yesterday", "12 Oct 2026".
String relativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24 && current.day == time.day) {
    return '${diff.inHours} h ago';
  }
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(time.year, time.month, time.day);
  if (today.difference(day).inDays == 1) return 'Yesterday';
  return '${time.day} ${_months[time.month - 1]} ${time.year}';
}

/// Shortens [path] in the middle so the drive and the last folders stay
/// visible: `C:\Users\…\Designs\OpenCanvasX`.
String shortenPath(String path, {int maxLength = 42}) {
  if (path.length <= maxLength) return path;
  final sep = Platform.pathSeparator;
  final parts = path.split(sep);
  if (parts.length <= 3) {
    return '${path.substring(0, maxLength ~/ 2)}…'
        '${path.substring(path.length - maxLength ~/ 2)}';
  }
  final head = parts.first;
  final tail = <String>[];
  var length = head.length + 2;
  for (final part in parts.reversed) {
    if (length + part.length + 1 > maxLength && tail.isNotEmpty) break;
    tail.insert(0, part);
    length += part.length + 1;
  }
  return '$head$sep…$sep${tail.join(sep)}';
}

/// `1080 × 1080 px`, `210 × 297 mm`.
String sizeLabel(double width, double height, String unit) {
  String f(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return '${f(width)} × ${f(height)} $unit';
}

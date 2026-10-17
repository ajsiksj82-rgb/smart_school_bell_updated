String two(int v) => v.toString().padLeft(2, '0');

String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

DateTime? parseYmd(String? s) {
  if (s == null) return null;
  final p = s.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  final dt = DateTime(y, m, d);
  if (dt.year != y || dt.month != m || dt.day != d) return null;
  return dt;
}

/// 'HH:mm' => دقائق منذ منتصف الليل، أو null إذا كانت الصيغة غير صحيحة.
int? parseHm(String? s) {
  if (s == null) return null;
  final p = s.split(':');
  if (p.length < 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

String hm(int minutes) => '${two(minutes ~/ 60)}:${two(minutes % 60)}';

/// أيام الأسبوع بترقيم Dart: الاثنين=1 ... الأحد=7.
const Map<int, String> weekdayNames = {
  6: 'السبت',
  7: 'الأحد',
  1: 'الاثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
};

/// ترتيب العرض: من السبت إلى الجمعة.
const List<int> weekdayOrder = [6, 7, 1, 2, 3, 4, 5];

const List<String> _months = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

String arabicDate(DateTime d) =>
    '${weekdayNames[d.weekday]} ${d.day} ${_months[d.month - 1]} ${d.year}';

String formatClock(DateTime d) => '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';

String formatDuration(Duration d) {
  final total = ((d.inMilliseconds + 999) ~/ 1000).clamp(0, 1 << 30);
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../models/lesson_progress_models.dart';
import '../services/lesson_progress_controller.dart';
import '../services/progress_calculator.dart';

const Color _lessonColor = Color(0xFF1565C0);
const Color _breakColor = Color(0xFF2E7D32);
const Color _assemblyColor = Color(0xFF6A1B9A);
const Color _nowColor = Color(0xFFEF6C00);

Color _kindColor(SegmentKind k) => switch (k) {
      SegmentKind.lesson => _lessonColor,
      SegmentKind.breakTime => _breakColor,
      SegmentKind.assembly => _assemblyColor,
    };

/// السير الزمني ليوم الدوام: شريط متناسب مع الوقت + قائمة بالحصص والاستراحات.
class DayTimeline extends StatefulWidget {
  const DayTimeline({super.key, required this.controller});

  final LessonProgressController controller;

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProgressSnapshot?>(
      valueListenable: widget.controller.snapshot,
      builder: (context, snap, _) {
        var segs = widget.controller.segments;
        var preview = false;
        String? previewDay;
        if (snap != null && segs.isEmpty) {
          final up = widget.controller.upcomingDay;
          if (up != null && up.segments.isNotEmpty) {
            segs = up.segments;
            preview = true;
            previewDay = _dayName(snap.now, up.date);
          }
        }
        if (snap == null || segs.isEmpty) return const SizedBox.shrink();
        final now = snap.now;
        final theme = Theme.of(context);

        final lessons = segs.where((s) => s.kind == SegmentKind.lesson).toList();
        final doneLessons = lessons.where((s) => !s.end.isAfter(now)).length;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Card(
            elevation: 3,
            shadowColor: const Color(0xFF0D2B5E).withAlpha(60),
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: Colors.blueGrey.withAlpha(40)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Row(
                      children: [
                        const Icon(Icons.timeline, color: _lessonColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              preview ? 'جدول $previewDay' : 'السير الزمني لليوم',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        if (lessons.isNotEmpty && !preview)
                          Text('انتهى $doneLessons من ${lessons.length} حصص',
                              style: theme.textTheme.bodySmall),
                        Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DayStrip(segments: segs, now: now),
                  const SizedBox(height: 10),
                  const _Legend(),
                  if (_expanded) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    for (var i = 0; i < segs.length; i++)
                      _TimelineRow(
                        segment: segs[i],
                        now: now,
                        isFirst: i == 0,
                        isLast: i == segs.length - 1,
                        preview: preview,
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// شريط اليوم: كل فترة بعرض يتناسب مع مدتها، وعلامة «الآن» تتحرك مع الوقت.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.segments, required this.now});

  final List<DaySegment> segments;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final dayStart = segments.first.start;
    final dayEnd = segments.last.end;
    final totalMs = dayEnd.difference(dayStart).inMilliseconds;
    if (totalMs <= 0) return const SizedBox.shrink();

    double frac(DateTime t) =>
        (t.difference(dayStart).inMilliseconds / totalMs).clamp(0.0, 1.0);

    final nowFrac = frac(now);
    final inDay = !now.isBefore(dayStart) && !now.isAfter(dayEnd);
    final theme = Theme.of(context);

    return Column(
      children: [
        SizedBox(
          height: 34,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // المسار الخلفي
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    top: 10,
                    height: 14,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withAlpha(30),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                  for (final s in segments)
                    PositionedDirectional(
                      start: w * frac(s.start),
                      top: 10,
                      height: 14,
                      width: (w * (frac(s.end) - frac(s.start)) - 2).clamp(2.0, w),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          // الفترات المنتهية أخفّ لونًا
                          color: _kindColor(s.kind)
                              .withAlpha(!s.end.isAfter(now) ? 90 : 255),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  if (inDay)
                    PositionedDirectional(
                      start: (w * nowFrac - 7).clamp(0.0, w - 14),
                      top: 0,
                      width: 14,
                      height: 34,
                      child: Column(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: _nowColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 3)
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(width: 2, color: _nowColor),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_hm(dayStart), style: _timeStyle(theme)),
            Text(_hm(dayEnd), style: _timeStyle(theme)),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 4),
          Text(t, style: Theme.of(context).textTheme.bodySmall),
        ]);
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        item(_lessonColor, 'حصة'),
        item(_breakColor, 'استراحة'),
        item(_assemblyColor, 'طابور'),
        item(_nowColor, 'الآن'),
      ],
    );
  }
}

enum _State { done, current, upcoming }

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.segment,
    required this.now,
    required this.isFirst,
    required this.isLast,
    this.preview = false,
  });

  /// معاينة يوم قادم: لا عدّ تنازلي، فقط الأوقات.
  final bool preview;

  final DaySegment segment;
  final DateTime now;
  final bool isFirst;
  final bool isLast;

  _State get _state {
    if (!segment.end.isAfter(now)) return _State.done;
    if (!now.isBefore(segment.start)) return _State.current;
    return _State.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = _state;
    final kindColor = _kindColor(segment.kind);
    final color = st == _State.current ? _nowColor : kindColor;
    final muted = st == _State.done;

    final String status;
    switch (st) {
      case _State.done:
        status = 'انتهت';
      case _State.current:
        status = 'جارية • متبقي ${_words(segment.end.difference(now))}';
      case _State.upcoming:
        status = preview ? '' : 'بعد ${_words(segment.start.difference(now))}';
    }

    final subject = segment.subject?.trim();
    final title = segment.kind == SegmentKind.lesson &&
            subject != null &&
            subject.isNotEmpty
        ? '${segment.name} • $subject'
        : segment.name;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : Colors.blueGrey.withAlpha(60),
                  ),
                ),
                _Dot(state: st, color: color),
                Expanded(
                  flex: 3,
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.blueGrey.withAlpha(60),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: st == _State.current ? _nowColor.withAlpha(24) : null,
                borderRadius: BorderRadius.circular(12),
                border: st == _State.current
                    ? Border.all(color: _nowColor.withAlpha(110))
                    : null,
              ),
              child: Opacity(
                opacity: muted ? 0.55 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: st == _State.current ? _nowColor : null)),
                        ),
                        Text('${_hm(segment.start)} – ${_hm(segment.end)}',
                            style: _timeStyle(theme)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (status.isNotEmpty) Text(status, style: theme.textTheme.bodySmall),
                    if (st == _State.current) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ProgressCalculator.fractionOf(
                              now, segment.start, segment.end),
                          minHeight: 6,
                          backgroundColor: _nowColor.withAlpha(40),
                          valueColor: const AlwaysStoppedAnimation<Color>(_nowColor),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.state, required this.color});

  final _State state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _State.done:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: color.withAlpha(150), shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 14, color: Colors.white),
        );
      case _State.current:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withAlpha(100), blurRadius: 8, spreadRadius: 2)],
          ),
          child: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
        );
      case _State.upcoming:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        );
    }
  }
}

TextStyle? _timeStyle(ThemeData theme) => theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w600,
    );

String _two(int v) => v.toString().padLeft(2, '0');

String _hm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// نص مختصر للمدة (تقريب للأعلى): "1 س 05 د" أو "27 د" أو "45 ث".
String _words(Duration d) {
  final ms = d.inMilliseconds < 0 ? 0 : d.inMilliseconds;
  final total = (ms + 999) ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (h > 0) return '$h س ${_two(m)} د';
  if (m > 0) return '$m د ${_two(s)} ث';
  return '$s ث';
}

String _dayName(DateTime now, DateTime d) {
  final diff = DateTime(d.year, d.month, d.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (diff == 1) return 'الغد';
  const names = {
    DateTime.saturday: 'السبت',
    DateTime.sunday: 'الأحد',
    DateTime.monday: 'الاثنين',
    DateTime.tuesday: 'الثلاثاء',
    DateTime.wednesday: 'الأربعاء',
    DateTime.thursday: 'الخميس',
    DateTime.friday: 'الجمعة',
  };
  return 'يوم ${names[d.weekday] ?? ''}';
}

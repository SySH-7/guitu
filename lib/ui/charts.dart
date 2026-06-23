import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/archive_store.dart';

const Color archiveOrange = Color(0xFFFF8A1F);
const Color archiveBlue = Color(0xFF1E88FF);
const Color archiveGreen = Color(0xFF44B75C);

class CombinedBarChart extends StatelessWidget {
  const CombinedBarChart({
    super.key,
    required this.bookValues,
    required this.filmValues,
  });

  final List<int> bookValues;
  final List<int> filmValues;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      width: double.infinity,
      child: CustomPaint(
        painter: _CombinedBarPainter(
          bookValues: bookValues,
          filmValues: filmValues,
          axisColor: Theme.of(context).dividerColor.withOpacity(0.42),
          labelColor:
              Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.58) ??
                  Colors.black54,
        ),
      ),
    );
  }
}

class _CombinedBarPainter extends CustomPainter {
  const _CombinedBarPainter({
    required this.bookValues,
    required this.filmValues,
    required this.axisColor,
    required this.labelColor,
  });

  final List<int> bookValues;
  final List<int> filmValues;
  final Color axisColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    const double left = 28;
    const double top = 10;
    const double bottom = 28;
    final double chartHeight = size.height - top - bottom;
    final double chartWidth = size.width - left - 8;
    final int maxValue =
        math.max(5, <int>[...bookValues, ...filmValues].fold<int>(0, math.max));

    for (int i = 0; i <= 3; i += 1) {
      final double y = top + chartHeight * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), gridPaint);
    }

    final Paint bookPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFFFF6B00), Color(0xFFFFB65A)],
      ).createShader(Rect.fromLTWH(0, top, 0, chartHeight));
    final Paint filmPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF1075FF), Color(0xFF76BBFF)],
      ).createShader(Rect.fromLTWH(0, top, 0, chartHeight));

    final double groupWidth = chartWidth / 12;
    final double barWidth = math.max(4, groupWidth * 0.18);
    for (int i = 0; i < 12; i += 1) {
      final double centerX = left + groupWidth * (i + 0.5);
      final double bookHeight = chartHeight * (bookValues[i] / maxValue);
      final double filmHeight = chartHeight * (filmValues[i] / maxValue);
      final RRect bookRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - barWidth - 2, top + chartHeight - bookHeight,
            barWidth, bookHeight),
        const Radius.circular(4),
      );
      final RRect filmRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            centerX + 2, top + chartHeight - filmHeight, barWidth, filmHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(bookRect, bookPaint);
      canvas.drawRRect(filmRect, filmPaint);
      _drawText(canvas, '${i + 1}月', Offset(centerX, size.height - 14), 9,
          labelColor, TextAlign.center);
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, double size,
      Color color, TextAlign align) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: size, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    painter.paint(
        canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CombinedBarPainter oldDelegate) {
    return oldDelegate.bookValues != bookValues ||
        oldDelegate.filmValues != filmValues ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.labelColor != labelColor;
  }
}

class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.palette,
  });

  final Map<String, int> values;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, int>> entries = values.entries
        .toList(growable: false)
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));
    final int total = entries.fold<int>(
        0, (int sum, MapEntry<String, int> entry) => sum + entry.value);

    return Row(
      children: <Widget>[
        SizedBox(
          width: 92,
          height: 92,
          child: CustomPaint(
            painter: _DonutPainter(entries: entries, palette: palette),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: total == 0
              ? Text('暂无数据', style: Theme.of(context).textTheme.bodySmall)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List<Widget>.generate(math.min(4, entries.length),
                      (int index) {
                    final MapEntry<String, int> entry = entries[index];
                    final int percent =
                        total == 0 ? 0 : (entry.value / total * 100).round();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: palette[index % palette.length],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${entry.key} $percent%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.entries,
    required this.palette,
  });

  final List<MapEntry<String, int>> entries;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE9EDF2);
    canvas.drawCircle(center, radius - 9, base);

    final int total = entries.fold<int>(
        0, (int sum, MapEntry<String, int> entry) => sum + entry.value);
    if (total == 0) {
      return;
    }
    double start = -math.pi / 2;
    for (int i = 0; i < entries.length; i += 1) {
      final double sweep = entries[i].value / total * math.pi * 2;
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..color = palette[i % palette.length];
      canvas.drawArc(
          rect.deflate(9), start, math.max(0.03, sweep - 0.03), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.entries != entries || oldDelegate.palette != palette;
  }
}

class YearLineChart extends StatelessWidget {
  const YearLineChart({
    super.key,
    required this.bookValues,
    required this.filmValues,
  });

  final List<YearStatPoint> bookValues;
  final List<YearStatPoint> filmValues;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 178,
      width: double.infinity,
      child: CustomPaint(
        painter: _YearLinePainter(
          bookValues: bookValues,
          filmValues: filmValues,
          gridColor: Theme.of(context).dividerColor.withOpacity(0.40),
          labelColor:
              Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.58) ??
                  Colors.black54,
        ),
      ),
    );
  }
}

class _YearLinePainter extends CustomPainter {
  const _YearLinePainter({
    required this.bookValues,
    required this.filmValues,
    required this.gridColor,
    required this.labelColor,
  });

  final List<YearStatPoint> bookValues;
  final List<YearStatPoint> filmValues;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final List<String> labels = <String>{
      ...bookValues.map((YearStatPoint point) => point.label),
      ...filmValues.map((YearStatPoint point) => point.label),
    }.toList(growable: false);
    if (labels.isEmpty) {
      return;
    }
    int valueFor(List<YearStatPoint> values, String label) {
      for (final YearStatPoint point in values) {
        if (point.label == label) {
          return point.value;
        }
      }
      return 0;
    }

    final int maxValue = math.max(
      5,
      <int>[
        ...labels.map((String label) => valueFor(bookValues, label)),
        ...labels.map((String label) => valueFor(filmValues, label)),
      ].fold<int>(0, math.max),
    );
    const double left = 26;
    const double right = 10;
    const double top = 12;
    const double bottom = 32;
    final double chartWidth = size.width - left - right;
    final double chartHeight = size.height - top - bottom;
    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i += 1) {
      final double y = top + chartHeight * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
    }

    List<Offset> pointsFor(List<YearStatPoint> values) {
      return List<Offset>.generate(labels.length, (int index) {
        final int value = valueFor(values, labels[index]);
        final double x = labels.length == 1
            ? left + chartWidth / 2
            : left + chartWidth * index / (labels.length - 1);
        final double y = top + chartHeight - chartHeight * (value / maxValue);
        return Offset(x, y);
      });
    }

    _drawSeries(canvas, pointsFor(bookValues), archiveOrange);
    _drawSeries(canvas, pointsFor(filmValues), archiveBlue);

    for (int i = 0; i < labels.length; i += 1) {
      final double x = labels.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * i / (labels.length - 1);
      _drawText(canvas, labels[i], Offset(x, size.height - 14), 9, labelColor);
    }
  }

  void _drawSeries(Canvas canvas, List<Offset> points, Color color) {
    if (points.isEmpty) {
      return;
    }
    if (points.length == 1) {
      final Paint dot = Paint()..color = color;
      canvas.drawCircle(points.single, 3.4, dot);
      canvas.drawCircle(
          points.single, 5.6, Paint()..color = color.withOpacity(0.12));
      return;
    }
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i += 1) {
      final Offset previous = points[i - 1];
      final Offset current = points[i];
      final Offset controlA =
          Offset(previous.dx + (current.dx - previous.dx) / 2, previous.dy);
      final Offset controlB =
          Offset(previous.dx + (current.dx - previous.dx) / 2, current.dy);
      path.cubicTo(controlA.dx, controlA.dy, controlB.dx, controlB.dy,
          current.dx, current.dy);
    }
    final Paint line = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, line);
    final Paint dot = Paint()..color = color;
    for (final Offset point in points) {
      canvas.drawCircle(point, 3.2, dot);
      canvas.drawCircle(point, 5.4, Paint()..color = color.withOpacity(0.12));
    }
  }

  void _drawText(
      Canvas canvas, String text, Offset center, double size, Color color) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: size, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
        canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _YearLinePainter oldDelegate) {
    return oldDelegate.bookValues != bookValues ||
        oldDelegate.filmValues != filmValues ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}

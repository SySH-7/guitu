import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String southChinaSeaBoundaryGb = '156990000';
const int southChinaSeaDashCount = 9;

class GeoProvince {
  const GeoProvince({
    required this.name,
    required this.polygons,
    this.center,
  });

  final String name;
  final List<List<List<Offset>>> polygons;
  final Offset? center;
}

class GeoBoundary {
  const GeoBoundary({
    required this.lines,
  });

  final List<List<Offset>> lines;
}

class GeoChinaData {
  const GeoChinaData({
    required this.provinces,
    required this.boundaries,
    required this.bounds,
  });

  final List<GeoProvince> provinces;
  final List<GeoBoundary> boundaries;
  final Rect bounds;
}

class ProvinceMapView extends StatefulWidget {
  const ProvinceMapView({
    super.key,
    required this.counts,
    this.selectedProvince,
    required this.onSelected,
  });

  final Map<String, int> counts;
  final String? selectedProvince;
  final ValueChanged<String> onSelected;

  @override
  State<ProvinceMapView> createState() => _ProvinceMapViewState();
}

class _ProvinceMapViewState extends State<ProvinceMapView> {
  late final Future<GeoChinaData> _future = _loadChinaGeoData();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GeoChinaData>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<GeoChinaData> snapshot) {
        if (snapshot.hasError) {
          return AspectRatio(
            aspectRatio: 1.12,
            child: Center(
              child: Text(
                '地图数据未配置',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.68),
                    ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const AspectRatio(
            aspectRatio: 1.12,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return AspectRatio(
          aspectRatio: 1.12,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Size size =
                  Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (TapDownDetails details) {
                  final String? province =
                      _provinceAt(snapshot.data!, details.localPosition, size);
                  if (province != null) {
                    widget.onSelected(province);
                  }
                },
                child: CustomPaint(
                  painter: ProvinceMapPainter(
                    data: snapshot.data!,
                    counts: widget.counts,
                    selectedProvince: widget.selectedProvince,
                    lineColor: Theme.of(context).dividerColor.withOpacity(0.66),
                    boundaryColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    labelColor: Theme.of(context).textTheme.bodySmall?.color ??
                        Colors.black54,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class ProvinceMapPainter extends CustomPainter {
  const ProvinceMapPainter({
    required this.data,
    required this.counts,
    required this.selectedProvince,
    required this.lineColor,
    required this.boundaryColor,
    required this.labelColor,
  });

  final GeoChinaData data;
  final Map<String, int> counts;
  final String? selectedProvince;
  final Color lineColor;
  final Color boundaryColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint border = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final Paint selectedBorder = Paint()
      ..color = const Color(0xFF2B6E38).withOpacity(0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final Paint officialBoundary = Paint()
      ..color = boundaryColor.withOpacity(0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.95
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final GeoProvince province in data.provinces) {
      final int count = counts[province.name] ?? 0;
      final bool selected = selectedProvince == province.name;
      final Paint fill = Paint()..color = provinceColor(count, selected);
      for (final Path path in _pathsForProvince(data, province, size)) {
        canvas.drawPath(path, fill);
        canvas.drawPath(path, selected ? selectedBorder : border);
      }
    }

    for (final GeoBoundary boundary in data.boundaries) {
      for (final Path path in _pathsForBoundary(data, boundary, size)) {
        canvas.drawPath(path, officialBoundary);
      }
    }

    if (selectedProvince != null) {
      final GeoProvince? province = _provinceByName(selectedProvince!);
      if (province != null) {
        final Offset labelCenter = _visualCenter(data, province, size);
        final int count = counts[selectedProvince] ?? 0;
        _drawText(canvas, '${_shortName(selectedProvince!)}  $count次',
            labelCenter, 11, labelColor);
      }
    }
  }

  GeoProvince? _provinceByName(String name) {
    for (final GeoProvince province in data.provinces) {
      if (province.name == name) {
        return province;
      }
    }
    return null;
  }

  void _drawText(
      Canvas canvas, String text, Offset center, double size, Color color) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: size, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 88);
    final RRect plate = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: center,
          width: painter.width + 14,
          height: painter.height + 8),
      const Radius.circular(12),
    );
    canvas.drawRRect(plate, Paint()..color = Colors.white.withOpacity(0.78));
    painter.paint(
        canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant ProvinceMapPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.counts != counts ||
        oldDelegate.selectedProvince != selectedProvince ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.boundaryColor != boundaryColor ||
        oldDelegate.labelColor != labelColor;
  }
}

Future<GeoChinaData> _loadChinaGeoData() async {
  final String raw =
      await rootBundle.loadString('assets/data/china_provinces.geojson');
  final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
  final List<dynamic> features = json['features'] as List<dynamic>;
  final List<GeoProvince> provinces = <GeoProvince>[];
  final List<GeoBoundary> boundaries = <GeoBoundary>[];
  double minLon = double.infinity;
  double minLat = double.infinity;
  double maxLon = -double.infinity;
  double maxLat = -double.infinity;

  for (final dynamic featureValue in features) {
    final Map<String, dynamic> feature = featureValue as Map<String, dynamic>;
    final Map<String, dynamic> properties =
        feature['properties'] as Map<String, dynamic>;
    final String name = (properties['name'] as String?) ?? '';
    final Map<String, dynamic> geometry =
        feature['geometry'] as Map<String, dynamic>;
    final List<List<List<Offset>>> polygons = _parsePolygons(geometry);
    final List<List<Offset>> lines =
        displayedBoundaryLinesForFeature(properties, geometry);

    for (final List<List<Offset>> polygon in polygons) {
      for (final List<Offset> ring in polygon) {
        for (final Offset point in ring) {
          minLon = math.min(minLon, point.dx);
          maxLon = math.max(maxLon, point.dx);
          minLat = math.min(minLat, point.dy);
          maxLat = math.max(maxLat, point.dy);
        }
      }
    }
    for (final List<Offset> line in lines) {
      for (final Offset point in line) {
        minLon = math.min(minLon, point.dx);
        maxLon = math.max(maxLon, point.dx);
        minLat = math.min(minLat, point.dy);
        maxLat = math.max(maxLat, point.dy);
      }
    }

    if (lines.isNotEmpty) {
      boundaries.add(GeoBoundary(lines: lines));
    } else if (name.isNotEmpty && polygons.isNotEmpty) {
      provinces.add(GeoProvince(
        name: name,
        polygons: polygons,
        center: _parseCenter(properties),
      ));
    }
  }

  return GeoChinaData(
    provinces: provinces,
    boundaries: boundaries,
    bounds: Rect.fromLTRB(minLon, minLat, maxLon, maxLat),
  );
}

List<List<Offset>> displayedBoundaryLinesForFeature(
  Map<String, dynamic> properties,
  Map<String, dynamic> geometry,
) {
  if (properties['name'] != '境界线' ||
      properties['gb']?.toString() != southChinaSeaBoundaryGb) {
    return <List<Offset>>[];
  }

  final List<List<Offset>> lines = _parseLines(geometry);
  return lines
      .where((List<Offset> line) =>
          line.isNotEmpty && line.every((Offset point) => point.dy < 23))
      .take(southChinaSeaDashCount)
      .toList(growable: false);
}

Offset? _parseCenter(Map<String, dynamic> properties) {
  final dynamic lng = properties['lng'];
  final dynamic lat = properties['lat'];
  if (lng is num && lat is num) {
    return Offset(lng.toDouble(), lat.toDouble());
  }
  return null;
}

List<List<List<Offset>>> _parsePolygons(Map<String, dynamic> geometry) {
  final String type = geometry['type'] as String;
  final dynamic coordinates = geometry['coordinates'];
  if (type == 'Polygon') {
    return <List<List<Offset>>>[_parsePolygon(coordinates as List<dynamic>)];
  }
  if (type == 'MultiPolygon') {
    return (coordinates as List<dynamic>)
        .map((dynamic polygon) => _parsePolygon(polygon as List<dynamic>))
        .toList(growable: false);
  }
  return <List<List<Offset>>>[];
}

List<List<Offset>> _parseLines(Map<String, dynamic> geometry) {
  final String type = geometry['type'] as String;
  final dynamic coordinates = geometry['coordinates'];
  if (type == 'LineString') {
    return <List<Offset>>[_parseLine(coordinates as List<dynamic>)];
  }
  if (type == 'MultiLineString') {
    return (coordinates as List<dynamic>)
        .map((dynamic line) => _parseLine(line as List<dynamic>))
        .toList(growable: false);
  }
  return <List<Offset>>[];
}

List<List<Offset>> _parsePolygon(List<dynamic> polygon) {
  return polygon.map((dynamic ringValue) {
    return _parseLine(ringValue as List<dynamic>);
  }).toList(growable: false);
}

List<Offset> _parseLine(List<dynamic> line) {
  return line.map((dynamic pointValue) {
    final List<dynamic> point = pointValue as List<dynamic>;
    return Offset((point[0] as num).toDouble(), (point[1] as num).toDouble());
  }).toList(growable: false);
}

List<Path> _pathsForProvince(
    GeoChinaData data, GeoProvince province, Size size) {
  return province.polygons.map((List<List<Offset>> polygon) {
    final Path path = Path();
    for (int ringIndex = 0; ringIndex < polygon.length; ringIndex += 1) {
      final List<Offset> ring = polygon[ringIndex];
      for (int i = 0; i < ring.length; i += 1) {
        final Offset point = _project(data, ring[i], size);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
    }
    path.fillType = PathFillType.evenOdd;
    return path;
  }).toList(growable: false);
}

List<Path> _pathsForBoundary(
    GeoChinaData data, GeoBoundary boundary, Size size) {
  return boundary.lines.map((List<Offset> line) {
    final Path path = Path();
    for (int i = 0; i < line.length; i += 1) {
      final Offset point = _project(data, line[i], size);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }).toList(growable: false);
}

Offset _project(GeoChinaData data, Offset lonLat, Size size) {
  final Rect bounds = data.bounds;
  const double padding = 8;
  final double availableWidth = size.width - padding * 2;
  final double availableHeight = size.height - padding * 2;
  final double geoWidth = bounds.width;
  final double geoHeight = bounds.height;
  final double scale =
      math.min(availableWidth / geoWidth, availableHeight / geoHeight);
  final double drawnWidth = geoWidth * scale;
  final double drawnHeight = geoHeight * scale;
  final double offsetX = (size.width - drawnWidth) / 2;
  final double offsetY = (size.height - drawnHeight) / 2;
  return Offset(
    offsetX + (lonLat.dx - bounds.left) * scale,
    offsetY + (bounds.bottom - lonLat.dy) * scale,
  );
}

String? _provinceAt(GeoChinaData data, Offset position, Size size) {
  for (final GeoProvince province in data.provinces.reversed) {
    for (final Path path in _pathsForProvince(data, province, size)) {
      if (path.contains(position)) {
        return province.name;
      }
    }
  }
  return null;
}

Offset _visualCenter(GeoChinaData data, GeoProvince province, Size size) {
  if (province.center != null) {
    return _project(data, province.center!, size);
  }
  double sumX = 0;
  double sumY = 0;
  int count = 0;
  for (final List<List<Offset>> polygon in province.polygons) {
    for (final Offset point in polygon.first) {
      final Offset projected = _project(data, point, size);
      sumX += projected.dx;
      sumY += projected.dy;
      count += 1;
    }
  }
  if (count == 0) {
    return Offset(size.width / 2, size.height / 2);
  }
  return Offset(sumX / count, sumY / count);
}

String _shortName(String name) {
  return name
      .replaceAll('特别行政区', '')
      .replaceAll('维吾尔自治区', '')
      .replaceAll('壮族自治区', '')
      .replaceAll('回族自治区', '')
      .replaceAll('自治区', '')
      .replaceAll('省', '')
      .replaceAll('市', '');
}

Color provinceColor(int count, bool selected) {
  final Color color;
  if (count >= 5) {
    color = const Color(0xFF5B9B66);
  } else if (count >= 3) {
    color = const Color(0xFF91BF93);
  } else if (count >= 1) {
    color = const Color(0xFFCFE3CC);
  } else {
    color = const Color(0xFFE9EDEA);
  }
  return selected
      ? Color.alphaBlend(const Color(0xFF172017).withOpacity(0.08), color)
      : color;
}

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String southChinaSeaBoundaryGb = '156990000';
const int southChinaSeaDashCount = 10;
const String chinaProvinceGeoJsonAsset = 'assets/data/china_provinces.geojson';
const String chinaCityGeoJsonAsset = 'assets/data/china_cities.geojson';
const double defaultChinaMapAspectRatio = 1.2280837330058147;
const double _mapPadding = 8;
const double _provinceStrokeWidth = 0.72;

final Map<String, Future<GeoChinaData>> _cachedChinaGeoData =
    <String, Future<GeoChinaData>>{};
final Map<_ProjectionCacheKey, _ProjectedChinaData> _projectedChinaDataCache =
    <_ProjectionCacheKey, _ProjectedChinaData>{};
final Map<_MapBaseCacheKey, ui.Image> _baseMapImageCache =
    <_MapBaseCacheKey, ui.Image>{};
final Map<_MapBaseCacheKey, Future<ui.Image>> _baseMapImageFutures =
    <_MapBaseCacheKey, Future<ui.Image>>{};

Future<GeoChinaData> preloadChinaGeoData({
  String assetPath = chinaProvinceGeoJsonAsset,
}) {
  return _cachedChinaGeoData[assetPath] ??= _loadChinaGeoData(assetPath);
}

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

  double get aspectRatio {
    if (bounds.height == 0) {
      return defaultChinaMapAspectRatio;
    }
    return bounds.width / bounds.height;
  }
}

class _ProjectedProvince {
  const _ProjectedProvince({
    required this.name,
    required this.paths,
    required this.labelCenter,
  });

  final String name;
  final List<Path> paths;
  final Offset labelCenter;
}

class _ProjectedBoundary {
  const _ProjectedBoundary({
    required this.paths,
  });

  final List<Path> paths;
}

class _ProjectedChinaData {
  const _ProjectedChinaData({
    required this.source,
    required this.size,
    required this.provinces,
    required this.boundaries,
  });

  final GeoChinaData source;
  final Size size;
  final List<_ProjectedProvince> provinces;
  final List<_ProjectedBoundary> boundaries;

  _ProjectedProvince? provinceByName(String name) {
    for (final _ProjectedProvince province in provinces) {
      if (province.name == name) {
        return province;
      }
    }
    return null;
  }
}

class _ProjectionCacheKey {
  const _ProjectionCacheKey(this.source, this.size);

  final GeoChinaData source;
  final Size size;

  @override
  bool operator ==(Object other) {
    return other is _ProjectionCacheKey &&
        identical(other.source, source) &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(identityHashCode(source), size);
}

class _MapBaseCacheKey {
  const _MapBaseCacheKey({
    required this.data,
    required this.countsSignature,
    required this.lineColor,
    required this.boundaryColor,
    required this.devicePixelRatioKey,
  });

  final _ProjectedChinaData data;
  final int countsSignature;
  final Color lineColor;
  final Color boundaryColor;
  final int devicePixelRatioKey;

  @override
  bool operator ==(Object other) {
    return other is _MapBaseCacheKey &&
        identical(other.data, data) &&
        other.countsSignature == countsSignature &&
        other.lineColor == lineColor &&
        other.boundaryColor == boundaryColor &&
        other.devicePixelRatioKey == devicePixelRatioKey;
  }

  @override
  int get hashCode => Object.hash(
        identityHashCode(data),
        countsSignature,
        lineColor,
        boundaryColor,
        devicePixelRatioKey,
      );
}

class ProvinceMapView extends StatefulWidget {
  const ProvinceMapView({
    super.key,
    required this.counts,
    this.selectedProvince,
    required this.onSelected,
    this.assetPath = chinaProvinceGeoJsonAsset,
    this.preferRasterBaseMap = false,
  });

  final Map<String, int> counts;
  final String? selectedProvince;
  final ValueChanged<String> onSelected;
  final String assetPath;
  final bool preferRasterBaseMap;

  @override
  State<ProvinceMapView> createState() => _ProvinceMapViewState();
}

class _ProvinceMapViewState extends State<ProvinceMapView> {
  late Future<GeoChinaData> _future;
  _ProjectedChinaData? _projectedData;

  @override
  void initState() {
    super.initState();
    _future = preloadChinaGeoData(assetPath: widget.assetPath);
  }

  @override
  void didUpdateWidget(covariant ProvinceMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _future = preloadChinaGeoData(assetPath: widget.assetPath);
      _projectedData = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GeoChinaData>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<GeoChinaData> snapshot) {
        if (snapshot.hasError) {
          return AspectRatio(
            aspectRatio: defaultChinaMapAspectRatio,
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
            aspectRatio: defaultChinaMapAspectRatio,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final GeoChinaData data = snapshot.data!;
        return AspectRatio(
          aspectRatio: data.aspectRatio,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Size size =
                  Size(constraints.maxWidth, constraints.maxHeight);
              final _ProjectedChinaData projectedData =
                  _projectedDataFor(data, size);
              final Color lineColor = Theme.of(context).dividerColor;
              final Color boundaryColor =
                  Theme.of(context).colorScheme.onSurfaceVariant;
              final int countsSignature = _countsSignature(widget.counts);
              final double devicePixelRatio =
                  MediaQuery.devicePixelRatioOf(context);
              final _MapBaseCacheKey baseCacheKey = _MapBaseCacheKey(
                data: projectedData,
                countsSignature: countsSignature,
                lineColor: lineColor,
                boundaryColor: boundaryColor,
                devicePixelRatioKey: (devicePixelRatio * 1000).round(),
              );
              final ui.Image? baseImage = _baseMapImageCache[baseCacheKey];
              _ensureBaseMapImage(
                key: baseCacheKey,
                data: projectedData,
                counts: widget.counts,
                lineColor: lineColor,
                boundaryColor: boundaryColor,
                devicePixelRatio: devicePixelRatio,
              );
              if (widget.preferRasterBaseMap && baseImage == null) {
                return const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (TapDownDetails details) {
                  final String? province =
                      _provinceAt(projectedData, details.localPosition);
                  if (province != null) {
                    widget.onSelected(province);
                  }
                },
                child: CustomPaint(
                  painter: _ProvinceMapPainter(
                    data: projectedData,
                    counts: widget.counts,
                    countsSignature: countsSignature,
                    selectedProvince: widget.selectedProvince,
                    lineColor: lineColor,
                    boundaryColor: boundaryColor,
                    baseImage: baseImage,
                    labelColor: const Color(0xFF172017),
                    labelPlateColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFEFF5EF).withOpacity(0.94)
                            : Colors.white.withOpacity(0.84),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  _ProjectedChinaData _projectedDataFor(GeoChinaData data, Size size) {
    final _ProjectedChinaData? cached = _projectedData;
    if (cached != null &&
        identical(cached.source, data) &&
        cached.size == size) {
      return cached;
    }
    final _ProjectionCacheKey cacheKey = _ProjectionCacheKey(data, size);
    return _projectedData =
        _projectedChinaDataCache[cacheKey] ??= _projectChinaData(data, size);
  }

  void _ensureBaseMapImage({
    required _MapBaseCacheKey key,
    required _ProjectedChinaData data,
    required Map<String, int> counts,
    required Color lineColor,
    required Color boundaryColor,
    required double devicePixelRatio,
  }) {
    if (_baseMapImageCache.containsKey(key) ||
        _baseMapImageFutures.containsKey(key)) {
      return;
    }
    _baseMapImageFutures[key] = _rasterizeBaseMap(
      data: data,
      counts: counts,
      lineColor: lineColor,
      boundaryColor: boundaryColor,
      devicePixelRatio: devicePixelRatio,
    ).then((ui.Image image) {
      _baseMapImageCache[key] = image;
      _baseMapImageFutures.remove(key);
      if (mounted) {
        setState(() {});
      }
      return image;
    }).catchError((Object error, StackTrace stackTrace) {
      _baseMapImageFutures.remove(key);
      throw error;
    });
  }
}

class _ProvinceMapPainter extends CustomPainter {
  const _ProvinceMapPainter({
    required this.data,
    required this.counts,
    required this.countsSignature,
    required this.selectedProvince,
    required this.lineColor,
    required this.boundaryColor,
    required this.baseImage,
    required this.labelColor,
    required this.labelPlateColor,
  });

  final _ProjectedChinaData data;
  final Map<String, int> counts;
  final int countsSignature;
  final String? selectedProvince;
  final Color lineColor;
  final Color boundaryColor;
  final ui.Image? baseImage;
  final Color labelColor;
  final Color labelPlateColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint selectedBorder = Paint()
      ..color = const Color(0xFF2B6E38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _provinceStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (baseImage != null) {
      canvas.drawImageRect(
        baseImage!,
        Rect.fromLTWH(
          0,
          0,
          baseImage!.width.toDouble(),
          baseImage!.height.toDouble(),
        ),
        Offset.zero & size,
        Paint(),
      );
    } else {
      _drawBaseMap(canvas, data, counts, lineColor, boundaryColor);
    }

    if (selectedProvince != null) {
      final _ProjectedProvince? province =
          data.provinceByName(selectedProvince!);
      if (province != null) {
        final Paint selectedFill = Paint()
          ..color = provinceColor(counts[selectedProvince] ?? 0, true);
        for (final Path path in province.paths) {
          canvas.drawPath(path, selectedFill);
        }
        for (final Path path in province.paths) {
          canvas.drawPath(path, selectedBorder);
        }
        final int count = counts[selectedProvince] ?? 0;
        _drawText(canvas, '${_shortName(selectedProvince!)}  $count次',
            province.labelCenter, 11, labelColor, labelPlateColor);
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, double size,
      Color color, Color plateColor) {
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
    canvas.drawRRect(plate, Paint()..color = plateColor);
    painter.paint(
        canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ProvinceMapPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.countsSignature != countsSignature ||
        oldDelegate.selectedProvince != selectedProvince ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.boundaryColor != boundaryColor ||
        oldDelegate.baseImage != baseImage ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.labelPlateColor != labelPlateColor;
  }
}

void _drawBaseMap(
  Canvas canvas,
  _ProjectedChinaData data,
  Map<String, int> counts,
  Color lineColor,
  Color boundaryColor,
) {
  final Paint border = Paint()
    ..color = lineColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = _provinceStrokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint officialBoundary = Paint()
    ..color = boundaryColor.withOpacity(0.82)
    ..style = PaintingStyle.stroke
    ..strokeWidth = _provinceStrokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  for (final _ProjectedProvince province in data.provinces) {
    final int count = counts[province.name] ?? 0;
    final Paint fill = Paint()..color = provinceColor(count, false);
    for (final Path path in province.paths) {
      canvas.drawPath(path, fill);
    }
  }

  for (final _ProjectedProvince province in data.provinces) {
    for (final Path path in province.paths) {
      canvas.drawPath(path, border);
    }
  }

  for (final _ProjectedBoundary boundary in data.boundaries) {
    for (final Path path in boundary.paths) {
      canvas.drawPath(path, officialBoundary);
    }
  }
}

Future<ui.Image> _rasterizeBaseMap({
  required _ProjectedChinaData data,
  required Map<String, int> counts,
  required Color lineColor,
  required Color boundaryColor,
  required double devicePixelRatio,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final int imageWidth =
      math.max(1, (data.size.width * devicePixelRatio).ceil());
  final int imageHeight =
      math.max(1, (data.size.height * devicePixelRatio).ceil());
  final Canvas canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, imageWidth.toDouble(), imageHeight.toDouble()),
  )..scale(devicePixelRatio, devicePixelRatio);
  _drawBaseMap(canvas, data, counts, lineColor, boundaryColor);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(imageWidth, imageHeight);
  picture.dispose();
  return image;
}

int _countsSignature(Map<String, int> counts) {
  if (counts.isEmpty) {
    return 0;
  }
  final List<MapEntry<String, int>> entries = counts.entries
      .map((MapEntry<String, int> entry) =>
          MapEntry<String, int>(entry.key, entry.value))
      .toList(growable: false)
    ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
        a.key.compareTo(b.key));
  return Object.hashAll(entries.map(
      (MapEntry<String, int> entry) => Object.hash(entry.key, entry.value)));
}

_ProjectedChinaData _projectChinaData(GeoChinaData data, Size size) {
  return _ProjectedChinaData(
    source: data,
    size: size,
    provinces: data.provinces.map((GeoProvince province) {
      return _ProjectedProvince(
        name: province.name,
        paths: _pathsForProvince(data, province, size),
        labelCenter: _visualCenter(data, province, size),
      );
    }).toList(growable: false),
    boundaries: data.boundaries.map((GeoBoundary boundary) {
      return _ProjectedBoundary(
        paths: _pathsForBoundary(data, boundary, size),
      );
    }).toList(growable: false),
  );
}

Future<GeoChinaData> _loadChinaGeoData(String assetPath) async {
  final String raw = await rootBundle.loadString(assetPath);
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
      .where((List<Offset> line) => line.isNotEmpty)
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
  return _projectWithBounds(data.bounds, lonLat, size);
}

Offset _projectWithBounds(Rect bounds, Offset lonLat, Size size) {
  final Rect projectedBounds = projectedMapBoundsForTesting(bounds, size);
  final double scale = projectedBounds.width / bounds.width;
  return Offset(
    projectedBounds.left + (lonLat.dx - bounds.left) * scale,
    projectedBounds.top + (bounds.bottom - lonLat.dy) * scale,
  );
}

Rect projectedMapBoundsForTesting(Rect bounds, Size size) {
  final double availableWidth = size.width - _mapPadding * 2;
  final double availableHeight = size.height - _mapPadding * 2;
  final double geoWidth = bounds.width;
  final double geoHeight = bounds.height;
  final double scale =
      math.min(availableWidth / geoWidth, availableHeight / geoHeight);
  final double drawnWidth = geoWidth * scale;
  final double drawnHeight = geoHeight * scale;
  final double offsetX = (size.width - drawnWidth) / 2;
  final double offsetY = (size.height - drawnHeight) / 2;
  return Rect.fromLTWH(offsetX, offsetY, drawnWidth, drawnHeight);
}

String? _provinceAt(_ProjectedChinaData data, Offset position) {
  for (final _ProjectedProvince province in data.provinces.reversed) {
    for (final Path path in province.paths) {
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

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:guitu/ui/map_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('天地图全国省级数据包含完整行政区与境界线', () {
    final File file = File('assets/data/china_provinces.geojson');
    if (!file.existsSync()) {
      return;
    }
    final Map<String, dynamic> data =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final List<dynamic> features = data['features'] as List<dynamic>;

    final List<Map<String, dynamic>> provinceFeatures = features
        .cast<Map<String, dynamic>>()
        .where((Map<String, dynamic> feature) {
      final Map<String, dynamic> geometry =
          feature['geometry'] as Map<String, dynamic>;
      return geometry['type'] == 'MultiPolygon' ||
          geometry['type'] == 'Polygon';
    }).toList(growable: false);
    final List<Map<String, dynamic>> boundaryFeatures = features
        .cast<Map<String, dynamic>>()
        .where((Map<String, dynamic> feature) {
      final Map<String, dynamic> properties =
          feature['properties'] as Map<String, dynamic>;
      return properties['name'] == '境界线';
    }).toList(growable: false);
    final Set<String> names = provinceFeatures.map((feature) {
      final Map<String, dynamic> properties =
          feature['properties'] as Map<String, dynamic>;
      return properties['name'] as String;
    }).toSet();

    expect(provinceFeatures, hasLength(34));
    expect(boundaryFeatures.length, greaterThanOrEqualTo(8));
    expect(
      names,
      containsAll(<String>[
        '台湾省',
        '海南省',
        '西藏自治区',
        '新疆维吾尔自治区',
        '香港特别行政区',
        '澳门特别行政区',
      ]),
    );

    double minLatitude = 90;
    void inspectCoordinates(dynamic value) {
      if (value is List<dynamic> &&
          value.length >= 2 &&
          value[0] is num &&
          value[1] is num) {
        final double latitude = (value[1] as num).toDouble();
        if (latitude < minLatitude) {
          minLatitude = latitude;
        }
        return;
      }
      if (value is List<dynamic>) {
        for (final dynamic child in value) {
          inspectCoordinates(child);
        }
      }
    }

    for (final dynamic feature in features) {
      final Map<String, dynamic> geometry =
          (feature as Map<String, dynamic>)['geometry'] as Map<String, dynamic>;
      inspectCoordinates(geometry['coordinates']);
    }

    expect(minLatitude, lessThan(4));
  });

  test('地图界面仅显示南海九段线', () {
    final List<dynamic> lines = List<dynamic>.generate(
      10,
      (int index) => <List<double>>[
        <double>[109.0 + index, 4.0 + index],
        <double>[109.2 + index, 4.2 + index],
      ],
    );
    final List<List<Offset>> displayedLines = displayedBoundaryLinesForFeature(
      <String, dynamic>{
        'name': '境界线',
        'gb': southChinaSeaBoundaryGb,
      },
      <String, dynamic>{
        'type': 'MultiLineString',
        'coordinates': lines,
      },
    );

    expect(displayedLines, hasLength(southChinaSeaDashCount));
    expect(displayedLines.last.first.dy, 12);
  });

  test('地图投影在不同容器尺寸下保持经纬比例不变', () {
    const Rect chinaBounds = Rect.fromLTRB(
      73.498962,
      3.408477,
      135.087387,
      53.558498,
    );
    final double sourceAspect = chinaBounds.width / chinaBounds.height;

    for (final Size size in <Size>[
      const Size(320, 260),
      const Size(500, 320),
      const Size(280, 520),
    ]) {
      final Rect projected = projectedMapBoundsForTesting(chinaBounds, size);
      final double projectedAspect = projected.width / projected.height;

      expect(projectedAspect, closeTo(sourceAspect, 0.0000001));
      expect(projected.left, greaterThanOrEqualTo(0));
      expect(projected.top, greaterThanOrEqualTo(0));
      expect(projected.right, lessThanOrEqualTo(size.width));
      expect(projected.bottom, lessThanOrEqualTo(size.height));
    }
  });
}

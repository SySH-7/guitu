import 'dart:convert';
import 'dart:io';

import 'package:archive_journey/ui/map_painter.dart';
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
}

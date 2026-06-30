part of '../main.dart';

enum _TravelMapLevel { province, city }

const Set<String> _wholeRegionCityMapFallbacks = <String>{
  '北京市',
  '天津市',
  '上海市',
  '重庆市',
  '台湾省',
  '香港特别行政区',
  '澳门特别行政区',
};

const Map<String, Set<String>> _missingCityMapRegions = <String, Set<String>>{
  '河南省': <String>{'济源市'},
  '湖北省': <String>{'仙桃市', '潜江市', '天门市', '神农架林区'},
  '广东省': <String>{'东莞市', '中山市'},
  '海南省': <String>{
    '儋州市',
    '五指山市',
    '琼海市',
    '文昌市',
    '万宁市',
    '东方市',
    '定安县',
    '屯昌县',
    '澄迈县',
    '临高县',
    '白沙黎族自治县',
    '昌江黎族自治县',
    '乐东黎族自治县',
    '陵水黎族自治县',
    '保亭黎族苗族自治县',
    '琼中黎族苗族自治县',
  },
  '甘肃省': <String>{
    '嘉峪关市',
    '中农发山丹马场',
    '莲花山风景林自然保护区',
    '太子山天然林保护区',
  },
  '新疆维吾尔自治区': <String>{
    '石河子市',
    '阿拉尔市',
    '图木舒克市',
    '五家渠市',
    '北屯市',
    '铁门关市',
    '双河市',
    '可克达拉市',
    '昆玉市',
    '胡杨河市',
    '新星市',
    '白杨市',
  },
};

class TravelScreen extends StatefulWidget {
  const TravelScreen({
    super.key,
    required this.store,
  });

  final ArchiveStore store;

  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> {
  _TravelMapLevel _mapLevel = _TravelMapLevel.province;
  String? _selectedProvince = '浙江省';
  String? _selectedCity;

  @override
  Widget build(BuildContext context) {
    final Map<String, int> provinceCounts = widget.store.provinceCounts();
    final Map<String, int> cityCounts = widget.store.cityCounts();
    final Map<String, int> cityMapCounts =
        _cityMapCounts(provinceCounts, cityCounts);
    final int visitedProvinceCount =
        provinceCounts.values.where((int count) => count > 0).length;
    final int visitedCityCount =
        cityCounts.values.where((int count) => count > 0).length;
    final List<MapEntry<String, int>> provinceEntries = provinceCounts.entries
        .toList(growable: false)
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));
    final List<MapEntry<String, int>> cityEntries = cityCounts.entries
        .toList(growable: false)
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));
    final bool isCityMap = _mapLevel == _TravelMapLevel.city;
    final String? selectedRegion =
        isCityMap ? _selectedCity : _selectedProvince;
    final List<MapEntry<String, int>> summaryEntries =
        isCityMap ? cityEntries : provinceEntries;

    return _PageFrame(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
        children: <Widget>[
          const _TopTitle(title: '旅途'),
          const SizedBox(height: 16),
          CupertinoSlidingSegmentedControl<_TravelMapLevel>(
            groupValue: _mapLevel,
            children: const <_TravelMapLevel, Widget>{
              _TravelMapLevel.province: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('省级'),
              ),
              _TravelMapLevel.city: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('市级'),
              ),
            },
            onValueChanged: (_TravelMapLevel? value) {
              if (value != null) {
                setState(() => _mapLevel = value);
              }
            },
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: isCityMap ? '中国地图 · 市级足迹' : '中国地图 · 省级足迹',
            trailing:
                isCityMap ? '$visitedCityCount个' : '$visitedProvinceCount/34',
            child: IndexedStack(
              index: isCityMap ? 1 : 0,
              sizing: StackFit.passthrough,
              children: <Widget>[
                RepaintBoundary(
                  child: ProvinceMapView(
                    key: const PageStorageKey<String>('province-footprint-map'),
                    assetPath: chinaProvinceGeoJsonAsset,
                    counts: provinceCounts,
                    selectedProvince: _selectedProvince,
                    onSelected: (String value) {
                      setState(() => _selectedProvince = value);
                    },
                  ),
                ),
                RepaintBoundary(
                  child: ProvinceMapView(
                    key: const PageStorageKey<String>('city-footprint-map'),
                    assetPath: chinaCityGeoJsonAsset,
                    preferRasterBaseMap: true,
                    counts: cityMapCounts,
                    selectedProvince: _selectedCity,
                    onSelected: (String value) {
                      setState(() => _selectedCity = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Legend(),
          const SizedBox(height: 16),
          _SectionHeader(
            title: isCityMap ? '去过的城市' : '去过的省份',
            action:
                isCityMap ? '$visitedCityCount个' : '$visitedProvinceCount/34',
          ),
          const SizedBox(height: 10),
          _ProvinceSummary(
              entries: summaryEntries, selectedProvince: selectedRegion),
        ],
      ),
    );
  }

  Map<String, int> _cityMapCounts(
    Map<String, int> provinceCounts,
    Map<String, int> cityCounts,
  ) {
    final Map<String, int> result = <String, int>{...cityCounts};
    for (final String regionName in _wholeRegionCityMapFallbacks) {
      final int count = provinceCounts[regionName] ?? 0;
      if (count > 0) {
        result[regionName] = count;
      }
    }

    final Map<String, int> missingRegionCounts = <String, int>{};
    for (final ArchiveEntry entry in widget.store.entries) {
      if (entry.kind != ArchiveKind.place) {
        continue;
      }
      final String? province = entry.province;
      if (province == null) {
        continue;
      }
      final Set<String>? missingCities = _missingCityMapRegions[province];
      if (missingCities == null) {
        continue;
      }
      final String? city = entry.city;
      if (city == null || city.isEmpty || missingCities.contains(city)) {
        missingRegionCounts[province] =
            (missingRegionCounts[province] ?? 0) + 1;
      }
    }
    result.addAll(missingRegionCounts);
    return result;
  }
}

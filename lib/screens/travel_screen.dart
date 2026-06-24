part of '../main.dart';

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
  String? _selectedProvince = '浙江省';

  @override
  Widget build(BuildContext context) {
    final Map<String, int> provinceCounts = widget.store.provinceCounts();
    final int visitedProvinceCount =
        provinceCounts.values.where((int count) => count > 0).length;
    final List<MapEntry<String, int>> provinceEntries = provinceCounts.entries
        .toList(growable: false)
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));

    return _PageFrame(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
        children: <Widget>[
          const _TopTitle(title: '旅途'),
          const SizedBox(height: 16),
          _SectionCard(
            title: '中国地图 · 省级足迹',
            trailing: '$visitedProvinceCount/34',
            child: ProvinceMapView(
              counts: provinceCounts,
              selectedProvince: _selectedProvince,
              onSelected: (String value) =>
                  setState(() => _selectedProvince = value),
            ),
          ),
          const SizedBox(height: 14),
          _Legend(),
          const SizedBox(height: 16),
          _SectionHeader(title: '去过的省份', action: '$visitedProvinceCount/34'),
          const SizedBox(height: 10),
          _ProvinceSummary(
              entries: provinceEntries, selectedProvince: _selectedProvince),
        ],
      ),
    );
  }
}

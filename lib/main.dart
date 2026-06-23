import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/app_data.dart';
import 'services/archive_store.dart';
import 'ui/charts.dart';
import 'ui/map_painter.dart';
import 'ui/record_form_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GuituApp());
}

class GuituApp extends StatefulWidget {
  const GuituApp({super.key});

  @override
  State<GuituApp> createState() => _GuituAppState();
}

class _GuituAppState extends State<GuituApp> {
  final ArchiveStore _store = ArchiveStore();

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (BuildContext context, _) {
        final bool dark = _store.darkMode;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor:
                dark ? const Color(0xFF111112) : const Color(0xFFFBFCFB),
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness:
                dark ? Brightness.light : Brightness.dark,
          ),
        );
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '归途',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: _store.isLoaded ? ArchiveShell(store: _store) : const _Splash(),
        );
      },
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  final Color surface =
      dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  final Color background =
      dark ? const Color(0xFF111112) : const Color(0xFFF7F8F7);
  final Color text = dark ? const Color(0xFFF2F2F2) : const Color(0xFF111417);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: archiveGreen,
      brightness: brightness,
      surface: surface,
    ),
    textTheme: Typography.blackCupertino.apply(
      bodyColor: text,
      displayColor: text,
      fontFamily: 'PingFang SC',
    ),
    cardColor: surface,
    dividerColor: dark ? const Color(0xFF2C2C2E) : const Color(0xFFE7EBE7),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF242426) : const Color(0xFFF4F6F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
            color: dark ? const Color(0xFF303033) : const Color(0xFFE8ECE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: archiveGreen, width: 1.4),
      ),
    ),
  );
}

Future<void> _confirmDeleteEntry(
  BuildContext context,
  ArchiveStore store,
  ArchiveEntry entry,
) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定删除“${entry.title}”吗？此操作不可撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB33A3A)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      );
    },
  );
  if (confirmed != true) {
    return;
  }
  await store.removeEntry(entry.id);
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('已删除：${entry.title}')));
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 92,
              height: 92,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 12)),
                ],
              ),
              child: Image.asset('assets/images/app_icon.png'),
            ),
            const SizedBox(height: 18),
            Text('归途',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class ArchiveShell extends StatefulWidget {
  const ArchiveShell({
    super.key,
    required this.store,
  });

  final ArchiveStore store;

  @override
  State<ArchiveShell> createState() => _ArchiveShellState();
}

class _ArchiveShellState extends State<ArchiveShell> {
  int _index = 0;

  Future<void> _openAddFlow() async {
    final ArchiveKind? kind = await showArchiveKindChooser(context);
    if (!mounted || kind == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) =>
          RecordFormSheet(kind: kind, store: widget.store),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      HomeScreen(store: widget.store, onAdd: _openAddFlow),
      BookFilmScreen(store: widget.store),
      TravelScreen(store: widget.store),
      SettingsScreen(store: widget.store),
    ];
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: KeyedSubtree(
                key: ValueKey<int>(_index),
                child: pages[_index],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 12,
            child: _BottomNav(
              selectedIndex: _index,
              onSelected: (int value) => setState(() => _index = value),
              onAdd: _openAddFlow,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedIndex,
    required this.onSelected,
    required this.onAdd,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(dark ? 0.94 : 0.86),
        borderRadius: BorderRadius.circular(28),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.72)),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.28 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: <Widget>[
            _NavItem(
                icon: CupertinoIcons.house_fill,
                label: '首页',
                selected: selectedIndex == 0,
                onTap: () => onSelected(0)),
            _NavItem(
                icon: CupertinoIcons.book,
                label: '书影',
                selected: selectedIndex == 1,
                onTap: () => onSelected(1)),
            Expanded(
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: onAdd,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFECEFED)
                          : const Color(0xFF171A18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.plus,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white,
                        size: 20),
                  ),
                ),
              ),
            ),
            _NavItem(
                icon: CupertinoIcons.map,
                label: '旅途',
                selected: selectedIndex == 2,
                onTap: () => onSelected(2)),
            _NavItem(
                icon: CupertinoIcons.person,
                label: '用户',
                selected: selectedIndex == 3,
                onTap: () => onSelected(3)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected
        ? Theme.of(context).textTheme.bodyLarge!.color!
        : Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.44);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 19, color: color),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.onAdd,
  });

  final ArchiveStore store;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final List<ArchiveEntry> recent = store.recentEntries(limit: 6);
    return _PageFrame(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
        children: <Widget>[
          _TopTitle(
            title: '归途',
            trailing: IconButton(
              icon: const Icon(CupertinoIcons.search),
              onPressed: () => _showSearch(context, store),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatTile(
                  color: archiveOrange,
                  icon: CupertinoIcons.book_fill,
                  label: '书籍已读',
                  value: store.totalFor(ArchiveKind.book),
                  unit: '本',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  color: archiveBlue,
                  icon: CupertinoIcons.film_fill,
                  label: '影视已看',
                  value: store.totalFor(ArchiveKind.film),
                  unit: '部',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  color: archiveGreen,
                  icon: CupertinoIcons.location_solid,
                  label: '去过地点',
                  value: store.totalFor(ArchiveKind.place),
                  unit: '个',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _SectionHeader(title: '最近记录'),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            _EmptyState(onAdd: onAdd)
          else
            ...recent.map((ArchiveEntry entry) => _RecordTile(
                entry: entry,
                onDelete: () => _confirmDeleteEntry(context, store, entry))),
        ],
      ),
    );
  }

  void _showSearch(BuildContext context, ArchiveStore store) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (BuildContext context) => _SearchSheet(store: store),
    );
  }
}

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.store});

  final ArchiveStore store;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final String keyword = _keyword.trim();
    final List<ArchiveEntry> records =
        widget.store.entries.where((ArchiveEntry entry) {
      if (keyword.isEmpty) {
        return true;
      }
      return '${entry.title}${entry.category}${entry.creator ?? ''}${entry.city ?? ''}${entry.province ?? ''}'
          .contains(keyword);
    }).toList(growable: false)
          ..sort((ArchiveEntry a, ArchiveEntry b) => b.date.compareTo(a.date));
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.74,
          child: Column(
            children: <Widget>[
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                    prefixIcon: Icon(CupertinoIcons.search),
                    hintText: '搜索书名、片名、城市或类型'),
                onChanged: (String value) => setState(() => _keyword = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: records
                      .map((ArchiveEntry entry) => _RecordTile(entry: entry))
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookFilmScreen extends StatefulWidget {
  const BookFilmScreen({
    super.key,
    required this.store,
  });

  final ArchiveStore store;

  @override
  State<BookFilmScreen> createState() => _BookFilmScreenState();
}

class _BookFilmScreenState extends State<BookFilmScreen>
    with WidgetsBindingObserver {
  int _segment = 0;
  late int _year;
  bool _followsSystemYear = true;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _followsSystemYear) {
      final int systemYear = DateTime.now().year;
      if (_year != systemYear && mounted) {
        setState(() => _year = systemYear);
      }
    }
  }

  void _selectYear(int year) {
    setState(() {
      _year = year;
      _followsSystemYear = year == DateTime.now().year;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
        children: <Widget>[
          const _TopTitle(title: '书影'),
          const SizedBox(height: 12),
          _SegmentedHeader(
            values: const <String>['统计', '书籍', '影视'],
            selectedIndex: _segment,
            onChanged: (int value) => setState(() => _segment = value),
          ),
          const SizedBox(height: 14),
          if (_segment == 0)
            _buildStats(context)
          else
            _buildList(
                context, _segment == 1 ? ArchiveKind.book : ArchiveKind.film),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final List<int> bookMonthly =
        widget.store.monthlyCounts(_year, ArchiveKind.book);
    final List<int> filmMonthly =
        widget.store.monthlyCounts(_year, ArchiveKind.film);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _YearChips(
          selected: _year,
          primaryYears: widget.store.primaryBookFilmYears(),
          earlierYears: widget.store.earlierBookFilmYears(),
          onChanged: _selectYear,
          onEarlier: _pickEarlierYear,
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '每月阅读/观影数量',
          child: CombinedBarChart(
              bookValues: bookMonthly, filmValues: filmMonthly),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '阅读/观影类型分布',
          child: Column(
            children: <Widget>[
              DonutChart(
                values:
                    widget.store.categoryCounts(ArchiveKind.book, year: _year),
                palette: const <Color>[
                  archiveOrange,
                  Color(0xFFFFB14D),
                  Color(0xFFFFD7A0),
                  Color(0xFFE9A05C)
                ],
              ),
              const SizedBox(height: 12),
              DonutChart(
                values:
                    widget.store.categoryCounts(ArchiveKind.film, year: _year),
                palette: const <Color>[
                  archiveBlue,
                  Color(0xFF63B5FF),
                  Color(0xFF94D5FF),
                  Color(0xFF2A65C8)
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '年度阅读/观影数量',
          child: YearLineChart(
            bookValues: widget.store.yearlySeries(ArchiveKind.book),
            filmValues: widget.store.yearlySeries(ArchiveKind.film),
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, ArchiveKind kind) {
    final List<ArchiveEntry> records = widget.store.entries
        .where((ArchiveEntry entry) =>
            entry.kind == kind && entry.date.year == _year)
        .toList(growable: false)
      ..sort((ArchiveEntry a, ArchiveEntry b) => b.date.compareTo(a.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _YearChips(
          selected: _year,
          primaryYears: widget.store.primaryBookFilmYears(),
          earlierYears: widget.store.earlierBookFilmYears(),
          onChanged: _selectYear,
          onEarlier: _pickEarlierYear,
        ),
        const SizedBox(height: 16),
        _SectionHeader(
            title: kind == ArchiveKind.book ? '书籍列表' : '影视列表',
            action: '${records.length}条'),
        const SizedBox(height: 10),
        if (records.isEmpty)
          const _PlainHint(text: '还没有记录。点击底部加号开始添加。')
        else
          ...records.map((ArchiveEntry entry) => _RecordTile(
              entry: entry,
              onDelete: () =>
                  _confirmDeleteEntry(context, widget.store, entry))),
      ],
    );
  }

  Future<void> _pickEarlierYear() async {
    final List<int> years = widget.store.earlierBookFilmYears();
    if (years.isEmpty) {
      return;
    }
    final int? picked = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('选择其他年份'),
          children: years.map((int year) {
            return SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(year),
              child: Text('$year'),
            );
          }).toList(growable: false),
        );
      },
    );
    if (picked != null) {
      _selectYear(picked);
    }
  }
}

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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.store,
  });

  final ArchiveStore store;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
        children: <Widget>[
          _ProfileHeader(store: store),
          const SizedBox(height: 22),
          _SettingTile(
            icon: CupertinoIcons.sun_max,
            title: '深色模式',
            trailing: Switch.adaptive(
                value: store.darkMode,
                activeColor: archiveOrange,
                onChanged: store.setDarkMode),
          ),
          _SettingTile(
            icon: CupertinoIcons.square_arrow_down,
            title: '导入数据',
            onTap: () => _importData(context, store),
          ),
          _SettingTile(
            icon: CupertinoIcons.square_arrow_up,
            title: '导出数据',
            onTap: () => _exportData(context, store),
          ),
          _SettingTile(
            icon: CupertinoIcons.trash,
            title: '清空全部数据',
            onTap: () => _confirmClearAll(context, store),
          ),
          _SettingTile(
            icon: CupertinoIcons.info_circle,
            title: 'App 信息',
            onTap: () => _showAppInfo(context),
          ),
        ],
      ),
    );
  }

  Future<void> _importData(BuildContext context, ArchiveStore store) async {
    try {
      final bool imported = await store.importFromDevice();
      if (!imported) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('导入成功，数据已刷新')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导入失败：$error')));
    }
  }

  Future<void> _exportData(BuildContext context, ArchiveStore store) async {
    try {
      final String? target = await store.exportToDevice();
      if (target == null) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已导出：$target')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败：$error')));
    }
  }

  void _showAppInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon:
              Image.asset('assets/images/app_icon.png', width: 58, height: 58),
          title: const Text('归途'),
          content: const Text('归途\n0.2.1 开源练习版\n开发者：SySH'),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了')),
          ],
        );
      },
    );
  }

  Future<void> _confirmClearAll(
      BuildContext context, ArchiveStore store) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('清空全部数据'),
          content: const Text('清空后将删除所有阅读、影视和旅途记录，此操作不可撤销。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB33A3A)),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认清空'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await store.clearAllEntries();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('全部记录已清空')));
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.store});

  final ArchiveStore store;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '',
      child: Row(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(36),
            onTap: () => _chooseAvatar(context),
            child: _Avatar(index: store.avatarIndex, size: 72),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _editName(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(store.userName,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('记录生活的每一刻',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(0.58))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final TextEditingController controller =
        TextEditingController(text: store.userName);
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('编辑昵称'),
          content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: '输入昵称')),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('保存')),
          ],
        );
      },
    );
    controller.dispose();
    if (value != null) {
      await store.setUserName(value);
    }
  }

  Future<void> _chooseAvatar(BuildContext context) async {
    final int? index = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('选择头像',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List<Widget>.generate(4, (int value) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(42),
                      onTap: () => Navigator.of(context).pop(value),
                      child: _Avatar(index: value, size: 72),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (index != null) {
      await store.setAvatarIndex(index);
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.index, required this.size});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final List<List<Color>> gradients = <List<Color>>[
      const <Color>[Color(0xFF1B1E22), Color(0xFF5E6D74)],
      const <Color>[archiveOrange, Color(0xFFFFC476)],
      const <Color>[archiveBlue, Color(0xFF8CCBFF)],
      const <Color>[archiveGreen, Color(0xFFAEE6A0)],
    ];
    final List<IconData> icons = <IconData>[
      CupertinoIcons.person_fill,
      CupertinoIcons.book_fill,
      CupertinoIcons.film_fill,
      CupertinoIcons.location_solid
    ];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradients[index % gradients.length]),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color:
                  gradients[index % gradients.length].first.withOpacity(0.28),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      child: Icon(icons[index % icons.length],
          color: Colors.white, size: size * 0.42),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(top: true, bottom: false, child: child);
  }
}

class _TopTitle extends StatelessWidget {
  const _TopTitle({
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0)),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _SegmentedHeader extends StatelessWidget {
  const _SegmentedHeader({
    required this.values,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> values;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 38,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF151E20) : const Color(0xFFF0F2F1),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: List<Widget>.generate(values.length, (int index) {
          final bool selected = selectedIndex == index;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? (dark ? Colors.white : Colors.black)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  values[index],
                  style: TextStyle(
                    color: selected
                        ? (dark ? Colors.black : Colors.white)
                        : Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.56),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _YearChips extends StatelessWidget {
  const _YearChips({
    required this.selected,
    required this.primaryYears,
    required this.earlierYears,
    required this.onChanged,
    required this.onEarlier,
  });

  final int selected;
  final List<int> primaryYears;
  final List<int> earlierYears;
  final ValueChanged<int> onChanged;
  final VoidCallback onEarlier;

  @override
  Widget build(BuildContext context) {
    final int currentYear = DateTime.now().year;
    final bool selectedIsEarlier = earlierYears.contains(selected);
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final int year in primaryYears)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _YearChip(
                label: year == currentYear ? '今年' : '$year',
                selected: selected == year,
                onTap: () => onChanged(year),
              ),
            ),
          if (earlierYears.isNotEmpty)
            _YearChip(
              label: selectedIsEarlier ? '$selected' : '更多',
              selected: selectedIsEarlier,
              onTap: onEarlier,
            ),
        ],
      ),
    );
  }
}

class _YearChip extends StatelessWidget {
  const _YearChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFECEFED)
          : const Color(0xFF171A18),
      backgroundColor: Theme.of(context).cardColor,
      side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.58)),
      labelStyle: TextStyle(
        color: selected
            ? (Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : Colors.white)
            : Theme.of(context).textTheme.bodySmall?.color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool hasTitle = title.isNotEmpty || trailing != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Colors.black.withOpacity(
                  Theme.of(context).brightness == Brightness.dark
                      ? 0.18
                      : 0.045),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hasTitle) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                    child: Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600))),
                if (trailing != null)
                  Text(trailing!,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.action,
  });

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700))),
        if (action != null)
          Text(action!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.color
                      ?.withOpacity(0.46))),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  final Color color;
  final IconData icon;
  final String label;
  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 13),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.50)),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Colors.black.withOpacity(
                  Theme.of(context).brightness == Brightness.dark
                      ? 0.16
                      : 0.045),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 5),
          FittedBox(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w700),
                children: <TextSpan>[
                  TextSpan(
                      text: '$value', style: const TextStyle(fontSize: 24)),
                  TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(0.58))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.entry,
    this.onDelete,
  });

  final ArchiveEntry entry;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final Color accent = _kindColor(entry.kind);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.48)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  accent.withOpacity(0.92),
                  accent.withOpacity(0.36)
                ],
              ),
              image: entry.kind == ArchiveKind.place
                  ? const DecorationImage(
                      image: AssetImage('assets/images/app_icon.png'),
                      fit: BoxFit.cover,
                      opacity: 0.28)
                  : null,
            ),
            child: Icon(_kindIcon(entry.kind), color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (onDelete != null)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(CupertinoIcons.ellipsis, size: 18),
                        onSelected: (_) => onDelete?.call(),
                        itemBuilder: (BuildContext context) =>
                            const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                              value: 'delete', child: Text('删除')),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(_entrySubtitle(entry),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.58))),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Text(_stars(entry.rating),
                        style: const TextStyle(
                            color: Color(0xFFFFB02E),
                            fontSize: 12,
                            letterSpacing: 1.2)),
                    const Spacer(),
                    Text(_formatDate(entry.date),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.color
                                ?.withOpacity(0.50))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProvinceSummary extends StatelessWidget {
  const _ProvinceSummary({
    required this.entries,
    required this.selectedProvince,
  });

  final List<MapEntry<String, int>> entries;
  final String? selectedProvince;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _PlainHint(text: '还没有旅途记录。点击底部加号添加地点。');
    }
    final List<MapEntry<String, int>> visible = selectedProvince == null
        ? entries
        : <MapEntry<String, int>>[
            if (entries.any(
                (MapEntry<String, int> entry) => entry.key == selectedProvince))
              entries.firstWhere((MapEntry<String, int> entry) =>
                  entry.key == selectedProvince),
            ...entries.where(
                (MapEntry<String, int> entry) => entry.key != selectedProvince),
          ];
    return Column(
      children: visible.map((MapEntry<String, int> entry) {
        final bool selected = entry.key == selectedProvince;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: provinceColor(entry.value, selected)
                .withOpacity(selected ? 1 : 0.72),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: const Color(0xFF5B9B66).withOpacity(0.16)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(entry.key,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF1E3523),
                          fontWeight: FontWeight.w600,
                        )),
              ),
              Text('${entry.value}次',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF1E3523),
                        fontWeight: FontWeight.w700,
                      )),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 8,
      children: <Widget>[
        _LegendItem(color: Color(0xFF43B95A), text: '5次及以上'),
        _LegendItem(color: Color(0xFF89DA7F), text: '3-4次'),
        _LegendItem(color: Color(0xFFCFEFC9), text: '1-2次'),
        _LegendItem(color: Color(0xFFF8FBF7), text: '0次'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.text,
  });

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.black.withOpacity(0.06)))),
        const SizedBox(width: 5),
        Text(text,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.52)),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600))),
              trailing ?? const Icon(CupertinoIcons.chevron_forward, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '',
      child: Column(
        children: <Widget>[
          Image.asset('assets/images/app_icon.png', width: 72, height: 72),
          const SizedBox(height: 10),
          Text('还没有记录',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('把一本书、一部电影或一次抵达放进时间里。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          FilledButton(onPressed: onAdd, child: const Text('开始记录')),
        ],
      ),
    );
  }
}

class _PlainHint extends StatelessWidget {
  const _PlainHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

Color _kindColor(ArchiveKind kind) {
  switch (kind) {
    case ArchiveKind.book:
      return archiveOrange;
    case ArchiveKind.film:
      return archiveBlue;
    case ArchiveKind.place:
      return archiveGreen;
  }
}

IconData _kindIcon(ArchiveKind kind) {
  switch (kind) {
    case ArchiveKind.book:
      return CupertinoIcons.book_fill;
    case ArchiveKind.film:
      return CupertinoIcons.film_fill;
    case ArchiveKind.place:
      return CupertinoIcons.location_solid;
  }
}

String _entrySubtitle(ArchiveEntry entry) {
  switch (entry.kind) {
    case ArchiveKind.book:
      return '${entry.creator ?? '未知作者'} / ${entry.category} / ${entry.amount}册';
    case ArchiveKind.film:
      return '${entry.creator ?? '未知导演'} / ${entry.category} / ${entry.amount}季';
    case ArchiveKind.place:
      return '${entry.province ?? ''}${entry.city == null ? '' : ' · ${entry.city}'} / ${entry.category}';
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _stars(int rating) {
  return '${'★' * rating}${'☆' * (5 - rating)}';
}

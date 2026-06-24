part of '../main.dart';

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

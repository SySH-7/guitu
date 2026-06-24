part of '../main.dart';

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

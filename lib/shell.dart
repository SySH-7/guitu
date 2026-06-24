part of 'main.dart';

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

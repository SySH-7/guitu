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
  bool _quickEntryExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_preloadMapDataSafely());
    });
  }

  Future<void> _preloadMapDataSafely() async {
    try {
      await Future.wait(<Future<GeoChinaData>>[
        preloadChinaGeoData(),
        preloadChinaGeoData(assetPath: chinaCityGeoJsonAsset),
      ]);
    } catch (_) {
      // The public source tree intentionally omits the private map asset.
    }
  }

  Future<void> _openAddFlow() async {
    final ArchiveKind? kind = await showArchiveKindChooser(context);
    if (!mounted || kind == null) {
      return;
    }
    await _openRecordForm(kind);
  }

  Future<void> _openRecordForm(
    ArchiveKind kind, {
    RecordFormPrefill? prefill,
  }) async {
    if (!mounted) {
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
          RecordFormSheet(kind: kind, store: widget.store, prefill: prefill),
    );
  }

  Future<void> _openQuickCoverEntry() async {
    final String? title = await QuickEntryFlow.pickConfirmedTitle(context);
    if (!mounted || title == null) {
      return;
    }
    final ArchiveKind? kind = await QuickEntryFlow.chooseBookOrFilm(context);
    if (!mounted || kind == null) {
      return;
    }
    await _openRecordForm(kind, prefill: RecordFormPrefill(title: title));
  }

  Future<void> _openQuickLocationEntry() async {
    if (!mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const _QuickLocationLoadingDialog(),
    );
    RegionMatch? region;
    LocationSnapshot? location;
    Object? error;
    try {
      location = await DeviceEntryService.instance.currentLocation();
      region = await RegionLookupService.instance.lookup(
        latitude: location.latitude,
        longitude: location.longitude,
      );
    } catch (caught) {
      error = caught;
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!mounted) {
      return;
    }
    if (error != null) {
      await _showQuickLocationError(error);
      return;
    }
    if (region == null || location == null) {
      await _showQuickLocationError(null);
      return;
    }
    await _openRecordForm(
      ArchiveKind.place,
      prefill: RecordFormPrefill(
        province: region.province,
        city: region.city,
        date: location.timestamp,
      ),
    );
  }

  Future<void> _showQuickLocationError(Object? error) {
    String message = '未能将当前位置转换为省市，请检查网络外的本地定位与系统定位设置后重试。';
    if (error is PlatformException) {
      switch (error.code) {
        case 'LOCATION_PERMISSION_DENIED':
          message = '未获得定位权限。允许定位后可自动预填省市，仍可继续手动新增地点。';
        case 'LOCATION_SERVICE_DISABLED':
          message = '系统定位服务未开启。开启后可自动预填省市，仍可继续手动新增地点。';
        case 'LOCATION_TIMEOUT':
          message = '定位超时，请移动到信号更好的位置后重试。';
      }
    }
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('无法获取当前位置'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
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
              onSelected: (int value) => setState(() {
                _index = value;
                _quickEntryExpanded = false;
              }),
              onAdd: _openAddFlow,
            ),
          ),
          if (_index != 3)
            Positioned(
              right: 26,
              bottom: 106,
              child: _QuickEntryFab(
                expanded: _quickEntryExpanded,
                onToggle: () => setState(
                  () => _quickEntryExpanded = !_quickEntryExpanded,
                ),
                onCover: () async {
                  setState(() => _quickEntryExpanded = false);
                  await _openQuickCoverEntry();
                },
                onLocation: () async {
                  setState(() => _quickEntryExpanded = false);
                  await _openQuickLocationEntry();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickLocationLoadingDialog extends StatelessWidget {
  const _QuickLocationLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 48),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(height: 16),
            Text(
              '正在获取当前位置',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '将使用内置行政区数据预填省市',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickEntryFab extends StatelessWidget {
  const _QuickEntryFab({
    required this.expanded,
    required this.onToggle,
    required this.onCover,
    required this.onLocation,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onCover;
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: expanded
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    _QuickFabCircle(
                      tooltip: '拍照识别书影',
                      icon: CupertinoIcons.camera_fill,
                      foreground: const Color(0xFFF7F7F3),
                      background: const Color(0xFF20211F),
                      onTap: onCover,
                    ),
                    const SizedBox(height: 12),
                    _QuickFabCircle(
                      tooltip: '记录当前位置',
                      icon: CupertinoIcons.location_solid,
                      foreground: const Color(0xFF20211F),
                      background: const Color(0xFFF1F0EB),
                      borderColor: Theme.of(context).dividerColor,
                      onTap: onLocation,
                    ),
                    const SizedBox(height: 12),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        _QuickFabCircle(
          tooltip: expanded ? '收起快捷录入' : '快捷录入',
          icon: expanded ? CupertinoIcons.xmark : CupertinoIcons.ellipsis,
          foreground: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF171A18)
              : Colors.white,
          background: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFECEFED)
              : const Color(0xFF171A18),
          onTap: onToggle,
        ),
      ],
    );
  }
}

class _QuickFabCircle extends StatelessWidget {
  const _QuickFabCircle({
    required this.tooltip,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.onTap,
    this.borderColor,
  });

  final String tooltip;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: CircleBorder(side: BorderSide(color: borderColor ?? background)),
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.24),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Semantics(
            button: true,
            label: tooltip,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(icon, color: foreground, size: 23),
            ),
          ),
        ),
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

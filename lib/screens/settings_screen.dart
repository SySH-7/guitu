part of '../main.dart';

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

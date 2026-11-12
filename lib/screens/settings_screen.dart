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
            icon: CupertinoIcons.chat_bubble_2,
            title: 'AI 助手设置',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AiSettingsScreen()),
            ),
          ),
          _SettingTile(
            icon: CupertinoIcons.photo_on_rectangle,
            title: '相册批量导入地点',
            onTap: () => PhotoTripDiscovery.start(context, store),
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
      final bool canAccess = await _prepareDocumentAccess(
        context,
        store,
        ArchiveDocumentAction.importData,
      );
      if (!canAccess) {
        return;
      }
      final bool imported = await store.importFromDevice();
      if (!imported) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未选择导入文件，导入已取消')),
        );
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
      final bool canAccess = await _prepareDocumentAccess(
        context,
        store,
        ArchiveDocumentAction.exportData,
      );
      if (!canAccess) {
        return;
      }
      final String? target = await store.exportToDevice();
      if (target == null) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未选择保存位置，导出已取消')),
        );
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

  Future<bool> _prepareDocumentAccess(
    BuildContext context,
    ArchiveStore store,
    ArchiveDocumentAction action,
  ) async {
    final bool hasSeenNotice = await store.hasSeenDocumentAccessNotice(action);
    if (!context.mounted) {
      return false;
    }
    if (!hasSeenNotice) {
      final bool accepted = await _showDocumentAccessNotice(context, action);
      if (!accepted) {
        if (!context.mounted) {
          return false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_documentActionLabel(action)}已取消')),
        );
        return false;
      }
      await store.markDocumentAccessNoticeSeen(action);
      if (!context.mounted) {
        return false;
      }
    }

    final DocumentAccessGrant grant = await store.requestDocumentAccess(action);
    if (grant.granted) {
      return true;
    }
    if (!context.mounted) {
      return false;
    }
    await _showDocumentAccessDenied(context, action, grant);
    return false;
  }

  Future<bool> _showDocumentAccessNotice(
    BuildContext context,
    ArchiveDocumentAction action,
  ) async {
    final bool isImport = action == ArchiveDocumentAction.importData;
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(CupertinoIcons.folder),
          title: Text(isImport ? '导入数据权限说明' : '导出数据权限说明'),
          content: Text(
            isImport
                ? '导入数据需要读取你选择的 JSON 文件。归途只会访问你主动选择的文件，不会扫描其它文件或目录。'
                : '导出数据需要把备份 JSON 写入你指定的位置。归途只会写入本次选择的文件，不会改动其它文件。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('暂不授权'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('继续'),
            ),
          ],
        );
      },
    );
    return accepted == true;
  }

  Future<void> _showDocumentAccessDenied(
    BuildContext context,
    ArchiveDocumentAction action,
    DocumentAccessGrant grant,
  ) {
    final bool isImport = action == ArchiveDocumentAction.importData;
    final String retryText = isImport ? '下次点击导入数据时会再次申请。' : '下次点击导出数据时会再次申请。';
    final String settingText =
        grant.permanentlyDenied ? '如果系统不再弹窗，请到系统设置中开启文件/存储访问权限。' : '';
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(CupertinoIcons.exclamationmark_triangle),
          title: const Text('权限未授予'),
          content: Text(
            isImport
                ? '没有文件读取权限，无法打开数据文件。$retryText$settingText'
                : '没有文件写入权限，无法保存导出文件。$retryText$settingText',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  String _documentActionLabel(ArchiveDocumentAction action) {
    switch (action) {
      case ArchiveDocumentAction.importData:
        return '导入数据';
      case ArchiveDocumentAction.exportData:
        return '导出数据';
    }
  }

  void _showAppInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _AppInfoDialog(),
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

class _AppInfoDialog extends StatefulWidget {
  const _AppInfoDialog();
  @override
  State<_AppInfoDialog> createState() => _AppInfoDialogState();
}

class _AppInfoDialogState extends State<_AppInfoDialog> {
  final _updates = UpdateService();
  String? _version;
  String? _message;
  bool _checking = false;
  bool _updateAvailable = false;

  @override
  void initState() {
    super.initState();
    _updates.currentVersion().then((value) {
      if (mounted) setState(() => _version = value);
    }).catchError((_) {
      if (mounted) setState(() => _version = '未知');
    });
  }

  Future<void> _open(String url) async {
    try {
      await _updates.openLink(url);
    } catch (_) {
      if (mounted) setState(() => _message = '无法打开浏览器，请检查设备设置。');
    }
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _message = null;
      _updateAvailable = false;
    });
    try {
      final current = await _updates.currentVersion();
      final latest = await _updates.latestVersion();
      final comparison = UpdateService.compare(current, latest);
      if (!mounted) return;
      setState(() {
        _version = current;
        _updateAvailable = comparison < 0;
        _message = comparison < 0
            ? '发现新版本 $latest，可前往 GitHub 下载更新。'
            : comparison == 0
                ? '已是最新版，无需更新。'
                : '当前版本高于 GitHub 最新发布版本。';
      });
    } catch (_) {
      if (mounted) setState(() => _message = '检查失败，请检查网络后重试。');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: Image.asset('assets/images/app_icon.png', width: 58, height: 58),
        title: const Text('归途'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('归途\nv${_version ?? '…'}\n开发者：SySH'),
              const SizedBox(height: 12),
              Text('用 AI 回顾书影与旅途，提问、总结并发现新灵感。',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _open(UpdateService.repositoryUrl),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const _GithubMark(size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                      child: Text('GitHub：SySH-7/guitu',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              decoration: TextDecoration.underline))),
                ]),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: _checking ? null : _check,
                  icon: const Icon(CupertinoIcons.arrow_clockwise, size: 18),
                  label: Text(_checking ? '正在检查…' : '检查更新')),
              if (_message != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_message!)),
              if (_updateAvailable)
                TextButton(
                    onPressed: () => _open(UpdateService.releasesUrl),
                    child: const Text('前往 GitHub 下载')),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'))
        ],
      );
}

class _GithubMark extends StatelessWidget {
  const _GithubMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/github_mark.png',
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.onSurface,
        semanticLabel: 'GitHub',
      );
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
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(ArchiveStore.fixedUserName,
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
        ],
      ),
    );
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

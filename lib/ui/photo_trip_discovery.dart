import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_data.dart';
import '../services/archive_store.dart';
import '../services/device_entry_service.dart';
import '../services/region_lookup_service.dart';
import 'charts.dart';

class PhotoTripDiscovery {
  PhotoTripDiscovery._();

  static Future<void> start(BuildContext context, ArchiveStore store) async {
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('从相册发现旅途'),
        content: const Text(
          '归途会读取当前获准访问照片的拍摄时间和 GPS 元数据，离线整理省市到访记录。'
          '不会复制、缓存或上传原始照片；扫描结果在你确认前不会写入旅途。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('暂不扫描'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: archiveGreen),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('授权并扫描'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) {
      return;
    }

    PhotoLibraryPermission permission;
    try {
      permission =
          await DeviceEntryService.instance.requestPhotoLibraryAccess();
    } on PlatformException {
      if (context.mounted) {
        await _showPhotoPermissionMessage(context, permanentlyDenied: false);
      }
      return;
    }
    if (!permission.granted) {
      if (context.mounted) {
        await _showPhotoPermissionMessage(
          context,
          permanentlyDenied: permission.permanentlyDenied,
        );
      }
      return;
    }
    if (!context.mounted) {
      return;
    }

    final List<TripImportCandidate>? candidates =
        await Navigator.of(context).push<List<TripImportCandidate>>(
      MaterialPageRoute<List<TripImportCandidate>>(
        builder: (BuildContext context) => const _PhotoScanProgressPage(),
      ),
    );
    if (!context.mounted || candidates == null || candidates.isEmpty) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _TripImportReviewPage(
          store: store,
          initialCandidates: candidates,
        ),
      ),
    );
  }

  static Future<void> _showPhotoPermissionMessage(
    BuildContext context, {
    required bool permanentlyDenied,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('未获得相册访问权限'),
        content: Text(
          permanentlyDenied
              ? '系统已不再显示授权请求。请在系统设置中允许照片访问后再试。'
              : '未获得照片访问权限，因此无法扫描历史旅途。你仍可手动添加地点记录。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _PhotoScanProgressPage extends StatefulWidget {
  const _PhotoScanProgressPage();

  @override
  State<_PhotoScanProgressPage> createState() => _PhotoScanProgressPageState();
}

class _PhotoScanProgressPageState extends State<_PhotoScanProgressPage> {
  AlbumScanProgress _progress =
      const AlbumScanProgress(scanned: 0, total: 0, stage: 'reading');
  String _stage = 'reading';
  bool _cancelling = false;
  bool _finished = false;
  String? _emptyMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_runScan());
  }

  Future<void> _runScan() async {
    try {
      final AlbumPhotoScan? scan =
          await DeviceEntryService.instance.scanPhotoLibrary(
        onProgress: (AlbumScanProgress value) {
          if (!mounted || _cancelling) {
            return;
          }
          setState(() {
            _stage = value.stage;
            _progress = value;
          });
        },
      );
      if (!mounted || scan == null || _cancelling) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
      if (scan.photos.isEmpty) {
        setState(() {
          _finished = true;
          _emptyMessage = scan.totalPhotoCount == 0
              ? '当前可访问的相册中没有可扫描的照片。'
              : '已检查 ${scan.totalPhotoCount} 张照片，但没有发现有效的 GPS 位置信息。';
        });
        return;
      }

      setState(() {
        _stage = 'analyzing';
        _progress = AlbumScanProgress(
          scanned: 0,
          total: scan.photos.length,
          stage: 'analyzing',
        );
      });
      final List<TripImportCandidate>? candidates =
          await RegionLookupService.instance.organizePhotoVisits(
        scan.photos,
        shouldCancel: () => _cancelling,
        onProgress: (LocalRegionProgress value) {
          if (!mounted || _cancelling) {
            return;
          }
          setState(() {
            _stage = value.stage;
            _progress = AlbumScanProgress(
              scanned: value.processed,
              total: value.total,
              stage: value.stage,
            );
          });
        },
      );
      if (!mounted || candidates == null || _cancelling) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
      if (candidates.isEmpty) {
        setState(() {
          _finished = true;
          _emptyMessage = '照片含有 GPS，但未能匹配到可导入的中国省市记录。';
        });
        return;
      }
      Navigator.of(context).pop(candidates);
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _finished = true;
        _errorMessage = _scanErrorMessage(error.code);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _finished = true;
        _errorMessage = '扫描未完成。请稍后重试，或确认相册访问权限和照片元数据是否正常。';
      });
    }
  }

  String _scanErrorMessage(String code) {
    switch (code) {
      case 'PHOTO_PERMISSION_DENIED':
        return '未获得照片访问权限，无法扫描相册。';
      case 'PHOTO_SCAN_BUSY':
        return '另一个相册扫描仍在停止中，请稍候再试。';
      default:
        return '扫描未完成。请稍后重试，或确认相册访问权限和照片元数据是否正常。';
    }
  }

  Future<void> _cancel() async {
    if (_cancelling || _finished) {
      return;
    }
    setState(() => _cancelling = true);
    try {
      await DeviceEntryService.instance.cancelPhotoScan();
    } catch (_) {
      // The local cancellation flag still prevents any later processing.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasMessage = _emptyMessage != null || _errorMessage != null;
    return PopScope(
      canPop: _finished,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) {
          unawaited(_cancel());
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: _finished
                          ? () => Navigator.of(context).pop()
                          : _cancel,
                      icon: const Icon(CupertinoIcons.chevron_back),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '从相册发现旅途',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: archiveGreen.withOpacity(0.16),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: hasMessage
                      ? _ScanTerminalState(
                          icon: _errorMessage == null
                              ? CupertinoIcons.photo_on_rectangle
                              : CupertinoIcons.exclamationmark_circle,
                          title: _errorMessage == null ? '没有扫描结果' : '扫描未完成',
                          message: _emptyMessage ?? _errorMessage!,
                          onClose: () => Navigator.of(context).pop(),
                        )
                      : _ScanProgressState(
                          progress: _progress,
                          stage: _stage,
                          cancelling: _cancelling,
                        ),
                ),
                const Spacer(flex: 2),
                if (!hasMessage)
                  OutlinedButton(
                    onPressed: _cancelling ? null : _cancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor:
                          Theme.of(context).textTheme.bodyLarge?.color,
                      side: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.8),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(_cancelling ? '正在安全停止扫描…' : '取消扫描'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanProgressState extends StatelessWidget {
  const _ScanProgressState({
    required this.progress,
    required this.stage,
    required this.cancelling,
  });

  final AlbumScanProgress progress;
  final String stage;
  final bool cancelling;

  String get _title {
    if (cancelling) {
      return '正在安全停止扫描';
    }
    switch (stage) {
      case 'analyzing':
        return '正在分析位置信息';
      case 'organizing':
        return '正在整理省市记录';
      default:
        return '正在读取相册';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: archiveGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            CupertinoIcons.photo_on_rectangle,
            color: archiveGreen,
            size: 26,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '${progress.percent}%',
          style: Theme.of(context)
              .textTheme
              .displaySmall
              ?.copyWith(fontWeight: FontWeight.w800, color: archiveGreen),
        ),
        const SizedBox(height: 6),
        Text(
          _title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          progress.total > 0
              ? '已处理 ${progress.scanned} / ${progress.total} 张可访问照片'
              : '正在准备读取当前可访问的照片',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.total > 0 ? progress.fraction : null,
            minHeight: 8,
            color: archiveGreen,
            backgroundColor: archiveGreen.withOpacity(0.12),
          ),
        ),
      ],
    );
  }
}

class _ScanTerminalState extends StatelessWidget {
  const _ScanTerminalState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onClose,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: archiveGreen, size: 32),
        const SizedBox(height: 18),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: archiveGreen,
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: onClose,
          child: const Text('返回旅途页'),
        ),
      ],
    );
  }
}

class _TripImportReviewPage extends StatefulWidget {
  const _TripImportReviewPage({
    required this.store,
    required this.initialCandidates,
  });

  final ArchiveStore store;
  final List<TripImportCandidate> initialCandidates;

  @override
  State<_TripImportReviewPage> createState() => _TripImportReviewPageState();
}

class _TripImportReviewPageState extends State<_TripImportReviewPage> {
  late List<TripImportCandidate> _candidates;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _candidates = List<TripImportCandidate>.from(widget.initialCandidates);
  }

  int get _selectedCount =>
      _candidates.where((TripImportCandidate value) => value.selected).length;

  void _replace(int index, TripImportCandidate value) {
    setState(() => _candidates[index] = value);
  }

  Future<void> _confirmImport() async {
    final List<TripImportCandidate> selected = _candidates
        .where((TripImportCandidate value) => value.selected)
        .toList(growable: false);
    if (selected.isEmpty || _saving) {
      return;
    }
    setState(() => _saving = true);
    final DateTime createdAt = DateTime.now();
    int index = 0;
    final List<ArchiveEntry> entries = <ArchiveEntry>[];
    for (final TripImportCandidate candidate in selected) {
      for (final DateTime date in candidate.visitDates) {
        index += 1;
        entries.add(ArchiveEntry(
          id: '${createdAt.microsecondsSinceEpoch}-$index',
          kind: ArchiveKind.place,
          title: candidate.city,
          category: '地点',
          date: date,
          rating: candidate.rating,
          amount: 1,
          province: candidate.province,
          city: candidate.city,
          notes: candidate.visitCount > 1
              ? '从相册发现：${candidate.visitCount} 次历史到访中的一条。'
              : '从相册发现的历史到访。',
          createdAt: createdAt,
        ));
      }
    }
    try {
      await widget.store.addEntries(entries);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 ${entries.length} 条地点记录')),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入未完成，未产生部分旅途数据。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool allSelected =
        _candidates.isNotEmpty && _selectedCount == _candidates.length;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(CupertinoIcons.chevron_back),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('扫描结果审核',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          '$_selectedCount / ${_candidates.length} 个省市已选择',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _candidates = _candidates
                                    .map((TripImportCandidate value) =>
                                        value.copyWith(selected: true))
                                    .toList(growable: false);
                              }),
                      icon: Icon(
                        allSelected
                            ? CupertinoIcons.checkmark_square_fill
                            : CupertinoIcons.checkmark_square,
                        size: 18,
                      ),
                      label: const Text('全选'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _candidates = _candidates
                                    .map((TripImportCandidate value) =>
                                        value.copyWith(selected: false))
                                    .toList(growable: false);
                              }),
                      icon: const Icon(CupertinoIcons.clear, size: 18),
                      label: const Text('批量取消'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 104),
                itemCount: _candidates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  final TripImportCandidate candidate = _candidates[index];
                  return _TripCandidateCard(
                    candidate: candidate,
                    onChanged: (TripImportCandidate value) =>
                        _replace(index, value),
                    onDelete: _saving
                        ? null
                        : () => setState(() => _candidates.removeAt(index)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton(
          onPressed: _selectedCount == 0 || _saving ? null : _confirmImport,
          style: FilledButton.styleFrom(
            backgroundColor: archiveGreen,
            minimumSize: const Size.fromHeight(54),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: Text(_saving ? '正在导入…' : '确认导入 $_selectedCount 个省市'),
        ),
      ),
    );
  }
}

class _TripCandidateCard extends StatelessWidget {
  const _TripCandidateCard({
    required this.candidate,
    required this.onChanged,
    required this.onDelete,
  });

  final TripImportCandidate candidate;
  final ValueChanged<TripImportCandidate> onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final String timeText = _dateRangeLabel(candidate.visitDates);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: candidate.selected
              ? archiveGreen.withOpacity(0.26)
              : Theme.of(context).dividerColor.withOpacity(0.72),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Checkbox(
          value: candidate.selected,
          activeColor: archiveGreen,
          onChanged: onDelete == null
              ? null
              : (bool? value) => onChanged(candidate.copyWith(
                    selected: value ?? false,
                  )),
        ),
        title: Text(
          '${candidate.province} · ${candidate.city}',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '检测到 ${candidate.visitCount} 次到访 · $timeText · ${candidate.rating} 分',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        trailing: IconButton(
          tooltip: '删除这条候选记录',
          onPressed: onDelete,
          icon: const Icon(CupertinoIcons.trash, size: 19),
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: candidate.province,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '省份'),
                  items: provinceNames
                      .map((String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(growable: false),
                  onChanged: onDelete == null
                      ? null
                      : (String? value) {
                          if (value == null) {
                            return;
                          }
                          final List<String> cities = chinaCities[value]!;
                          final String city = cities.contains(candidate.city)
                              ? candidate.city
                              : cities.first;
                          onChanged(candidate.copyWith(
                            province: value,
                            city: city,
                          ));
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: candidate.city,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '城市'),
                  items: chinaCities[candidate.province]!
                      .map((String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(growable: false),
                  onChanged: onDelete == null
                      ? null
                      : (String? value) {
                          if (value != null) {
                            onChanged(candidate.copyWith(city: value));
                          }
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onDelete == null
                ? null
                : () async {
                    final List<DateTime>? dates = await _editVisitDates(
                      context,
                      candidate.visitDates,
                    );
                    if (dates != null && dates.isNotEmpty) {
                      onChanged(candidate.copyWith(visitDates: dates));
                    }
                  },
            icon: const Icon(CupertinoIcons.calendar, size: 18),
            label: Text('到访日期：$timeText'),
          ),
          const SizedBox(height: 14),
          Text('评分',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: List<Widget>.generate(5, (int index) {
              final int rating = index + 1;
              final bool selected = candidate.rating == rating;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: rating == 5 ? 0 : 7),
                  child: InkWell(
                    onTap: onDelete == null
                        ? null
                        : () => onChanged(candidate.copyWith(rating: rating)),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? archiveGreen
                            : archiveGreen.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$rating',
                        style: TextStyle(
                          color: selected ? Colors.white : archiveGreen,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

String _dateRangeLabel(List<DateTime> values) {
  String format(DateTime value) {
    final String date =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    if (value.hour == 0 && value.minute == 0) {
      return date;
    }
    return '$date ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  if (values.length == 1) {
    return format(values.single);
  }
  return '${format(values.first)} 至 ${format(values.last)}';
}

Future<List<DateTime>?> _editVisitDates(
  BuildContext context,
  List<DateTime> initial,
) {
  final List<DateTime> values = List<DateTime>.from(initial)..sort();
  return showModalBottomSheet<List<DateTime>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('编辑到访日期',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('每次候选会保留首次抵达照片的拍摄时间。',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: values.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final DateTime value = values[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          CupertinoIcons.calendar,
                          color: archiveGreen,
                        ),
                        title: Text(_dateRangeLabel(<DateTime>[value])),
                        trailing: IconButton(
                          icon: const Icon(CupertinoIcons.pencil, size: 18),
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: value,
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                values[index] = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  value.hour,
                                  value.minute,
                                  value.second,
                                  value.millisecond,
                                  value.microsecond,
                                );
                                values.sort();
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: archiveGreen,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () {
                    final List<DateTime> deduplicated = values.toSet().toList()
                      ..sort();
                    Navigator.of(context).pop(deduplicated);
                  },
                  child: const Text('完成'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

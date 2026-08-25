import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_data.dart';
import '../services/device_entry_service.dart';
import 'charts.dart';

class QuickEntryFlow {
  QuickEntryFlow._();

  static final ImagePicker _picker = ImagePicker();

  static Future<String?> pickConfirmedTitle(BuildContext context) async {
    final ImageSource? source = await _chooseImageSource(context);
    if (source == null || !context.mounted) {
      return null;
    }

    XFile? image;
    try {
      image = await _picker.pickImage(
        source: source,
        maxWidth: 2200,
        imageQuality: 92,
      );
    } catch (_) {
      if (context.mounted) {
        await _showMessage(
          context,
          title: '无法读取图片',
          message: '请检查相机或照片访问权限后重试。',
        );
      }
      return null;
    }
    if (image == null || !context.mounted) {
      return null;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const _QuickOcrLoadingDialog(),
    );
    List<String> candidates = const <String>[];
    Object? error;
    try {
      candidates = await _recognizeCandidates(image.path);
    } catch (caught) {
      error = caught;
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!context.mounted) {
      return null;
    }
    if (error != null) {
      await _showMessage(
        context,
        title: '识别未完成',
        message: '本地文字识别暂时不可用，请更换清晰封面后重试。',
      );
      return null;
    }
    if (candidates.isEmpty) {
      await _showMessage(
        context,
        title: '没有识别到作品名称',
        message: '可以换一张更清晰、正面的书影封面再试。',
      );
      return null;
    }
    return _confirmTitle(context, candidates);
  }

  static Future<ArchiveKind?> chooseBookOrFilm(BuildContext context) {
    return showModalBottomSheet<ArchiveKind>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '这是哪一类作品？',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '名称已确认，只会预填到下一页，其他字段仍由你决定。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _QuickKindChoice(
                color: archiveOrange,
                icon: CupertinoIcons.book_fill,
                title: '阅读',
                subtitle: '进入阅读新增页并预填书籍名',
                onTap: () => Navigator.of(context).pop(ArchiveKind.book),
              ),
              const SizedBox(height: 10),
              _QuickKindChoice(
                color: archiveBlue,
                icon: CupertinoIcons.film_fill,
                title: '影视',
                subtitle: '进入影视新增页并预填片名',
                onTap: () => Navigator.of(context).pop(ArchiveKind.film),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<ImageSource?> _chooseImageSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '识别书影封面',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '文字只在本机识别，不会上传图片或调用网络服务。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _ImageSourceChoice(
                icon: CupertinoIcons.camera_fill,
                title: '相机拍照',
                subtitle: '拍摄眼前的书籍或影视封面',
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              const SizedBox(height: 10),
              _ImageSourceChoice(
                icon: CupertinoIcons.photo_fill_on_rectangle_fill,
                title: '从相册选择图片',
                subtitle: '只读取你在系统选择器中选中的这一张',
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<List<String>> _recognizeCandidates(String path) async {
    final List<String> raw =
        await DeviceEntryService.instance.recognizeCoverText(path);
    return _cleanCandidates(raw);
  }

  static List<String> _cleanCandidates(Iterable<String> rawValues) {
    final List<String> candidates = <String>[];
    final Set<String> seen = <String>{};
    for (final String raw in rawValues) {
      for (final String line in raw.split(RegExp(r'[\r\n]+'))) {
        String value = line
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'^[|·•—–_~]+|[|·•—–_~]+$'), '')
            .trim();
        if (value.length < 2 || value.length > 80) {
          continue;
        }
        if (!RegExp(r'[A-Za-z\u4e00-\u9fff]').hasMatch(value) ||
            RegExp(r'^(isbn|issn|第?\d+[册集季]?|\d+[.\d\-]*$)',
                    caseSensitive: false)
                .hasMatch(value)) {
          continue;
        }
        final String key = value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
        if (seen.add(key)) {
          candidates.add(value);
        }
      }
    }
    candidates.sort((String a, String b) {
      final int wordLength = a.length.compareTo(b.length);
      return wordLength == 0 ? a.compareTo(b) : wordLength;
    });
    return candidates.take(12).toList(growable: false);
  }

  static Future<String?> _confirmTitle(
    BuildContext context,
    List<String> candidates,
  ) {
    final TextEditingController controller =
        TextEditingController(text: candidates.first);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '确认作品名称',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '选择候选文字，或直接修改后继续。不会自动创建记录。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: candidates
                        .map(
                          (String value) => ChoiceChip(
                            label: Text(value, overflow: TextOverflow.ellipsis),
                            selected: controller.text == value,
                            onSelected: (_) =>
                                setState(() => controller.text = value),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: false,
                    decoration: const InputDecoration(labelText: '作品名称 *'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF20211F),
                      foregroundColor: const Color(0xFFF7F7F3),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: controller.text.trim().isEmpty
                        ? null
                        : () =>
                            Navigator.of(context).pop(controller.text.trim()),
                    child: const Text(
                      '确认名称',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(controller.dispose);
  }

  static Future<void> _showMessage(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
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
}

class _QuickOcrLoadingDialog extends StatelessWidget {
  const _QuickOcrLoadingDialog();

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
              '正在本地识别文字',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '图片不会上传到网络',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageSourceChoice extends StatelessWidget {
  const _ImageSourceChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF20211F),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFFF7F7F3), size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_forward, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickKindChoice extends StatelessWidget {
  const _QuickKindChoice({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_forward, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

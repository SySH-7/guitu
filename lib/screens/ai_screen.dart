import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/app_data.dart';
import '../services/ai_insights.dart';
import '../services/ai_service.dart';
import '../services/archive_store.dart';
import '../ui/charts.dart';

/// A deliberately on-demand assistant: opening this screen sends no data.
class AiScreen extends StatefulWidget {
  const AiScreen({super.key, required this.store});
  final ArchiveStore store;

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _question = TextEditingController();
  final Map<ArchiveKind, List<String>> _recommended =
      <ArchiveKind, List<String>>{};
  ArchiveKind? _recommendationKind;
  int _feature = 0;
  int? _year;
  bool _loading = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_loading) return;
    if (_feature == 0 && _question.text.trim().isEmpty) {
      setState(() => _error = '请先输入你的问题');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final config = await AiConfigStore().load();
      if (config == null) throw StateError('请先在设置中配置 AI API。');
      final data = AiInsights(widget.store.entries);
      String prompt;
      ArchiveKind? kind;
      switch (_feature) {
        case 0:
          prompt = data.questionPrompt(_question.text.trim());
        case 1:
          prompt = data.annualPrompt(_year);
        case 2:
          prompt = data.recentPrompt();
        default:
          kind = _recommendationKind ?? data.chooseRecommendationKind();
          prompt =
              data.recommendationPrompt(kind, _recommended[kind] ?? const []);
      }
      String output = '';
      final rejected = <String>[...?_recommended[kind]];
      for (var attempt = 0; attempt < (kind == null ? 1 : 3); attempt++) {
        final answer = await AiService().generate(
          config: config,
          systemPrompt: AiInsights.systemPrompt,
          userPrompt:
              kind == null ? prompt : data.recommendationPrompt(kind, rejected),
        );
        if (kind == null) {
          output = answer
              .trim()
              .replaceAll(RegExp(r'\*\*|__|^#{1,6}\s*', multiLine: true), '')
              .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '');
          break;
        }
        try {
          final start = answer.indexOf('{');
          final end = answer.lastIndexOf('}');
          if (start < 0 || end <= start) continue;
          final object = jsonDecode(answer.substring(start, end + 1));
          if (object is! Map ||
              object['title'] is! String ||
              object['reason'] is! String) continue;
          final title = (object['title'] as String).trim();
          final reason = (object['reason'] as String).trim();
          String normalize(String value) => value
              .toLowerCase()
              .replaceAll(RegExp(r'[\s《》「」“”\-·：:，,。.!！?？]'), '');
          final key = normalize(title);
          if (key.isEmpty || reason.isEmpty) continue;
          if (widget.store.entries
                  .any((e) => e.kind == kind && normalize(e.title) == key) ||
              rejected.any((e) => normalize(e) == key)) {
            rejected.add(title);
            continue;
          }
          (_recommended[kind] ??= <String>[]).add(title);
          output = '${kind.label} · $title\n\n$reason';
          break;
        } on FormatException {
          continue;
        }
      }
      if (output.isEmpty) {
        throw StateError(
            kind == null ? 'AI 未返回有效内容，请稍后再试。' : '暂时没有找到合适的推荐，请稍后再试。');
      }
      if (mounted) setState(() => _result = output);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e.toString().replaceFirst(
                RegExp(r'^(Bad state|FormatException|Exception): '),
                '',
              ),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _labels = <String>['向 AI 提问', '年度总结', '近期分析', '随机推荐'];
  static const _descriptions = <String>[
    '从记录里寻找答案',
    '回看一年里的故事',
    '看看最近的变化',
    '发现下一段旅程'
  ];
  static const _icons = <IconData>[
    CupertinoIcons.chat_bubble_text,
    CupertinoIcons.book,
    CupertinoIcons.chart_bar,
    CupertinoIcons.compass,
  ];
  static const _accents = <Color>[
    archiveGreen,
    archiveOrange,
    archiveBlue,
    archiveGreen
  ];

  @override
  Widget build(BuildContext context) {
    final data = AiInsights(widget.store.entries);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurface.withOpacity(.58);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title:
            const Text('归途 AI', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF203126) : const Color(0xFFEAF4EB),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF345A3C) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(CupertinoIcons.sparkles,
                      color: archiveGreen, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('让记录，慢慢有了回响',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text('从读过的书、看过的故事和走过的路里，发现新的线索。',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: muted, height: 1.55)),
                  ],
                )),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text('选择你想做的事',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List<Widget>.generate(
                  4,
                  (i) => SizedBox(
                        width: width,
                        child: _featureTile(context, i),
                      )),
            );
          }),
          const SizedBox(height: 26),
          _workArea(context, data),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _run,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF326B3C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                          const Icon(CupertinoIcons.sparkles, size: 18),
                          const SizedBox(width: 8),
                          Text(
                              _feature == 0
                                  ? '发送问题'
                                  : _feature == 3 && _result != null
                                      ? '换一个推荐'
                                      : <String>[
                                          '发送问题',
                                          '生成年度总结',
                                          '生成近期分析',
                                          '生成随机推荐'
                                        ][_feature],
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Icon(CupertinoIcons.lock_shield, size: 14, color: muted),
            const SizedBox(width: 6),
            Expanded(
                child: Text('点击生成后，相关记录将发送至你选择的 AI 服务商。',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: muted, height: 1.45))),
          ]),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!,
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (_result != null)
            Container(
              margin: const EdgeInsets.only(top: 22),
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(context),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(children: <Widget>[
                      const Icon(CupertinoIcons.sparkles,
                          color: archiveGreen, size: 18),
                      const SizedBox(width: 8),
                      Text('归途的回响',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 14),
                    SelectableText(_result!,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.8)),
                  ]),
            ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context, {bool selected = false}) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
          color: selected ? archiveGreen : theme.dividerColor,
          width: selected ? 1.5 : 1),
      boxShadow: <BoxShadow>[
        BoxShadow(
            color: Colors.black
                .withOpacity(theme.brightness == Brightness.dark ? .12 : .035),
            blurRadius: 20,
            offset: const Offset(0, 6)),
      ],
    );
  }

  Widget _featureTile(BuildContext context, int i) {
    final selected = _feature == i;
    final theme = Theme.of(context);
    final accent = _accents[i];
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _loading
              ? null
              : () => setState(() {
                    _feature = i;
                    _result = null;
                    _error = null;
                  }),
          child: Ink(
            decoration: _cardDecoration(context, selected: selected),
            padding: const EdgeInsets.all(14),
            child: Row(children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: accent.withOpacity(.11),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(_icons[i], size: 19, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                    Text(_labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_descriptions[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color:
                                theme.colorScheme.onSurface.withOpacity(.52))),
                  ])),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _workArea(BuildContext context, AiInsights data) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withOpacity(.56);
    final selected = data.forYear(_year);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[
              Text(_labels[_feature],
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Icon(_icons[_feature], size: 19, color: _accents[_feature]),
            ]),
            const SizedBox(height: 6),
            Text(
                <String>[
                  '关于你的记录，你想知道什么？',
                  '把书影与旅途整理成一份小结。',
                  '回看最近的阅读、观影与旅途。',
                  '按照近期偏好，寻找新的可能。'
                ][_feature],
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: muted, height: 1.5)),
            const SizedBox(height: 16),
            if (_feature == 0)
              TextField(
                controller: _question,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                    hintText: '例如：最近我读了哪些类型的书？', hintMaxLines: 2),
              ),
            if (_feature == 1) ...<Widget>[
              DropdownButtonFormField<int>(
                value: _year ?? 0,
                decoration: const InputDecoration(labelText: '选择年份'),
                items: <DropdownMenuItem<int>>[
                  const DropdownMenuItem<int>(value: 0, child: Text('全部年份')),
                  ...data.years.map((y) =>
                      DropdownMenuItem<int>(value: y, child: Text('$y 年'))),
                ],
                onChanged: _loading
                    ? null
                    : (value) => setState(() {
                          _year = value == 0 ? null : value;
                          _result = null;
                        }),
              ),
              const SizedBox(height: 18),
              _countSummary(context, data, selected),
            ],
            if (_feature == 2) ...<Widget>[
              Text('最近 30 天  ·  对比此前 30 天',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              const SizedBox(height: 10),
              _comparison(
                  context,
                  '书籍',
                  data.count(data.recentMonth, ArchiveKind.book),
                  data.count(data.previousMonth, ArchiveKind.book),
                  archiveOrange,
                  '本'),
              const SizedBox(height: 8),
              _comparison(
                  context,
                  '影视',
                  data.count(data.recentMonth, ArchiveKind.film),
                  data.count(data.previousMonth, ArchiveKind.film),
                  archiveBlue,
                  '部'),
              const SizedBox(height: 8),
              _comparison(
                  context,
                  '旅行',
                  data.count(data.recentMonth, ArchiveKind.place),
                  data.count(data.previousMonth, ArchiveKind.place),
                  archiveGreen,
                  '个'),
            ],
            if (_feature == 3) ...<Widget>[
              Text('为下一本书、一部电影或一次出发寻找灵感。',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: muted, height: 1.6)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final option in <(String, ArchiveKind?)>[
                    ('随机', null),
                    ('书籍', ArchiveKind.book),
                    ('影视', ArchiveKind.film),
                    ('地点', ArchiveKind.place),
                  ])
                    ChoiceChip(
                      label: Text(option.$1),
                      selected: _recommendationKind == option.$2,
                      onSelected: _loading
                          ? null
                          : (_) => setState(() {
                                _recommendationKind = option.$2;
                                _result = null;
                                _error = null;
                              }),
                    ),
                ],
              ),
            ],
          ]),
    );
  }

  Widget _countSummary(
      BuildContext context, AiInsights data, List<ArchiveEntry> selected) {
    final books = data.count(selected, ArchiveKind.book);
    final films = data.count(selected, ArchiveKind.film);
    final places = data.count(selected, ArchiveKind.place);
    final total = books + films + places;
    final theme = Theme.of(context);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: _stat('书籍', '$books 本', archiveOrange)),
            Expanded(child: _stat('影视', '$films 部', archiveBlue)),
            Expanded(child: _stat('旅行', '$places 个', archiveGreen)),
          ]),
          const SizedBox(height: 16),
          Row(children: <Widget>[
            for (final item in <(int, Color)>[
              (books, archiveOrange),
              (films, archiveBlue),
              (places, archiveGreen)
            ])
              if (item.$1 > 0)
                Expanded(
                    flex: item.$1, child: Container(height: 8, color: item.$2)),
            if (total == 0)
              Expanded(child: Container(height: 8, color: theme.dividerColor)),
          ]),
        ]);
  }

  Widget _stat(String label, String value, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
      ]);

  Widget _comparison(BuildContext context, String label, int current,
      int previous, Color color, String unit) {
    final difference = current - previous;
    final change = difference == 0
        ? '持平'
        : difference > 0
            ? '增加 $difference $unit'
            : '减少 ${-difference} $unit';
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: <Widget>[
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('之前 $previous $unit · $change',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(.55))),
            ])),
        Text('$current $unit',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

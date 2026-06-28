import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/app_data.dart';
import '../services/archive_store.dart';
import 'charts.dart';

Future<ArchiveKind?> showArchiveKindChooser(BuildContext context) {
  final Color textColor =
      Theme.of(context).textTheme.titleMedium?.color ?? Colors.black;
  return showModalBottomSheet<ArchiveKind>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('记录这一刻',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              _KindOption(
                color: archiveOrange,
                icon: CupertinoIcons.book_fill,
                title: '阅读',
                subtitle: '书籍、作者、读后感与完成日期',
                onTap: () => Navigator.of(context).pop(ArchiveKind.book),
              ),
              _KindOption(
                color: archiveBlue,
                icon: CupertinoIcons.film_fill,
                title: '影视',
                subtitle: '片名、导演、类型、季数与评分',
                onTap: () => Navigator.of(context).pop(ArchiveKind.film),
              ),
              _KindOption(
                color: archiveGreen,
                icon: CupertinoIcons.location_solid,
                title: '地点',
                subtitle: '省市、抵达日期、花费与游后感',
                onTap: () => Navigator.of(context).pop(ArchiveKind.place),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text('数据会保存在应用本地空间',
                    style: TextStyle(
                        color: textColor.withOpacity(0.46), fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _KindOption extends StatelessWidget {
  const _KindOption({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.12)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(14)),
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
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(height: 1.25)),
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

class RecordFormSheet extends StatefulWidget {
  const RecordFormSheet({
    super.key,
    required this.kind,
    required this.store,
  });

  final ArchiveKind kind;
  final ArchiveStore store;

  @override
  State<RecordFormSheet> createState() => _RecordFormSheetState();
}

class _RecordFormSheetState extends State<RecordFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _creatorController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  final TextEditingController _expenseController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late String _category;
  DateTime _date = DateTime.now();
  int _rating = 4;
  int _amount = 1;
  String _province = provinceNames.first;
  late String _city;

  @override
  void initState() {
    super.initState();
    _category = _categories.first;
    _city = chinaCities[_province]!.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _creatorController.dispose();
    _detailController.dispose();
    _expenseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    switch (widget.kind) {
      case ArchiveKind.book:
        return bookCategories;
      case ArchiveKind.film:
        return filmCategories;
      case ArchiveKind.place:
        return const <String>['地点'];
    }
  }

  Color get _accent {
    switch (widget.kind) {
      case ArchiveKind.book:
        return archiveOrange;
      case ArchiveKind.film:
        return archiveBlue;
      case ArchiveKind.place:
        return archiveGreen;
    }
  }

  String get _title {
    switch (widget.kind) {
      case ArchiveKind.book:
        return '新增阅读';
      case ArchiveKind.film:
        return '新增影视';
      case ArchiveKind.place:
        return '新增地点';
    }
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.90,
          minChildSize: 0.58,
          maxChildSize: 0.96,
          builder: (BuildContext context, ScrollController scrollController) {
            return Form(
              key: _formKey,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(_title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(CupertinoIcons.xmark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widget.kind != ArchiveKind.place) ...<Widget>[
                    _RequiredTextField(
                      controller: _titleController,
                      label: widget.kind == ArchiveKind.book ? '书籍名' : '影视名',
                      accent: _accent,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _creatorController,
                      decoration: InputDecoration(
                          labelText: widget.kind == ArchiveKind.book
                              ? '作者名（选填）'
                              : '导演名（选填）'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.kind != ArchiveKind.place) ...<Widget>[
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: _requiredDecoration('类型'),
                      items: _categories
                          .map((String value) => DropdownMenuItem<String>(
                              value: value, child: Text(value)))
                          .toList(),
                      onChanged: (String? value) =>
                          setState(() => _category = value ?? _category),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.kind == ArchiveKind.place) ...<Widget>[
                    DropdownButtonFormField<String>(
                      value: _province,
                      isExpanded: true,
                      menuMaxHeight: 420,
                      decoration: _requiredDecoration('省份'),
                      items: provinceNames
                          .map((String value) => DropdownMenuItem<String>(
                              value: value, child: Text(value)))
                          .toList(),
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _province = value;
                          _city = chinaCities[_province]!.first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>(_province),
                      value: _city,
                      isExpanded: true,
                      menuMaxHeight: 420,
                      decoration: _requiredDecoration('城市'),
                      items: chinaCities[_province]!
                          .map((String value) => DropdownMenuItem<String>(
                              value: value, child: Text(value)))
                          .toList(),
                      onChanged: (String? value) =>
                          setState(() => _city = value ?? _city),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _detailController,
                      decoration:
                          const InputDecoration(labelText: '更具体地点（选填，默认城市）'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _expenseController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '大概消费（选填）'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _DateButton(
                      date: _date, accent: _accent, onPressed: _pickDate),
                  const SizedBox(height: 14),
                  _RatingSelector(
                      value: _rating,
                      accent: _accent,
                      isPlace: widget.kind == ArchiveKind.place,
                      onChanged: (int value) =>
                          setState(() => _rating = value)),
                  const SizedBox(height: 14),
                  if (widget.kind != ArchiveKind.place)
                    _AmountStepper(
                      value: _amount,
                      label: widget.kind == ArchiveKind.book ? '册数' : '季数',
                      accent: _accent,
                      onChanged: (int value) => setState(() => _amount = value),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                        labelText: widget.kind == ArchiveKind.place
                            ? '游后感 / 其他相关（选填）'
                            : '感想 / 其他相关（选填）'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: _submit,
                    child: const Text('保存记录',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _requiredDecoration(String label) {
    return InputDecoration(
      label: RichText(
        text: TextSpan(
          text: label,
          style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.72)),
          children: const <TextSpan>[
            TextSpan(text: ' *', style: TextStyle(color: Colors.redAccent))
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
                Theme.of(context).colorScheme.copyWith(primary: _accent),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (value != null) {
      setState(() => _date = value);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final String detail = _detailController.text.trim();
    final bool isPlace = widget.kind == ArchiveKind.place;
    final String title = isPlace
        ? '$_city${detail.isEmpty ? '' : ' · $detail'}'
        : _titleController.text.trim();
    final ArchiveEntry entry = ArchiveEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: widget.kind,
      title: title,
      category: isPlace ? '地点' : _category,
      date: _date,
      rating: _rating,
      amount: isPlace ? 1 : _amount,
      creator: _creatorController.text.trim().isEmpty
          ? null
          : _creatorController.text.trim(),
      province: isPlace ? _province : null,
      city: isPlace ? _city : null,
      detail: isPlace && detail.isNotEmpty ? detail : null,
      expense: isPlace ? double.tryParse(_expenseController.text.trim()) : null,
      notes: _notesController.text.trim(),
      createdAt: DateTime.now(),
    );
    await widget.store.addEntry(entry);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存：${entry.title}')),
    );
  }
}

class _RequiredTextField extends StatelessWidget {
  const _RequiredTextField({
    required this.controller,
    required this.label,
    required this.accent,
  });

  final TextEditingController controller;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        label: RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.72)),
            children: const <TextSpan>[
              TextSpan(text: ' *', style: TextStyle(color: Colors.redAccent))
            ],
          ),
        ),
      ),
      validator: (String? value) {
        if (value == null || value.trim().isEmpty) {
          return '请填写$label';
        }
        return null;
      },
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.date,
    required this.accent,
    required this.onPressed,
  });

  final DateTime date;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(CupertinoIcons.calendar, color: accent, size: 18),
      label: Text(
          '完成 / 抵达日期 *  ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: Theme.of(context).textTheme.bodyMedium?.color,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: accent.withOpacity(0.28)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _RatingSelector extends StatelessWidget {
  const _RatingSelector({
    required this.value,
    required this.accent,
    required this.isPlace,
    required this.onChanged,
  });

  final int value;
  final Color accent;
  final bool isPlace;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<Color> placeColors = <Color>[
      const Color(0xFFE54B4B),
      const Color(0xFFFF8D8D),
      const Color(0xFFE8BF30),
      const Color(0xFF85CE72),
      const Color(0xFF2FAE4E),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('评分 *',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: List<Widget>.generate(5, (int index) {
            final int rating = index + 1;
            final bool selected = value == rating;
            final Color color = isPlace ? placeColors[index] : accent;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 4 ? 0 : 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onChanged(rating),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? color : color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: color.withOpacity(selected ? 0 : 0.20)),
                    ),
                    child: Text(
                      isPlace
                          ? <String>['极差', '差', '一般', '不错', '完美'][index]
                          : '$rating',
                      style: TextStyle(
                        color: selected ? Colors.white : color,
                        fontSize: isPlace ? 11 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _AmountStepper extends StatelessWidget {
  const _AmountStepper({
    required this.value,
    required this.label,
    required this.accent,
    required this.onChanged,
  });

  final int value;
  final String label;
  final Color accent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.36)),
      ),
      child: Row(
        children: <Widget>[
          Text('$label *',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          _RoundIconButton(
              icon: CupertinoIcons.minus,
              onTap: value > 1 ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 54,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          _RoundIconButton(
              icon: CupertinoIcons.plus,
              onTap: () => onChanged(value + 1),
              accent: accent),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    this.onTap,
    this.accent,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color color =
        accent ?? Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(onTap == null ? 0.04 : 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            size: 16, color: onTap == null ? color.withOpacity(0.2) : color),
      ),
    );
  }
}

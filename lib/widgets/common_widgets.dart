part of '../main.dart';

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(top: true, bottom: false, child: child);
  }
}

class _TopTitle extends StatelessWidget {
  const _TopTitle({
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0)),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _SegmentedHeader extends StatelessWidget {
  const _SegmentedHeader({
    required this.values,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> values;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 38,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF151E20) : const Color(0xFFF0F2F1),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: List<Widget>.generate(values.length, (int index) {
          final bool selected = selectedIndex == index;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? (dark ? Colors.white : Colors.black)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  values[index],
                  style: TextStyle(
                    color: selected
                        ? (dark ? Colors.black : Colors.white)
                        : Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.56),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _YearChips extends StatelessWidget {
  const _YearChips({
    required this.selected,
    required this.primaryYears,
    required this.earlierYears,
    required this.onChanged,
    required this.onEarlier,
  });

  final int selected;
  final List<int> primaryYears;
  final List<int> earlierYears;
  final ValueChanged<int> onChanged;
  final VoidCallback onEarlier;

  @override
  Widget build(BuildContext context) {
    final int currentYear = DateTime.now().year;
    final bool selectedIsEarlier = earlierYears.contains(selected);
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final int year in primaryYears)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _YearChip(
                label: year == currentYear ? '今年' : '$year',
                selected: selected == year,
                onTap: () => onChanged(year),
              ),
            ),
          if (earlierYears.isNotEmpty)
            _YearChip(
              label: selectedIsEarlier ? '$selected' : '更多',
              selected: selectedIsEarlier,
              onTap: onEarlier,
            ),
        ],
      ),
    );
  }
}

class _YearChip extends StatelessWidget {
  const _YearChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFECEFED)
          : const Color(0xFF171A18),
      backgroundColor: Theme.of(context).cardColor,
      side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.58)),
      labelStyle: TextStyle(
        color: selected
            ? (Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : Colors.white)
            : Theme.of(context).textTheme.bodySmall?.color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool hasTitle = title.isNotEmpty || trailing != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Colors.black.withOpacity(
                  Theme.of(context).brightness == Brightness.dark
                      ? 0.18
                      : 0.045),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hasTitle) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                    child: Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600))),
                if (trailing != null)
                  Text(trailing!,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.action,
  });

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700))),
        if (action != null)
          Text(action!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.color
                      ?.withOpacity(0.46))),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  final Color color;
  final IconData icon;
  final String label;
  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 13),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.50)),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Colors.black.withOpacity(
                  Theme.of(context).brightness == Brightness.dark
                      ? 0.16
                      : 0.045),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 5),
          FittedBox(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w700),
                children: <TextSpan>[
                  TextSpan(
                      text: '$value', style: const TextStyle(fontSize: 24)),
                  TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                          fontSize: 11,
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
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.entry,
    this.onDelete,
  });

  final ArchiveEntry entry;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final Color accent = entry.kind.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.48)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  accent.withOpacity(0.92),
                  accent.withOpacity(0.36)
                ],
              ),
              image: entry.kind == ArchiveKind.place
                  ? const DecorationImage(
                      image: AssetImage('assets/images/app_icon.png'),
                      fit: BoxFit.cover,
                      opacity: 0.28)
                  : null,
            ),
            child: Icon(entry.kind.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (onDelete != null)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(CupertinoIcons.ellipsis, size: 18),
                        onSelected: (_) => onDelete?.call(),
                        itemBuilder: (BuildContext context) =>
                            const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                              value: 'delete', child: Text('删除')),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(_entrySubtitle(entry),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.58))),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Text(_stars(entry.rating),
                        style: const TextStyle(
                            color: Color(0xFFFFB02E),
                            fontSize: 12,
                            letterSpacing: 1.2)),
                    const Spacer(),
                    Text(_formatDate(entry.date),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.color
                                ?.withOpacity(0.50))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProvinceSummary extends StatelessWidget {
  const _ProvinceSummary({
    required this.entries,
    required this.selectedProvince,
  });

  final List<MapEntry<String, int>> entries;
  final String? selectedProvince;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _PlainHint(text: '还没有旅途记录。点击底部加号添加地点。');
    }
    final List<MapEntry<String, int>> visible = selectedProvince == null
        ? entries
        : <MapEntry<String, int>>[
            if (entries.any(
                (MapEntry<String, int> entry) => entry.key == selectedProvince))
              entries.firstWhere((MapEntry<String, int> entry) =>
                  entry.key == selectedProvince),
            ...entries.where(
                (MapEntry<String, int> entry) => entry.key != selectedProvince),
          ];
    return Column(
      children: visible.map((MapEntry<String, int> entry) {
        final bool selected = entry.key == selectedProvince;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: provinceColor(entry.value, selected)
                .withOpacity(selected ? 1 : 0.72),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: const Color(0xFF5B9B66).withOpacity(0.16)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(entry.key,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF1E3523),
                          fontWeight: FontWeight.w600,
                        )),
              ),
              Text('${entry.value}次',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF1E3523),
                        fontWeight: FontWeight.w700,
                      )),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 8,
      children: <Widget>[
        _LegendItem(color: Color(0xFF43B95A), text: '5次及以上'),
        _LegendItem(color: Color(0xFF89DA7F), text: '3-4次'),
        _LegendItem(color: Color(0xFFCFEFC9), text: '1-2次'),
        _LegendItem(color: Color(0xFFF8FBF7), text: '0次'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.text,
  });

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.black.withOpacity(0.06)))),
        const SizedBox(width: 5),
        Text(text,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.52)),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600))),
              trailing ?? const Icon(CupertinoIcons.chevron_forward, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '',
      child: Column(
        children: <Widget>[
          Image.asset('assets/images/app_icon.png', width: 72, height: 72),
          const SizedBox(height: 10),
          Text('还没有记录',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('把一本书、一部电影或一次抵达放进时间里。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          FilledButton(onPressed: onAdd, child: const Text('开始记录')),
        ],
      ),
    );
  }
}

class _PlainHint extends StatelessWidget {
  const _PlainHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

String _entrySubtitle(ArchiveEntry entry) {
  switch (entry.kind) {
    case ArchiveKind.book:
      return '${entry.creator ?? '未知作者'} / ${entry.category} / ${entry.amount}册';
    case ArchiveKind.film:
      return '${entry.creator ?? '未知导演'} / ${entry.category} / ${entry.amount}季';
    case ArchiveKind.place:
      return '${entry.province ?? ''}${entry.city == null ? '' : ' · ${entry.city}'} / ${entry.category}';
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _stars(int rating) {
  return '${'★' * rating}${'☆' * (5 - rating)}';
}

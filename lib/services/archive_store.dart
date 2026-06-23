import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_data.dart';

class ArchivePlatformStorage {
  static const MethodChannel _channel = MethodChannel('guitu/storage');

  File get _fallbackFile {
    final Directory directory = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}guitu_archive');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return File('${directory.path}${Platform.pathSeparator}snapshot.json');
  }

  Future<String?> readSnapshot() async {
    try {
      return await _channel.invokeMethod<String>('readSnapshot');
    } on MissingPluginException {
      if (!_fallbackFile.existsSync()) {
        return null;
      }
      return _fallbackFile.readAsStringSync();
    }
  }

  Future<void> writeSnapshot(String data) async {
    try {
      await _channel
          .invokeMethod<void>('writeSnapshot', <String, Object?>{'data': data});
    } on MissingPluginException {
      _fallbackFile.writeAsStringSync(data);
    }
  }

  Future<String?> importSnapshot() async {
    try {
      return await _channel.invokeMethod<String>('importSnapshot');
    } on MissingPluginException {
      if (!_fallbackFile.existsSync()) {
        return null;
      }
      return _fallbackFile.readAsStringSync();
    }
  }

  Future<String?> exportSnapshot(String data, String fileName) async {
    try {
      return await _channel.invokeMethod<String>(
        'exportSnapshot',
        <String, Object?>{'data': data, 'fileName': fileName},
      );
    } on MissingPluginException {
      final File file = File(
          '${_fallbackFile.parent.path}${Platform.pathSeparator}$fileName');
      file.writeAsStringSync(data);
      return file.path;
    }
  }
}

class ArchiveStore extends ChangeNotifier {
  final ArchivePlatformStorage _storage = ArchivePlatformStorage();

  bool _loaded = false;
  bool darkMode = false;
  String userName = '我的归途';
  int avatarIndex = 0;
  List<ArchiveEntry> entries = <ArchiveEntry>[];

  bool get isLoaded => _loaded;

  Future<void> load() async {
    final String? raw = await _storage.readSnapshot();
    if (raw == null) {
      entries = <ArchiveEntry>[];
      await _persist();
    } else {
      _applySnapshot(raw, fallbackToSeed: true);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setUserName(String value) async {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    userName = trimmed;
    notifyListeners();
    await _persist();
  }

  Future<void> setAvatarIndex(int value) async {
    avatarIndex = value;
    notifyListeners();
    await _persist();
  }

  Future<void> addEntry(ArchiveEntry entry) async {
    entries = <ArchiveEntry>[entry, ...entries];
    notifyListeners();
    await _persist();
  }

  Future<void> removeEntry(String id) async {
    entries = entries
        .where((ArchiveEntry entry) => entry.id != id)
        .toList(growable: false);
    notifyListeners();
    await _persist();
  }

  Future<void> clearAllEntries() async {
    entries = <ArchiveEntry>[];
    notifyListeners();
    await _persist();
  }

  Future<void> replaceFromJson(String raw) async {
    _applySnapshot(raw, fallbackToSeed: false);
    notifyListeners();
    await _persist();
  }

  Future<bool> importFromDevice() async {
    final String? raw = await _storage.importSnapshot();
    if (raw == null) {
      return false;
    }
    await replaceFromJson(raw);
    return true;
  }

  Future<String?> exportToDevice() async {
    final String fileName =
        'guitu_export_${DateTime.now().millisecondsSinceEpoch}.json';
    return _storage.exportSnapshot(exportJson(), fileName);
  }

  String exportJson() {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(_snapshot());
  }

  List<ArchiveEntry> recentEntries({int limit = 8}) {
    final List<ArchiveEntry> copy = List<ArchiveEntry>.from(entries);
    copy.sort((ArchiveEntry a, ArchiveEntry b) => b.date.compareTo(a.date));
    return copy.take(limit).toList(growable: false);
  }

  int totalFor(ArchiveKind kind) {
    final Iterable<ArchiveEntry> filtered =
        entries.where((ArchiveEntry entry) => entry.kind == kind);
    if (kind == ArchiveKind.place) {
      return filtered.length;
    }
    return filtered.fold<int>(
        0, (int total, ArchiveEntry entry) => total + entry.amount);
  }

  List<int> monthlyCounts(int year, ArchiveKind kind) {
    final List<int> result = List<int>.filled(12, 0);
    for (final ArchiveEntry entry in entries.where((ArchiveEntry entry) {
      return entry.kind == kind && entry.date.year == year;
    })) {
      result[entry.date.month - 1] +=
          kind == ArchiveKind.place ? 1 : entry.amount;
    }
    return result;
  }

  Map<String, int> categoryCounts(ArchiveKind kind, {int? year}) {
    final Map<String, int> result = <String, int>{};
    for (final ArchiveEntry entry in entries.where((ArchiveEntry entry) {
      return entry.kind == kind && (year == null || entry.date.year == year);
    })) {
      result[entry.category] = (result[entry.category] ?? 0) +
          (kind == ArchiveKind.place ? 1 : entry.amount);
    }
    return result;
  }

  int get currentYear => DateTime.now().year;

  int get latestBookFilmYear {
    final Iterable<ArchiveEntry> bookFilmEntries = entries.where(
        (ArchiveEntry entry) =>
            entry.kind != ArchiveKind.place && entry.date.year <= currentYear);
    if (bookFilmEntries.isEmpty) {
      return currentYear;
    }
    return bookFilmEntries.fold<int>(currentYear,
        (int latest, ArchiveEntry entry) {
      return entry.date.year > latest ? entry.date.year : latest;
    });
  }

  List<int> availableYearsFor(Iterable<ArchiveKind> kinds) {
    final Set<int> years = <int>{currentYear};
    for (final ArchiveEntry entry in entries) {
      if (kinds.contains(entry.kind) && entry.date.year <= currentYear) {
        years.add(entry.date.year);
      }
    }
    final List<int> sorted = years.toList(growable: false)
      ..sort((int a, int b) => b.compareTo(a));
    return sorted;
  }

  List<int> primaryBookFilmYears() {
    return List<int>.generate(4, (int index) => currentYear - index);
  }

  List<int> earlierBookFilmYears() {
    final Set<int> primary = primaryBookFilmYears().toSet();
    return availableYearsFor(<ArchiveKind>{ArchiveKind.book, ArchiveKind.film})
        .where((int year) => !primary.contains(year))
        .toList(growable: false);
  }

  List<YearStatPoint> yearlySeries(ArchiveKind kind) {
    final int latest = latestBookFilmYear;
    final int oldestVisible = (latest - 5).clamp(2021, latest).toInt();
    final List<int> years = <int>[];
    for (int year = latest; year >= oldestVisible; year -= 1) {
      years.add(year);
    }
    final List<YearStatPoint> points = years.map((int year) {
      return YearStatPoint(
        label: '$year',
        value: _yearCount(kind, year),
      );
    }).toList(growable: true);
    final int earlierTotal = entries
        .where((ArchiveEntry entry) =>
            entry.kind == kind && entry.date.year < oldestVisible)
        .fold<int>(0, (int total, ArchiveEntry entry) => total + entry.amount);
    if (earlierTotal > 0 || oldestVisible > 2021) {
      points.add(YearStatPoint(label: '更早', value: earlierTotal));
    }
    return points;
  }

  int _yearCount(ArchiveKind kind, int year) {
    return entries
        .where((ArchiveEntry entry) =>
            entry.kind == kind && entry.date.year == year)
        .fold<int>(
            0,
            (int total, ArchiveEntry entry) =>
                total + (kind == ArchiveKind.place ? 1 : entry.amount));
  }

  Map<String, int> provinceCounts() {
    final Map<String, int> result = <String, int>{};
    for (final ArchiveEntry entry in entries
        .where((ArchiveEntry entry) => entry.kind == ArchiveKind.place)) {
      final String? province = entry.province;
      if (province == null || province.isEmpty) {
        continue;
      }
      result[province] = (result[province] ?? 0) + 1;
    }
    return result;
  }

  Map<String, int> cityCounts() {
    final Map<String, int> result = <String, int>{};
    for (final ArchiveEntry entry in entries
        .where((ArchiveEntry entry) => entry.kind == ArchiveKind.place)) {
      final String? city = entry.city;
      if (city == null || city.isEmpty) {
        continue;
      }
      result[city] = (result[city] ?? 0) + 1;
    }
    return result;
  }

  Map<String, dynamic> _snapshot() {
    return <String, dynamic>{
      'schema': 'guitu.archive.v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'userName': userName,
      'darkMode': darkMode,
      'avatarIndex': avatarIndex,
      'entries': entries
          .map((ArchiveEntry entry) => entry.toJson())
          .toList(growable: false),
    };
  }

  void _applySnapshot(String raw, {required bool fallbackToSeed}) {
    try {
      final Object? decoded = jsonDecode(raw);
      final Map<String, dynamic> json;
      if (decoded is List<dynamic>) {
        json = <String, dynamic>{'entries': decoded};
      } else {
        json = Map<String, dynamic>.from(decoded as Map<dynamic, dynamic>);
      }

      userName = (json['userName'] as String?)?.trim().isNotEmpty == true
          ? json['userName'] as String
          : '我的归途';
      darkMode = (json['darkMode'] as bool?) ?? false;
      avatarIndex =
          ((json['avatarIndex'] as num?)?.round() ?? 0).clamp(0, 3).toInt();
      entries = ((json['entries'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> value) =>
              ArchiveEntry.fromJson(Map<String, dynamic>.from(value)))
          .toList(growable: false);
      if (entries.isEmpty && fallbackToSeed) {
        entries = <ArchiveEntry>[];
      }
    } catch (_) {
      if (!fallbackToSeed) {
        rethrow;
      }
      userName = '我的归途';
      darkMode = false;
      avatarIndex = 0;
      entries = <ArchiveEntry>[];
    }
  }

  Future<void> _persist() async {
    await _storage.writeSnapshot(exportJson());
  }
}

class YearStatPoint {
  const YearStatPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;
}

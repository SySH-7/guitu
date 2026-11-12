import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitu/models/app_data.dart';
import 'package:guitu/services/ai_insights.dart';

ArchiveEntry entry(ArchiveKind kind, DateTime date, {int amount = 1}) =>
    ArchiveEntry(
      id: '${kind.name}-${date.toIso8601String()}',
      kind: kind,
      title: '记录',
      category: '其他',
      date: date,
      rating: 4,
      amount: amount,
      createdAt: date,
    );

void main() {
  test(
    'recent windows are adjacent, inclusive of today and exclude future dates',
    () {
      final today = DateTime(2026, 11, 11);
      final end = today.add(const Duration(days: 1));
      final data = AiInsights([
        entry(ArchiveKind.book, today, amount: 2),
        entry(ArchiveKind.film, end.subtract(const Duration(days: 30))),
        entry(ArchiveKind.book, end.subtract(const Duration(days: 31))),
        entry(ArchiveKind.film, end.subtract(const Duration(days: 60))),
        entry(ArchiveKind.book, end.subtract(const Duration(days: 61))),
        entry(ArchiveKind.book, end),
        entry(ArchiveKind.place, today),
      ], now: today);
      expect(data.count(data.recentMonth, ArchiveKind.book), 2);
      expect(data.count(data.recentMonth, ArchiveKind.film), 1);
      expect(data.count(data.previousMonth, ArchiveKind.book), 1);
      expect(data.count(data.previousMonth, ArchiveKind.film), 1);
      expect(data.count(data.recentMonth, ArchiveKind.place), 1);
    },
  );

  test('calendar windows include complete days across daylight saving changes',
      () {
    final data = AiInsights([
      entry(ArchiveKind.book, DateTime(2026, 2, 19)),
      entry(ArchiveKind.film, DateTime(2026, 2, 18)),
    ], now: DateTime(2026, 3, 20));
    expect(data.count(data.recentMonth, ArchiveKind.book), 1);
    expect(data.count(data.previousMonth, ArchiveKind.film), 1);
  });

  test('annual statistics include all categories and preserve quantities', () {
    final data = AiInsights([
      entry(ArchiveKind.book, DateTime(2025, 1, 1), amount: 3),
      entry(ArchiveKind.film, DateTime(2026, 2, 1)),
      entry(ArchiveKind.place, DateTime(2024, 1, 1)),
    ], now: DateTime(2026, 11, 11));
    expect(data.years, [2026, 2025, 2024]);
    expect(data.count(data.forYear(2025), ArchiveKind.book), 3);
    expect(data.forYear(null).length, 3);
    expect(data.count(data.forYear(2024), ArchiveKind.place), 1);
  });

  test(
      'recommendation draws in proportion to 90-day counts and ignores older records',
      () {
    final now = DateTime(2026, 11, 11);
    final data = AiInsights([
      entry(ArchiveKind.book, now, amount: 3),
      entry(ArchiveKind.film, now, amount: 1),
      entry(ArchiveKind.place, now.subtract(const Duration(days: 90))),
    ], now: now);
    final random = Random(17);
    final draws = List.generate(
      10000,
      (_) => data.chooseRecommendationKind(random: random),
    );
    final books = draws.where((kind) => kind == ArchiveKind.book).length;
    expect(books, inInclusiveRange(7200, 7800));
    expect(draws, isNot(contains(ArchiveKind.place)));
  });
}

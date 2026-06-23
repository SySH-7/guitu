import 'package:archive_journey/services/archive_store.dart';
import 'package:archive_journey/models/app_data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('书影快捷年份始终从系统当年开始', () {
    final ArchiveStore store = ArchiveStore();
    final int currentYear = DateTime.now().year;

    expect(
      store.primaryBookFilmYears(),
      <int>[currentYear, currentYear - 1, currentYear - 2, currentYear - 3],
    );
  });

  test('未来日期记录不会改变默认年度趋势范围', () {
    final ArchiveStore store = ArchiveStore();
    final int currentYear = DateTime.now().year;
    store.entries = <ArchiveEntry>[
      ArchiveEntry(
        id: 'future',
        kind: ArchiveKind.book,
        title: '未来记录',
        category: '其他',
        date: DateTime(currentYear + 9),
        rating: 3,
        amount: 1,
        createdAt: DateTime.now(),
      ),
    ];

    expect(store.latestBookFilmYear, currentYear);
    expect(store.yearlySeries(ArchiveKind.book).first.label, '$currentYear');
  });

  test('取消导出时返回空结果而不是伪造成功文件名', () async {
    const MethodChannel channel = MethodChannel('guitu/storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'exportSnapshot');
      return null;
    });

    final ArchivePlatformStorage storage = ArchivePlatformStorage();
    expect(await storage.exportSnapshot('{}', 'guitu.json'), isNull);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}

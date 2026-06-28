import 'dart:convert';

import 'package:guitu/models/app_data.dart';
import 'package:guitu/services/archive_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel storageChannel = MethodChannel('guitu/storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (MethodCall call) async {
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (MethodCall call) async {
      expect(call.method, 'exportSnapshot');
      return null;
    });

    final ArchivePlatformStorage storage = ArchivePlatformStorage();
    expect(await storage.exportSnapshot('{}', 'guitu.json'), isNull);
  });

  test('文件访问授权状态会解析原生返回', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (MethodCall call) async {
      expect(call.method, 'requestDocumentAccess');
      expect(
        (call.arguments as Map<dynamic, dynamic>)['action'],
        ArchiveDocumentAction.importData.name,
      );
      return <String, Object?>{
        'granted': false,
        'systemDialogShown': true,
        'permanentlyDenied': true,
        'sdkInt': 32,
      };
    });

    final ArchivePlatformStorage storage = ArchivePlatformStorage();
    final DocumentAccessGrant grant = await storage.requestDocumentAccess(
      ArchiveDocumentAction.importData,
    );

    expect(grant.granted, isFalse);
    expect(grant.systemDialogShown, isTrue);
    expect(grant.permanentlyDenied, isTrue);
    expect(grant.sdkInt, 32);
  });

  test('文件访问说明状态通过原生通道持久化', () async {
    final List<String> calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (MethodCall call) async {
      calls.add(call.method);
      if (call.method == 'hasSeenDocumentAccessNotice') {
        expect(
          (call.arguments as Map<dynamic, dynamic>)['action'],
          ArchiveDocumentAction.exportData.name,
        );
        return false;
      }
      if (call.method == 'markDocumentAccessNoticeSeen') {
        expect(
          (call.arguments as Map<dynamic, dynamic>)['action'],
          ArchiveDocumentAction.exportData.name,
        );
      }
      return null;
    });

    final ArchivePlatformStorage storage = ArchivePlatformStorage();

    expect(
      await storage.hasSeenDocumentAccessNotice(
        ArchiveDocumentAction.exportData,
      ),
      isFalse,
    );
    await storage.markDocumentAccessNoticeSeen(
      ArchiveDocumentAction.exportData,
    );
    expect(calls, <String>[
      'hasSeenDocumentAccessNotice',
      'markDocumentAccessNoticeSeen',
    ]);
  });

  test('新增记录会更新 entries 并写入快照', () async {
    final List<String> writes = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (MethodCall call) async {
      if (call.method == 'writeSnapshot') {
        final Map<dynamic, dynamic> arguments =
            call.arguments as Map<dynamic, dynamic>;
        writes.add(arguments['data'] as String);
      }
      return null;
    });

    final ArchiveStore store = ArchiveStore();
    final ArchiveEntry entry = ArchiveEntry(
      id: 'book-1',
      kind: ArchiveKind.book,
      title: '测试书籍',
      category: '文学',
      date: DateTime(2026, 6, 24),
      rating: 5,
      amount: 1,
      creator: '作者',
      createdAt: DateTime(2026, 6, 24),
    );

    await store.addEntry(entry);

    expect(store.entries, hasLength(1));
    expect(store.entries.single.title, '测试书籍');
    expect(writes, hasLength(1));

    final Map<String, dynamic> snapshot =
        jsonDecode(writes.single) as Map<String, dynamic>;
    final List<dynamic> entries = snapshot['entries'] as List<dynamic>;
    expect(snapshot['schema'], 'guitu.archive.v1');
    expect(entries.single, containsPair('title', '测试书籍'));
  });

  test('JSON 导出导入可以还原用户设置和记录', () async {
    final ArchiveStore source = ArchiveStore()
      ..userName = 'SySH'
      ..darkMode = true
      ..avatarIndex = 2
      ..entries = <ArchiveEntry>[
        ArchiveEntry(
          id: 'film-1',
          kind: ArchiveKind.film,
          title: '测试电影',
          category: '剧情',
          date: DateTime(2026, 5, 1),
          rating: 4,
          amount: 1,
          creator: '导演',
          createdAt: DateTime(2026, 5, 1),
        ),
        ArchiveEntry(
          id: 'place-1',
          kind: ArchiveKind.place,
          title: '杭州',
          category: '城市漫游',
          date: DateTime(2026, 6, 1),
          rating: 5,
          amount: 1,
          province: '浙江省',
          city: '杭州市',
          createdAt: DateTime(2026, 6, 1),
        ),
      ];
    final String raw = source.exportJson();
    final Map<String, dynamic> exported =
        jsonDecode(raw) as Map<String, dynamic>;
    final List<dynamic> exportedEntries = exported['entries'] as List<dynamic>;
    final Map<String, dynamic> exportedPlace =
        exportedEntries.last as Map<String, dynamic>;
    expect(exportedPlace, isNot(contains('category')));
    final ArchiveStore restored = ArchiveStore();

    await restored.replaceFromJson(raw);

    expect(restored.userName, 'SySH');
    expect(restored.darkMode, isTrue);
    expect(restored.avatarIndex, 2);
    expect(restored.entries, hasLength(2));
    expect(restored.entries.first.title, '测试电影');
    expect(restored.entries.last.province, '浙江省');
    expect(restored.entries.last.category, '地点');
  });

  test('旧地点 JSON 的类型字段会被兼容读取但不再保留', () {
    final ArchiveEntry place = ArchiveEntry.fromJson(<String, dynamic>{
      'id': 'legacy-place',
      'kind': 'place',
      'title': '旧地点',
      'category': '城市漫步',
      'date': '2026-06-01T00:00:00.000',
      'rating': 4,
      'amount': 1,
      'province': '浙江省',
      'city': '杭州市',
      'createdAt': '2026-06-01T00:00:00.000',
    });

    expect(place.category, '地点');
    expect(place.toJson(), isNot(contains('category')));
  });
}

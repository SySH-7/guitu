import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitu/models/app_data.dart';
import 'package:guitu/services/archive_store.dart';
import 'package:guitu/services/device_entry_service.dart';
import 'package:guitu/services/region_lookup_service.dart';
import 'package:guitu/ui/record_form_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('离线行政区边界可匹配杭州并按首次抵达聚合', () async {
    if (!File('assets/data/china_cities.geojson').existsSync()) {
      return;
    }
    final RegionLookupService lookup = RegionLookupService.instance;
    final RegionMatch? region = await lookup.lookup(
      latitude: 30.2741,
      longitude: 120.1551,
    );

    expect(region, isNotNull);
    expect(region!.province, '浙江省');
    expect(region.city, '杭州市');

    final List<AlbumPhotoMetadata> photos = <AlbumPhotoMetadata>[
      AlbumPhotoMetadata(
        mediaId: '1',
        uri: 'content://media/1',
        latitude: 30.2741,
        longitude: 120.1551,
        takenAt: DateTime(2024, 5, 1, 9),
      ),
      AlbumPhotoMetadata(
        mediaId: '2',
        uri: 'content://media/2',
        latitude: 30.2741,
        longitude: 120.1551,
        takenAt: DateTime(2024, 5, 1, 17),
      ),
      AlbumPhotoMetadata(
        mediaId: '3',
        uri: 'content://media/3',
        latitude: 30.2741,
        longitude: 120.1551,
        takenAt: DateTime(2024, 5, 3, 10),
      ),
    ];
    final List<LocalRegionProgress> progress = <LocalRegionProgress>[];
    final List<TripImportCandidate>? candidates =
        await lookup.organizePhotoVisits(
      photos,
      shouldCancel: () => false,
      onProgress: progress.add,
    );

    expect(candidates, hasLength(1));
    expect(candidates!.single.province, '浙江省');
    expect(candidates.single.city, '杭州市');
    expect(candidates.single.visitCount, 1);
    expect(candidates.single.visitDates.single, DateTime(2024, 5, 1, 9));
    expect(candidates.single.rating, 5);
    expect(progress.last.total, photos.length);
  });

  test('相册到访在七天间隔或中途到过其他地点后才累计', () async {
    if (!File('assets/data/china_cities.geojson').existsSync()) {
      return;
    }
    final List<AlbumPhotoMetadata> photos = <AlbumPhotoMetadata>[
      AlbumPhotoMetadata(
        mediaId: '6',
        uri: 'content://media/6',
        latitude: 30.2741,
        longitude: 120.1551,
        takenAt: DateTime(2024, 5, 14, 9),
      ),
      AlbumPhotoMetadata(
        mediaId: '1',
        uri: 'content://media/1',
        latitude: 30.2741,
        longitude: 120.1551,
        takenAt: DateTime(2024, 5, 1, 9),
      ),
      AlbumPhotoMetadata(
        mediaId: '2',
        uri: 'content://media/2',
        latitude: 30.2741,
        longitude: 120.1551,
        takenAt: DateTime(2024, 5, 3, 10),
      ),
      AlbumPhotoMetadata(
        mediaId: '3',
        uri: 'content://media/3',
        latitude: 29.8683,
        longitude: 121.5440,
        takenAt: DateTime(2024, 5, 4, 12),
      ),
      AlbumPhotoMetadata(
        mediaId: '4',
        uri: 'content://media/4',
        latitude: 30.2741,
        longitude: 120.1551,
        takenAt: DateTime(2024, 5, 5, 9),
      ),
      AlbumPhotoMetadata(
        mediaId: '5',
        uri: 'content://media/5',
        latitude: 30.2741,
        longitude: 120.1551,
        takenAt: DateTime(2024, 5, 6, 9),
      ),
    ];
    final List<TripImportCandidate>? candidates =
        await RegionLookupService.instance.organizePhotoVisits(
      photos,
      shouldCancel: () => false,
      onProgress: (_) {},
    );

    final TripImportCandidate hangzhou = candidates!.firstWhere(
      (TripImportCandidate candidate) => candidate.city == '杭州市',
    );
    expect(hangzhou.visitCount, 3);
    expect(hangzhou.visitDates, <DateTime>[
      DateTime(2024, 5, 1, 9),
      DateTime(2024, 5, 5, 9),
      DateTime(2024, 5, 14, 9),
    ]);
  });

  test('首页地点计数按省市去重，书影计数保持原有数量规则', () {
    final ArchiveStore store = ArchiveStore()
      ..entries = <ArchiveEntry>[
        _placeEntry('1', '浙江省', '杭州', DateTime(2024, 5, 1)),
        _placeEntry('2', '浙江省', '杭州', DateTime(2024, 5, 3)),
        _placeEntry('3', '浙江省', '宁波', DateTime(2024, 5, 4)),
        _bookEntry('4', amount: 2),
      ];

    expect(store.totalFor(ArchiveKind.place), 2);
    expect(store.totalFor(ArchiveKind.book), 2);
  });

  testWidgets('快速 OCR 预填只写入阅读标题字段', (WidgetTester tester) async {
    final ArchiveStore store = ArchiveStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 720,
            child: RecordFormSheet(
              kind: ArchiveKind.book,
              store: store,
              prefill: const RecordFormPrefill(title: '测试作品'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final TextFormField titleField =
        tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(titleField.controller?.text, '测试作品');
  });
}

ArchiveEntry _placeEntry(
  String id,
  String province,
  String city,
  DateTime date,
) {
  return ArchiveEntry(
    id: id,
    kind: ArchiveKind.place,
    title: city,
    category: '地点',
    date: date,
    rating: 5,
    amount: 1,
    province: province,
    city: city,
    createdAt: date,
  );
}

ArchiveEntry _bookEntry(String id, {required int amount}) {
  return ArchiveEntry(
    id: id,
    kind: ArchiveKind.book,
    title: '测试图书',
    category: '小说',
    date: DateTime(2024, 5, 1),
    rating: 4,
    amount: amount,
    createdAt: DateTime(2024, 5, 1),
  );
}

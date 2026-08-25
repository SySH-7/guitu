import 'dart:async';

import 'package:flutter/services.dart';

class DeviceEntryService {
  DeviceEntryService._();

  static final DeviceEntryService instance = DeviceEntryService._();

  static const MethodChannel _channel = MethodChannel('guitu/device_entry');
  static const EventChannel _scanEvents =
      EventChannel('guitu/photo_scan_events');

  Future<LocationSnapshot> currentLocation() async {
    final Map<dynamic, dynamic>? raw =
        await _channel.invokeMapMethod<dynamic, dynamic>('getCurrentLocation');
    if (raw == null) {
      throw PlatformException(
        code: 'LOCATION_UNAVAILABLE',
        message: '未能获取当前位置。',
      );
    }
    return LocationSnapshot.fromPlatform(raw);
  }

  Future<List<String>> recognizeCoverText(String path) async {
    final Map<dynamic, dynamic>? raw =
        await _channel.invokeMapMethod<dynamic, dynamic>(
      'recognizeCoverText',
      <String, Object?>{'path': path},
    );
    final List<dynamic> lines =
        raw?['lines'] as List<dynamic>? ?? const <dynamic>[];
    final String fullText = raw?['text']?.toString() ?? '';
    return <String>[
      if (fullText.isNotEmpty) fullText,
      ...lines.map((dynamic value) => value.toString()),
    ];
  }

  Future<PhotoLibraryPermission> requestPhotoLibraryAccess() async {
    final Map<dynamic, dynamic>? raw = await _channel
        .invokeMapMethod<dynamic, dynamic>('requestPhotoLibraryAccess');
    return PhotoLibraryPermission.fromPlatform(raw);
  }

  Future<AlbumPhotoScan?> scanPhotoLibrary({
    required ValueChanged<AlbumScanProgress> onProgress,
  }) async {
    final Completer<AlbumPhotoScan?> completer = Completer<AlbumPhotoScan?>();
    late final StreamSubscription<dynamic> subscription;
    subscription = _scanEvents.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is! Map<dynamic, dynamic>) {
          return;
        }
        final String type = event['type']?.toString() ?? '';
        if (type == 'progress') {
          onProgress(AlbumScanProgress.fromPlatform(event));
          return;
        }
        if (type == 'complete') {
          if (!completer.isCompleted) {
            completer.complete(AlbumPhotoScan.fromPlatform(event));
          }
          return;
        }
        if (type == 'cancelled') {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          return;
        }
        if (type == 'error' && !completer.isCompleted) {
          completer.completeError(PlatformException(
            code: event['code']?.toString() ?? 'PHOTO_SCAN_FAILED',
            message: event['message']?.toString() ?? '相册扫描失败。',
          ));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );

    try {
      await _channel.invokeMethod<void>('startPhotoScan');
      return await completer.future;
    } catch (_) {
      if (!completer.isCompleted) {
        rethrow;
      }
      return null;
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> cancelPhotoScan() {
    return _channel.invokeMethod<void>('cancelPhotoScan');
  }
}

class LocationSnapshot {
  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;

  factory LocationSnapshot.fromPlatform(Map<dynamic, dynamic> raw) {
    return LocationSnapshot(
      latitude: (raw['latitude'] as num).toDouble(),
      longitude: (raw['longitude'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (raw['timestamp'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

class PhotoLibraryPermission {
  const PhotoLibraryPermission({
    required this.granted,
    required this.limited,
    required this.permanentlyDenied,
    this.sdkInt,
  });

  final bool granted;
  final bool limited;
  final bool permanentlyDenied;
  final int? sdkInt;

  factory PhotoLibraryPermission.fromPlatform(Map<dynamic, dynamic>? raw) {
    return PhotoLibraryPermission(
      granted: raw?['granted'] as bool? ?? false,
      limited: raw?['limited'] as bool? ?? false,
      permanentlyDenied: raw?['permanentlyDenied'] as bool? ?? false,
      sdkInt: (raw?['sdkInt'] as num?)?.round(),
    );
  }
}

class AlbumScanProgress {
  const AlbumScanProgress({
    required this.scanned,
    required this.total,
    required this.stage,
  });

  final int scanned;
  final int total;
  final String stage;

  double get fraction {
    if (total <= 0) {
      return 0;
    }
    return (scanned / total).clamp(0, 1);
  }

  int get percent => (fraction * 100).round();

  factory AlbumScanProgress.fromPlatform(Map<dynamic, dynamic> raw) {
    return AlbumScanProgress(
      scanned: (raw['scanned'] as num?)?.round() ?? 0,
      total: (raw['total'] as num?)?.round() ?? 0,
      stage: raw['stage']?.toString() ?? 'reading',
    );
  }
}

class AlbumPhotoScan {
  const AlbumPhotoScan({
    required this.totalPhotoCount,
    required this.photos,
  });

  final int totalPhotoCount;
  final List<AlbumPhotoMetadata> photos;

  factory AlbumPhotoScan.fromPlatform(Map<dynamic, dynamic> raw) {
    final List<dynamic> records =
        raw['photos'] as List<dynamic>? ?? const <dynamic>[];
    return AlbumPhotoScan(
      totalPhotoCount: (raw['total'] as num?)?.round() ?? 0,
      photos: records
          .whereType<Map<dynamic, dynamic>>()
          .map(AlbumPhotoMetadata.fromPlatform)
          .toList(growable: false),
    );
  }
}

class AlbumPhotoMetadata {
  const AlbumPhotoMetadata({
    required this.mediaId,
    required this.uri,
    required this.latitude,
    required this.longitude,
    required this.takenAt,
  });

  final String mediaId;
  final String uri;
  final double latitude;
  final double longitude;
  final DateTime takenAt;

  factory AlbumPhotoMetadata.fromPlatform(Map<dynamic, dynamic> raw) {
    return AlbumPhotoMetadata(
      mediaId: raw['id']?.toString() ?? '',
      uri: raw['uri']?.toString() ?? '',
      latitude: (raw['latitude'] as num).toDouble(),
      longitude: (raw['longitude'] as num).toDouble(),
      takenAt: DateTime.fromMillisecondsSinceEpoch(
        (raw['takenAt'] as num).toInt(),
      ),
    );
  }
}

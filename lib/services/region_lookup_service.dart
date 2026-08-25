import 'dart:ui';

import 'package:flutter/foundation.dart';
import '../models/app_data.dart';
import '../ui/map_painter.dart';
import 'device_entry_service.dart';

class RegionLookupService {
  RegionLookupService._();

  static final RegionLookupService instance = RegionLookupService._();

  late final Future<_RegionIndex> _indexFuture = _loadIndex();

  Future<RegionMatch?> lookup({
    required double latitude,
    required double longitude,
  }) async {
    final _RegionIndex index = await _indexFuture;
    return index.lookup(latitude: latitude, longitude: longitude);
  }

  Future<List<TripImportCandidate>?> organizePhotoVisits(
    List<AlbumPhotoMetadata> photos, {
    required ValueChanged<LocalRegionProgress> onProgress,
    required bool Function() shouldCancel,
  }) async {
    final _RegionIndex index = await _indexFuture;
    final Map<String, _VisitAggregation> groups = <String, _VisitAggregation>{};
    final List<_MatchedPhoto> matchedPhotos = <_MatchedPhoto>[];

    for (int indexOfPhoto = 0;
        indexOfPhoto < photos.length;
        indexOfPhoto += 1) {
      if (shouldCancel()) {
        return null;
      }
      final AlbumPhotoMetadata photo = photos[indexOfPhoto];
      final RegionMatch? match = index.lookup(
        latitude: photo.latitude,
        longitude: photo.longitude,
      );
      if (match != null) {
        matchedPhotos.add(_MatchedPhoto(match: match, takenAt: photo.takenAt));
      }
      if (indexOfPhoto == photos.length - 1 || indexOfPhoto % 24 == 0) {
        onProgress(LocalRegionProgress(
          processed: indexOfPhoto + 1,
          total: photos.length,
          stage: 'organizing',
        ));
        await Future<void>.delayed(Duration.zero);
      }
    }

    // MediaStore normally returns newest-first. Visit detection needs the
    // actual travel sequence: a later return is only a new visit after a
    // seven-day gap or after photos show another province/city in between.
    matchedPhotos.sort((
      _MatchedPhoto a,
      _MatchedPhoto b,
    ) =>
        a.takenAt.compareTo(b.takenAt));
    String? previousLocationKey;
    int locationSegment = 0;
    for (final _MatchedPhoto photo in matchedPhotos) {
      final String key = '${photo.match.province}\u0000${photo.match.city}';
      if (key != previousLocationKey) {
        locationSegment += 1;
        previousLocationKey = key;
      }
      final _VisitAggregation aggregation = groups.putIfAbsent(
        key,
        () => _VisitAggregation(photo.match),
      );
      aggregation.add(photo.takenAt, locationSegment);
    }

    final List<TripImportCandidate> result = groups.values
        .map((_VisitAggregation value) => value.toCandidate())
        .toList(growable: false)
      ..sort((TripImportCandidate a, TripImportCandidate b) =>
          b.latestDate.compareTo(a.latestDate));
    return result;
  }

  Future<_RegionIndex> _loadIndex() async {
    final List<GeoChinaData> data = await Future.wait(<Future<GeoChinaData>>[
      preloadChinaGeoData(assetPath: chinaCityGeoJsonAsset),
      preloadChinaGeoData(assetPath: chinaProvinceGeoJsonAsset),
    ]);
    final Map<String, String> provinceByCity = <String, String>{
      for (final MapEntry<String, List<String>> entry in chinaCities.entries)
        for (final String city in entry.value) city: entry.key,
    };
    return _RegionIndex(
      cityBoundaries: _boundariesFor(data.first.provinces),
      provinceBoundaries: _boundariesFor(data.last.provinces),
      provinceByCity: provinceByCity,
    );
  }
}

class RegionMatch {
  const RegionMatch({required this.province, required this.city});

  final String province;
  final String city;
}

class LocalRegionProgress {
  const LocalRegionProgress({
    required this.processed,
    required this.total,
    required this.stage,
  });

  final int processed;
  final int total;
  final String stage;

  double get fraction {
    if (total <= 0) {
      return 0;
    }
    return (processed / total).clamp(0, 1);
  }

  int get percent => (fraction * 100).round();
}

class TripImportCandidate {
  const TripImportCandidate({
    required this.province,
    required this.city,
    required this.visitDates,
    this.rating = 5,
    this.selected = true,
  });

  final String province;
  final String city;
  final List<DateTime> visitDates;
  final int rating;
  final bool selected;

  int get visitCount => visitDates.length;
  DateTime get earliestDate => visitDates.first;
  DateTime get latestDate => visitDates.last;

  TripImportCandidate copyWith({
    String? province,
    String? city,
    List<DateTime>? visitDates,
    int? rating,
    bool? selected,
  }) {
    return TripImportCandidate(
      province: province ?? this.province,
      city: city ?? this.city,
      visitDates: visitDates ?? this.visitDates,
      rating: rating ?? this.rating,
      selected: selected ?? this.selected,
    );
  }
}

class _MatchedPhoto {
  const _MatchedPhoto({required this.match, required this.takenAt});

  final RegionMatch match;
  final DateTime takenAt;
}

class _VisitAggregation {
  _VisitAggregation(this.match);

  final RegionMatch match;
  final List<DateTime> _visitStarts = <DateTime>[];
  DateTime? _lastSeenAt;
  int? _lastLocationSegment;

  void add(DateTime value, int locationSegment) {
    final DateTime? lastSeenAt = _lastSeenAt;
    final int? lastLocationSegment = _lastLocationSegment;
    final bool isFirstArrival = lastSeenAt == null;
    final bool hasSevenDayGap = lastSeenAt != null &&
        !value.isBefore(lastSeenAt.add(const Duration(days: 7)));
    final bool visitedAnotherLocationInBetween =
        lastLocationSegment != null && locationSegment != lastLocationSegment;
    if (isFirstArrival || hasSevenDayGap || visitedAnotherLocationInBetween) {
      _visitStarts.add(value);
    }
    _lastSeenAt = value;
    _lastLocationSegment = locationSegment;
  }

  TripImportCandidate toCandidate() {
    final List<DateTime> dates = List<DateTime>.from(_visitStarts)..sort();
    return TripImportCandidate(
      province: match.province,
      city: match.city,
      visitDates: dates,
    );
  }
}

class _RegionIndex {
  const _RegionIndex({
    required this.cityBoundaries,
    required this.provinceBoundaries,
    required this.provinceByCity,
  });

  final List<_RegionBoundary> cityBoundaries;
  final List<_RegionBoundary> provinceBoundaries;
  final Map<String, String> provinceByCity;

  RegionMatch? lookup({
    required double latitude,
    required double longitude,
  }) {
    final String? city = _lookupName(cityBoundaries, latitude, longitude);
    if (city != null) {
      final String? province =
          provinceByCity[city] ?? (chinaCities.containsKey(city) ? city : null);
      if (province != null && chinaCities[province]?.contains(city) == true) {
        return RegionMatch(province: province, city: city);
      }
    }

    final String? province =
        _lookupName(provinceBoundaries, latitude, longitude);
    if (province == null) {
      return null;
    }
    final List<String>? cities = chinaCities[province];
    if (cities != null && cities.contains(province)) {
      return RegionMatch(province: province, city: province);
    }
    return null;
  }

  String? _lookupName(
    List<_RegionBoundary> boundaries,
    double latitude,
    double longitude,
  ) {
    for (final _RegionBoundary boundary in boundaries) {
      if (boundary.contains(latitude: latitude, longitude: longitude)) {
        return boundary.name;
      }
    }
    return null;
  }
}

List<_RegionBoundary> _boundariesFor(List<GeoProvince> provinces) {
  return provinces
      .map(_RegionBoundary.fromGeoProvince)
      .where((_RegionBoundary boundary) => boundary.isValid)
      .toList(growable: false);
}

class _RegionBoundary {
  const _RegionBoundary({
    required this.name,
    required this.polygons,
    required this.minLongitude,
    required this.maxLongitude,
    required this.minLatitude,
    required this.maxLatitude,
  });

  final String name;
  final List<List<List<Offset>>> polygons;
  final double minLongitude;
  final double maxLongitude;
  final double minLatitude;
  final double maxLatitude;

  bool get isValid => name.isNotEmpty && polygons.isNotEmpty;

  factory _RegionBoundary.fromGeoProvince(GeoProvince province) {
    double minLongitude = double.infinity;
    double maxLongitude = -double.infinity;
    double minLatitude = double.infinity;
    double maxLatitude = -double.infinity;
    for (final List<List<Offset>> polygon in province.polygons) {
      for (final List<Offset> ring in polygon) {
        for (final Offset point in ring) {
          minLongitude = minLongitude < point.dx ? minLongitude : point.dx;
          maxLongitude = maxLongitude > point.dx ? maxLongitude : point.dx;
          minLatitude = minLatitude < point.dy ? minLatitude : point.dy;
          maxLatitude = maxLatitude > point.dy ? maxLatitude : point.dy;
        }
      }
    }
    return _RegionBoundary(
      name: province.name,
      polygons: province.polygons,
      minLongitude: minLongitude,
      maxLongitude: maxLongitude,
      minLatitude: minLatitude,
      maxLatitude: maxLatitude,
    );
  }

  bool contains({required double latitude, required double longitude}) {
    if (longitude < minLongitude ||
        longitude > maxLongitude ||
        latitude < minLatitude ||
        latitude > maxLatitude) {
      return false;
    }
    for (final List<List<Offset>> polygon in polygons) {
      if (polygon.isEmpty ||
          !_containsRing(polygon.first, latitude, longitude)) {
        continue;
      }
      final bool inHole = polygon
          .skip(1)
          .any((List<Offset> hole) => _containsRing(hole, latitude, longitude));
      if (!inHole) {
        return true;
      }
    }
    return false;
  }
}

bool _containsRing(List<Offset> ring, double latitude, double longitude) {
  if (ring.length < 3) {
    return false;
  }
  bool inside = false;
  for (int index = 0, previous = ring.length - 1;
      index < ring.length;
      previous = index++) {
    final Offset point = ring[index];
    final Offset previousPoint = ring[previous];
    final bool crossesLatitude =
        (point.dy > latitude) != (previousPoint.dy > latitude);
    if (crossesLatitude) {
      final double intersectLongitude = (previousPoint.dx - point.dx) *
              (latitude - point.dy) /
              (previousPoint.dy - point.dy) +
          point.dx;
      if (longitude < intersectLongitude) {
        inside = !inside;
      }
    }
  }
  return inside;
}

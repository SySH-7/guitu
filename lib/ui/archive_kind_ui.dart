import 'package:flutter/cupertino.dart';

import '../models/app_data.dart';
import 'charts.dart';

extension ArchiveKindUi on ArchiveKind {
  Color get color {
    switch (this) {
      case ArchiveKind.book:
        return archiveOrange;
      case ArchiveKind.film:
        return archiveBlue;
      case ArchiveKind.place:
        return archiveGreen;
    }
  }

  IconData get icon {
    switch (this) {
      case ArchiveKind.book:
        return CupertinoIcons.book_fill;
      case ArchiveKind.film:
        return CupertinoIcons.film_fill;
      case ArchiveKind.place:
        return CupertinoIcons.location_solid;
    }
  }
}

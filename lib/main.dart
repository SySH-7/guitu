import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/app_data.dart';
import 'services/archive_store.dart';
import 'ui/archive_kind_ui.dart';
import 'ui/charts.dart';
import 'ui/map_painter.dart';
import 'ui/record_form_sheet.dart';

part 'shell.dart';
part 'screens/home_screen.dart';
part 'screens/book_film_screen.dart';
part 'screens/travel_screen.dart';
part 'screens/settings_screen.dart';
part 'widgets/common_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GuituApp());
}

class GuituApp extends StatefulWidget {
  const GuituApp({super.key});

  @override
  State<GuituApp> createState() => _GuituAppState();
}

class _GuituAppState extends State<GuituApp> {
  final ArchiveStore _store = ArchiveStore();

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (BuildContext context, _) {
        final bool dark = _store.darkMode;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor:
                dark ? const Color(0xFF111112) : const Color(0xFFFBFCFB),
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness:
                dark ? Brightness.light : Brightness.dark,
          ),
        );
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '归途',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: _store.isLoaded ? ArchiveShell(store: _store) : const _Splash(),
        );
      },
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  final Color surface =
      dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  final Color background =
      dark ? const Color(0xFF111112) : const Color(0xFFF7F8F7);
  final Color text = dark ? const Color(0xFFF2F2F2) : const Color(0xFF111417);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: archiveGreen,
      brightness: brightness,
      surface: surface,
    ),
    textTheme: Typography.blackCupertino.apply(
      bodyColor: text,
      displayColor: text,
      fontFamily: 'PingFang SC',
    ),
    cardColor: surface,
    dividerColor: dark ? const Color(0xFF2C2C2E) : const Color(0xFFE7EBE7),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF242426) : const Color(0xFFF4F6F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
            color: dark ? const Color(0xFF303033) : const Color(0xFFE8ECE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: archiveGreen, width: 1.4),
      ),
    ),
  );
}

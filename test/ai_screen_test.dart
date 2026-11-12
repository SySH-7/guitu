import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitu/screens/ai_screen.dart';
import 'package:guitu/services/archive_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('guitu/ai_config');

  testWidgets(
      'opening and choosing features does not read configuration or send requests',
      (tester) async {
    var reads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'read') reads++;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(MaterialApp(home: AiScreen(store: ArchiveStore())));
    expect(reads, 0);
    await tester.tap(find.text('年度总结').first);
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(find.text('全部年份'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('生成年度总结'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('生成年度总结'));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(find.text('请先在设置中配置 AI API。'), findsOneWidget);
  });
}

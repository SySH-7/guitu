import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guitu/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('归途首页可以启动并展示核心统计', (WidgetTester tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('guitu/storage'),
      (MethodCall call) async {
        if (call.method == 'readSnapshot') {
          return null;
        }
        if (call.method == 'writeSnapshot') {
          return null;
        }
        return null;
      },
    );

    await tester.pumpWidget(const GuituApp());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('归途'), findsWidgets);
    expect(find.text('书籍已读'), findsOneWidget);
    expect(find.text('影视已看'), findsOneWidget);
    expect(find.text('去过地点'), findsOneWidget);
  });
}

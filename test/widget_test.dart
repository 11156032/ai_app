// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_app/main.dart';

void main() {
  testWidgets('App launch smoke test', (WidgetTester tester) async {
    // 1. 建立 App
    await tester.pumpWidget(const MyApp());

    // 2. 關鍵修正：等待所有非同步任務 (如：初始化、導航、動畫) 完成
    // 這會確保 UI 已經穩定顯示在畫面上了
    await tester.pumpAndSettle();

    // 3. 驗證 UI 元素
    // 注意：請確保這些文字在您最新的 UI 版本中依然存在
    expect(find.text('YeBang 家教'), findsOneWidget);
    expect(find.text('以訪客身份直接登入'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:movie_mind_app/main.dart';

void main() {
  testWidgets('MovieMind App should load without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MovieMindApp());

    // 等待一帧，确保 UI 开始构建
    await tester.pump();

    // 验证 App 标题是否存在
    expect(find.text('MovieMind'), findsOneWidget);
    
    // 验证应用能正常渲染（不会崩溃）
    expect(find.byType(MovieMindApp), findsOneWidget);
  });
}

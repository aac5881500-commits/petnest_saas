import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/web/petnest_startup_screen.dart';

void main() {
  testWidgets('等待狀態在手機與桌機都有 Directionality，且不出現紅色錯誤', (
    WidgetTester tester,
  ) async {
    await _expectFrame(
      tester,
      const Size(390, 820),
      const PetNestStartupFrame(
        child: PetNestStartupStatus(
          title: 'PetNest',
          message: '正在準備連線',
        ),
      ),
      '正在準備連線',
    );
    await _expectFrame(
      tester,
      const Size(1200, 900),
      const PetNestStartupFrame(
        child: PetNestStartupStatus(
          title: 'PetNest',
          message: '正在準備連線',
        ),
      ),
      '正在準備連線',
    );
  });

  testWidgets('初始化失敗顯示原因與再試一次，且只按一次', (WidgetTester tester) async {
    var taps = 0;
    await _expectFrame(
      tester,
      const Size(390, 820),
      PetNestStartupFrame(
        child: PetNestStartupStatus(
          title: 'PetNest 暫時無法啟動',
          message: '連線準備沒有完成。可以再試一次，不會清除登入資料。',
          busy: false,
          showRetry: true,
          onRetry: () => taps += 1,
        ),
      ),
      'PetNest 暫時無法啟動',
    );
    expect(find.text('再試一次'), findsOneWidget);
    await tester.tap(find.text('再試一次'));
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('準備完成後換成正式 App，不會留下兩層 MaterialApp', (
    WidgetTester tester,
  ) async {
    await _surface(tester, const Size(1200, 900));
    await tester.pumpWidget(
      const _ReadyGate(ready: false),
    );
    expect(find.text('正在準備連線'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);

    await tester.pumpWidget(
      const _ReadyGate(ready: true),
    );
    await tester.pump();
    expect(find.text('正式 App'), findsOneWidget);
    expect(find.text('正在準備連線'), findsNothing);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ReadyGate extends StatelessWidget {
  const _ReadyGate({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    if (ready) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: Text('正式 App'))),
      );
    }
    return const PetNestStartupFrame(
      child: PetNestStartupStatus(
        title: 'PetNest',
        message: '正在準備連線',
      ),
    );
  }
}

Future<void> _expectFrame(
  WidgetTester tester,
  Size size,
  Widget widget,
  String message,
) async {
  await _surface(tester, size);
  await tester.pumpWidget(widget);
  await tester.pump();
  expect(find.text(message), findsOneWidget);
  expect(find.byType(MaterialApp), findsOneWidget);
  expect(find.byType(Directionality), findsWidgets);
  expect(tester.takeException(), isNull);
}

Future<void> _surface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

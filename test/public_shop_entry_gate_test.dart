import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/platform/widgets/public_shop_entry_gate.dart';

void main() {
  testWidgets(
    'slow selection shows entry immediately and preloads shop, blocking actions',
    (tester) async {
      final ready = Completer<void>();
      var actions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PublicShopEntryGate(
            prepare: () => ready.future,
            shopBuilder: (_) => Scaffold(
              body: TextButton(
                onPressed: () => actions++,
                child: const Text('預約'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('正在進入店家…'), findsOneWidget);
      expect(find.text('預約'), findsOneWidget);
      expect(
        tester
            .widget<AbsorbPointer>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is AbsorbPointer && widget.child is ExcludeFocus,
              ),
            )
            .absorbing,
        isTrue,
      );
      expect(
        tester
            .widget<ExcludeFocus>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is ExcludeFocus && widget.child is ExcludeSemantics,
              ),
            )
            .excluding,
        isTrue,
      );
      ready.complete();
      await tester.pumpAndSettle();
      expect(find.text('正在進入店家…'), findsNothing);
      await tester.tap(find.text('預約'));
      expect(actions, 1);
    },
  );
  testWidgets(
    'failed selection never unlocks the shop, and retry waits for confirmation',
    (tester) async {
      var attempt = 0;
      final retry = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicShopEntryGate(
            prepare: () {
              attempt++;
              return attempt == 1
                  ? Future.error(StateError('offline'))
                  : retry.future;
            },
            shopBuilder: (_) => const Scaffold(body: Text('店家內容')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暫時無法進入店家'), findsOneWidget);
      expect(find.text('店家內容'), findsNothing);
      await tester.tap(find.text('重新載入'));
      await tester.pump();
      expect(attempt, 2);
      expect(find.text('正在進入店家…'), findsOneWidget);
      retry.complete();
      await tester.pumpAndSettle();
      expect(find.text('店家內容'), findsOneWidget);
    },
  );
  testWidgets(
    'leaving while selection is pending handles its late failure safely',
    (tester) async {
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicShopEntryGate(
            prepare: () => pending.future,
            shopBuilder: (_) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: Text('找店')));
      pending.completeError(StateError('late network failure'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('找店'), findsOneWidget);
    },
  );
  testWidgets('loading feedback fits a narrow phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: PublicShopEntryGate(
          prepare: () => pending.future,
          shopBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );
    expect(find.text('返回找店'), findsOneWidget);
    expect(tester.takeException(), isNull);
    pending.complete();
    await tester.pumpAndSettle();
  });
}

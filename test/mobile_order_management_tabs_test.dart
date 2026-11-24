import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/room/pages/room_dashboard_page.dart';

void main() {
  testWidgets('手機四個工作分頁可切換，320 寬不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = OrderManagementView.orders;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            appBar: AppBar(
              bottom: MobileOrderManagementTabs(
                views: const [
                  OrderManagementView.orders,
                  OrderManagementView.today,
                  OrderManagementView.rooms,
                  OrderManagementView.reports,
                ],
                selected: selected,
                onSelected: (value) => setState(() => selected = value),
              ),
            ),
            body: Text(selected.destinationId),
          ),
        ),
      ),
    );
    for (final (label, view) in const [
      ('今日照護', OrderManagementView.today),
      ('房況', OrderManagementView.rooms),
      ('回報', OrderManagementView.reports),
      ('訂單', OrderManagementView.orders),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(selected, view);
      expect(find.text(view.destinationId), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('僅訂單權限不顯示其餘工作分頁', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            bottom: MobileOrderManagementTabs(
              views: const [OrderManagementView.orders],
              selected: OrderManagementView.orders,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('訂單'), findsOneWidget);
    expect(find.text('今日照護'), findsNothing);
    expect(find.text('房況'), findsNothing);
    expect(find.text('回報'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

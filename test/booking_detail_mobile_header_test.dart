import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_tabs.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'booking_detail_customer_workspace_test.dart' as fixture;

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets(
      'mobile header scrolls away and tabs stay reachable at $scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final tabs = TabController(length: 4, vsync: tester);
        final scroll = ScrollController();
        addTearDown(tabs.dispose);
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: BookingDetailMilkTeaScope(
              child: Scaffold(
                appBar: AppBar(title: const Text('住宿詳細')),
                body: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(390, 700),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: BookingDetailTabs(
                    controller: tabs,
                    overviewController: scroll,
                    view: fixture.example(),
                    brand: const SizedBox(
                      height: 104,
                      child: Center(child: Text('本次預約的店家：森林旅館')),
                    ),
                    overview: Column(
                      children: [
                        for (var i = 0; i < 30; i++)
                          SizedBox(height: 56, child: Text('訂單內容 $i')),
                      ],
                    ),
                    guests: const Text('完整入住資料'),
                    services: const Text('照護內容'),
                    payment: const Text('付款與點數'),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('本次預約的店家：森林旅館').hitTestable(), findsOneWidget);
        await tester.drag(find.text('訂單內容 2'), const Offset(0, -420));
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(200));
        expect(find.text('本次預約的店家：森林旅館').hitTestable(), findsNothing);
        expect(find.text('入住資料').hitTestable(), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('總覽').hitTestable()).dy,
          lessThan(125),
        );
        await tester.tap(find.text('入住資料').hitTestable());
        await tester.pumpAndSettle();
        expect(find.text('完整入住資料').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

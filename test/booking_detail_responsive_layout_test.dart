import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';

void main() {
  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('detail layout at $width keeps payment readable and anchors reachable', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final paymentKey = GlobalKey();
      final messageKey = GlobalKey();
      Widget card(String text, {Key? key, double height = 240}) => BookingDetailCard(
        key: key,
        child: SizedBox(height: height, child: Text(text)),
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: BookingDetailResponsiveLayout(paymentIndex: 2, children: [
          card('等待付款'),
          card('入住資料：測試、喵喵'),
          card('費用與付款 NT\$ 1800', key: paymentKey, height: 650),
          const SizedBox.shrink(),
          card('聯絡店家', key: messageKey),
        ]),
      )));
      expect(tester.takeException(), isNull);
      final summary = tester.getTopLeft(find.text('等待付款'));
      final payment = tester.getTopLeft(find.text('費用與付款 NT\$ 1800'));
      if (width >= 960) {
        expect(payment.dx, greaterThan(summary.dx + 300));
        expect(payment.dy, summary.dy);
      } else {
        expect(payment.dy, greaterThan(summary.dy));
        expect(payment.dx, summary.dx);
      }
      await Scrollable.ensureVisible(messageKey.currentContext!);
      await tester.pumpAndSettle();
      expect(find.text('聯絡店家').hitTestable(), findsOneWidget);
      await Scrollable.ensureVisible(paymentKey.currentContext!);
      await tester.pumpAndSettle();
      expect(find.text('費用與付款 NT\$ 1800').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

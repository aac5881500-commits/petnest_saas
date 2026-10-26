import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_business_status_card.dart';

void main() {
  testWidgets('窄版狀態選單可切換暫停接單', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoreBusinessControls(
              entitled: true,
              status: 'open',
              canManage: true,
              saving: false,
              onChanged: (value) => selected = value,
              onContact: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('暫停接單・保留商品瀏覽').last);
    await tester.pumpAndSettle();
    expect(selected, 'paused');
    expect(tester.takeException(), isNull);
  });
  testWidgets('無資格或無權限不能變更營業狀態', (tester) async {
    for (final permitted in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoreBusinessControls(
              entitled: permitted,
              status: 'preparing',
              canManage: !permitted,
              saving: false,
              onChanged: (_) => fail('不能變更狀態'),
              onContact: () {},
            ),
          ),
        ),
      );
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.onChanged, isNull);
    }
  });
}

// 檔案名稱：test/floating_contact_button_size_test.dart
// 功能說明：撥打電話圓鈕固定 52px，點擊與預覽都不會放大。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/floating_contact_button.dart';

void main() {
  testWidgets('390px 撥打電話按鈕維持 52px，預覽點擊不放大', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 844,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const Center(child: Text('熱門房型')),
                FloatingContactButton(
                  shopId: 'shop-1',
                  isPreview: true,
                  shop: <String, dynamic>{
                    'phone': '0912345678',
                    'floatingContactButton': <String, dynamic>{
                      'enabled': true,
                      'type': 'phone',
                      'size': 'large',
                    },
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder button = find.byKey(FloatingContactButton.buttonKey);
    expect(tester.getSize(button), const Size(52, 52));
    expect(
      tester.getRect(button).overlaps(tester.getRect(find.text('熱門房型'))),
      isFalse,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(button);
    await tester.pump();

    expect(find.text('預覽模式不會撥打電話'), findsOneWidget);
    expect(tester.getSize(button), const Size(52, 52));
    expect(find.text('熱門房型'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

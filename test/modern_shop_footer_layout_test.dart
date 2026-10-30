import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_shop_footer.dart';

ModernShopFooter footer({bool full = true}) => ModernShopFooter(
  shopId: '',
  shopName: '貓咪旅店很長的店名也可以完整閱讀',
  shop: full
      ? {
          'phone': '02-12345678',
          'city': '台北市',
          'address': '很長的地址巷弄與樓層資訊',
          'businessHours': '週一至週五 10:00–19:00，例假日採預約制',
          'licenseNumber': '測試字號',
          'taxId': '12345678',
          'showTaxId': false,
          'lineUrl': 'https://line.me/test',
        }
      : {},
  primaryColor: Colors.orange,
  darkTextColor: Colors.black87,
  secondaryTextColor: Colors.black54,
  cardColor: Colors.white,
  borderColor: Colors.black12,
  isPreview: true,
);
void main() {
  testWidgets(
    'narrow large-text panel expands with contact actions and keeps private tax ID hidden',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(children: [ModernShopInfoPanel(footer: footer())]),
          ),
        ),
      );
      expect(find.text('營業時間・地址・聯絡方式'), findsOneWidget);
      await tester.tap(find.text('店家資訊'));
      await tester.pumpAndSettle();
      expect(find.text('開啟地圖'), findsOneWidget);
      expect(find.text('LINE'), findsOneWidget);
      expect(
        find
            .textContaining('12345678')
            .evaluate()
            .any(
              (e) =>
                  e.widget is Text && (e.widget as Text).data!.contains('統一編號'),
            ),
        isFalse,
      );
      await tester.ensureVisible(find.text('撥打電話'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('撥打電話'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'information sheet scrolls on small screens and missing links are omitted',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => footer().showShopInfoSheet(context),
                child: const Text('開啟'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開啟'));
      await tester.pumpAndSettle();
      expect(find.text('營業時間'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [ModernShopInfoPanel(footer: footer(full: false))],
            ),
          ),
        ),
      );
      await tester.tap(find.text('店家資訊'));
      await tester.pumpAndSettle();
      expect(find.text('貓咪旅店很長的店名也可以完整閱讀'), findsOneWidget);
      expect(find.text('撥打電話'), findsNothing);
      expect(find.text('LINE'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

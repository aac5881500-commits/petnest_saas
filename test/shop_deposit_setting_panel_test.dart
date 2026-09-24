// 檔案名稱：test/shop_deposit_setting_panel_test.dart
// 功能說明：收款設定版面寬度、摘要即時更新與儲存按鈕狀態，不連 Firestore。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/shop_deposit_setting_panel.dart';

void main() {
  late TextEditingController valueCtrl;

  setUp(() {
    valueCtrl = TextEditingController(text: '50');
  });

  tearDown(() {
    valueCtrl.dispose();
  });

  Future<void> pumpPanel(
    WidgetTester tester, {
    required Size size,
    bool enabled = true,
    String type = 'percent',
    int value = 50,
    String base = 'total',
    int expireHours = 12,
    bool dirty = true,
    VoidCallback? onSave,
    ValueChanged<int>? onExpire,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    valueCtrl.text = value.toString();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: ShopDepositSettingPanel(
              depositEnabled: enabled,
              depositType: type,
              depositValue: value,
              depositBase: base,
              depositExpireHours: expireHours,
              depositValueController: valueCtrl,
              dirty: dirty,
              saving: false,
              onToggleEnabled: (_) {},
              onExpireHours: onExpire ?? (_) {},
              onDepositBase: (_) {},
              onDepositType: (_) {},
              onDepositValueChanged: (_) {},
              onSave: onSave ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('桌機內容有最大寬度且兩欄同時出現設定與預覽', (WidgetTester tester) async {
    await pumpPanel(tester, size: const Size(1600, 1000));
    expect(find.text('收款設定'), findsWidgets);
    expect(find.text('設定訂金規則與客戶付款期限'), findsOneWidget);
    expect(find.text('已啟用訂金｜總金額 50%｜12 小時內'), findsOneWidget);
    expect(find.text('客戶付款預覽'), findsOneWidget);
    expect(find.text('此為設定示意，實際金額依訂單內容計算'), findsOneWidget);
    expect(find.text('付款期限'), findsWidgets);
    expect(find.text('訂金計算基礎'), findsOneWidget);
    expect(find.text('訂金金額'), findsOneWidget);
    expect(find.byType(RadioListTile<int>), findsNothing);
    final ConstrainedBox shell = tester.widget<ConstrainedBox>(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is ConstrainedBox && widget.constraints.maxWidth == 1160,
      ),
    );
    expect(shell.constraints.maxWidth, 1160);
  });

  testWidgets('手機單欄、選項可點且儲存按鈕可辨識', (WidgetTester tester) async {
    int? expire;
    await pumpPanel(
      tester,
      size: const Size(390, 844),
      dirty: false,
      onExpire: (int value) => expire = value,
    );
    expect(find.text('僅測試'), findsOneWidget);
    expect(find.text('儲存設定'), findsOneWidget);
    final FilledButton save = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('shop-deposit-save')),
    );
    expect(save.onPressed, isNull);
    await tester.ensureVisible(find.text('1 天'));
    await tester.tap(find.text('1 天'));
    expect(expire, 24);
  });

  testWidgets('未啟用訂金時摘要與預覽改為中性說明', (WidgetTester tester) async {
    await pumpPanel(tester, size: const Size(800, 900), enabled: false);
    expect(find.text('未啟用訂金｜客戶將依訂單設定支付全額或免訂金'), findsOneWidget);
    expect(find.textContaining('目前未啟用訂金', skipOffstage: false), findsOneWidget);
  });

  test('金額格式與期限文案', () {
    expect(ShopDepositSettingPanel.ntd(3000), 'NT\$3,000');
    expect(ShopDepositSettingPanel.expireLabel(0), '1 分鐘內');
    expect(ShopDepositSettingPanel.expireLabel(24), '1 天內');
  });
}

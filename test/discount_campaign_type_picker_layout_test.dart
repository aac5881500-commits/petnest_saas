import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/discount_campaign_model.dart';
import 'package:petnest_saas/features/shop/widgets/discount_campaign_type_picker.dart';

void main() {
  const List<String> titles = <String>[
    '新會員優惠',
    '長住優惠',
    '指定服務日期優惠',
    '指定房型／安親方案優惠',
    '滿額優惠',
    '限時下單優惠',
  ];

  Future<void> pumpPicker(
    WidgetTester tester, {
    required Size size,
    required ValueChanged<DiscountCampaignType> onPicked,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: DiscountCampaignTypePickerPage(onPicked: onPicked)),
    );
    await tester.pumpAndSettle();
  }

  double cardHeightOf(WidgetTester tester, String title) {
    final Finder material = find
        .ancestor(of: find.text(title), matching: find.byType(Material))
        .first;
    return tester.getSize(material).height;
  }

  testWidgets('手機寬度使用固定高度雙欄小卡', (WidgetTester tester) async {
    DiscountCampaignType? picked;
    await pumpPicker(
      tester,
      size: const Size(360, 800),
      onPicked: (DiscountCampaignType type) => picked = type,
    );

    for (final String title in titles) {
      expect(find.text(title), findsOneWidget);
      final double height = cardHeightOf(tester, title);
      expect(height, inInclusiveRange(142, 156));
    }
    expect(find.text('選擇 →'), findsNothing);
    expect(find.text('安親不適用'), findsNothing);
    expect(find.text('僅住宿'), findsOneWidget);

    await tester.tap(find.text('長住優惠'));
    await tester.pump();
    expect(picked, DiscountCampaignType.longStay);
  });

  testWidgets('較窄手機與桌機高度變化都不會拉長卡片', (WidgetTester tester) async {
    await pumpPicker(tester, size: const Size(500, 900), onPicked: (_) {});
    expect(cardHeightOf(tester, '滿額優惠'), inInclusiveRange(142, 156));

    await pumpPicker(tester, size: const Size(1200, 900), onPicked: (_) {});
    expect(cardHeightOf(tester, '新會員優惠'), inInclusiveRange(150, 165));

    await pumpPicker(tester, size: const Size(1400, 1600), onPicked: (_) {});
    expect(cardHeightOf(tester, '限時下單優惠'), inInclusiveRange(150, 165));
  });

  testWidgets('六種類型點擊都進入對應表單入口', (WidgetTester tester) async {
    const Map<String, DiscountCampaignType> expected =
        <String, DiscountCampaignType>{
          '新會員優惠': DiscountCampaignType.newMember,
          '長住優惠': DiscountCampaignType.longStay,
          '指定服務日期優惠': DiscountCampaignType.stayDate,
          '指定房型／安親方案優惠': DiscountCampaignType.roomType,
          '滿額優惠': DiscountCampaignType.minimumAmount,
          '限時下單優惠': DiscountCampaignType.limitedTime,
        };
    for (final MapEntry<String, DiscountCampaignType> entry
        in expected.entries) {
      DiscountCampaignType? picked;
      await pumpPicker(
        tester,
        size: const Size(390, 844),
        onPicked: (DiscountCampaignType type) => picked = type,
      );
      await tester.tap(find.text(entry.key));
      await tester.pump();
      expect(picked, entry.value);
    }
  });
}

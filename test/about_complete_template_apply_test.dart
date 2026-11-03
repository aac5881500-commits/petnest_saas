// 功能：整份範本含圖片與文字，確認後才作用於草稿。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:petnest_saas/core/models/about_page_template.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_manage_page.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_intro_view.dart';

void main() {
  test('完整套用與示意使用同一份照片、文字及顯示，其他資料仍保留', () {
    final current = AboutPageSetting.fromMap({
      'team': [
        {'id': 'owner', 'title': '真實店主'},
      ],
      'appearance': {
        'sectionBackgrounds': {'stories': 0xff000000},
        'contactLayout': 'footer',
      },
    });
    final sample = AboutPageTemplate.complete(AboutPageSetting());
    final actual = AboutPageTemplate.complete(current);
    expect(actual.cover.toMap(), sample.cover.toMap());
    expect(
      actual.items('principles').map((e) => e.toMap()),
      sample.items('principles').map((e) => e.toMap()),
    );
    expect(
      actual.items('stories').map((e) => e.toMap()),
      sample.items('stories').map((e) => e.toMap()),
    );
    expect(actual.sectionBackground('stories'), isNull);
    expect(actual.visible('services'), isFalse);
    expect(actual.items('team').single.title, '真實店主');
    expect(
      AboutPageSetting.fromMap(actual.toMap()).cover.assetId,
      'daylight-cover',
    );
  });
  testWidgets('取消不替換，確認含圖片文字，尚未儲存不發布', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final writes = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ShopAboutManagePage(
          shopId: 'local',
          shopStream: Stream<Map<String, dynamic>?>.value(const {
            'name': '我的店',
            'aboutTitle': '原本標題',
            'aboutDescription': '原本簡介',
          }),
          saveAbout: (data) async => writes.add(data),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('版型範本'));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('about-apply-daylight-template'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    AboutIntroView actual() =>
        tester.widgetList<AboutIntroView>(find.byType(AboutIntroView)).first;
    expect(actual().shop['aboutTitle'], '原本標題');
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('套用到草稿'));
    await tester.pumpAndSettle();
    expect(actual().shop['aboutTitle'], AboutPageTemplate.title);
    expect(actual().setting.cover.assetId, 'daylight-cover');
    expect(actual().setting.items('principles'), hasLength(3));
    expect(actual().setting.items('stories'), hasLength(1));
    expect(actual().shop['name'], '我的店');
    expect(writes, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

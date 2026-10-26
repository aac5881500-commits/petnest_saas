import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/room_intro_appearance.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_typography.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_surface.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_list.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_type_detail_content.dart';

void main() {
  test('list and detail fonts round trip independently and survive other appearance changes', () {
    final original = RoomIntroAppearance(
      list: const RoomListAppearance(look: RoomIntroLook(fontFamily: 'NotoSerifTC')),
      detail: const RoomDetailAppearance(look: RoomIntroLook(fontFamily: 'jfOpenHuninn')),
    );
    final restored = RoomIntroAppearance.fromMap(original.toMap());
    expect(restored.list.look.fontFamily, 'NotoSerifTC');
    expect(restored.detail.look.fontFamily, 'jfOpenHuninn');
    expect(restored.list.look.copyWith(textSize: 'large').fontFamily, 'NotoSerifTC');
    expect(RoomIntroLook.fromMap({'fontFamily': 'invalid'}).appliedFontFamily, isNull);
    expect(RoomIntroLook.fromMap(null).fontFamily, '');
  });

  void font(WidgetTester tester, String text, String expected) {
    for (final element in find.text(text).evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      expect(paragraph.text.style?.fontFamily, expected, reason: text);
    }
    expect(find.text(text), findsWidgets);
  }

  testWidgets('entire page theme covers app bar, body, price and buttons; reset follows theme', (tester) async {
    Widget page(RoomIntroLook look) => MaterialApp(theme: ThemeData(fontFamily: 'NotoSansTC'),
      home: RoomIntroTypography(look: look, child: Scaffold(
        appBar: AppBar(title: const Text('頁首')),
        body: const Column(children: <Widget>[Text('內文'), Text('NT\$ 800 / 晚')]),
        bottomNavigationBar: FilledButton(onPressed: () {}, child: const Text('我要預約')),
      )));
    await tester.pumpWidget(page(const RoomIntroLook(fontFamily: 'NotoSerifTC')));
    await tester.pumpAndSettle();
    for (final label in ['頁首', '內文', 'NT\$ 800 / 晚', '我要預約']) {
      font(tester, label, 'NotoSerifTC');
    }
    await tester.pumpWidget(page(const RoomIntroLook()));
    await tester.pumpAndSettle();
    font(tester, '頁首', 'NotoSansTC');
    font(tester, '我要預約', 'NotoSansTC');
  });

  testWidgets('actual list and detail preview apply chosen font to title, price, text and controls', (tester) async {
    final theme = HomeThemeModel.classicDefault;
    const look = RoomIntroLook(fontFamily: 'jfOpenHuninn');
    final room = <String, dynamic>{'id': 'one', 'name': '舒適房', 'price': 800,
      'capacity': 2, 'description': '安靜住宿空間', 'images': <String>[]};
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RoomIntroSurface(
      look: look, theme: theme, child: SingleChildScrollView(child: RoomIntroList(
        rooms: [room], setting: const RoomListAppearance(look: look), theme: theme, onOpen: (_) {},
      )),
    ))));
    await tester.pumpAndSettle();
    font(tester, '房間介紹', 'jfOpenHuninn');
    font(tester, '舒適房', 'jfOpenHuninn');
    font(tester, '查看房型介紹', 'jfOpenHuninn');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RoomTypeDetailContent(
      roomType: room, theme: theme, appearance: const RoomDetailAppearance(look: look),
      showChrome: true, previewOnly: true,
    ))));
    await tester.pumpAndSettle();
    font(tester, '舒適房', 'jfOpenHuninn');
    font(tester, 'NT\$ 800 / 晚', 'jfOpenHuninn');
    font(tester, '我要預約', 'jfOpenHuninn');
    expect(tester.takeException(), isNull);
  });
}

// 檔案名稱：test/shop_room_type_rooms_hub_layout_test.dart
// 功能說明：房型與房間整合畫面在 390／800／1366 的管理與預覽切換。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_live_preview.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_rooms_hub.dart';

void main() {
  final List<Map<String, dynamic>> types = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'rt1',
      'name': 'VIP尊爵房',
      'price': 1800,
      'capacity': 2,
      'totalRooms': 2,
      'extraPrice': 300,
      'description': '寬敞舒適',
      'width': 200,
      'depth': 180,
      'height': 220,
      'features': <String>['camera'],
      'customFeatures': <Map<String, String>>[],
      'images': <String>[],
    },
    <String, dynamic>{
      'id': 'rt2',
      'name': '標準房',
      'price': 900,
      'capacity': 1,
      'totalRooms': 1,
      'extraPrice': 0,
      'description': '安靜',
      'images': <String>[],
    },
  ];
  final List<Map<String, dynamic>> rooms = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'r1',
      'name': 'A1',
      'roomTypeId': 'rt1',
      'enabled': 1,
    },
  ];

  Future<void> pumpHub(WidgetTester tester, {required double width}) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: width,
          height: 900,
          child: ShopRoomTypeRoomsHub(
            key: UniqueKey(),
            shopId: 'shop-test',
            embeddedInSetupCenter: true,
            roomTypesStream: Stream<List<Map<String, dynamic>>>.value(types),
            roomsStream: Stream<List<Map<String, dynamic>>>.value(rooms),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('390 與 800 為管理／前台預覽切換，表單草稿保留', (WidgetTester tester) async {
    for (final double width in <double>[390, 800]) {
      await pumpHub(tester, width: width);
      expect(tester.takeException(), isNull);
      expect(find.text('管理'), findsOneWidget);
      expect(find.text('前台預覽'), findsOneWidget);
      expect(find.text('房型與房間管理'), findsOneWidget);
      expect(find.text('VIP尊爵房'), findsWidgets);
      await tester.tap(find.text('新增房型'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, '房型名稱'), '草稿房型');
      await tester.pump();
      await tester.tap(find.text('前台預覽'));
      await tester.pump();
      expect(find.byType(ShopRoomTypeLivePreview), findsOneWidget);
      expect(find.text('草稿房型'), findsWidgets);
      await tester.tap(find.text('管理'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '房型名稱'))
            .controller
            ?.text,
        '草稿房型',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('1366 左預覽右管理，點選房型更新預覽', (WidgetTester tester) async {
    await pumpHub(tester, width: 1366);
    expect(tester.takeException(), isNull);
    expect(find.byType(ShopRoomTypeLivePreview), findsOneWidget);
    expect(find.text('VIP尊爵房'), findsWidgets);
    expect(find.text('管理'), findsNothing);
    await tester.tap(find.text('標準房').first);
    await tester.pump();
    expect(find.text('標準房'), findsWidgets);
    expect(find.text('安靜'), findsWidgets);
    expect(find.text('我要預約'), findsOneWidget);
  });
}

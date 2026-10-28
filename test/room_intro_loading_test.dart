// 功能說明：房間介紹首次載入逾時、缺店家與讀取錯誤的局部回歸檢查。
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_intro_page.dart';

void main() {
  for (final roomsFirst in [true, false]) {
    testWidgets(roomsFirst ? '房型先到仍保留快照與自訂字體' : '外觀先到仍顯示房型與自訂字體', (
      tester,
    ) async {
      var listens = 0;
      var cancels = 0;
      final shop = StreamController<Map<String, dynamic>?>();
      final rooms = StreamController<List<Map<String, dynamic>>>.broadcast(
        onListen: () {
          listens++;
        },
        onCancel: () {
          cancels++;
        },
      );
      const rows = [
        {'id': 'room1', 'name': '測試房型', 'price': 800},
      ];
      final appearance = {
        'homeAppearance': {
          'roomIntro': {
            'list': {
              'title': '我的房間介紹',
              'layout': 'vertical',
              'look': {'fontFamily': 'ChironSungHK', 'radius': 24},
            },
          },
        },
      };
      await tester.pumpWidget(
        MaterialApp(
          home: ShopRoomIntroPage(
            shopId: 'test',
            theme: HomeThemeModel.modernDefault,
            shopStream: shop.stream,
            roomTypesStream: rooms.stream,
          ),
        ),
      );
      final streamFinder = find.byWidgetPredicate(
        (widget) => widget is StreamBuilder<List<Map<String, dynamic>>>,
      );
      final originalState = tester.state(streamFinder);
      if (roomsFirst) {
        rooms.add(rows);
      } else {
        shop.add(appearance);
      }
      await tester.pump();
      await tester.pump();
      if (roomsFirst) {
        shop.add(appearance);
      } else {
        rooms.add(rows);
      }
      await tester.pump();
      await tester.pump();
      expect(tester.state(streamFinder), same(originalState));
      expect(find.text('測試房型'), findsOneWidget);
      expect(find.text('我的房間介紹'), findsNWidgets(2));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        Theme.of(
          tester.element(find.text('測試房型')),
        ).textTheme.bodyMedium?.fontFamily,
        'ChironSungHK',
      );
      // 後續外觀變更、切回跟隨主題也不能清空已到達的房型資料。
      shop.add({
        'homeAppearance': {
          'roomIntro': {
            'list': {
              'look': {'fontFamily': 'NotoSansTC'},
            },
          },
        },
      });
      await tester.pump();
      await tester.pump();
      expect(tester.state(streamFinder), same(originalState));
      expect(
        Theme.of(
          tester.element(find.text('測試房型')),
        ).textTheme.bodyMedium?.fontFamily,
        'NotoSansTC',
      );
      shop.add({
        'homeAppearance': {
          'roomIntro': {
            'list': {
              'look': {'fontFamily': ''},
            },
          },
        },
      });
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 21));
      expect(tester.state(streamFinder), same(originalState));
      expect(find.text('測試房型'), findsOneWidget);
      expect(find.text('重新載入'), findsNothing);
      expect(listens, 1);
      expect(cancels, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await shop.close();
        await rooms.close();
      });
    });
  }

  testWidgets('未回傳資料不會永久轉圈，晚到資料仍可恢復', (tester) async {
    final shop = StreamController<Map<String, dynamic>?>();
    final rooms = StreamController<List<Map<String, dynamic>>>();
    await tester.pumpWidget(
      MaterialApp(
        home: ShopRoomIntroPage(
          shopId: 'test',
          theme: HomeThemeModel.modernDefault,
          shopStream: shop.stream,
          roomTypesStream: rooms.stream,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('重新載入'), findsOneWidget);
    shop.add({'name': '測試店家'});
    rooms.add([]);
    await tester.pump();
    await tester.pump();
    expect(find.text('重新載入'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await shop.close();
      await rooms.close();
    });
  });
  testWidgets('查無店家與拒絕讀取顯示錯誤，不停在載入', (tester) async {
    for (final source in [
      Stream<Map<String, dynamic>?>.value(null),
      Stream<Map<String, dynamic>?>.error(StateError('permission-denied')),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: ShopRoomIntroPage(
            key: UniqueKey(),
            shopId: 'test',
            theme: HomeThemeModel.modernDefault,
            shopStream: source,
            roomTypesStream: Stream.value([]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('重新載入'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });
}

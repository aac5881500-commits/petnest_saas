import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/platform/widgets/explore_sidebar.dart';

void main() {
  for (final scale in <double>[1, 2]) {
    testWidgets('single member panel scrolls on a short phone at $scale and keeps each action', (tester) async {
      tester.view.physicalSize = const Size(320, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final hits = <String>[];
      await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: Scaffold(body: SizedBox(width: 282, child: ExploreMemberPanel(
          onClose: () => hits.add('close'), onMap: () => hits.add('map'),
          onMyStays: () => hits.add('stays'), onBookings: () => hits.add('bookings'),
          onFavorites: () => hits.add('favorites'), onRecent: () => hits.add('recent'),
          stays: const [], loggedIn: false, onOpenStay: (_) {},
        ))),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final entry in <String, String>{'繼續探索店家': 'close', '地圖找店': 'map', '我的旅店': 'stays', '我的預約': 'bookings', '我的收藏': 'favorites', '最近瀏覽': 'recent'}.entries) {
        await tester.scrollUntilVisible(find.text(entry.key), 100);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(entry.key));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.key));
        expect(hits.last, entry.value);
      }
      await tester.tap(find.byTooltip('關閉會員選單'));
      expect(hits.last, 'close');
      expect(tester.takeException(), isNull);
    });
  }
}

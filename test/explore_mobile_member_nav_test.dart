import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/platform/widgets/explore_mobile_member_nav.dart';

void main() {
  for (final width in <double>[320, 500]) {
    for (final scale in <double>[1, 2]) {
      testWidgets('bottom member nav $width / $scale fits, respects safe area and routes each action', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final hits = <int>[0, 0, 0, 0];
        await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), padding: const EdgeInsets.only(bottom: 24)), child: child!),
          home: Scaffold(body: Column(children: <Widget>[
            const Expanded(child: Center(child: Text('探索內容'))),
            ExploreMobileMemberNav(onMyStays: () => hits[0]++, onBookings: () => hits[1]++,
              onFavorites: () => hits[2]++, onRecent: () => hits[3]++),
          ])),
        ));
        await tester.pumpAndSettle();
        for (final label in ['我的旅店', '預約', '收藏', '最近瀏覽']) {
          final button = find.byKey(ValueKey<String>('explore-nav-$label'));
          expect(button.hitTestable(), findsOneWidget);
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(tester.getRect(button).bottom, lessThanOrEqualTo(820));
          await tester.tap(button);
        }
        expect(hits, [1, 1, 1, 1]);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

// 檔案名稱：test/point_shop_notice_dialog_test.dart
// 功能說明：驗證點數平台公告只看本機已讀狀態，以及手機與桌機 Dialog 不溢出。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/point_notice_acceptance.dart';
import 'package:petnest_saas/core/services/point_platform_notice_store.dart';
import 'package:petnest_saas/features/member/widgets/point_shop_notice_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('本機未讀且點數已啟用才顯示；已讀或換版本 key 才再看', () async {
    expect(
      PointPlatformNotice.seenKey,
      'platform_notice_seen_point_system_independence_v1',
    );
    expect(
      PointPlatformNotice.shouldShow(pointsEnabled: false, seen: false),
      isFalse,
    );
    expect(
      PointPlatformNotice.shouldShow(pointsEnabled: true, seen: false),
      isTrue,
    );
    expect(
      PointPlatformNotice.shouldShow(pointsEnabled: true, seen: true),
      isFalse,
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    expect(await PointPlatformNoticeStore.hasSeen(), isFalse);

    SharedPreferences.setMockInitialValues(<String, Object>{
      PointPlatformNotice.seenKey: false,
    });
    expect(await PointPlatformNoticeStore.hasSeen(), isFalse);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'platform_notice_seen_point_system_independence_v2': true,
    });
    expect(await PointPlatformNoticeStore.hasSeen(), isFalse);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    await PointPlatformNoticeStore.markSeen();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PointPlatformNotice.seenKey), isTrue);
    expect(await PointPlatformNoticeStore.hasSeen(), isTrue);
    expect(prefs.getKeys().contains('shopId'), isFalse);
  });

  testWidgets('手機 390 與桌機平台通知不溢出，確認鈕不是滿版', (WidgetTester tester) async {
    await _pumpNotice(tester, const Size(390, 844), requireAcceptance: true);
    expect(tester.takeException(), isNull);
    expect(find.text('PETNEST NOTICE'), findsOneWidget);
    expect(find.text('PetNest 平台通知'), findsOneWidget);
    expect(find.text('PetNest 的點數制度由各店家獨立營運。'), findsOneWidget);
    expect(find.text('點數僅限原店家使用'), findsOneWidget);
    expect(find.text('無法跨店合併或轉移'), findsOneWidget);
    expect(find.text('各店規則可能不同'), findsOneWidget);
    expect(find.text('實際可用點數與明細，請以您目前查看的店家頁面為準。'), findsOneWidget);
    expect(find.textContaining('專屬點數'), findsNothing);
    expect(find.textContaining('我了解本店'), findsNothing);
    expect(find.textContaining('儲存'), findsNothing);
    expect(find.byTooltip('關閉'), findsNothing);

    final Rect card = tester.getRect(
      find.byKey(const Key('point-platform-notice-card')),
    );
    expect(card.left, greaterThanOrEqualTo(24));
    expect(card.right, lessThanOrEqualTo(366));
    expect(card.width, lessThanOrEqualTo(342));
    expect(card.bottom, lessThanOrEqualTo(844));

    final Size button = tester.getSize(
      find.widgetWithText(FilledButton, '我知道了'),
    );
    expect(button.width, inInclusiveRange(130, 150));
    expect(button.height, inInclusiveRange(40, 42));
    final Rect buttonRect = tester.getRect(
      find.widgetWithText(FilledButton, '我知道了'),
    );
    expect(buttonRect.width, lessThan(card.width - 40));

    await _pumpNotice(tester, const Size(1440, 900), requireAcceptance: false);
    expect(tester.takeException(), isNull);
    expect(find.text('關閉'), findsOneWidget);
    expect(find.byTooltip('關閉'), findsOneWidget);
    expect(find.text('我知道了'), findsNothing);
    final Rect desktop = tester.getRect(
      find.byKey(const Key('point-platform-notice-card')),
    );
    expect(desktop.width, PointPlatformNoticeDialog.desktopWidth);
    expect(desktop.height, lessThan(760));
    expect(PointPlatformNoticeDialog.barrierColor, const Color(0x73000000));
  });
}

Future<void> _pumpNotice(
  WidgetTester tester,
  Size size, {
  required bool requireAcceptance,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PointPlatformNoticeDialog(
          requireAcceptance: requireAcceptance,
          maxHeight: size.height - 48,
          onPrimary: () {},
          onDismiss: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

// 檔案名稱：test/booking_points_display_test.dart
// 功能說明：店家與客戶訂單詳細的點數顯示。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_points_card.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_points_card.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_points_display.dart';

void main() {
  test('舊訂單缺欄位、NaN 不會算出異常點數', () {
    final BookingPointsDisplay missing = BookingPointsDisplay.fromBooking(
      <String, dynamic>{'status': 'pending'},
    );
    expect(missing.pointsUsed, 0);
    expect(missing.systemPoints, 0);
    expect(missing.finalPoints, 0);
    expect(missing.issuedAmount, 0);
    expect(missing.customerVisible, isFalse);

    final BookingPointsDisplay dirty = BookingPointsDisplay.fromBooking(
      <String, dynamic>{
        'pointsUsed': '200',
        'pointAmount': double.nan,
        'rewardPointsSystem': '100',
        'rewardPointsFinal': 120.4,
        'pointsIssuedAmount': true,
      },
    );
    expect(dirty.pointsUsed, 200);
    expect(dirty.discountNtd, 0);
    expect(dirty.systemPoints, 100);
    expect(dirty.finalPoints, 120);
    expect(dirty.issuedAmount, 0);
  });

  test('系統值與調整值相同時不當成有調整', () {
    final BookingPointsDisplay display = BookingPointsDisplay.fromBooking(
      <String, dynamic>{
        'rewardPointsSystem': 100,
        'rewardPointsAdjusted': true,
        'rewardPointsFinal': 100,
      },
    );
    expect(display.showAdjustment, isFalse);
    expect(display.finalPoints, 100);
  });

  testWidgets('CASE 1 使用 200 點會顯示點數與折抵', (WidgetTester tester) async {
    await _pumpAdmin(tester, <String, dynamic>{
      'pointsUsed': 200,
      'pointAmount': 200,
    });
    expect(find.text('使用點數'), findsOneWidget);
    expect(find.text('200 點'), findsOneWidget);
    expect(find.text('折抵金額'), findsOneWidget);
    expect(find.text('NT\$ 200'), findsOneWidget);
  });

  testWidgets('CASE 2 系統 100 尚未發放', (WidgetTester tester) async {
    await _pumpAdmin(tester, <String, dynamic>{
      'rewardPointsSystem': 100,
      'bookingKind': 'accommodation',
    });
    expect(find.text('系統計算'), findsOneWidget);
    expect(find.text('100 點'), findsWidgets);
    expect(find.text('待發放'), findsOneWidget);
    expect(find.text('預計 100 點'), findsOneWidget);
    expect(find.text('已發放'), findsNothing);
  });

  testWidgets('CASE 3 系統 100 調整 120 尚未發放', (WidgetTester tester) async {
    await _pumpAdmin(tester, <String, dynamic>{
      'rewardPointsSystem': 100,
      'rewardPointsAdjusted': true,
      'rewardPointsFinal': 120,
      'rewardPointsAdjustReason': '特殊補償',
      'bookingKind': 'daycare',
    });
    expect(find.text('系統計算'), findsOneWidget);
    expect(find.text('100 點'), findsOneWidget);
    expect(find.text('店家調整'), findsOneWidget);
    expect(find.text('最終點數'), findsOneWidget);
    expect(find.text('120 點'), findsWidgets);
    expect(find.text('+20'), findsOneWidget);
    expect(find.text('調整原因 特殊補償'), findsOneWidget);
    expect(find.text('待發放'), findsOneWidget);
    expect(find.text('預計 120 點'), findsOneWidget);
  });

  testWidgets('CASE 4 最終 120 已發放 120', (WidgetTester tester) async {
    await _pumpAdmin(tester, <String, dynamic>{
      'rewardPointsSystem': 100,
      'rewardPointsAdjusted': true,
      'rewardPointsFinal': 120,
      'pointsIssuedAmount': 120,
      'rewardPointIssuedAt': DateTime.utc(2026, 10, 5, 12, 30),
    });
    expect(find.text('最終點數'), findsOneWidget);
    expect(find.text('已發放'), findsOneWidget);
    expect(find.text('已發放 120 點'), findsOneWidget);
    expect(find.textContaining('2026/10/05 20:30'), findsOneWidget);
  });

  testWidgets('CASE 5 客戶尚未發放只看到預計 120', (WidgetTester tester) async {
    await _pumpCustomer(tester, <String, dynamic>{
      'bookingKind': 'accommodation',
      'rewardPointsSystem': 100,
      'rewardPointsAdjusted': true,
      'rewardPointsFinal': 120,
      'rewardPointsAdjustReason': '特殊補償',
    });
    expect(find.text('點數回饋'), findsOneWidget);
    expect(find.text('完成訂單後預計獲得'), findsOneWidget);
    expect(find.text('120 點'), findsOneWidget);
    expect(find.text('實際回饋點數以訂單完成結算結果為準'), findsOneWidget);
    expect(find.text('待發放'), findsOneWidget);
    expect(find.text('系統計算'), findsNothing);
    expect(find.text('店家調整'), findsNothing);
    expect(find.text('調整原因 特殊補償'), findsNothing);
    expect(find.text('本次獲得'), findsNothing);
  });

  testWidgets('CASE 6 客戶已發放看到本次獲得', (WidgetTester tester) async {
    await _pumpCustomer(tester, <String, dynamic>{
      'bookingKind': 'daycare',
      'pointsIssuedAmount': 120,
      'rewardPointIssuedAt': DateTime.utc(2026, 10, 5, 12, 30),
    });
    expect(find.text('本次獲得'), findsOneWidget);
    expect(find.text('120 點'), findsOneWidget);
    expect(find.text('已發放'), findsOneWidget);
    expect(find.textContaining('2026/10/05 20:30'), findsOneWidget);
    expect(find.text('完成訂單後預計獲得'), findsNothing);
    expect(find.text('系統計算'), findsNothing);
  });

  testWidgets('CASE 7 舊訂單缺少新欄位仍可渲染', (WidgetTester tester) async {
    await _pumpAdmin(tester, <String, dynamic>{
      'customerName': '小花',
      'totalPrice': '1,200',
    });
    expect(find.text('本筆訂單未使用點數制度'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _pumpCustomer(tester, <String, dynamic>{'nights': '三'});
    expect(find.text('點數回饋'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CASE 8 完全沒有點數時客戶端不顯示空卡', (WidgetTester tester) async {
    await _pumpCustomer(tester, <String, dynamic>{
      'bookingKind': 'daycare',
      'status': 'confirmed',
    });
    expect(find.text('點數回饋'), findsNothing);
    expect(find.text('0 點'), findsNothing);
  });

  testWidgets('CASE 9 手動會員顯示不累積點數', (WidgetTester tester) async {
    await _pumpAdmin(tester, <String, dynamic>{
      'isTempAdminMember': true,
      'source': 'admin',
      'rewardPointsSystem': 0,
      'bookingKind': 'accommodation',
    });
    expect(find.text('此會員尚未綁定 App 帳號，不累積會員點數'), findsOneWidget);
    expect(find.text('0 點'), findsNothing);

    await _pumpAdmin(
      tester,
      <String, dynamic>{'bookingKind': 'daycare', 'userId': 'walk-in'},
      member: <String, dynamic>{'source': 'admin'},
    );
    expect(find.text('此會員尚未綁定 App 帳號，不累積會員點數'), findsOneWidget);
  });

  testWidgets('CASE 10 住宿與安親窄螢幕都能渲染', (WidgetTester tester) async {
    await _pumpAdmin(
      tester,
      <String, dynamic>{
        'bookingKind': 'accommodation',
        'pointsUsed': 200,
        'pointsDiscountAmount': 200,
        'rewardPointsSystem': 100,
        'rewardPointsAdjusted': true,
        'rewardPointsFinal': 120,
        'rewardPointsAdjustReason': '特殊補償',
        'pointsIssuedAmount': 120,
      },
      width: 320,
    );
    expect(find.text('點數'), findsOneWidget);
    expect(find.text('使用點數'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpCustomer(
      tester,
      <String, dynamic>{
        'bookingKind': 'daycare',
        'pointsUsed': 40,
        'pointAmount': 40,
        'pointsIssuedAmount': 8,
      },
      width: 320,
    );
    expect(find.text('點數回饋'), findsOneWidget);
    expect(find.text('本次使用'), findsOneWidget);
    expect(find.text('本次獲得'), findsOneWidget);
    expect(find.text('系統計算'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpAdmin(
  WidgetTester tester,
  Map<String, dynamic> booking, {
  Map<String, dynamic>? member,
  double width = 800,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminBookingPointsCard(
          shopId: 'shop-1',
          bookingId: 'booking-1',
          booking: booking,
          member: member,
          lookupMember: false,
        ),
      ),
    ),
  );
}

Future<void> _pumpCustomer(
  WidgetTester tester,
  Map<String, dynamic> booking, {
  double width = 800,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: BookingDetailPointsCard(booking: booking)),
    ),
  );
}

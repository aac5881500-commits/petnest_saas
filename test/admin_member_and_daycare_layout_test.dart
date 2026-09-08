// 檔案名稱：test/admin_member_and_daycare_layout_test.dart
// 功能說明：會員卡／安親寵物卡／舊訂單缺欄位在窄螢幕不 overflow

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/navigation/admin_booking_route.dart';
import 'package:petnest_saas/core/services/daycare_status_labels.dart';
import 'package:petnest_saas/features/admin/pages/admin_daycare_detail_page.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_customer_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_card.dart';

void main() {
  test('從房務、會員、安親列表打開同筆安親訂單都判定為安親詳細頁', () {
    const Map<String, dynamic> booking = <String, dynamic>{
      'bookingKind': 'daycare',
      'shopId': 'shop-a',
    };
    expect(AdminBookingRoute.isDaycareBooking(booking), isTrue);
    expect(
      AdminBookingRoute.page(bookingId: 'b1', data: booking, shopId: 'shop-a')
          is AdminDaycareDetailPage,
      isTrue,
    );
    expect(BookingKind.resolve(booking), BookingKind.daycare);
  });

  testWidgets('會員聯絡與寵物卡 390/500 不 overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                AdminBookingCustomerSection(
                  data: <String, dynamic>{
                    'customerName': '王小明',
                    'customerPhone': '0911111111',
                    'address': '台北市信義區很長的地址測試不要爆版',
                  },
                  emergency: <String, dynamic>{'name': '緊急', 'phone': '0922'},
                ),
                AdminBookingPetCard(
                  pet: <String, dynamic>{
                    'name': '咪',
                    'species': 'cat',
                    'breed': '英短',
                    'isNeutered': false,
                  },
                  shopId: 'shop-a',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(500, 900);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('舊安親訂單欄位缺漏仍能顯示寵物卡', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminBookingPetCard(pet: <String, dynamic>{'petId': 'p1'}),
        ),
      ),
    );
    expect(find.text('未命名寵物'), findsOneWidget);
    expect(DaycareStatusLabels.primary(<String, dynamic>{'status': ''}), '待確認');
  });
}

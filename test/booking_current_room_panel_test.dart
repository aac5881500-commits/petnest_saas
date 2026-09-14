// 檔案名稱：test/booking_current_room_panel_test.dart
// 功能說明：店主／客戶目前安排區塊顯示房型與房號

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/booking_current_room.dart';
import 'package:petnest_saas/features/booking/widgets/booking_current_room_panel.dart';

void main() {
  testWidgets('店員端顯示目前安排與房號 badge', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BookingCurrentRoomPanel(
            data: <String, dynamic>{
              'roomTypeName': '舒適標準房',
              'roomName': 'A1',
              'roomId': 'rid-a1',
            },
            audience: BookingCurrentRoomAudience.staff,
          ),
        ),
      ),
    );
    expect(find.text('目前安排'), findsOneWidget);
    expect(find.text('房型'), findsOneWidget);
    expect(find.text('舒適標準房'), findsOneWidget);
    expect(find.text('實際房間'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
  });

  testWidgets('店員端未分房不顯示假房號', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BookingCurrentRoomPanel(
            data: <String, dynamic>{'roomTypeName': '舒適標準房'},
            audience: BookingCurrentRoomAudience.staff,
          ),
        ),
      ),
    );
    expect(find.text('尚未分配實體房間'), findsOneWidget);
    expect(find.text('---'), findsNothing);
  });

  testWidgets('客戶端資訊條', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BookingCurrentRoomPanel(
            data: <String, dynamic>{
              'roomTypeName': '舒適標準房',
              'roomName': 'A1',
            },
            audience: BookingCurrentRoomAudience.customer,
          ),
        ),
      ),
    );
    expect(find.text('目前房型'), findsOneWidget);
    expect(find.text('店家安排房間'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
  });

  testWidgets('客戶端未分房', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BookingCurrentRoomPanel(
            data: <String, dynamic>{'roomTypeName': '舒適標準房'},
            audience: BookingCurrentRoomAudience.customer,
          ),
        ),
      ),
    );
    expect(find.text('房間將由店家安排'), findsOneWidget);
  });
}

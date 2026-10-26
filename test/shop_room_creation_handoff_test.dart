import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/services/stay_booking_readiness.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_rooms_hub.dart';
import 'package:petnest_saas/features/shop/widgets/room_management_section.dart';
import 'package:petnest_saas/features/shop/widgets/shop_setup_spotlight.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_setup_center_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_settings_page.dart';

class _PublishPolicyResult extends NavigatorObserver {
  _PublishPolicyResult(this.publish);
  final VoidCallback publish;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name != 'opening-stay-policy') return;
    // Simulate only the acknowledged route result; no policy or room writes.
    scheduleMicrotask(() {
      publish();
      navigator!.pop(true);
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async => Firebase.initializeApp());
  Map<String, dynamic> type(String id) => {
    'id': id,
    'name': id,
    'price': 1200,
    'capacity': 2,
    'totalRooms': 10,
  };
  Future<void> saveType(WidgetTester tester, String name) async {
    for (final field in {
      '房型名稱': name,
      '每晚價格': '1200',
      '最多入住數': '2',
      '房間數量／上限': '10',
    }.entries) {
      await tester.enterText(
        find.widgetWithText(TextField, field.key),
        field.value,
      );
    }
    await tester.ensureVisible(find.text('建立房型'));
    await tester.tap(find.text('建立房型'));
    await tester.pumpAndSettle();
  }

  testWidgets('既有店家正常管理不觸發開店完成視窗', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShopRoomTypeRoomsHub(
            shopId: 'fixture',
            guideUserId: 'u',
            embeddedInSetupCenter: true,
            roomTypesStream: Stream.value([type('old')]),
            roomsStream: Stream.value([
              {'id': 'r', 'roomTypeId': 'old', 'enabled': true},
            ]),
            loadTutorialEligibility: () async => false,
            loadReadiness: () async {
              reads++;
              throw StateError('不應由一般管理觸發');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('展開／收合房間'));
    await tester.pumpAndSettle();
    final section = tester.widget<RoomManagementSection>(
      find.byType(RoomManagementSection),
    );
    await section.onRoomCreated!();
    section.onQuickCreateChanged!(true);
    section.onQuickCreateChanged!(false);
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('選擇建立房間的方式'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('設定中心補建房不被 guideStayOpening 強制切回預約', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final roomTypes = [type('t')];
    await tester.pumpWidget(
      MaterialApp(
        home: ShopBookingSetupCenterPage(
          shopId: 'fixture',
          initialTab: ShopBookingSetupTab.rooms,
          guideStayOpening: true,
          loadMember: () async => {'role': 'owner'},
          appBarActions: const [],
          roomTypesStream: Stream.value(roomTypes),
          roomsStream: Stream.value([]),
          shopStream: Stream.value({
            'bookingEnabled': false,
            'maxAdvanceBookingDays': 30,
          }),
          readinessStream: Stream.value(StayBookingReadiness(roomTypes, [])),
          actionLogsStream: Stream.value([]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ShopRoomTypeRoomsHub>(find.byType(ShopRoomTypeRoomsHub))
          .isActive,
      isTrue,
    );
    final hub = tester.widget<ShopRoomTypeRoomsHub>(
      find.byType(ShopRoomTypeRoomsHub),
    );
    await hub.onOpenGuidedBookingSettings!();
    await tester.pumpAndSettle();
    final booking = tester.widget<ShopBookingSettingsPage>(
      find.byType(ShopBookingSettingsPage),
    );
    expect(booking.isActive, isTrue);
    expect(booking.guideStayOpening, isTrue);
    await booking.onManageRooms!();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ShopRoomTypeRoomsHub>(find.byType(ShopRoomTypeRoomsHub))
          .isActive,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('指定最新房型等候串流、解除舊暫停、批次結束及條款重新確認', (tester) async {
    for (final width in [390.0, 1280.0]) {
      await tester.binding.setSurfaceSize(Size(width, 950));
      SharedPreferences.setMockInitialValues({
        'firstRoomTutorialPaused:u:fixture': true,
      });
      final types = StreamController<List<Map<String, dynamic>>>();
      final rooms = StreamController<List<Map<String, dynamic>>>();
      var saved = 0, bookings = 0, confirmations = 0;
      var policy = false;
      var policyFailure = true;
      var actualTypes = [type('old')];
      var actualRooms = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [_PublishPolicyResult(() => policy = true)],
          home: Scaffold(
            body: ShopRoomTypeRoomsHub(
              shopId: 'fixture',
              guideUserId: 'u',
              embeddedInSetupCenter: true,
              roomTypesStream: types.stream,
              roomsStream: rooms.stream,
              loadTutorialEligibility: () async => true,
              loadReadiness: () async {
                confirmations++;
                return StayBookingReadiness(
                  actualTypes,
                  actualRooms,
                  shopId: 'fixture',
                );
              },
              loadStayPolicy: () async {
                if (policyFailure) throw StateError('fixture offline');
                return policy;
              },
              canManagePolicy: true,
              onOpenBookingSettings: () async => bookings++,
              onOpenGuidedBookingSettings: () async => bookings++,
              saveDraft: (_) async => 'new${++saved}',
            ),
          ),
        ),
      );
      types.add(actualTypes);
      rooms.add(actualRooms);
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增房型'));
      await tester.pumpAndSettle();
      await saveType(tester, '第一個新房型');
      expect(find.text('建立此房型的房間'), findsOneWidget);
      expect(find.text('前往預約設定'), findsNothing);
      await tester.tap(find.text('繼續新增房型'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '房型名稱'))
            .controller!
            .text,
        isEmpty,
      );
      await saveType(tester, '第二個新房型');
      await tester.tap(find.text('建立此房型的房間'));
      await tester.pumpAndSettle();
      expect(find.textContaining('正在等候新房型資料'), findsOneWidget);
      expect(find.byType(RoomManagementSection), findsNothing);
      actualTypes = [type('old'), type('new1')];
      types.add(actualTypes);
      await tester.pumpAndSettle();
      expect(find.byType(RoomManagementSection), findsNothing);
      actualTypes = [...actualTypes, type('new2')];
      types.add(actualTypes);
      await tester.pumpAndSettle();
      var section = tester.widget<RoomManagementSection>(
        find.byType(RoomManagementSection),
      );
      expect(section.roomType['id'], 'new2');
      final coach = tester.widget<ShopSetupSpotlight>(
        find.byType(ShopSetupSpotlight),
      );
      expect(coach.target, isNotNull);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'firstRoomTutorialPaused:u:fixture',
        ),
        isFalse,
      );
      expect(find.text('選擇建立房間的方式'), findsOneWidget);
      expect(find.text('新增房間'), findsOneWidget);
      expect(find.text('快速建房'), findsOneWidget);
      types.add(actualTypes.where((t) => t['id'] != 'new2').toList());
      await tester.pumpAndSettle();
      expect(find.textContaining('指定房型狀態已變更'), findsOneWidget);
      expect(find.byType(RoomManagementSection), findsNothing);
      types.add(actualTypes);
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增房間'));
      await tester.pumpAndSettle();
      expect(find.text('填寫房號並確認新增'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('選擇建立房間的方式'), findsOneWidget);
      await section.onRoomCreated!();
      await tester.pumpAndSettle();
      expect(find.text('確認開店下一步'), findsNothing);
      // Simulate only the existing successful-operation callbacks; no real writes.
      actualRooms = [
        {
          'id': 'r',
          'shopId': 'fixture',
          'roomTypeId': 'new2',
          'enabled': false,
        },
      ];
      rooms.add(actualRooms);
      await tester.pumpAndSettle();
      section = tester.widget<RoomManagementSection>(
        find.byType(RoomManagementSection),
      );
      await section.onRoomCreated!();
      await tester.pumpAndSettle();
      expect(find.text('確認開店下一步'), findsNothing);
      Scrollable.of(
        tester.element(find.byType(RoomManagementSection)),
      ).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.textContaining('不需要再新增房間'), findsOneWidget);
      section.onQuickCreateChanged!(true);
      actualRooms = [
        {...actualRooms.first, 'enabled': true},
      ];
      rooms.add(actualRooms);
      await tester.pumpAndSettle();
      final before = confirmations;
      await section.onRoomCreated!();
      expect(confirmations, before);
      expect(find.text('確認開店下一步'), findsNothing);
      section.onQuickCreateChanged!(false);
      await tester.pumpAndSettle();
      expect(find.text('確認開店下一步'), findsNothing);
      final completion = section.onRoomCreated!();
      await tester.pumpAndSettle();
      expect(find.text('重新確認'), findsOneWidget);
      expect(find.text('前往預約設定'), findsNothing);
      policyFailure = false;
      await tester.tap(find.text('重新確認'));
      await tester.pumpAndSettle();
      expect(find.text('前往設定入住條款'), findsOneWidget);
      if (width == 390) {
        policy = true; // Changed while the choice was open: must re-check.
        await tester.tap(find.text('前往設定入住條款'));
        await tester.pumpAndSettle();
        expect(find.text('前往預約設定'), findsOneWidget);
        await tester.tap(find.text('前往預約設定'));
        await tester.pumpAndSettle();
      } else {
        // Successful publish result goes directly to the existing guided tab.
        await tester.tap(find.text('前往設定入住條款'));
        await tester.pumpAndSettle();
        expect(find.text('確認開店下一步'), findsNothing);
      }
      await completion;
      expect(bookings, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(types.close());
      unawaited(rooms.close());
    }
    await tester.binding.setSurfaceSize(null);
  });
}

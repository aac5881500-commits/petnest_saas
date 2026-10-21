import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/services/stay_booking_readiness.dart';
import 'package:petnest_saas/core/legal_pet/shop_profile_lock.dart';
import 'package:petnest_saas/features/shop/widgets/shop_opening_progress.dart';
import 'package:petnest_saas/features/shop/widgets/room_enabled_action.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_entry_page.dart';

void main() {
  final types = <Map<String, dynamic>>[
    {'id': 't', 'totalRooms': 99},
  ];
  Map<String, dynamic> room(
    String id, {
    bool enabled = true,
    String status = 'available',
    String type = 't',
  }) => {
    'id': id,
    'roomTypeId': type,
    'enabled': enabled,
    'permanentStatus': status,
  };
  StayBookingReadiness ready() => StayBookingReadiness(types, [room('a')]);

  test('基本資料沿用旗標與舊資料，不要求重填', () {
    expect(isPhoneSetupCompleted({'phoneSetupCompleted': true}), isTrue);
    expect(isAddressSetupCompleted({'addressSetupCompleted': true}), isTrue);
    expect(isPhoneSetupCompleted({'phone': '02-12345678'}), isTrue);
    expect(isAddressSetupCompleted({'address': '台北市測試路1號'}), isTrue);
    expect(isPhoneSetupCompleted({'phone': '  '}), isFalse);
    expect(isAddressSetupCompleted({}), isFalse);
  });

  test('引導依實際房型、房間、永久狀態切換，忽略設定數量與孤立房間', () {
    final noTypes = StayBookingReadiness([], [room('orphan')]);
    expect(noTypes.ready, isFalse);
    expect(noTypes.action, '建立第一個房型');
    final noRooms = StayBookingReadiness(types, [
      room('orphan', type: 'missing'),
    ]);
    expect(noRooms.ready, isFalse);
    expect(noRooms.action, '建立實際房間');
    final disabled = StayBookingReadiness(types, [room('a', enabled: false)]);
    expect(disabled.ready, isFalse);
    expect(disabled.action, '啟用可預約房間');
    for (final status in ['maintenance', 'blocked', 'unavailable']) {
      expect(
        StayBookingReadiness(types, [room('a', status: status)]).ready,
        isFalse,
      );
    }
    expect(
      StayBookingReadiness(types, [
        {'id': 'a', 'roomTypeId': 't', 'status': 'maintenance'},
      ]).ready,
      isFalse,
    );
    expect(
      StayBookingReadiness(types, [
        room('a', enabled: false),
        room('b'),
      ]).usableCount,
      1,
    );
    expect(ready().ready, isTrue);
  });

  test('日期關房、清潔、滿房不影響配置資格', () {
    expect(
      StayBookingReadiness(types, [
        {
          ...room('a'),
          'status': 'cleaning',
          'blockedDates': ['2026-10-19'],
        },
      ]).ready,
      isTrue,
    );
    expect(
      StayBookingReadiness(types, [
        {...room('a'), 'status': 'occupied'},
      ]).ready,
      isTrue,
    );
  });

  test('無效或跨店房型與房間不計入；批次啟用略過永久狀態', () {
    expect(
      StayBookingReadiness(
        [
          {'id': ''},
        ],
        [room('a', type: '')],
      ).ready,
      isFalse,
    );
    expect(
      StayBookingReadiness(
        [
          {'id': 't', 'shopId': 'other'},
        ],
        [room('a')],
        shopId: 's',
      ).ready,
      isFalse,
    );
    expect(
      StayBookingReadiness(types, [
        {...room('a'), 'shopId': 'other'},
      ], shopId: 's').ready,
      isFalse,
    );
    expect(
      StayBookingReadiness.canBatchEnable(room('a', enabled: false)),
      isTrue,
    );
    expect(StayBookingReadiness.canBatchEnable(room('a')), isFalse);
    for (final status in ['maintenance', 'blocked', 'unavailable']) {
      expect(
        StayBookingReadiness.canBatchEnable(
          room('a', enabled: false, status: status),
        ),
        isFalse,
      );
    }
    expect(
      StayBookingReadiness.canBatchEnable({
        'enabled': false,
        'status': 'maintenance',
      }),
      isFalse,
    );
  });

  test('取消最後房間停用不寫入；確認以單次提交關閉住宿', () async {
    var writes = 0;
    var close = false;
    Future<bool> apply(bool confirm) => applyStayRoomChange(
      affectedIds: {'a'},
      load: () async => ready(),
      bookingEnabled: () async => true,
      confirmLast: () async => confirm,
      commit: (value) async {
        writes++;
        close = value;
      },
    );
    expect(await apply(false), isFalse);
    expect(writes, 0);
    expect(await apply(true), isTrue);
    expect(writes, 1);
    expect(close, isTrue);
  });

  test('其他房間仍可售時不關閉；住宿已關閉時不要求再次確認', () async {
    var confirmations = 0;
    final both = StayBookingReadiness(types, [room('a'), room('b')]);
    for (final state in [both, ready()]) {
      await applyStayRoomChange(
        affectedIds: {'a'},
        load: () async => state,
        bookingEnabled: () async => identical(state, both),
        confirmLast: () async {
          confirmations++;
          return true;
        },
        commit: (close) async => expect(close, isFalse),
      );
    }
    expect(confirmations, 0);
  });

  test('確認後重新讀取，並傳遞寫入失敗，不能回報成功', () async {
    var reads = 0;
    final both = StayBookingReadiness(types, [room('a'), room('b')]);
    await applyStayRoomChange(
      affectedIds: {'a'},
      load: () async => ++reads == 1 ? ready() : both,
      bookingEnabled: () async => true,
      confirmLast: () async => true,
      commit: (close) async => expect(close, isFalse),
    );
    expect(reads, 2);
    await expectLater(
      applyStayRoomChange(
        affectedIds: {'a'},
        load: () async => ready(),
        bookingEnabled: () async => true,
        confirmLast: () async => true,
        commit: (_) async => throw StateError('write failed'),
      ),
      throwsStateError,
    );
    var committed = false;
    await expectLater(
      applyStayRoomChange(
        affectedIds: {'a'},
        load: () async => throw StateError('read failed'),
        bookingEnabled: () async => true,
        confirmLast: () async => true,
        commit: (_) async {
          committed = true;
        },
      ),
      throwsStateError,
    );
    expect(committed, isFalse);
  });

  test('住宿無資格不影響安親入口選擇', () {
    expect(
      resolveBookingEntry(
        initialService: BookingEntryInitialService.automatic,
        accommodationOn: false,
        daycareOn: true,
      ),
      BookingEntryDestination.daycare,
    );
    expect(
      resolveBookingEntry(
        initialService: BookingEntryInitialService.accommodation,
        accommodationOn: false,
        daycareOn: true,
      ),
      BookingEntryDestination.paused,
    );
  });

  testWidgets('最後房間實際確認視窗：取消無操作，確認才送出', (tester) async {
    var writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await applyStayRoomChange(
                  affectedIds: {'a'},
                  load: () async => ready(),
                  bookingEnabled: () async => true,
                  confirmLast: () => confirmLastStayRoom(context),
                  commit: (close) async {
                    expect(close, isTrue);
                    writes++;
                  },
                );
              },
              child: const Text('停用'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('停用'));
    await tester.pumpAndSettle();
    expect(find.text('停用後將沒有可預約的住宿房間，住宿預約也會關閉。既有訂單仍會保留，是否繼續？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(find.text('停用'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('繼續'));
    await tester.pumpAndSettle();
    expect(writes, 1);
  });

  testWidgets('基本資料未完成顯示第一階段，完成後同頁切到房型', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final readiness = Stream<StayBookingReadiness>.value(
      StayBookingReadiness([], []),
    );
    Future<void> pump(bool complete) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShopOpeningProgress(
                loadStayPolicy: () async => true,
                shopId: 's',
                userId: 'u',
                readinessStream: readiness,
                shop: {
                  'phoneSetupCompleted': complete,
                  'addressSetupCompleted': complete,
                  'bookingEnabled': false,
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(false);
    expect(find.text('前往完善基本資料'), findsOneWidget);
    expect(find.text('開店準備 · 第 1 步'), findsOneWidget);
    await pump(true);
    expect(find.text('前往完善基本資料'), findsNothing);
    expect(find.text('建立第一個房型'), findsOneWidget);
    expect(find.text('開店準備 · 第 2 步'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('選填收合偏好依使用者與店家分開，重建後仍保留', (tester) async {
    SharedPreferences.setMockInitialValues({'openingOptional:u:s': true});
    Future<void> pump(String user, String shop) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopOpeningProgress(
              loadStayPolicy: () async => true,
              shopId: shop,
              userId: user,
              shop: const {
                'bookingEnabled': true,
                'phoneSetupCompleted': true,
                'addressSetupCompleted': true,
              },
              readinessStream: Stream.value(ready()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump('u', 's');
    expect(find.text('環境介紹'), findsNothing);
    await pump('other', 's');
    expect(find.text('環境介紹'), findsOneWidget);
    await pump('u', 'otherShop');
    expect(find.text('環境介紹'), findsOneWidget);
    await pump('u', 's');
    expect(find.text('環境介紹'), findsNothing);
    await tester.tap(find.text('豐富你的店家介紹（展開）'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await pump('u', 's');
    expect(find.text('環境介紹'), findsOneWidget);
  });

  testWidgets('開店卡監聽切換、讀取錯誤、收合偏好與各寬度無溢出', (tester) async {
    SharedPreferences.setMockInitialValues({});
    for (final width in [320.0, 390.0, 430.0, 768.0, 1280.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      final controller = StreamController<StayBookingReadiness>();
      Future<void> pump({
        bool booking = false,
        String user = 'u',
        String shop = 's',
        bool paid = false,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ShopOpeningProgress(
                  loadStayPolicy: () async => true,
                  key: ValueKey('$width:$user:$shop'),
                  shopId: shop,
                  userId: user,
                  shop: {
                    'bookingEnabled': booking,
                    'phoneSetupCompleted': true,
                    'addressSetupCompleted': true,
                    if (paid) ...{
                      'plan': 'basic',
                      'paidUntil': Timestamp.fromDate(
                        DateTime.now().add(const Duration(days: 30)),
                      ),
                    },
                  },
                  readinessStream: controller.stream,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump();
      expect(find.text('正在確認房型與房間…'), findsOneWidget);
      controller.add(StayBookingReadiness([], []));
      await tester.pumpAndSettle();
      expect(find.text('建立第一個房型'), findsOneWidget);
      controller.add(StayBookingReadiness(types, []));
      await tester.pumpAndSettle();
      expect(find.text('建立實際房間'), findsOneWidget);
      controller.add(StayBookingReadiness(types, [room('a', enabled: false)]));
      await tester.pumpAndSettle();
      expect(find.text('啟用可預約房間'), findsOneWidget);
      controller.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('房型與房間讀取失敗，尚無法確認住宿預約條件'), findsOneWidget);
      expect(find.text('建立第一個房型'), findsNothing);
      controller.add(ready());
      await tester.pumpAndSettle();
      expect(find.text('前往預約設定'), findsOneWidget);
      await pump(booking: true);
      expect(find.text('準備開放住宿預約'), findsNothing);
      expect(find.text('環境介紹'), findsOneWidget);
      expect(find.text('關於我們管理'), findsOneWidget);
      expect(find.text('公告管理'), findsOneWidget);
      expect(find.text('常見問題管理'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '環境介紹'))
            .onPressed,
        isNull,
      );
      await pump(booking: true, paid: true);
      for (final label in ['環境介紹', '關於我們管理', '公告管理', '常見問題管理']) {
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, label),
              )
              .onPressed,
          isNotNull,
        );
      }
      await tester.tap(find.text('稍後再設定'));
      await tester.pumpAndSettle();
      expect(find.text('環境介紹'), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getBool('openingOptional:u:s'),
        isTrue,
      );
      await tester.tap(find.text('豐富你的店家介紹（展開）'));
      await tester.pumpAndSettle();
      expect(find.text('環境介紹'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(controller.close());
      await tester.pump();
    }
    await tester.binding.setSurfaceSize(null);
  });
}

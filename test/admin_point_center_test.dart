// 檔案名稱：test/admin_point_center_test.dart
// 功能說明：點數兌換中心統計與建立兌換商品表單的驗收測試。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/models/member_point_log_model.dart';
import 'package:petnest_saas/core/models/point_redemption_model.dart';
import 'package:petnest_saas/core/models/point_reward_model.dart';
import 'package:petnest_saas/features/admin/pages/admin_point_center_stats.dart';
import 'package:petnest_saas/features/admin/pages/admin_point_reward_form_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_point_reward_list_page.dart';

final DateTime _now = DateTime(2026, 5, 20, 10);

PointRewardModel _reward({
  String id = 'reward-a',
  String name = '洗毛精',
  PointRewardFulfillmentType type = PointRewardFulfillmentType.physicalProduct,
  int pointsCost = 300,
  int exchangedCount = 0,
  int totalExchangeLimit = 0,
  int stockQuantity = 0,
  bool enabled = true,
}) {
  return PointRewardModel(
    id: id,
    shopId: 'shop-1',
    name: name,
    pointsCost: pointsCost,
    couponType: MemberCouponType.fixedAmount,
    applyTarget: MemberCouponApplyTarget.total,
    enabled: enabled,
    createdAt: _now,
    updatedAt: _now,
    fulfillmentType: type,
    stockQuantity: stockQuantity,
    exchangedCount: exchangedCount,
    totalExchangeLimit: totalExchangeLimit,
  );
}

MemberPointLogModel _log({
  required String id,
  required String rewardId,
  required DateTime createdAt,
  int points = -300,
  String userId = 'user-1',
  String redemptionId = '',
  String couponId = '',
}) {
  return MemberPointLogModel(
    id: id,
    shopId: 'shop-1',
    userId: userId,
    type: MemberPointLogType.rewardExchange,
    points: points,
    balanceBefore: 1000,
    balanceAfter: 1000 + points,
    reason: '兌換「洗毛精」',
    operatorUid: 'system',
    createdAt: createdAt,
    rewardId: rewardId,
    redemptionId: redemptionId,
    couponId: couponId,
  );
}

PointRedemptionModel _redemption({
  required String id,
  required PointRedemptionStatus status,
  String rewardId = 'reward-a',
  String memberName = '王小明',
  DateTime? pickedUpAt,
}) {
  return PointRedemptionModel(
    id: id,
    shopId: 'shop-1',
    userId: 'user-1',
    rewardId: rewardId,
    rewardName: '洗毛精',
    pointsCost: 300,
    balanceBefore: 1000,
    balanceAfter: 700,
    status: status,
    pickupCode: 'AB12',
    createdAt: _now,
    updatedAt: _now,
    pickedUpAt: pickedUpAt,
    memberName: memberName,
  );
}

void main() {
  group('點數兌換中心統計', () {
    test('KPI 由真實兌換流水與兌換紀錄計算', () {
      final PointCenterKpi kpi = summarizePointCenterKpi(
        rewards: <PointRewardModel>[
          _reward(),
          _reward(id: 'reward-b', name: '毛巾', enabled: false),
          _reward(
            id: 'reward-c',
            name: '住宿折價券',
            type: PointRewardFulfillmentType.coupon,
          ),
        ],
        exchangeLogs: <MemberPointLogModel>[
          _log(id: 'log-1', rewardId: 'reward-a', createdAt: _now),
          _log(
            id: 'log-2',
            rewardId: 'reward-c',
            createdAt: DateTime(2026, 5, 2),
            points: -500,
          ),
          // 上個月的紀錄不算進本月。
          _log(
            id: 'log-3',
            rewardId: 'reward-a',
            createdAt: DateTime(2026, 4, 28),
            points: -300,
          ),
        ],
        redemptions: <PointRedemptionModel>[
          _redemption(id: 'r-1', status: PointRedemptionStatus.pendingPickup),
          _redemption(id: 'r-2', status: PointRedemptionStatus.pickedUp),
        ],
        now: _now,
      );

      expect(kpi.enabledRewards, 2);
      expect(kpi.monthExchangeCount, 2);
      expect(kpi.pendingPickupCount, 1);
      expect(kpi.monthPointsSpent, 800);
    });

    test('沒有任何紀錄時不會出現除以零', () {
      final PointCenterAnalytics analytics = summarizePointCenterAnalytics(
        rewards: <PointRewardModel>[_reward()],
        exchangeLogs: const <MemberPointLogModel>[],
        redemptions: const <PointRedemptionModel>[],
        now: _now,
      );

      expect(analytics.hasData, isFalse);
      expect(analytics.redemptionTotal, 0);
      expect(analytics.statusShare(0), 0);
      expect(analytics.statusShare(5), 0);
      expect(analytics.topRewards, isEmpty);
      expect(formatPointRate(value: 3, total: 0), '不限');
      expect(pointRewardStockLabel(_reward(stockQuantity: 0)), '不限兌換數量');
    });

    test('已有兌換紀錄的商品即使額滿也不可刪除', () {
      final PointRewardModel full = _reward(
        exchangedCount: 5,
        totalExchangeLimit: 5,
      );

      expect(full.isSoldOut, isTrue);
      expect(canDeletePointReward(full), isFalse);
      expect(pointExchangeLimitLabel(full), '5 / 5');
      expect(canDeletePointReward(_reward()), isTrue);
    });

    test('兌換紀錄顯示會員名稱與交付狀態，不顯示 UID', () {
      final List<PointExchangeRow> rows = buildPointExchangeRows(
        exchangeLogs: <MemberPointLogModel>[
          _log(
            id: 'log-1',
            rewardId: 'reward-a',
            createdAt: _now,
            redemptionId: 'r-1',
          ),
          _log(
            id: 'log-2',
            rewardId: 'reward-c',
            createdAt: _now,
            userId: 'user-2',
            couponId: 'coupon-1',
          ),
        ],
        rewards: <PointRewardModel>[
          _reward(),
          _reward(
            id: 'reward-c',
            name: '住宿折價券',
            type: PointRewardFulfillmentType.coupon,
          ),
        ],
        redemptions: <PointRedemptionModel>[
          _redemption(id: 'r-1', status: PointRedemptionStatus.pendingPickup),
        ],
        memberLabelOf: (String userId) =>
            userId == 'user-2' ? 'member@example.com' : '',
      );

      expect(rows.first.memberLabel, '王小明');
      expect(rows.first.delivery, PointDeliveryState.pendingPickup);
      expect(pointDeliveryLabel(rows.first.delivery), '待領取');
      expect(rows.last.memberLabel, 'member@example.com');
      expect(pointDeliveryLabel(rows.last.delivery), '已發券');
      expect(
        rows.every((PointExchangeRow row) => row.memberLabel != 'user-1'),
        isTrue,
      );

      final List<PointExchangeRow> onlyPhysical = filterPointExchangeRows(
        rows: rows,
        now: _now,
        type: PointRewardTypeFilter.physical,
      );

      expect(onlyPhysical.length, 1);
      expect(onlyPhysical.single.rewardName, '洗毛精');
    });
  });

  group('數位券與實體商品狀態', () {
    test('折價券與免費住宿券顯示已發券，不進待核銷也不帶核銷碼', () {
      final PointRewardModel stayCoupon = _reward(
        id: 'reward-stay',
        name: '免費住宿券',
        type: PointRewardFulfillmentType.coupon,
      ).copyWith(couponType: MemberCouponType.freeStay);
      final PointRewardModel amountCoupon = _reward(
        id: 'reward-off',
        name: '住宿折價券',
        type: PointRewardFulfillmentType.coupon,
      );
      final List<PointExchangeRow> rows = buildPointExchangeRows(
        exchangeLogs: <MemberPointLogModel>[
          _log(
            id: 'coupon-1',
            rewardId: 'reward-stay',
            createdAt: _now,
            couponId: 'member-coupon-1',
          ),
          _log(
            id: 'coupon-2',
            rewardId: 'reward-off',
            createdAt: _now,
            couponId: 'member-coupon-2',
          ),
        ],
        rewards: <PointRewardModel>[stayCoupon, amountCoupon],
        redemptions: const <PointRedemptionModel>[],
        templateNames: const <String, String>{},
      );

      expect(rows, hasLength(2));
      for (final PointExchangeRow row in rows) {
        expect(row.isPhysical, isFalse);
        expect(row.delivery, PointDeliveryState.couponIssued);
        expect(pointExchangeResultLabel(row), '數位優惠券・已發送');
        expect(pointDeliveryLabel(row.delivery), '已發券');
        expect(row.redemption, isNull);
        expect(pointExchangeResultLabel(row).contains('領取碼'), isFalse);
      }
      expect(
        filterPointExchangeRows(
          rows: rows,
          now: _now,
          delivery: PointDeliveryFilter.pendingPickup,
        ),
        isEmpty,
      );

      final PointCenterKpi kpi = summarizePointCenterKpi(
        rewards: <PointRewardModel>[stayCoupon, amountCoupon],
        exchangeLogs: rows.map((PointExchangeRow row) => row.log).toList(),
        redemptions: const <PointRedemptionModel>[],
        now: _now,
      );
      expect(kpi.monthExchangeCount, 2);
      expect(kpi.monthCouponIssued, 2);
      expect(kpi.pendingPickupCount, 0);
    });

    test('實體商品兌換後為待領取，舊資料不需核銷旗標也會待領取', () {
      final PointRewardModel reward = _reward().copyWith(
        requiresStaffVerification: false,
      );
      final PointRedemptionModel legacy = PointRedemptionModel.fromMap(
        id: 'legacy-1',
        data: <String, dynamic>{
          'shopId': 'shop-1',
          'userId': 'user-1',
          'rewardId': 'reward-a',
          'rewardName': '洗毛精',
          'status': 'pendingPickup',
          'pickupCode': 'ZX90',
          'memberName': '王小明',
          'createdAt': _now,
          'updatedAt': _now,
        },
      );
      expect(legacy.status, PointRedemptionStatus.pendingPickup);
      expect(reward.requiresStaffVerification, isFalse);

      final List<PointExchangeRow> rows = buildPointExchangeRows(
        exchangeLogs: <MemberPointLogModel>[
          _log(
            id: 'physical-1',
            rewardId: 'reward-a',
            createdAt: _now,
            redemptionId: 'legacy-1',
          ),
        ],
        rewards: <PointRewardModel>[reward],
        redemptions: <PointRedemptionModel>[legacy],
      );
      expect(rows.single.isPhysical, isTrue);
      expect(rows.single.delivery, PointDeliveryState.pendingPickup);
      expect(pointExchangeResultLabel(rows.single), '待領取');
      expect(
        summarizePointCenterKpi(
          rewards: <PointRewardModel>[reward],
          exchangeLogs: <MemberPointLogModel>[rows.single.log],
          redemptions: <PointRedemptionModel>[legacy],
          now: _now,
        ).pendingPickupCount,
        1,
      );
    });
  });

  group('點數流水', () {
    MemberPointLogModel typed({
      required String id,
      required MemberPointLogType type,
      required int points,
      String reason = '調整原因',
      String operatorUid = 'staff-1',
      String bookingId = '',
      DateTime? createdAt,
    }) {
      return MemberPointLogModel(
        id: id,
        shopId: 'shop-1',
        userId: 'user-1',
        type: type,
        points: points,
        balanceBefore: 100,
        balanceAfter: 100 + points,
        reason: reason,
        operatorUid: operatorUid,
        createdAt: createdAt ?? _now,
        bookingId: bookingId,
      );
    }

    test('本月發放不含退點，兌換扣點只計 rewardExchange', () {
      final List<MemberPointLogModel> logs = <MemberPointLogModel>[
        typed(id: 'earn', type: MemberPointLogType.bookingEarned, points: 80),
        typed(id: 'add', type: MemberPointLogType.manualAdded, points: 20),
        typed(
          id: 'adjust',
          type: MemberPointLogType.bookingAdjusted,
          points: 15,
        ),
        typed(
          id: 'refund',
          type: MemberPointLogType.refunded,
          points: 40,
          reason: '取消訂單退點',
        ),
        typed(id: 'spent', type: MemberPointLogType.bookingSpent, points: -30),
        typed(
          id: 'exchange',
          type: MemberPointLogType.rewardExchange,
          points: -50,
        ),
        typed(
          id: 'deduct',
          type: MemberPointLogType.manualDeducted,
          points: -10,
        ),
      ];
      final PointLedgerKpi kpi = summarizePointLedger(logs: logs, now: _now);
      expect(kpi.monthGranted, 80 + 20 + 15);
      expect(kpi.monthMemberSpent, 30);
      expect(kpi.monthExchangeSpent, 50);
      expect(kpi.manualAdjustLabel, '+35／-10');
    });

    test('手動增加、手動扣除與訂單調整都會出現在流水', () {
      final List<PointLedgerRow> rows = buildPointLedgerRows(
        logs: <MemberPointLogModel>[
          typed(
            id: 'add',
            type: MemberPointLogType.manualAdded,
            points: 20,
            operatorUid: 'staff-1',
          ),
          typed(
            id: 'deduct',
            type: MemberPointLogType.manualDeducted,
            points: -10,
            operatorUid: 'op-2',
          ),
          typed(
            id: 'adjust',
            type: MemberPointLogType.bookingAdjusted,
            points: -5,
            bookingId: 'booking-1',
          ),
        ],
        rewards: const <PointRewardModel>[],
        redemptions: const <PointRedemptionModel>[],
        memberLabelOf: (_) => '王小明',
        operatorLabelOf: (String uid) =>
            uid == 'staff-1' ? 'owner@example.com' : '',
      );
      expect(
        rows.map((PointLedgerRow row) => row.log.type).toSet(),
        <MemberPointLogType>{
          MemberPointLogType.manualAdded,
          MemberPointLogType.manualDeducted,
          MemberPointLogType.bookingAdjusted,
        },
      );
      expect(rows.first.memberLabel, '王小明');
      expect(rows.first.memberLabel.contains('user-1'), isFalse);
      expect(rows.first.operatorLabel, 'owner@example.com');
      expect(rows[1].operatorLabel, '操作者資料已不可用');
      expect(rows[1].operatorLabel.contains('op-2'), isFalse);
      expect(rows.last.opensBooking, isTrue);

      final List<PointLedgerRow> onlyManual = filterPointLedgerRows(
        rows: rows,
        now: _now,
        type: PointLedgerTypeFilter.manualAdded,
      );
      expect(onlyManual.single.log.id, 'add');
    });
  });

  group('建立點數兌換商品表單', () {
    Future<void> pumpForm(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPointRewardFormPage(
            key: ValueKey<Size>(size),
            shopId: 'shop-1',
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('優惠券與實體商品欄位分開顯示', (WidgetTester tester) async {
      await pumpForm(tester, const Size(1440, 1000));

      expect(find.text('優惠券設定'), findsOneWidget);
      expect(find.text('實體商品設定'), findsNothing);

      await tester.tap(find.text('實體商品'));
      await tester.pumpAndSettle();

      expect(find.text('實體商品設定'), findsOneWidget);
      expect(find.text('優惠券設定'), findsNothing);
      expect(find.text('此商品為店內自取；會員到店領取時，由店員完成交付核銷。'), findsOneWidget);
      expect(find.text('需要店員核銷'), findsNothing);
      expect(find.text('到店服務'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('手機與桌機寬度都不會 RenderFlex overflow', (WidgetTester tester) async {
      for (final Size size in <Size>[
        const Size(390, 844),
        const Size(1440, 900),
      ]) {
        await pumpForm(tester, size);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('實體商品'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });

  testWidgets('點數兌換中心桌機與手機切換流水不 overflow', (WidgetTester tester) async {
    for (final Size size in <Size>[
      const Size(390, 844),
      const Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminPointRewardListPage(
            key: ValueKey<Size>(size),
            shopId: 'shop-1',
            initialSection: PointCenterSection.ledger,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('本月發放點數'), findsOneWidget);
      expect(find.text('本月兌換扣點'), findsOneWidget);
      final Finder chipScroll = find.byWidgetPredicate(
        (Widget widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      await tester.drag(chipScroll.first, const Offset(-280, 0));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, '兌換紀錄'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(FilterChip, '點數流水'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}

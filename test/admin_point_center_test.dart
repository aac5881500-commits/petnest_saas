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
      expect(find.text('需要店員核銷'), findsOneWidget);
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
}

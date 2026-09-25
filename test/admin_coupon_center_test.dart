import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/coupon_template_model.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/features/admin/pages/admin_coupon_center_stats.dart';
import 'package:petnest_saas/features/admin/pages/admin_coupon_template_form_page.dart';

void main() {
  final DateTime now = DateTime(2026, 9, 25, 12);

  MemberCouponModel coupon({
    String id = 'c1',
    String name = '春日券',
    String templateId = '',
    String userId = 'member-1',
    MemberCouponStatus status = MemberCouponStatus.available,
    MemberCouponSource source = MemberCouponSource.manual,
    DateTime? createdAt,
    DateTime? expireAt,
    DateTime? usedAt,
    num discountValue = 300,
  }) {
    final DateTime created = createdAt ?? now.subtract(const Duration(days: 3));
    return MemberCouponModel(
      id: id,
      shopId: 'shop-1',
      userId: userId,
      name: name,
      type: MemberCouponType.fixedAmount,
      applyTarget: MemberCouponApplyTarget.total,
      source: source,
      status: status,
      discountValue: discountValue,
      createdAt: created,
      updatedAt: created,
      expireAt: expireAt,
      usedAt: usedAt,
      templateId: templateId,
    );
  }

  CouponTemplateModel template({
    String id = 'tpl-1',
    String name = '春日券',
    bool enabled = true,
  }) {
    return CouponTemplateModel(
      id: id,
      shopId: 'shop-1',
      name: name,
      type: MemberCouponType.fixedAmount,
      applyTarget: MemberCouponApplyTarget.total,
      enabled: enabled,
      discountValue: 300,
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('四種券型只顯示對應欄位', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdminCouponTemplateFormPage(shopId: 'shop-1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('折抵金額 *'), findsOneWidget);
    expect(find.text('僅房價'), findsOneWidget);
    expect(find.text('最低消費金額'), findsOneWidget);
    expect(find.text('不限最低消費'), findsOneWidget);
    expect(find.text('免費住宿晚數 *'), findsNothing);
    expect(find.text('指定免費服務'), findsNothing);

    await tester.tap(find.text('百分比折扣券'));
    await tester.pump();
    expect(find.text('折扣百分比 *'), findsOneWidget);
    expect(find.text('最高折抵金額'), findsOneWidget);
    expect(find.text('不限最高折抵'), findsOneWidget);
    expect(find.text('僅房價'), findsOneWidget);
    expect(find.text('折抵金額 *'), findsNothing);
    expect(find.text('免費住宿晚數 *'), findsNothing);

    await tester.tap(find.text('免費住宿券'));
    await tester.pump();
    expect(find.text('免費住宿晚數 *'), findsOneWidget);
    expect(find.text('全部房型可用'), findsOneWidget);
    expect(find.text('僅房價'), findsNothing);
    expect(find.text('最低消費金額'), findsNothing);
    expect(find.text('指定免費服務'), findsNothing);

    await tester.tap(find.text('免費服務券'));
    await tester.pump();
    expect(find.text('指定免費服務'), findsWidgets);
    expect(find.text('適用範圍固定為指定服務。'), findsOneWidget);
    expect(find.text('全部房型可用'), findsNothing);
    expect(find.text('僅房價'), findsNothing);
    expect(find.text('免費住宿晚數 *'), findsNothing);

    expect(tester.takeException(), isNull, reason: '券型切換後不應溢出');
  });

  test('空資料的使用率不會除以 0', () {
    final CouponCenterSummary summary = summarizeCouponCenter(
      coupons: const <MemberCouponModel>[],
      templates: const <CouponTemplateModel>[],
      now: now,
    );

    expect(summary.issued, 0);
    expect(summary.usable, 0);
    expect(summary.used, 0);
    expect(summary.expired, 0);
    expect(summary.expiringSoon, 0);
    expect(summary.usageRateLabel, '尚無發券紀錄');
    expect(summary.issuedLast30, 0);
    expect(summary.topCoupons, isEmpty);
    expect(formatCouponUsageRate(used: 0, issued: 0), '尚無發券紀錄');
  });

  test('舊券沒有 templateId 仍可依名稱統計', () {
    final MemberCouponModel legacy = MemberCouponModel.fromMap(
      id: 'old-1',
      data: <String, dynamic>{
        'shopId': 'shop-1',
        'userId': 'member-1',
        'name': '春日券',
        'type': 'fixedAmount',
        'applyTarget': 'total',
        'source': 'manual',
        'status': 'available',
        'discountValue': 300,
        'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
        'updatedAt': now.toIso8601String(),
      },
    );
    expect(legacy.templateId, isEmpty);

    final MemberCouponModel used = coupon(
      id: 'old-2',
      status: MemberCouponStatus.used,
      usedAt: now.subtract(const Duration(days: 1)),
    );
    final CouponCenterSummary summary = summarizeCouponCenter(
      coupons: <MemberCouponModel>[legacy, used],
      templates: <CouponTemplateModel>[template()],
      now: now,
    );

    expect(summary.issued, 2);
    expect(summary.usable, 1);
    expect(summary.used, 1);
    expect(summary.topCoupons, hasLength(1));
    expect(summary.topCoupons.single.name, '春日券');
    expect(summary.topCoupons.single.issued, 2);
    expect(summary.topCoupons.single.used, 1);
    expect(summary.templateUsage['tpl-1']?.issued, 2);
    expect(legacy.userId, isNot(contains('顯示')));
  });

  test('模板發券會把 templateId 寫進新會員券', () {
    final CouponTemplateModel source = template(id: 'tpl-9', name: '週末券');
    final MemberCouponModel issued = coupon(
      id: 'new-1',
      name: source.name,
      templateId: issuedTemplateId(source),
    );

    expect(issuedTemplateId(source), 'tpl-9');
    expect(issued.toMap()['templateId'], 'tpl-9');
    expect(issued.copyWith().templateId, 'tpl-9');

    final MemberCouponModel points = coupon(
      id: 'points-1',
      source: MemberCouponSource.pointsExchange,
    );
    expect(points.toMap()['templateId'], isEmpty);
  });

  test('停用模板不會改掉已發出的會員券', () {
    final MemberCouponModel issued = coupon(discountValue: 300);
    final CouponTemplateModel enabledTemplate = template();
    final CouponTemplateModel disabledTemplate = template(enabled: false);

    final CouponCenterSummary before = summarizeCouponCenter(
      coupons: <MemberCouponModel>[issued],
      templates: <CouponTemplateModel>[enabledTemplate],
      now: now,
    );
    final CouponCenterSummary after = summarizeCouponCenter(
      coupons: <MemberCouponModel>[issued],
      templates: <CouponTemplateModel>[disabledTemplate],
      now: now,
    );

    expect(disabledTemplate.enabled, isFalse);
    expect(after.usable, before.usable);
    expect(after.issued, 1);
    expect(after.templateUsage['tpl-1']?.usable, 1);
    expect(issued.status, MemberCouponStatus.available);
    expect(issued.discountValue, 300);
    expect(issued.expireAt, isNull);
    expect(issued.usedCount, 0);
  });
}

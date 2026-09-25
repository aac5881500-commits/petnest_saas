// 檔案名稱：lib/features/admin/pages/admin_coupon_center_stats.dart
// 功能說明：優惠券中心的統計、篩選與顯示文案。不讀寫訂單，不改計價。

import 'package:petnest_saas/core/models/coupon_template_model.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';

enum CouponCenterSection { all, templates, records, analytics }

enum CouponRecordStatusFilter {
  all,
  usable,
  reserved,
  used,
  expired,
  revoked,
  expiringOrExpired,
}

enum CouponRecordSourceFilter { all, manual, pointsExchange }

enum CouponRecordTimeFilter { days30, days90, all }

enum CouponCenterBucket { usable, used, reserved, expired, revoked }

class CouponUsageRank {
  const CouponUsageRank({
    required this.key,
    required this.name,
    required this.issued,
    required this.used,
  });

  final String key;
  final String name;
  final int issued;
  final int used;

  String get rateLabel => formatCouponUsageRate(used: used, issued: issued);
}

class CouponTemplateUsage {
  const CouponTemplateUsage({
    required this.issued,
    required this.usable,
    required this.used,
  });

  final int issued;
  final int usable;
  final int used;

  String get rateLabel => formatCouponUsageRate(used: used, issued: issued);
}

class CouponCenterSummary {
  const CouponCenterSummary({
    required this.issued,
    required this.usable,
    required this.used,
    required this.reserved,
    required this.expired,
    required this.revoked,
    required this.expiringSoon,
    required this.issuedLast30,
    required this.usedLast30,
    required this.pointsLast30,
    required this.manualLast30,
    required this.topCoupons,
    required this.templateUsage,
  });

  final int issued;
  final int usable;
  final int used;
  final int reserved;
  final int expired;
  final int revoked;
  final int expiringSoon;
  final int issuedLast30;
  final int usedLast30;
  final int pointsLast30;
  final int manualLast30;
  final List<CouponUsageRank> topCoupons;
  final Map<String, CouponTemplateUsage> templateUsage;

  String get usageRateLabel {
    return formatCouponUsageRate(used: used, issued: issued);
  }

  int countOf(CouponCenterBucket bucket) {
    switch (bucket) {
      case CouponCenterBucket.usable:
        return usable;
      case CouponCenterBucket.used:
        return used;
      case CouponCenterBucket.reserved:
        return reserved;
      case CouponCenterBucket.expired:
        return expired;
      case CouponCenterBucket.revoked:
        return revoked;
    }
  }
}

const String memberProfileUnavailableLabel = '會員資料已不可用';

String formatCouponUsageRate({required int used, required int issued}) {
  if (issued <= 0) {
    return '尚無發券紀錄';
  }
  final double percent = used * 100 / issued;
  final String text = percent == percent.roundToDouble()
      ? percent.toStringAsFixed(0)
      : percent.toStringAsFixed(1);
  return '$text%';
}

String memberProfileLabel(Map<String, dynamic>? data) {
  if (data == null) {
    return memberProfileUnavailableLabel;
  }
  final String name = (data['displayName'] ?? data['name'] ?? '')
      .toString()
      .trim();
  if (name.isNotEmpty) {
    return name;
  }
  final String email = (data['email'] ?? '').toString().trim();
  if (email.isNotEmpty) {
    return email;
  }
  return memberProfileUnavailableLabel;
}

String couponOfferLabel({
  required MemberCouponType type,
  required num discountValue,
  required int freeStayNights,
  required String serviceName,
}) {
  switch (type) {
    case MemberCouponType.fixedAmount:
      return '折抵 NT\$${discountValue.round()}';
    case MemberCouponType.percent:
      final String value = discountValue == discountValue.roundToDouble()
          ? discountValue.toStringAsFixed(0)
          : discountValue.toString();
      return '折扣 $value%';
    case MemberCouponType.freeStay:
      return '免費住宿 $freeStayNights 晚';
    case MemberCouponType.freeService:
      return serviceName.trim().isEmpty ? '免費服務' : serviceName.trim();
  }
}

String couponStatusLabel(MemberCouponModel coupon, DateTime now) {
  switch (couponCenterBucket(coupon, now)) {
    case CouponCenterBucket.usable:
      return '可使用';
    case CouponCenterBucket.used:
      return '已使用';
    case CouponCenterBucket.reserved:
      return '保留中';
    case CouponCenterBucket.expired:
      return '已過期';
    case CouponCenterBucket.revoked:
      return '已撤銷';
  }
}

String couponSourceLabel(MemberCouponSource source) {
  switch (source) {
    case MemberCouponSource.manual:
      return '店主發放';
    case MemberCouponSource.pointsExchange:
      return '點數兌換';
  }
}

String couponExpiryLabel(MemberCouponModel coupon, DateTime now) {
  if (couponIsExpired(coupon, now)) {
    return '已過期';
  }
  final DateTime? end = coupon.expireAt;
  if (end == null) {
    return '永久有效';
  }
  return formatCouponDay(end);
}

String couponBookingLabel(String usedBookingId) {
  if (usedBookingId.trim().isEmpty) {
    return '';
  }
  return '查看訂單';
}

String formatCouponDay(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}/$month/$day';
}

bool couponIsExpired(MemberCouponModel coupon, DateTime now) {
  if (coupon.status == MemberCouponStatus.expired) {
    return true;
  }
  final DateTime? end = coupon.expireAt;
  if (end == null) {
    return false;
  }
  return now.isAfter(end);
}

bool couponIsUsable(MemberCouponModel coupon, DateTime now) {
  if (coupon.status != MemberCouponStatus.available) {
    return false;
  }
  if (couponIsExpired(coupon, now)) {
    return false;
  }
  final DateTime? start = coupon.startAt;
  if (start != null && now.isBefore(start)) {
    return false;
  }
  if (coupon.usageLimit > 0 && coupon.usedCount >= coupon.usageLimit) {
    return false;
  }
  return true;
}

bool couponIsExpiringSoon(MemberCouponModel coupon, DateTime now) {
  if (!couponIsUsable(coupon, now)) {
    return false;
  }
  final DateTime? end = coupon.expireAt;
  if (end == null) {
    return false;
  }
  final DateTime limit = now.add(const Duration(days: 7));
  return !now.isAfter(end) && !end.isAfter(limit);
}

CouponCenterBucket couponCenterBucket(MemberCouponModel coupon, DateTime now) {
  if (coupon.status == MemberCouponStatus.revoked) {
    return CouponCenterBucket.revoked;
  }
  if (coupon.status == MemberCouponStatus.used) {
    return CouponCenterBucket.used;
  }
  if (couponIsExpired(coupon, now)) {
    return CouponCenterBucket.expired;
  }
  if (coupon.status == MemberCouponStatus.reserved) {
    return CouponCenterBucket.reserved;
  }
  return CouponCenterBucket.usable;
}

bool couponMatchesTemplate({
  required MemberCouponModel coupon,
  required CouponTemplateModel template,
}) {
  final String templateId = coupon.templateId.trim();
  if (templateId.isNotEmpty) {
    return templateId == template.id;
  }
  return coupon.name.trim() == template.name.trim();
}

String couponGroupKey(MemberCouponModel coupon) {
  final String templateId = coupon.templateId.trim();
  if (templateId.isNotEmpty) {
    return 'id:$templateId';
  }
  return 'name:${coupon.name.trim()}';
}

CouponCenterSummary summarizeCouponCenter({
  required List<MemberCouponModel> coupons,
  required List<CouponTemplateModel> templates,
  required DateTime now,
}) {
  var usable = 0;
  var used = 0;
  var reserved = 0;
  var expired = 0;
  var revoked = 0;
  var expiringSoon = 0;
  var issuedLast30 = 0;
  var usedLast30 = 0;
  var pointsLast30 = 0;
  var manualLast30 = 0;
  final DateTime recentStart = now.subtract(const Duration(days: 30));

  final Map<String, List<MemberCouponModel>> groups =
      <String, List<MemberCouponModel>>{};

  for (final MemberCouponModel coupon in coupons) {
    switch (couponCenterBucket(coupon, now)) {
      case CouponCenterBucket.usable:
        usable += 1;
        break;
      case CouponCenterBucket.used:
        used += 1;
        break;
      case CouponCenterBucket.reserved:
        reserved += 1;
        break;
      case CouponCenterBucket.expired:
        expired += 1;
        break;
      case CouponCenterBucket.revoked:
        revoked += 1;
        break;
    }
    if (couponIsExpiringSoon(coupon, now)) {
      expiringSoon += 1;
    }
    if (!_isBefore(coupon.createdAt, recentStart)) {
      issuedLast30 += 1;
      if (coupon.source == MemberCouponSource.pointsExchange) {
        pointsLast30 += 1;
      }
      if (coupon.source == MemberCouponSource.manual) {
        manualLast30 += 1;
      }
    }
    final DateTime? usedAt = coupon.usedAt;
    if (coupon.status == MemberCouponStatus.used &&
        usedAt != null &&
        !_isBefore(usedAt, recentStart)) {
      usedLast30 += 1;
    }
    groups.putIfAbsent(couponGroupKey(coupon), () => <MemberCouponModel>[]);
    groups[couponGroupKey(coupon)]!.add(coupon);
  }

  final List<CouponUsageRank> ranks = groups.entries.map((
    MapEntry<String, List<MemberCouponModel>> entry,
  ) {
    final List<MemberCouponModel> items = entry.value;
    items.sort((MemberCouponModel a, MemberCouponModel b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    final int usedCount = items
        .where(
          (MemberCouponModel coupon) =>
              coupon.status == MemberCouponStatus.used,
        )
        .length;
    return CouponUsageRank(
      key: entry.key,
      name: items.first.name.trim().isEmpty ? '未命名優惠券' : items.first.name,
      issued: items.length,
      used: usedCount,
    );
  }).toList();
  ranks.sort((CouponUsageRank a, CouponUsageRank b) {
    final int byUsed = b.used.compareTo(a.used);
    if (byUsed != 0) {
      return byUsed;
    }
    return b.issued.compareTo(a.issued);
  });

  final Map<String, CouponTemplateUsage> templateUsage =
      <String, CouponTemplateUsage>{};
  for (final CouponTemplateModel template in templates) {
    final List<MemberCouponModel> matched = coupons
        .where(
          (MemberCouponModel coupon) =>
              couponMatchesTemplate(coupon: coupon, template: template),
        )
        .toList();
    templateUsage[template.id] = CouponTemplateUsage(
      issued: matched.length,
      usable: matched
          .where((MemberCouponModel coupon) => couponIsUsable(coupon, now))
          .length,
      used: matched
          .where(
            (MemberCouponModel coupon) =>
                coupon.status == MemberCouponStatus.used,
          )
          .length,
    );
  }

  return CouponCenterSummary(
    issued: coupons.length,
    usable: usable,
    used: used,
    reserved: reserved,
    expired: expired,
    revoked: revoked,
    expiringSoon: expiringSoon,
    issuedLast30: issuedLast30,
    usedLast30: usedLast30,
    pointsLast30: pointsLast30,
    manualLast30: manualLast30,
    topCoupons: ranks.take(5).toList(),
    templateUsage: templateUsage,
  );
}

List<MemberCouponModel> filterCouponRecords({
  required List<MemberCouponModel> coupons,
  required DateTime now,
  required String keyword,
  required CouponRecordStatusFilter status,
  required CouponRecordSourceFilter source,
  required CouponRecordTimeFilter time,
  required String couponName,
  String Function(MemberCouponModel coupon)? memberLabel,
}) {
  final String query = keyword.trim().toLowerCase();
  final DateTime? start = switch (time) {
    CouponRecordTimeFilter.days30 => now.subtract(const Duration(days: 30)),
    CouponRecordTimeFilter.days90 => now.subtract(const Duration(days: 90)),
    CouponRecordTimeFilter.all => null,
  };
  return coupons.where((MemberCouponModel coupon) {
    if (couponName.trim().isNotEmpty &&
        coupon.name.trim() != couponName.trim()) {
      return false;
    }
    if (start != null && _isBefore(coupon.createdAt, start)) {
      return false;
    }
    if (source == CouponRecordSourceFilter.manual &&
        coupon.source != MemberCouponSource.manual) {
      return false;
    }
    if (source == CouponRecordSourceFilter.pointsExchange &&
        coupon.source != MemberCouponSource.pointsExchange) {
      return false;
    }
    if (!_matchesStatus(coupon, now, status)) {
      return false;
    }
    if (query.isEmpty) {
      return true;
    }
    final String label = memberLabel == null ? '' : memberLabel(coupon);
    final String haystack = '${coupon.name} $label'.toLowerCase();
    return haystack.contains(query);
  }).toList();
}

bool _matchesStatus(
  MemberCouponModel coupon,
  DateTime now,
  CouponRecordStatusFilter status,
) {
  switch (status) {
    case CouponRecordStatusFilter.all:
      return true;
    case CouponRecordStatusFilter.usable:
      return couponCenterBucket(coupon, now) == CouponCenterBucket.usable;
    case CouponRecordStatusFilter.reserved:
      return couponCenterBucket(coupon, now) == CouponCenterBucket.reserved;
    case CouponRecordStatusFilter.used:
      return couponCenterBucket(coupon, now) == CouponCenterBucket.used;
    case CouponRecordStatusFilter.expired:
      return couponCenterBucket(coupon, now) == CouponCenterBucket.expired;
    case CouponRecordStatusFilter.revoked:
      return couponCenterBucket(coupon, now) == CouponCenterBucket.revoked;
    case CouponRecordStatusFilter.expiringOrExpired:
      return couponIsExpiringSoon(coupon, now) || couponIsExpired(coupon, now);
  }
}

bool _isBefore(DateTime value, DateTime start) {
  return value.isBefore(start);
}

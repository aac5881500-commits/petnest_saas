// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_points_display.dart
// 功能說明：訂單詳細點數顯示。只讀既有 booking 欄位，不重算點數。

import 'package:petnest_saas/core/services/shop_member_kind.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class BookingPointsDisplay {
  const BookingPointsDisplay({
    required this.pointsUsed,
    required this.discountNtd,
    required this.systemPoints,
    required this.finalPoints,
    required this.adjusted,
    required this.adjustReason,
    required this.issuedAmount,
    required this.issuedAt,
    required this.manualUnbound,
  });

  final int pointsUsed;
  final int discountNtd;
  final int systemPoints;
  final int finalPoints;
  final bool adjusted;
  final String adjustReason;
  final int issuedAmount;
  final DateTime? issuedAt;
  final bool manualUnbound;

  bool get showSpend => pointsUsed > 0 || discountNtd > 0;

  bool get showSystem => systemPoints > 0;

  bool get showAdjustment => adjusted && finalPoints != systemPoints;

  bool get issued => issuedAmount > 0;

  int get adjustmentDelta => finalPoints - systemPoints;

  /// 客戶看到的預計點數：已調整用最終值，否則用系統值。
  int get previewPoints {
    if (issued || manualUnbound) {
      return 0;
    }
    if (finalPoints > 0) {
      return finalPoints;
    }
    return systemPoints;
  }

  bool get participates =>
      !manualUnbound &&
      (showSpend || showSystem || finalPoints > 0 || issued || showAdjustment);

  bool get pending => participates && !issued && previewPoints > 0;

  bool get customerVisible =>
      showSpend || issued || (!manualUnbound && previewPoints > 0);

  String get shopStatusLabel {
    if (!participates || manualUnbound) {
      return '';
    }
    return issued ? '已發放' : '待發放';
  }

  static BookingPointsDisplay fromBooking(
    Map<String, dynamic>? booking, {
    Map<String, dynamic>? member,
  }) {
    final Map<String, dynamic> raw = booking ?? <String, dynamic>{};
    final int used = _points(raw['pointsUsed']);
    final int discount = _points(
      raw['pointAmount'] ?? raw['pointsDiscountAmount'] ?? raw['pointsDiscount'],
    );
    final bool hasSystem = raw.containsKey('rewardPointsSystem');
    final int system = _points(
      hasSystem ? raw['rewardPointsSystem'] : raw['expectedRewardPoints'],
    );
    final bool adjusted = SafeParse.parseBool(raw['rewardPointsAdjusted']);
    final bool hasFinal = raw.containsKey('rewardPointsFinal');
    final int finalPoints = adjusted || hasFinal
        ? _points(raw['rewardPointsFinal'])
        : system;
    final int issued = raw.containsKey('pointsIssuedAmount')
        ? _points(raw['pointsIssuedAmount'])
        : _points(raw['rewardPointAmount'] ?? raw['pointsIssued']);
    final DateTime? issuedAt = SafeParse.parseDate(
      raw['rewardPointIssuedAt'] ?? raw['pointsIssuedAt'],
    );
    final bool flaggedManual =
        SafeParse.parseBool(raw['isTempAdminMember']) ||
        (member != null && ShopMemberKind.isManualMember(member));
    final bool hasEarnOrSpend =
        used > 0 || discount > 0 || system > 0 || finalPoints > 0 || issued > 0;
    return BookingPointsDisplay(
      pointsUsed: used,
      discountNtd: discount,
      systemPoints: system,
      finalPoints: finalPoints,
      adjusted: adjusted,
      adjustReason: SafeParse.parseString(raw['rewardPointsAdjustReason']),
      issuedAmount: issued,
      issuedAt: issuedAt,
      manualUnbound: flaggedManual && !hasEarnOrSpend,
    );
  }

  static int _points(dynamic value) {
    if (value is num && !value.isFinite) {
      return 0;
    }
    final int parsed = SafeParse.parseMoney(value);
    return parsed < 0 ? 0 : parsed;
  }
}

// 檔案名稱：lib/core/services/policy_acceptance_merge.dart
// 功能說明：條款同意紀錄服務類型判斷與訂單快照列合併（不去寫入）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/shop_policy_history.dart';

class PolicyAcceptanceLogRow {
  const PolicyAcceptanceLogRow({
    required this.userId,
    required this.serviceType,
    required this.acceptedVersion,
    required this.acceptedAt,
    required this.email,
    required this.phone,
    required this.customerName,
    required this.bookingId,
    required this.bookingCode,
    required this.policyTitle,
  });

  final String userId;
  final String serviceType;
  final int acceptedVersion;
  final dynamic acceptedAt;
  final String email;
  final String phone;
  final String customerName;
  final String bookingId;
  final String bookingCode;
  final String policyTitle;

  bool get isUnknown => serviceType == ShopPolicyHistory.unknownService;

  String get serviceLabel {
    if (isUnknown) {
      return '舊資料待確認';
    }
    return serviceType == PolicyApplicableService.daycare ? '安親' : '住宿';
  }

  String get dedupeKey {
    if (bookingId.isNotEmpty) {
      return 'b:$bookingId:$serviceType:$acceptedVersion';
    }
    return 'u:$userId:$serviceType:$acceptedVersion';
  }
}

class PolicyAcceptanceMerge {
  PolicyAcceptanceMerge._();

  static String resolveServiceType(
    Map<String, dynamic> data, {
    String sourceCollection = 'bookings',
  }) {
    String token(dynamic raw) => (raw ?? '').toString().trim();
    const List<String> keys = <String>[
      'policyServiceType',
      'termsType',
      'policyKind',
      'bookingKind',
      'serviceType',
    ];
    for (final String key in keys) {
      final String value = token(data[key]);
      if (value == PolicyApplicableService.daycare ||
          value == PolicyApplicableService.accommodation) {
        return value;
      }
    }
    if (sourceCollection == 'daycare_bookings') {
      return PolicyApplicableService.daycare;
    }
    if (BookingKind.isDaycare(data)) {
      return PolicyApplicableService.daycare;
    }
    final bool hasStayHint =
        token(data['roomTypeId']).isNotEmpty ||
        token(data['roomTypeName']).isNotEmpty ||
        token(data['startDate']).isNotEmpty ||
        (data['nights'] is num && (data['nights'] as num) > 0);
    if (hasStayHint || sourceCollection == 'bookings') {
      return PolicyApplicableService.accommodation;
    }
    return ShopPolicyHistory.unknownService;
  }

  static PolicyAcceptanceLogRow? fromBooking({
    required Map<String, dynamic> data,
    required String bookingId,
    String sourceCollection = 'bookings',
  }) {
    final int version = ShopPolicyHistory.parseVersion(
      data['termsVersion'] ??
          data['policyVersion'] ??
          data['policySnapshotVersion'],
    );
    if (version <= 0) {
      return null;
    }
    final String serviceType = resolveServiceType(
      data,
      sourceCollection: sourceCollection,
    );
    final String code = (data['bookingCode'] ?? '').toString().trim();
    final String title = (data['termsTitle'] ?? data['policyTitle'] ?? '')
        .toString()
        .trim();
    return PolicyAcceptanceLogRow(
      userId: (data['userId'] ?? '').toString().trim(),
      serviceType: serviceType,
      acceptedVersion: version,
      acceptedAt: data['policyAcceptedAt'] ?? data['termsAcceptedAt'],
      email: (data['customerEmail'] ?? data['email'] ?? '').toString().trim(),
      phone: (data['customerPhone'] ?? data['phone'] ?? '').toString().trim(),
      customerName: (data['customerName'] ?? data['name'] ?? '')
          .toString()
          .trim(),
      bookingId: bookingId,
      bookingCode: code.isNotEmpty
          ? code
          : (bookingId.length >= 8 ? bookingId.substring(0, 8) : bookingId),
      policyTitle: title.isNotEmpty
          ? title
          : (serviceType == PolicyApplicableService.daycare ? '安親須知' : '入住須知'),
    );
  }

  static PolicyAcceptanceLogRow keepNewer(
    PolicyAcceptanceLogRow current,
    PolicyAcceptanceLogRow incoming,
  ) {
    final DateTime left = _time(current.acceptedAt);
    final DateTime right = _time(incoming.acceptedAt);
    if (right.isAfter(left)) {
      return incoming;
    }
    return current;
  }

  static DateTime _time(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

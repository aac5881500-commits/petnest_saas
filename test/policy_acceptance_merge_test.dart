// 檔案名稱：test/policy_acceptance_merge_test.dart
// 功能說明：條款同意紀錄依服務類型分列，v5 住宿與安親不可合併

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/policy_acceptance_merge.dart';

void main() {
  test('住宿與安親同時 v5 各自一筆', () {
    final PolicyAcceptanceLogRow stay = PolicyAcceptanceMerge.fromBooking(
      data: <String, dynamic>{
        'bookingKind': 'accommodation',
        'policyServiceType': 'accommodation',
        'policyVersion': 5,
        'policyTitle': '入住須知',
        'customerName': 'A',
        'bookingCode': 'S1',
        'userId': 'u1',
      },
      bookingId: 'stay1',
    )!;
    final PolicyAcceptanceLogRow daycare = PolicyAcceptanceMerge.fromBooking(
      data: <String, dynamic>{
        'bookingKind': 'daycare',
        'policyServiceType': 'daycare',
        'policyVersion': 5,
        'policyTitle': '安親須知',
        'customerName': 'A',
        'bookingCode': 'D1',
        'userId': 'u1',
      },
      bookingId: 'day1',
    )!;
    expect(stay.serviceType, PolicyApplicableService.accommodation);
    expect(daycare.serviceType, PolicyApplicableService.daycare);
    expect(stay.dedupeKey, isNot(daycare.dedupeKey));
    expect(stay.acceptedVersion, 5);
    expect(daycare.acceptedVersion, 5);
  });

  test('只有訂單快照、沒有 userId 的手動單仍可列出', () {
    final PolicyAcceptanceLogRow? row = PolicyAcceptanceMerge.fromBooking(
      data: <String, dynamic>{
        'bookingKind': 'accommodation',
        'policyVersion': 5,
        'customerName': '現場客人',
        'customerPhone': '0911',
        'bookingCode': 'M1',
      },
      bookingId: 'manual1',
    );
    expect(row, isNotNull);
    expect(row!.userId, isEmpty);
    expect(row.customerName, '現場客人');
    expect(row.bookingCode, 'M1');
  });

  test('安親訂單用 bookingKind 判斷，不靠版本號', () {
    final PolicyAcceptanceLogRow row = PolicyAcceptanceMerge.fromBooking(
      data: <String, dynamic>{
        'bookingKind': 'daycare',
        'scheduledStartAt': DateTime(2026, 1, 1),
        'policyVersion': 5,
      },
      bookingId: 'd2',
    )!;
    expect(row.serviceType, PolicyApplicableService.daycare);
  });
}

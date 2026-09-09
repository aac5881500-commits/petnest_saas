// 檔案名稱：test/policy_acceptance_rows_test.dart
// 功能說明：條款同意紀錄依服務拆列，舊住宿資料不進安親 Tab

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/policy_acceptance_rows.dart';

void main() {
  test('舊資料只有 acceptedVersion 時只出現在住宿', () {
    final List<PolicyAcceptanceRow> rows = PolicyAcceptanceRows.expand(
      <String, dynamic>{
        'userId': 'u1',
        'acceptedVersion': 3,
        'acceptedAt': 't',
        'email': 'a@b.c',
      },
    );
    expect(rows.length, 1);
    expect(rows.first.serviceType, PolicyApplicableService.accommodation);
    expect(rows.first.acceptedVersion, 3);
  });

  test('per-service 版本分別進住宿與安親', () {
    final List<PolicyAcceptanceRow> rows = PolicyAcceptanceRows.expand(
      <String, dynamic>{
        'userId': 'u1',
        'acceptedVersions': <String, dynamic>{'accommodation': 2, 'daycare': 5},
        'acceptedAtByService': <String, dynamic>{
          'accommodation': 'stay',
          'daycare': 'day',
        },
      },
    );
    expect(rows.length, 2);
    expect(
      rows
          .where(
            (PolicyAcceptanceRow row) =>
                row.serviceType == PolicyApplicableService.daycare,
          )
          .single
          .acceptedVersion,
      5,
    );
  });
}

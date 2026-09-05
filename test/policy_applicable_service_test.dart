// 檔案名稱：test/policy_applicable_service_test.dart
// 功能說明：條款適用範圍的單元測試（舊條款沒有適用類型時視為僅住宿）

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';

void main() {
  test('舊條款沒有適用類型時視為僅住宿', () {
    expect(
      PolicyApplicableService.parse(null),
      PolicyApplicableService.accommodationOnly,
    );
    expect(
      PolicyApplicableService.appliesTo(
        PolicyApplicableService.parse(null),
        PolicyApplicableService.daycare,
      ),
      isFalse,
    );
    expect(
      PolicyApplicableService.appliesTo(
        PolicyApplicableService.parse(null),
        PolicyApplicableService.accommodation,
      ),
      isTrue,
    );
  });

  test('共用條款同時適用住宿與臨托', () {
    expect(
      PolicyApplicableService.appliesTo(
        PolicyApplicableService.shared,
        PolicyApplicableService.daycare,
      ),
      isTrue,
    );
  });

  test('字串舊額外條款可解析為僅住宿', () {
    final items = PolicyApplicableService.normalizeCustomPolicies(<dynamic>[
      '舊條款文字',
      <String, dynamic>{
        'text': '臨托專用',
        'applicableServices': <String>['daycare'],
      },
    ]);
    expect(
      PolicyApplicableService.textsForService(
        items: items,
        serviceType: PolicyApplicableService.accommodation,
      ),
      <String>['舊條款文字'],
    );
    expect(
      PolicyApplicableService.textsForService(
        items: items,
        serviceType: PolicyApplicableService.daycare,
      ),
      <String>['臨托專用'],
    );
  });
}

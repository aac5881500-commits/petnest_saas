// 檔案名稱：test/shop_policy_history_test.dart
// 功能說明：住宿／安親歷史條款讀取順序，不可互用 v5

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/shop_policy_history.dart';

void main() {
  final Map<String, Map<String, dynamic>> store = <String, Map<String, dynamic>>{
    'policy_versions/v5': <String, dynamic>{
      'version': 5,
      'serviceType': 'accommodation',
      'title': '入住須知',
    },
    'policy_versions/daycare_v5': <String, dynamic>{
      'version': 5,
      'serviceType': 'daycare',
      'title': '安親須知',
    },
    'daycare_policy_versions/v5': <String, dynamic>{
      'version': 5,
      'title': '舊安親須知',
    },
  };

  test('住宿 v5 只讀 policy_versions/v5，不可讀 daycare_v5', () {
    final Map<String, dynamic>? found = ShopPolicyHistory.pickFromStore(
      plan: ShopPolicyHistory.readPlan(
        serviceType: PolicyApplicableService.accommodation,
        version: 5,
      ),
      store: store,
    );
    expect(found?['title'], '入住須知');
    expect(
      ShopPolicyHistory.readPlan(
        serviceType: PolicyApplicableService.accommodation,
        version: 5,
      ).map((PolicyHistoryReadStep step) => step.documentId),
      <String>['v5'],
    );
  });

  test('安親新版讀 daycare_v5', () {
    final Map<String, dynamic>? found = ShopPolicyHistory.pickFromStore(
      plan: ShopPolicyHistory.readPlan(
        serviceType: PolicyApplicableService.daycare,
        version: 5,
      ),
      store: store,
    );
    expect(found?['title'], '安親須知');
  });

  test('安親舊版讀 daycare_policy_versions/v5', () {
    final Map<String, Map<String, dynamic>> oldOnly =
        <String, Map<String, dynamic>>{
          'policy_versions/v5': store['policy_versions/v5']!,
          'daycare_policy_versions/v5': store['daycare_policy_versions/v5']!,
        };
    final Map<String, dynamic>? found = ShopPolicyHistory.pickFromStore(
      plan: ShopPolicyHistory.readPlan(
        serviceType: PolicyApplicableService.daycare,
        version: 5,
      ),
      store: oldOnly,
    );
    expect(found?['title'], '舊安親須知');
  });

  test('住宿 v5 不可當安親 fallback', () {
    final Map<String, dynamic>? found = ShopPolicyHistory.pickFromStore(
      plan: ShopPolicyHistory.readPlan(
        serviceType: PolicyApplicableService.daycare,
        version: 5,
      ),
      store: <String, Map<String, dynamic>>{
        'policy_versions/v5': store['policy_versions/v5']!,
      },
    );
    expect(found, isNull);
  });

  test('僅當 v5 文件明確標示 daycare 才可給安親讀', () {
    final Map<String, dynamic>? found = ShopPolicyHistory.pickFromStore(
      plan: ShopPolicyHistory.readPlan(
        serviceType: PolicyApplicableService.daycare,
        version: 5,
      ),
      store: <String, Map<String, dynamic>>{
        'policy_versions/v5': <String, dynamic>{
          'version': 5,
          'serviceType': 'daycare',
          'title': '誤存在住宿路徑的安親',
        },
      },
    );
    expect(found?['title'], '誤存在住宿路徑的安親');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';

void main() {
  final service = ShopPolicyService.instance;
  Map<String, dynamic> legacy({
    String text = '入住請攜帶疫苗手冊',
    bool enabled = true,
  }) => {
    'version': 2,
    'sections': {'checkinNotice': text},
    'enabled': {'checkinNotice': enabled},
  };
  bool ready(Map<String, dynamic>? current, [Map<String, dynamic>? history]) =>
      service.hasPublishedStayPolicy(policy: current, published: history);

  test(
    'legacy and published stay versions qualify without main status field',
    () {
      expect(ready(legacy(), {...legacy(), 'status': 'published'}), isTrue);
      expect(ready(legacy(), legacy()), isTrue);
    },
  );
  test('missing, blank, disabled and refund-only policies do not qualify', () {
    expect(ready(null), isFalse);
    for (final policy in [
      legacy(text: ' \n '),
      legacy(enabled: false),
      {
        'version': 2,
        'sections': {'cancelPolicy': '退款規則'},
        'enabled': {'cancelPolicy': true},
      },
    ]) {
      expect(ready(policy, {...policy, 'status': 'published'}), isFalse);
    }
  });
  test('daycare-only and unpublished or unmatched versions do not qualify', () {
    final daycare = {
      ...legacy(),
      'sectionApplicableServices': {
        'checkinNotice': ['daycare'],
      },
    };
    expect(
      ready(daycare, {
        ...daycare,
        'status': 'published',
        'serviceType': 'daycare',
      }),
      isFalse,
    );
    expect(ready(legacy()), isFalse);
    expect(ready(legacy(), {...legacy(), 'status': 'draft'}), isFalse);
    expect(ready(legacy(), {...legacy(), 'version': 1}), isFalse);
    expect(ready(legacy(text: '未發布的變更'), legacy()), isFalse);
  });
  test(
    'service-specific custom stay content qualifies even without standard sections',
    () {
      final policy = <String, dynamic>{
        'serviceVersions': {'accommodation': 3, 'daycare': 8},
        'sectionTextsByService': {'accommodation': <String, String>{}},
        'customPoliciesByService': {
          'accommodation': {
            'page1': ['入住須知'],
            'page2': [],
          },
        },
      };
      expect(ready(policy, {...policy, 'status': 'published'}), isTrue);
      final disabled = {
        ...policy,
        'customPoliciesByService': {
          'accommodation': {
            'page1': [
              {'text': '已停用', 'enabled': false},
            ],
            'page2': [],
          },
        },
      };
      expect(ready(disabled, {...disabled, 'status': 'published'}), isFalse);
    },
  );
}

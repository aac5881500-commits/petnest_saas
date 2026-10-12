import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/shop_plan_access.dart';

void main() {
  test('生效前保留原方案，生效後才套用下一期模組', () {
    final shop = <String, dynamic>{
      'plan': 'basic',
      'lockedModule': 'cat_hotel',
      'enabledModules': <String>['basic_info', 'cat_hotel', 'reports'],
      'nextPlan': 'pro',
      'nextPlanStarts': '2026-03-21',
    };

    expect(ShopPlanAccess.effectivePlan(shop, today: '2026-03-01'), 'basic');
    expect(ShopPlanAccess.scheduleApplied(shop, today: '2026-03-01'), isFalse);
    expect(ShopPlanAccess.pendingNextPlan(shop, today: '2026-03-01'), 'pro');
    expect(
      ShopPlanAccess.effectivePlan(shop, today: '2026-03-21'),
      'pro',
    );
    expect(ShopPlanAccess.scheduleApplied(shop, today: '2026-03-21'), isTrue);
    expect(
      ShopPlanAccess.modulesFor(shop, 'pro'),
      contains('dog_hotel'),
    );
  });
}

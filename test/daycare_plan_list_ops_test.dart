// 檔案名稱：test/daycare_plan_list_ops_test.dart
// 功能說明：安親方案列表操作的單元測試（最後一個方案不可刪除）

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/services/daycare_plan_list_ops.dart';

void main() {
  test('最後一個方案不可刪除', () {
    expect(
      DaycarePlanListOps.deleteBlockReason(const <DaycarePlanModel>[
        DaycarePlanModel(id: 'a', name: 'A'),
      ]),
      DaycarePlanListOps.lastPlanMessage,
    );
  });

  test('刪除方案後重新整理排序，舊快照金額不變', () {
    const DaycarePlanModel first = DaycarePlanModel(
      id: 'a',
      name: '舊方案',
      basePrice: 880,
      extraBillingPrice: 200,
      sortOrder: 0,
    );
    const DaycarePlanModel second = DaycarePlanModel(
      id: 'b',
      name: '新方案',
      basePrice: 500,
      sortOrder: 1,
    );
    final Map<String, dynamic> snapshot = first.toMap();
    final List<DaycarePlanModel> next = DaycarePlanListOps.deleteAndReindex(
      plans: const <DaycarePlanModel>[first, second],
      planId: 'a',
    );
    expect(next.length, 1);
    expect(next.first.id, 'b');
    expect(next.first.sortOrder, 0);
    expect(snapshot['basePrice'], 880);
    expect(snapshot['extraBillingPrice'], 200);
  });
}

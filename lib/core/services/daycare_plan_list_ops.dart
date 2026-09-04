// lib/core/services/daycare_plan_list_ops.dart
// 🐾 安親獨立方案清單：刪除與重新整理排序（不碰 Firestore 舊訂單）

import 'package:petnest_saas/core/models/daycare_plan_model.dart';

class DaycarePlanListOps {
  DaycarePlanListOps._();

  static const String lastPlanMessage = '至少需要保留一個安親方案。';

  static String? deleteBlockReason(List<DaycarePlanModel> plans) {
    if (plans.length <= 1) {
      return lastPlanMessage;
    }
    return null;
  }

  static List<DaycarePlanModel> deleteAndReindex({
    required List<DaycarePlanModel> plans,
    required String planId,
  }) {
    final List<DaycarePlanModel> next = plans
        .where((DaycarePlanModel e) => e.id != planId)
        .toList();
    return reindex(next);
  }

  static List<DaycarePlanModel> reindex(List<DaycarePlanModel> plans) {
    return plans.asMap().entries.map((MapEntry<int, DaycarePlanModel> e) {
      return e.value.copyWith(sortOrder: e.key);
    }).toList();
  }
}

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';

/// Shared by the original and three styled customer views. Text remains editable;
/// stable catalog IDs choose the short heading and semantic icon.
class PreArrivalItemPresentation {
  const PreArrivalItemPresentation(this.title, this.icon, {this.atlasCell});
  final String title;
  final IconData icon;
  final int? atlasCell;
  static const catalog = <String, PreArrivalItemPresentation>{
    'food': PreArrivalItemPresentation(
      '日常餐食',
      Icons.restaurant_outlined,
      atlasCell: 1,
    ),
    'carrier': PreArrivalItemPresentation(
      '安全外出籠',
      Icons.luggage_outlined,
      atlasCell: 2,
    ),
    'vaccine': PreArrivalItemPresentation('疫苗紀錄', Icons.vaccines_outlined),
    'parasite': PreArrivalItemPresentation('驅蟲紀錄', Icons.pest_control_outlined),
    'food-portions': PreArrivalItemPresentation(
      '餐食分裝與標示',
      Icons.lunch_dining_outlined,
    ),
    'handover-contacts': PreArrivalItemPresentation(
      '飼主與緊急聯絡人',
      Icons.contact_phone_outlined,
    ),
    'blanket': PreArrivalItemPresentation(
      '熟悉的毛毯或玩具',
      Icons.toys_outlined,
      atlasCell: 3,
    ),
    'comfort': PreArrivalItemPresentation(
      '熟悉的毛毯或玩具',
      Icons.toys_outlined,
      atlasCell: 3,
    ),
    'medicine': PreArrivalItemPresentation(
      '藥品與照護說明',
      Icons.medical_services_outlined,
      atlasCell: 4,
    ),
    'cold-food': PreArrivalItemPresentation('冷藏與冷凍餐食', Icons.ac_unit_outlined),
    'allergy-note': PreArrivalItemPresentation(
      '過敏與飲食禁忌',
      Icons.no_food_outlined,
    ),
    'supplements': PreArrivalItemPresentation(
      '保健品與餵食方式',
      Icons.medication_outlined,
    ),
    'own-litter': PreArrivalItemPresentation('自備慣用貓砂', Icons.grain_outlined),
    'own-bowl': PreArrivalItemPresentation(
      '自備餐碗與飲水器',
      Icons.water_drop_outlined,
    ),
    'bedding': PreArrivalItemPresentation('睡墊與小窩', Icons.bed_outlined),
    'carrier-pad': PreArrivalItemPresentation(
      '外出籠墊布與墊材',
      Icons.layers_outlined,
    ),
    'snacks': PreArrivalItemPresentation('零食份量與限制', Icons.cookie_outlined),
    'litter': PreArrivalItemPresentation(
      '貓砂與砂盆',
      Icons.grain_outlined,
      atlasCell: 5,
    ),
    'bowl': PreArrivalItemPresentation('餐碗與飲水用品', Icons.water_drop_outlined),
    'time': PreArrivalItemPresentation(
      '確認接送時間',
      Icons.schedule_outlined,
      atlasCell: 6,
    ),
    'contact': PreArrivalItemPresentation(
      '特殊需求提前聯繫',
      Icons.chat_bubble_outline,
      atlasCell: 7,
    ),
    'clinic-contact': PreArrivalItemPresentation(
      '就醫與醫院聯絡資料',
      Icons.local_hospital_outlined,
    ),
    'pickup-person': PreArrivalItemPresentation(
      '接送人與委託接回',
      Icons.badge_outlined,
    ),
    'belongings-list': PreArrivalItemPresentation(
      '物品標示與交接清單',
      Icons.inventory_2_outlined,
    ),
    'health-change': PreArrivalItemPresentation(
      '近期健康與用藥變化',
      Icons.monitor_heart_outlined,
    ),
    'long-stay-supply': PreArrivalItemPresentation(
      '長住餐食與用品補給',
      Icons.local_shipping_outlined,
    ),
  };
  static PreArrivalItemPresentation forBlock(PreArrivalGuideBlock block) {
    final id = block.id.startsWith('catalog-')
        ? block.id.substring(8)
        : block.id;
    final known = catalog[id];
    if (known != null) return known;
    for (final (pattern, key) in const [
      ('疫苗|預防針', 'vaccine'),
      ('驅蟲|除蚤', 'parasite'),
      ('冷藏|冷凍', 'cold-food'),
      ('過敏|不能吃', 'allergy-note'),
      ('保健品', 'supplements'),
      ('緊急聯絡|飼主', 'handover-contacts'),
      ('醫院|就醫', 'clinic-contact'),
      ('接送人|接回', 'pickup-person'),
      ('分裝|餐次', 'food-portions'),
      ('貓砂|砂盆', 'own-litter'),
      ('餐碗|飲水', 'own-bowl'),
      ('睡墊|小窩', 'bedding'),
      ('墊布|墊材', 'carrier-pad'),
      ('零食', 'snacks'),
      ('藥|照護', 'medicine'),
      ('飼料|餐食|罐頭', 'food'),
      ('外出籠', 'carrier'),
      ('毛毯|玩具', 'blanket'),
      ('接送|時間', 'time'),
      ('補給|長住', 'long-stay-supply'),
    ]) {
      if (RegExp(pattern).hasMatch(block.text)) return catalog[key]!;
    }
    return const PreArrivalItemPresentation(
      '自訂準備事項',
      Icons.fact_check_outlined,
    );
  }
}

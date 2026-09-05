// 檔案名稱：lib/core/constants/emergency_relation_options.dart
// 功能說明：緊急聯絡人關係固定選項，供會員中心與預約表單共用。

class EmergencyRelationOptions {
  EmergencyRelationOptions._();

  static const String parents = '父母';
  static const String couple = '夫妻';
  static const String spouse = '配偶';
  static const String siblings = '兄弟姊妹';
  static const String partner = '情侶';
  static const String friend = '朋友';
  static const String other = '其他';

  static const List<String> presets = <String>[
    parents,
    couple,
    spouse,
    siblings,
    partner,
    friend,
    other,
  ];

  static bool isPreset(String value) => presets.contains(value);

  static bool isFixedPreset(String value) {
    return isPreset(value) && value != other;
  }
}

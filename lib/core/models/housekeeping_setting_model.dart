// lib/core/models/housekeeping_setting_model.dart
// 房務設定 Model

class HousekeepingSettingModel {
  const HousekeepingSettingModel({this.autoCleaningAfterCheckout = true});

  /// 退房後自動進入清潔中
  final bool autoCleaningAfterCheckout;

  factory HousekeepingSettingModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const HousekeepingSettingModel();
    }

    return HousekeepingSettingModel(
      autoCleaningAfterCheckout: map['autoCleaningAfterCheckout'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {'autoCleaningAfterCheckout': autoCleaningAfterCheckout};
  }

  HousekeepingSettingModel copyWith({bool? autoCleaningAfterCheckout}) {
    return HousekeepingSettingModel(
      autoCleaningAfterCheckout:
          autoCleaningAfterCheckout ?? this.autoCleaningAfterCheckout,
    );
  }
}

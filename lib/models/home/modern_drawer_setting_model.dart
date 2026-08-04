// lib/models/home/modern_drawer_setting_model.dart
// 🎨 新版 Drawer 設定 Model
// 功能：控制新版首頁 Drawer 各區塊是否顯示

class ModernDrawerSettingModel {
  const ModernDrawerSettingModel({
    this.showLatestBooking = true,
    this.showMemberCenter = true,
    this.showShopMenus = true,
    this.showFooter = true,
    this.showContactPlatform = true,
  });

  final bool showLatestBooking;
  final bool showMemberCenter;
  final bool showShopMenus;
  final bool showFooter;
  final bool showContactPlatform;

  factory ModernDrawerSettingModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const ModernDrawerSettingModel();
    }

    return ModernDrawerSettingModel(
      showLatestBooking: map['showLatestBooking'] ?? true,
      showMemberCenter: map['showMemberCenter'] ?? true,
      showShopMenus: map['showShopMenus'] ?? true,
      showFooter: map['showFooter'] ?? true,
      showContactPlatform: map['showContactPlatform'] ?? true,
    );
  }

  ModernDrawerSettingModel copyWith({
    bool? showLatestBooking,
    bool? showMemberCenter,
    bool? showShopMenus,
    bool? showFooter,
    bool? showContactPlatform,
  }) {
    return ModernDrawerSettingModel(
      showLatestBooking: showLatestBooking ?? this.showLatestBooking,
      showMemberCenter: showMemberCenter ?? this.showMemberCenter,
      showShopMenus: showShopMenus ?? this.showShopMenus,
      showFooter: showFooter ?? this.showFooter,
      showContactPlatform: showContactPlatform ?? this.showContactPlatform,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'showLatestBooking': showLatestBooking,
      'showMemberCenter': showMemberCenter,
      'showShopMenus': showShopMenus,
      'showFooter': showFooter,
      'showContactPlatform': showContactPlatform,
    };
  }
}

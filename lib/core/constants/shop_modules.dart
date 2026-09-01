// lib/core/constants/shop_modules.dart
// 🧩 店家模組常數
// 功能：集中管理各模板模組與方案可用模組

class ShopModules {
  static const basicInfo = 'basic_info';

  static const catHotel = 'cat_hotel';
  static const dogHotel = 'dog_hotel';
  static const grooming = 'grooming';
  static const hospital = 'hospital';
  static const store = 'store';

  static const reports = 'reports';

  /// 舊資料相容：臨托已改為貓咪旅店附屬功能，不再作為獨立模組開關。
  static const daycare = 'daycare';

  /// 📦 中央庫存管理
  ///
  /// 不列入方案鎖定模組，只要有庫存權限即可在後台顯示。
  static const inventory = 'inventory';

  /// 全部合法模組
  static const all = [
    basicInfo,
    catHotel,
    dogHotel,
    grooming,
    hospital,
    store,
    reports,
    daycare,
  ];

  /// 可被激活碼鎖定的模板
  static const lockableModules = [
    catHotel,
    dogHotel,
    grooming,
    hospital,
    store,
  ];

  /// pro 可自由開啟的模板
  static const proModules = [
    catHotel,
    dogHotel,
    grooming,
    hospital,
    store,
  ];

  /// 舊資料 fallback
  static const defaultEnabled = [basicInfo, catHotel, reports];

  /// free / basic 固定只能用基本資料 + 鎖定模板
  static List<String> lockedPlanModules(String lockedModule) {
    if (!lockableModules.contains(lockedModule)) {
      return [...defaultEnabled];
    }

    return [basicInfo, lockedModule, reports];
  }

  /// pro 可用全部模板
  static List<String> proEnabledModules() {
    return [basicInfo, ...proModules, reports];
  }
}

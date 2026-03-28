//lib/core/constants/shop_modules.dart

class ShopModules {
  static const basicInfo = 'basic_info';
  static const catHotel = 'cat_hotel';
  static const dogHotel = 'dog_hotel';
  static const grooming = 'grooming';
  static const hospital = 'hospital';
  static const store = 'store';
  static const reports = 'reports';

  static const all = [
    basicInfo,
    catHotel,
    dogHotel,
    grooming,
    hospital,
    store,
    reports,
  ];

  /// 目前先給最基本可用模組
  static const defaultEnabled = [
    basicInfo,
    catHotel,
    reports,
  ];
}
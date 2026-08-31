// lib/core/models/housekeeping_setting_model.dart
// 🧹 房務設定 Model
// 功能：保存店家的房務、自動清潔與每日照護紀錄設定。

class HousekeepingSettingModel {
  const HousekeepingSettingModel({
    this.autoCleaningAfterCheckout = true,
    this.dailyCareEnabled = false,
    this.dailyCareSessionCount = 2,
    this.carePhotoEnabled = true,
    this.maxPhotosPerSession = 3,
    this.cameraEnabled = false,
    this.downloadHoursAfterCheckout = 24,
  });

  /// 退房後自動進入清潔中
  final bool autoCleaningAfterCheckout;

  /// 是否啟用每日照護紀錄
  final bool dailyCareEnabled;

  /// 每天需要填寫幾次照護紀錄
  ///
  /// 預設一天 2 次。顯示名稱由 dailyCareSetting.sessionLabels 決定。
  final int dailyCareSessionCount;

  /// 是否允許店員上傳照護照片
  final bool carePhotoEnabled;

  /// 每一場照護紀錄最多可上傳幾張照片
  final int maxPhotosPerSession;

  /// 是否啟用 24H 攝影機入口
  final bool cameraEnabled;

  /// 退房後多久仍可下載完整紀錄與照片
  ///
  /// 預設 24 小時。
  final int downloadHoursAfterCheckout;

  factory HousekeepingSettingModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const HousekeepingSettingModel();
    }

    return HousekeepingSettingModel(
      autoCleaningAfterCheckout: map['autoCleaningAfterCheckout'] is bool
          ? map['autoCleaningAfterCheckout'] as bool
          : true,
      dailyCareEnabled: map['dailyCareEnabled'] is bool
          ? map['dailyCareEnabled'] as bool
          : false,
      dailyCareSessionCount: _readPositiveInt(
        map['dailyCareSessionCount'],
        fallback: 2,
      ),
      carePhotoEnabled: map['carePhotoEnabled'] is bool
          ? map['carePhotoEnabled'] as bool
          : true,
      maxPhotosPerSession: _readPositiveInt(
        map['maxPhotosPerSession'],
        fallback: 3,
      ),
      cameraEnabled: map['cameraEnabled'] is bool
          ? map['cameraEnabled'] as bool
          : false,
      downloadHoursAfterCheckout: _readPositiveInt(
        map['downloadHoursAfterCheckout'],
        fallback: 24,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'autoCleaningAfterCheckout': autoCleaningAfterCheckout,
      'dailyCareEnabled': dailyCareEnabled,
      'dailyCareSessionCount': dailyCareSessionCount,
      'carePhotoEnabled': carePhotoEnabled,
      'maxPhotosPerSession': maxPhotosPerSession,
      'cameraEnabled': cameraEnabled,
      'downloadHoursAfterCheckout': downloadHoursAfterCheckout,
    };
  }

  HousekeepingSettingModel copyWith({
    bool? autoCleaningAfterCheckout,
    bool? dailyCareEnabled,
    int? dailyCareSessionCount,
    bool? carePhotoEnabled,
    int? maxPhotosPerSession,
    bool? cameraEnabled,
    int? downloadHoursAfterCheckout,
  }) {
    return HousekeepingSettingModel(
      autoCleaningAfterCheckout:
          autoCleaningAfterCheckout ?? this.autoCleaningAfterCheckout,
      dailyCareEnabled: dailyCareEnabled ?? this.dailyCareEnabled,
      dailyCareSessionCount:
          dailyCareSessionCount ?? this.dailyCareSessionCount,
      carePhotoEnabled: carePhotoEnabled ?? this.carePhotoEnabled,
      maxPhotosPerSession: maxPhotosPerSession ?? this.maxPhotosPerSession,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      downloadHoursAfterCheckout:
          downloadHoursAfterCheckout ?? this.downloadHoursAfterCheckout,
    );
  }

  static int _readPositiveInt(Object? value, {required int fallback}) {
    if (value is int && value > 0) {
      return value;
    }

    if (value is num && value > 0) {
      return value.toInt();
    }

    return fallback;
  }
}

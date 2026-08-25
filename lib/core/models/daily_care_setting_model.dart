// lib/core/models/daily_care_setting_model.dart
// 🐾 每日照護紀錄設定 Model
// 功能：保存店家每日照護紀錄的啟用狀態、填寫次數、
// 顯示欄位、自訂欄位、照片功能與退房後下載期限。

/// 🧩 店家自訂照護欄位
///
/// 店家可以依自己的照護流程新增欄位，
/// 例如：吃藥、梳毛、精神狀況、清耳朵等。
class DailyCareCustomField {
  const DailyCareCustomField({
    required this.id,
    required this.label,
    required this.category,
    required this.inputType,
  });

  /// 自訂欄位固定 ID
  ///
  /// 例如：
  /// custom_1720000000000
  final String id;

  /// 顯示名稱
  ///
  /// 例如：
  /// 吃藥
  /// 梳毛
  /// 精神狀況
  final String label;

  /// 欄位分類
  ///
  /// food     = 飲食與飲水
  /// toilet   = 大小便狀況
  /// activity = 活動與玩樂
  /// relax    = 放鬆與用品
  /// other    = 其他紀錄
  final String category;

  /// 填寫方式
  ///
  /// yesNo     = 有 / 無
  /// amount    = 無 / 少 / 一般 / 多
  /// condition = 正常 / 偏少 / 偏多 / 異常
  /// text      = 自由文字
  final String inputType;

  /// 從 Firestore Map 建立自訂欄位
  factory DailyCareCustomField.fromMap(Map<String, dynamic> map) {
    return DailyCareCustomField(
      id: map['id']?.toString().trim() ?? '',
      label: map['label']?.toString().trim() ?? '',
      category: map['category']?.toString().trim() ?? 'other',
      inputType: map['inputType']?.toString().trim() ?? 'yesNo',
    );
  }

  /// 轉成 Firestore Map
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'category': category,
      'inputType': inputType,
    };
  }

  /// 複製並修改部分內容
  DailyCareCustomField copyWith({
    String? id,
    String? label,
    String? category,
    String? inputType,
  }) {
    return DailyCareCustomField(
      id: id ?? this.id,
      label: label ?? this.label,
      category: category ?? this.category,
      inputType: inputType ?? this.inputType,
    );
  }
}

/// 🐾 每日照護紀錄設定
class DailyCareSettingModel {
  const DailyCareSettingModel({
    this.enabled = false,
    this.sessionCount = 2,
    this.enabledFields = const <String>[
      'water',
      'dryFood',
      'wetFood',
      'snack',
      'stool',
      'urine',
      'wandToy',
      'scratchBoard',
      'jumpPlatform',
      'toyBall',
      'catHouse',
      'catnip',
      'silverVine',
      'catGrass',
      'generalNote',
      'petNotes',
    ],
    this.customFields = const <DailyCareCustomField>[],
    this.photoEnabled = true,
    this.downloadHoursAfterCheckout = 24,
  });

  /// 是否啟用每日照護紀錄
  final bool enabled;

  /// 每房每天需要填寫幾次
  ///
  /// 例如：
  /// 1 = 每天一次
  /// 2 = 上午、晚上
  /// 3 = 上午、下午、晚上
  final int sessionCount;

  /// 店家選擇要填寫的系統內建照護欄位
  final List<String> enabledFields;

  /// 店家自行新增的照護欄位
  ///
  /// 例如：
  /// 吃藥
  /// 梳毛
  /// 精神狀況
  final List<DailyCareCustomField> customFields;

  /// 是否啟用照護照片
  final bool photoEnabled;

  /// 退房後可下載紀錄與照片的時間
  final int downloadHoursAfterCheckout;

  /// 從 Firestore Map 建立設定
  factory DailyCareSettingModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const DailyCareSettingModel();
    }

    final Object? rawFields = map['enabledFields'];
    final Object? rawCustomFields = map['customFields'];

    return DailyCareSettingModel(
      enabled: map['enabled'] is bool ? map['enabled'] as bool : false,

      sessionCount: _readSessionCount(map['sessionCount']),

      enabledFields: rawFields is List
          ? rawFields
                .whereType<String>()
                .map((String value) => value.trim())
                .where((String value) => value.isNotEmpty)
                .toList()
          : const DailyCareSettingModel().enabledFields,

      customFields: rawCustomFields is List
          ? rawCustomFields
                .whereType<Map>()
                .map(
                  (Map value) => DailyCareCustomField.fromMap(
                    Map<String, dynamic>.from(value),
                  ),
                )
                .where(
                  (DailyCareCustomField field) =>
                      field.id.isNotEmpty && field.label.isNotEmpty,
                )
                .toList()
          : const <DailyCareCustomField>[],

      photoEnabled: map['photoEnabled'] is bool
          ? map['photoEnabled'] as bool
          : true,

      downloadHoursAfterCheckout: _readDownloadHours(
        map['downloadHoursAfterCheckout'],
      ),
    );
  }

  /// 轉成 Firestore Map
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'enabled': enabled,
      'sessionCount': sessionCount,
      'enabledFields': enabledFields,
      'customFields': customFields
          .map((DailyCareCustomField field) => field.toMap())
          .toList(),
      'photoEnabled': photoEnabled,
      'downloadHoursAfterCheckout': downloadHoursAfterCheckout,
    };
  }

  /// 複製設定並修改部分內容
  DailyCareSettingModel copyWith({
    bool? enabled,
    int? sessionCount,
    List<String>? enabledFields,
    List<DailyCareCustomField>? customFields,
    bool? photoEnabled,
    int? downloadHoursAfterCheckout,
  }) {
    return DailyCareSettingModel(
      enabled: enabled ?? this.enabled,
      sessionCount: sessionCount ?? this.sessionCount,
      enabledFields: enabledFields ?? this.enabledFields,
      customFields: customFields ?? this.customFields,
      photoEnabled: photoEnabled ?? this.photoEnabled,
      downloadHoursAfterCheckout:
          downloadHoursAfterCheckout ?? this.downloadHoursAfterCheckout,
    );
  }

  /// 驗證每天填寫次數
  static int _readSessionCount(Object? value) {
    if (value is num) {
      final int result = value.toInt();

      if (result >= 1 && result <= 3) {
        return result;
      }
    }

    return 2;
  }

  /// 驗證退房後下載期限
  static int _readDownloadHours(Object? value) {
    if (value is num) {
      final int result = value.toInt();

      if (<int>[12, 24, 48, 72].contains(result)) {
        return result;
      }
    }

    return 24;
  }
}

// lib/core/models/daily_care_setting_model.dart
// 🐾 每日照護紀錄設定 Model
// 功能：保存店家每日照護紀錄的啟用狀態、填寫次數、
// 顯示欄位、自訂欄位、照片功能、日誌外觀與退房後下載期限。

import 'package:flutter/material.dart';

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

/// 🎨 每日照護日誌外觀
///
/// backgroundType：
/// system = 系統預設底色
/// color  = 內建色卡
/// image  = 店家自訂背景圖片
///
/// 未來可再擴充官方主題／節慶圖，不必改舊欄位語意。
class DailyCareJournalTheme {
  static const String typeSystem = 'system';
  static const String typeColor = 'color';
  static const String typeImage = 'image';

  static const String colorDefault = 'default';
  static const String colorWarm = 'warm';
  static const String colorBlue = 'blue';
  static const String colorPink = 'pink';
  static const String colorGreen = 'green';

  static const String fitCover = 'cover';
  static const String fitContain = 'contain';

  static const String fadeNone = 'none';
  static const String fadeLight = 'light';
  static const String fadeHeavy = 'heavy';

  static const String cardTypeSolid = 'solid';
  static const String cardTypePreset = 'preset';
  static const String cardTypeImage = 'image';

  static const String cardPresetNone = 'none';
  static const String cardPresetPaw = 'paw_soft';
  static const String cardPresetLeaf = 'leaf_soft';
  static const String cardPresetCat = 'cat_line';
  static const String cardPresetHome = 'home_soft';
  static const String cardPresetGeo = 'geo_soft';

  static const String cardAssetFolder =
      'assets/daily_care/card_backgrounds';

  static const List<DailyCareCardBackgroundPreset> cardPresets =
      <DailyCareCardBackgroundPreset>[
        DailyCareCardBackgroundPreset(
          key: cardPresetNone,
          label: '無圖 / 純白',
        ),
        DailyCareCardBackgroundPreset(
          key: cardPresetPaw,
          label: '淡腳印',
          assetPath: '$cardAssetFolder/paw_soft.png',
        ),
        DailyCareCardBackgroundPreset(
          key: cardPresetLeaf,
          label: '淡葉子',
          assetPath: '$cardAssetFolder/leaf_soft.png',
        ),
        DailyCareCardBackgroundPreset(
          key: cardPresetCat,
          label: '淡貓咪線稿',
          assetPath: '$cardAssetFolder/cat_line.png',
        ),
        DailyCareCardBackgroundPreset(
          key: cardPresetHome,
          label: '淡居家',
          assetPath: '$cardAssetFolder/home_soft.png',
        ),
        DailyCareCardBackgroundPreset(
          key: cardPresetGeo,
          label: '淡幾何',
          assetPath: '$cardAssetFolder/geo_soft.png',
        ),
      ];

  static const int sessionLabelMaxLength = 12;

  static DailyCareCardBackgroundPreset? cardPresetByKey(String key) {
    for (final DailyCareCardBackgroundPreset preset in cardPresets) {
      if (preset.key == key) {
        return preset;
      }
    }
    return null;
  }
}

/// 系統內建卡片背景（Firestore 只存 key，不存 asset URL）
class DailyCareCardBackgroundPreset {
  const DailyCareCardBackgroundPreset({
    required this.key,
    required this.label,
    this.assetPath = '',
  });

  final String key;
  final String label;
  final String assetPath;

  bool get hasAsset => assetPath.trim().isNotEmpty;
}

/// 🐾 每日照護紀錄設定
class DailyCareSettingModel {
  const DailyCareSettingModel({
    this.enabled = false,
    this.sessionCount = 2,
    this.sessionLabels = const <String>[],
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
    this.backgroundType = DailyCareJournalTheme.typeSystem,
    this.backgroundColorKey = DailyCareJournalTheme.colorDefault,
    this.backgroundImageUrl = '',
    this.backgroundImagePath = '',
    this.backgroundImageFit = DailyCareJournalTheme.fitCover,
    this.backgroundImageFade = DailyCareJournalTheme.fadeLight,
    this.cardBackgroundType = DailyCareJournalTheme.cardTypeSolid,
    this.cardBackgroundPreset = DailyCareJournalTheme.cardPresetNone,
    this.cardBackgroundImageUrl = '',
    this.cardBackgroundImagePath = '',
    this.cardBackgroundImageFit = DailyCareJournalTheme.fitCover,
    this.cardBackgroundImageFade = DailyCareJournalTheme.fadeLight,
  });

  /// 是否啟用每日照護紀錄
  final bool enabled;

  /// 每房每天需要填寫幾次（1 / 2 / 3）
  ///
  /// 資料只認 sessionIndex，不認顯示名稱。
  final int sessionCount;

  /// 照護紀錄顯示名稱
  ///
  /// index 對應 sessionIndex，不可用名稱當 ID。
  /// 舊店家已有自訂值（含上午場／下午場／晚上場）會原樣保留。
  /// 沒有 sessionLabels 或欄位空白時，才用中性 fallback。
  final List<String> sessionLabels;

  /// 日誌背景類型：system / color / image
  final String backgroundType;

  /// 內建色卡 key：default / warm / blue / pink / green
  final String backgroundColorKey;

  /// 自訂背景圖片下載網址
  final String backgroundImageUrl;

  /// 自訂背景圖片 Storage path，刪除時優先使用
  final String backgroundImagePath;

  /// 背景圖片顯示：cover / contain
  final String backgroundImageFit;

  /// 背景圖片淡化：none / light / heavy
  final String backgroundImageFade;

  /// 內容卡片背景：solid / preset / image
  final String cardBackgroundType;

  /// 系統內建卡片背景 key（不含 asset URL）
  final String cardBackgroundPreset;

  /// 店家自訂卡片背景下載網址（所有內容卡片共用）
  final String cardBackgroundImageUrl;

  /// 店家自訂卡片背景 Storage path
  final String cardBackgroundImagePath;

  /// 卡片圖片顯示：cover / contain
  final String cardBackgroundImageFit;

  /// 卡片圖片淡化：none / light / heavy
  final String cardBackgroundImageFade;

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
    final int sessionCount = _readSessionCount(map['sessionCount']);

    return DailyCareSettingModel(
      enabled: map['enabled'] is bool ? map['enabled'] as bool : false,

      sessionCount: sessionCount,
      sessionLabels: _readSessionLabels(map['sessionLabels'], sessionCount),
      backgroundType: _readBackgroundType(map['backgroundType']),
      backgroundColorKey: _readBackgroundColorKey(map['backgroundColorKey']),
      backgroundImageUrl: _readString(map['backgroundImageUrl']),
      backgroundImagePath: _readString(map['backgroundImagePath']),
      backgroundImageFit: _readBackgroundFit(map['backgroundImageFit']),
      backgroundImageFade: _readBackgroundFade(map['backgroundImageFade']),
      cardBackgroundType: _readCardBackgroundType(map['cardBackgroundType']),
      cardBackgroundPreset: _readCardBackgroundPreset(
        map['cardBackgroundPreset'],
      ),
      cardBackgroundImageUrl: _readString(map['cardBackgroundImageUrl']),
      cardBackgroundImagePath: _readString(map['cardBackgroundImagePath']),
      cardBackgroundImageFit: _readBackgroundFit(
        map['cardBackgroundImageFit'],
      ),
      cardBackgroundImageFade: _readBackgroundFade(
        map['cardBackgroundImageFade'],
      ),

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
      'sessionLabels': resolvedSessionLabels(),
      'backgroundType': backgroundType,
      'backgroundColorKey': backgroundColorKey,
      'backgroundImageUrl': backgroundImageUrl,
      'backgroundImagePath': backgroundImagePath,
      'backgroundImageFit': backgroundImageFit,
      'backgroundImageFade': backgroundImageFade,
      'cardBackgroundType': cardBackgroundType,
      'cardBackgroundPreset': cardBackgroundPreset,
      'cardBackgroundImageUrl': cardBackgroundImageUrl,
      'cardBackgroundImagePath': cardBackgroundImagePath,
      'cardBackgroundImageFit': cardBackgroundImageFit,
      'cardBackgroundImageFade': cardBackgroundImageFade,
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
    List<String>? sessionLabels,
    List<String>? enabledFields,
    List<DailyCareCustomField>? customFields,
    bool? photoEnabled,
    int? downloadHoursAfterCheckout,
    String? backgroundType,
    String? backgroundColorKey,
    String? backgroundImageUrl,
    String? backgroundImagePath,
    String? backgroundImageFit,
    String? backgroundImageFade,
    String? cardBackgroundType,
    String? cardBackgroundPreset,
    String? cardBackgroundImageUrl,
    String? cardBackgroundImagePath,
    String? cardBackgroundImageFit,
    String? cardBackgroundImageFade,
  }) {
    return DailyCareSettingModel(
      enabled: enabled ?? this.enabled,
      sessionCount: sessionCount ?? this.sessionCount,
      sessionLabels: sessionLabels ?? this.sessionLabels,
      enabledFields: enabledFields ?? this.enabledFields,
      customFields: customFields ?? this.customFields,
      photoEnabled: photoEnabled ?? this.photoEnabled,
      downloadHoursAfterCheckout:
          downloadHoursAfterCheckout ?? this.downloadHoursAfterCheckout,
      backgroundType: backgroundType ?? this.backgroundType,
      backgroundColorKey: backgroundColorKey ?? this.backgroundColorKey,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      backgroundImageFit: backgroundImageFit ?? this.backgroundImageFit,
      backgroundImageFade: backgroundImageFade ?? this.backgroundImageFade,
      cardBackgroundType: cardBackgroundType ?? this.cardBackgroundType,
      cardBackgroundPreset: cardBackgroundPreset ?? this.cardBackgroundPreset,
      cardBackgroundImageUrl:
          cardBackgroundImageUrl ?? this.cardBackgroundImageUrl,
      cardBackgroundImagePath:
          cardBackgroundImagePath ?? this.cardBackgroundImagePath,
      cardBackgroundImageFit:
          cardBackgroundImageFit ?? this.cardBackgroundImageFit,
      cardBackgroundImageFade:
          cardBackgroundImageFade ?? this.cardBackgroundImageFade,
    );
  }

  /// 依 sessionCount 回傳完整顯示名稱（含舊資料 fallback）
  List<String> resolvedSessionLabels() {
    final List<String> defaults = defaultSessionLabels(sessionCount);
    return List<String>.generate(sessionCount, (int index) {
      if (index < sessionLabels.length) {
        final String label = sessionLabels[index].trim();
        if (label.isNotEmpty) {
          return label;
        }
      }
      return defaults[index];
    });
  }

  /// 以 sessionIndex 取顯示名稱，舊紀錄仍靠 index 對應
  String sessionLabel(int sessionIndex) {
    final List<String> labels = resolvedSessionLabels();
    if (sessionIndex >= 0 && sessionIndex < labels.length) {
      return labels[sessionIndex];
    }
    return fallbackSessionLabel(sessionIndex);
  }

  bool get hasCustomBackgroundImage {
    return backgroundType == DailyCareJournalTheme.typeImage &&
        backgroundImageUrl.trim().isNotEmpty;
  }

  bool get hasCustomCardBackgroundImage {
    return cardBackgroundType == DailyCareJournalTheme.cardTypeImage &&
        cardBackgroundImageUrl.trim().isNotEmpty;
  }

  DailyCareCardBackgroundPreset get resolvedCardPreset {
    return DailyCareJournalTheme.cardPresetByKey(cardBackgroundPreset) ??
        DailyCareJournalTheme.cardPresets.first;
  }

  /// 內容卡片是否要畫圖案／自訂圖（純色則否）
  /// 自訂圖以 URL 為準；內建圖即使還沒放 asset 也要能畫 fallback。
  bool get hasCardBackgroundVisual {
    if (cardBackgroundType == DailyCareJournalTheme.cardTypeSolid) {
      return false;
    }
    if (hasCustomCardBackgroundImage) {
      return true;
    }
    if (cardBackgroundType == DailyCareJournalTheme.cardTypePreset) {
      return cardBackgroundPreset != DailyCareJournalTheme.cardPresetNone;
    }
    return cardBackgroundImageUrl.trim().isNotEmpty;
  }

  BoxFit resolvedCardImageFit() {
    return cardBackgroundImageFit == DailyCareJournalTheme.fitContain
        ? BoxFit.contain
        : BoxFit.cover;
  }

  /// 卡片白色 overlay：原圖要看得出圖案，很淡才接近白卡。
  /// longText：今日概況再多蓋一層，但仍要看得到背景。
  double resolvedCardOverlayOpacity({bool longText = false}) {
    final double base = switch (cardBackgroundImageFade) {
      DailyCareJournalTheme.fadeNone => 0.58,
      DailyCareJournalTheme.fadeHeavy => 0.82,
      _ => 0.70,
    };
    if (!longText) {
      return base;
    }
    return (base + 0.10).clamp(0.0, 0.92);
  }

  Color backgroundColor() {
    switch (backgroundColorKey) {
      case DailyCareJournalTheme.colorWarm:
        return const Color(0xFFF6EFE4);
      case DailyCareJournalTheme.colorBlue:
        return const Color(0xFFE8F1F8);
      case DailyCareJournalTheme.colorPink:
        return const Color(0xFFF8E9EE);
      case DailyCareJournalTheme.colorGreen:
        return const Color(0xFFE8F3EA);
      case DailyCareJournalTheme.colorDefault:
      default:
        return const Color(0xFFF5F6F8);
    }
  }

  Color resolvedPageColor() {
    if (backgroundType == DailyCareJournalTheme.typeColor) {
      return backgroundColor();
    }
    return const Color(0xFFF5F6F8);
  }

  BoxFit resolvedImageFit() {
    return backgroundImageFit == DailyCareJournalTheme.fitContain
        ? BoxFit.contain
        : BoxFit.cover;
  }

  double resolvedImageOverlayOpacity() {
    switch (backgroundImageFade) {
      case DailyCareJournalTheme.fadeNone:
        return 0.32;
      case DailyCareJournalTheme.fadeHeavy:
        return 0.66;
      case DailyCareJournalTheme.fadeLight:
      default:
        return 0.48;
    }
  }

  /// 頁面圖淡化用暖米色，避免洗成冷灰。
  Color resolvedPageOverlayColor() {
    return const Color(0xFFFFF9F1).withValues(
      alpha: resolvedImageOverlayOpacity(),
    );
  }

  /// 缺少自訂名稱時的中性 fallback，不綁早中晚。
  static String fallbackSessionLabel(int sessionIndex) {
    return '第 ${sessionIndex + 1} 次照護';
  }

  static List<String> defaultSessionLabels(int sessionCount) {
    final int count = _readSessionCount(sessionCount);
    return List<String>.generate(count, fallbackSessionLabel);
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

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static List<String> _readSessionLabels(Object? value, int sessionCount) {
    final List<String> defaults = defaultSessionLabels(sessionCount);
    final List<String> raw = value is List
        ? value
              .map((dynamic item) => item?.toString().trim() ?? '')
              .toList()
        : const <String>[];

    return List<String>.generate(sessionCount, (int index) {
      if (index < raw.length && raw[index].isNotEmpty) {
        return raw[index];
      }
      return defaults[index];
    });
  }

  static String _readBackgroundType(Object? value) {
    final String type = _readString(value);
    if (type == DailyCareJournalTheme.typeColor ||
        type == DailyCareJournalTheme.typeImage ||
        type == DailyCareJournalTheme.typeSystem) {
      return type;
    }
    return DailyCareJournalTheme.typeSystem;
  }

  static String _readBackgroundColorKey(Object? value) {
    final String key = _readString(value);
    switch (key) {
      case DailyCareJournalTheme.colorWarm:
      case DailyCareJournalTheme.colorBlue:
      case DailyCareJournalTheme.colorPink:
      case DailyCareJournalTheme.colorGreen:
      case DailyCareJournalTheme.colorDefault:
        return key;
      default:
        return DailyCareJournalTheme.colorDefault;
    }
  }

  static String _readBackgroundFit(Object? value) {
    final String fit = _readString(value);
    if (fit == DailyCareJournalTheme.fitContain) {
      return DailyCareJournalTheme.fitContain;
    }
    return DailyCareJournalTheme.fitCover;
  }

  static String _readBackgroundFade(Object? value) {
    final String fade = _readString(value);
    if (fade == DailyCareJournalTheme.fadeNone ||
        fade == DailyCareJournalTheme.fadeHeavy) {
      return fade;
    }
    return DailyCareJournalTheme.fadeLight;
  }

  static String _readCardBackgroundType(Object? value) {
    final String type = _readString(value);
    if (type == DailyCareJournalTheme.cardTypePreset ||
        type == DailyCareJournalTheme.cardTypeImage ||
        type == DailyCareJournalTheme.cardTypeSolid) {
      return type;
    }
    return DailyCareJournalTheme.cardTypeSolid;
  }

  static String _readCardBackgroundPreset(Object? value) {
    final String key = _readString(value);
    if (DailyCareJournalTheme.cardPresetByKey(key) != null) {
      return key;
    }
    return DailyCareJournalTheme.cardPresetNone;
  }
}

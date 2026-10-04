// 檔案名稱：lib/core/models/platform_media_asset.dart
// 功能說明：平台共用外觀圖庫素材。Firestore：platform_media_library。

import 'package:cloud_firestore/cloud_firestore.dart';

/// 平台圖庫分類。可新增未來分類，不要把服務寫死成只有兩種。
abstract final class PlatformMediaCategories {
  static const String dailyCarePage = 'dailyCarePage';
  static const String dailyCareCard = 'dailyCareCard';
  static const String dailyCareIcon = 'dailyCareIcon';
  static const String shopHouse = 'shopHouse';

  static const List<String> known = <String>[
    dailyCarePage,
    dailyCareCard,
    dailyCareIcon,
    shopHouse,
  ];

  static String label(String category) {
    switch (category) {
      case dailyCarePage:
        return '每日照護頁背景';
      case dailyCareCard:
        return '每日照護卡片背景';
      case dailyCareIcon:
        return '每日照護小圖示';
      case shopHouse:
        return '店家小屋';
      default:
        return category;
    }
  }

  static String hint(String category) {
    switch (category) {
      case dailyCarePage:
        return '建議直式 9:16';
      case dailyCareCard:
        return '建議橫式 4:3 或 3:2';
      case dailyCareIcon:
        return '建議 256 × 256 正方形、透明背景 PNG 或 WebP，四周保留安全空間';
      case shopHouse:
        return '依允許使用區域的建議選擇圖片。不符仍可上傳。';
      default:
        return '';
    }
  }
}

/// 店家小屋可套用的區域。一張素材可勾選多個。
abstract final class ShopHousePlacements {
  static const String roof = 'house.roof';
  static const String wall = 'house.wall';
  static const String windowFrame = 'house.windowFrame';
  static const String decorationLeft = 'house.decorationLeft';
  static const String decorationRight = 'house.decorationRight';
  static const String decorationTop = 'house.decorationTop';
  static const String base = 'house.base';

  static const List<String> known = <String>[
    roof,
    wall,
    windowFrame,
    decorationLeft,
    decorationRight,
    decorationTop,
    base,
  ];

  static String label(String placement) {
    switch (placement) {
      case roof:
        return '屋頂';
      case wall:
        return '牆面／室內背景';
      case windowFrame:
        return '照片窗框';
      case decorationLeft:
        return '左側裝飾';
      case decorationRight:
        return '右側裝飾';
      case decorationTop:
        return '上方裝飾';
      case base:
        return '底座／地板';
      default:
        return placement;
    }
  }

  static String shortLabel(String placement) {
    switch (placement) {
      case roof:
        return '屋頂';
      case wall:
        return '牆面';
      case windowFrame:
        return '照片窗框';
      case decorationLeft:
        return '左側裝飾';
      case decorationRight:
        return '右側裝飾';
      case decorationTop:
        return '上方裝飾';
      case base:
        return '底座';
      default:
        return placement;
    }
  }

  static String defaultLabel(String placement) {
    switch (placement) {
      case roof:
        return '預設暖木屋頂';
      case wall:
        return '預設暖白';
      case windowFrame:
        return '預設木質窗框';
      case base:
        return '預設木質底座';
      default:
        return '預設';
    }
  }

  static String hint(String placement) {
    switch (placement) {
      case roof:
        return '屋頂建議：透明背景 PNG 或 WebP，橫向素材。';
      case wall:
        return '牆面／室內背景建議：JPG、PNG 或 WebP，適合大面積背景。';
      case windowFrame:
        return '照片窗框建議：透明背景 PNG 或 WebP。';
      case decorationLeft:
      case decorationRight:
        return '左右裝飾建議：透明背景 PNG 或 WebP。';
      case decorationTop:
        return '上方裝飾建議：透明背景 PNG 或 WebP。';
      case base:
        return '底座／地板建議：透明背景 PNG 或 WebP，橫向素材。';
      default:
        return '';
    }
  }

  static String usageText(Iterable<String> placements) {
    final List<String> labels = <String>[
      for (final String placement in known)
        if (placements.contains(placement)) '・${label(placement)}',
    ];
    if (labels.isEmpty) {
      return '店家小屋';
    }
    return '店家小屋\n${labels.join('\n')}';
  }
}

class PlatformMediaAsset {
  const PlatformMediaAsset({
    required this.id,
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.storagePath,
    required this.width,
    required this.height,
    required this.fileBytes,
    required this.sortOrder,
    required this.enabled,
    this.placements = const <String>[],
    this.createdAt,
    this.updatedAt,
    this.createdByUid = '',
    this.createdByEmail = '',
  });

  final String id;
  final String name;
  final String category;
  final List<String> placements;
  final String imageUrl;
  final String thumbnailUrl;
  final String storagePath;
  final int width;
  final int height;
  final int fileBytes;
  final int sortOrder;
  final bool enabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdByUid;
  final String createdByEmail;

  factory PlatformMediaAsset.fromMap(String id, Map<String, dynamic>? map) {
    if (map == null) {
      return PlatformMediaAsset(
        id: id,
        name: '',
        category: '',
        placements: const <String>[],
        imageUrl: '',
        thumbnailUrl: '',
        storagePath: '',
        width: 0,
        height: 0,
        fileBytes: 0,
        sortOrder: 0,
        enabled: false,
      );
    }
    final String imageUrl = _readString(map['imageUrl']);
    final String thumbnailUrl = _readString(map['thumbnailUrl']);
    return PlatformMediaAsset(
      id: id,
      name: _readString(map['name']),
      category: _readString(map['category']),
      placements: _readPlacements(map['placements']),
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl.isEmpty ? imageUrl : thumbnailUrl,
      storagePath: _readString(map['storagePath']),
      width: _readInt(map['width']),
      height: _readInt(map['height']),
      fileBytes: _readInt(map['fileBytes']),
      sortOrder: _readInt(map['sortOrder']),
      enabled: map['enabled'] == true,
      createdAt: _readTime(map['createdAt']),
      updatedAt: _readTime(map['updatedAt']),
      createdByUid: _readString(map['createdByUid']),
      createdByEmail: _readString(map['createdByEmail']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'category': category,
      'placements': placements,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl.isEmpty ? imageUrl : thumbnailUrl,
      'storagePath': storagePath,
      'width': width,
      'height': height,
      'fileBytes': fileBytes,
      'sortOrder': sortOrder,
      'enabled': enabled,
      'createdByUid': createdByUid,
      'createdByEmail': createdByEmail,
    };
  }

  PlatformMediaAsset copyWith({
    String? id,
    String? name,
    String? category,
    List<String>? placements,
    String? imageUrl,
    String? thumbnailUrl,
    String? storagePath,
    int? width,
    int? height,
    int? fileBytes,
    int? sortOrder,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByUid,
    String? createdByEmail,
  }) {
    return PlatformMediaAsset(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      placements: placements ?? this.placements,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      storagePath: storagePath ?? this.storagePath,
      width: width ?? this.width,
      height: height ?? this.height,
      fileBytes: fileBytes ?? this.fileBytes,
      sortOrder: sortOrder ?? this.sortOrder,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByEmail: createdByEmail ?? this.createdByEmail,
    );
  }

  bool allowsPlacement(String placement) {
    return category == PlatformMediaCategories.shopHouse &&
        placements.contains(placement);
  }

  static List<String> _readPlacements(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    final List<String> result = <String>[];
    for (final Object? item in value) {
      final String key = item?.toString().trim() ?? '';
      if (ShopHousePlacements.known.contains(key) && !result.contains(key)) {
        result.add(key);
      }
    }
    return result;
  }

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _readTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

// 檔案名稱：lib/core/models/platform_media_asset.dart
// 功能說明：平台共用外觀圖庫素材。Firestore：platform_media_library。

import 'package:cloud_firestore/cloud_firestore.dart';

/// 平台圖庫分類。可新增未來分類，不要把服務寫死成只有兩種。
abstract final class PlatformMediaCategories {
  static const String dailyCarePage = 'dailyCarePage';
  static const String dailyCareCard = 'dailyCareCard';

  static const List<String> known = <String>[dailyCarePage, dailyCareCard];

  static String label(String category) {
    switch (category) {
      case dailyCarePage:
        return '每日照護頁背景';
      case dailyCareCard:
        return '每日照護卡片背景';
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
      default:
        return '';
    }
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
    this.createdAt,
    this.updatedAt,
    this.createdByUid = '',
    this.createdByEmail = '',
  });

  final String id;
  final String name;
  final String category;
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

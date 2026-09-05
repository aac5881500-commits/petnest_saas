// 檔案名稱：lib/core/models/platform_admin_model.dart
// 功能說明：平台最高管理員、開發管理員、平台員工共用資料模型。
// 👑 平台管理員 Model

import 'package:cloud_firestore/cloud_firestore.dart';

class PlatformAdminModel {
  const PlatformAdminModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.enabled,
    required this.permissions,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String name;
  final String email;

  /// super_admin / developer_admin / platform_staff
  final String role;

  /// 是否啟用
  final bool enabled;

  /// 權限清單
  final List<String> permissions;

  /// 建立者 UID
  final String? createdBy;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory PlatformAdminModel.fromMap(Map<String, dynamic> map) {
    return PlatformAdminModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      enabled: map['enabled'] ?? true,
      permissions: (map['permissions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      createdBy: map['createdBy'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'enabled': enabled,
      'permissions': permissions,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  PlatformAdminModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    bool? enabled,
    List<String>? permissions,
    String? createdBy,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return PlatformAdminModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      enabled: enabled ?? this.enabled,
      permissions: permissions ?? this.permissions,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

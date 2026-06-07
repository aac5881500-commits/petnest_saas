// lib/features/auth/widgets/my_shop_meta_info.dart
// 🧾 我的店家營運資訊區
// 功能：顯示服務類型、營業時間、公開狀態、店家字號、統一編號、最後更新時間

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MyShopMetaInfo extends StatelessWidget {
  const MyShopMetaInfo({
    super.key,
    required this.enabledModules,
    required this.openTime,
    required this.closeTime,
    required this.isPublic,
    required this.licenseNumber,
    required this.taxId,
    required this.updatedAt,
  });

  final List<String> enabledModules;
  final String openTime;
  final String closeTime;
  final bool isPublic;
  final String licenseNumber;
  final String taxId;
  final dynamic updatedAt;

  String _moduleLabel(String value) {
    switch (value) {
      case 'cat_hotel':
        return '貓咪旅館';
      case 'dog_hotel':
        return '狗狗旅館';
      case 'grooming':
        return '寵物美容';
      case 'hospital':
        return '動物醫院';
      case 'store':
        return '寵物賣場';
      case 'basic_info':
        return '基本資訊';
      case 'reports':
        return '報表統計';
      default:
        return value;
    }
  }

  String get _serviceText {
    final modules = enabledModules
        .where((item) => item != 'basic_info' && item != 'reports')
        .map(_moduleLabel)
        .toList();

    if (modules.isEmpty) return '尚未開啟';

    return modules.join('、');
  }

  String get _businessTimeText {
    if (openTime.isEmpty || closeTime.isEmpty) {
      return '尚未設定';
    }

    return '$openTime - $closeTime';
  }

  String _formatUpdatedAt(dynamic value) {
    if (value == null) return '尚未更新';

    DateTime? dateTime;

    if (value is Timestamp) {
      dateTime = value.toDate();
    } else if (value is DateTime) {
      dateTime = value;
    }

    if (dateTime == null) return '尚未更新';

    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${dateTime.year}/'
        '${twoDigits(dateTime.month)}/'
        '${twoDigits(dateTime.day)} '
        '${twoDigits(dateTime.hour)}:'
        '${twoDigits(dateTime.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetaBox(
                  icon: Icons.extension,
                  label: '服務類型',
                  value: _serviceText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetaBox(
                  icon: Icons.visibility,
                  label: '公開狀態',
                  value: isPublic ? '公開中' : '未公開',
                  valueColor: isPublic
                      ? Colors.green.shade700
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Expanded(
                child: _MetaBox(
                  icon: Icons.schedule,
                  label: '營業時間',
                  value: _businessTimeText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetaBox(
                  icon: Icons.update,
                  label: '最後更新',
                  value: _formatUpdatedAt(updatedAt),
                ),
              ),
            ],
          ),

          const SizedBox(width: 6),

          Row(
            children: [
              Expanded(
                child: _MetaBox(
                  icon: Icons.verified,
                  label: '店家字號',
                  value: licenseNumber.isEmpty ? '尚未設定' : licenseNumber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetaBox(
                  icon: Icons.receipt_long,
                  label: '統一編號',
                  value: taxId.isEmpty ? '尚未設定' : taxId,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaBox extends StatelessWidget {
  const _MetaBox({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: valueColor ?? Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }
}

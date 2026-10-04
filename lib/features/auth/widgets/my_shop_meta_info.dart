// 檔案名稱：lib/features/auth/widgets/my_shop_meta_info.dart
// 功能說明：顯示服務類型、營業時間、公開狀態、店家字號、統一編號、最後更新時間
// 🧾 我的店家營運資訊區

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_info.dart';

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
    required this.city,
    required this.district,
    required this.shopId,
    this.businessType = '',
  });

  final List<String> enabledModules;
  final String openTime;
  final String closeTime;
  final bool isPublic;
  final String licenseNumber;
  final String taxId;
  final dynamic updatedAt;
  final String city;
  final String district;
  final String shopId;
  final String businessType;

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

    if (modules.isEmpty) {
      return businessType.trim().isEmpty ? '尚未開啟' : businessType.trim();
    }
    final String type = businessType.trim();
    if (type.isNotEmpty && !modules.contains(type)) {
      return <String>[type, ...modules].join('、');
    }
    return modules.join('、');
  }

  String get _businessTimeText {
    if (openTime.isEmpty || closeTime.isEmpty) {
      return '尚未設定';
    }

    return '$openTime - $closeTime';
  }

  String get _placeText {
    final String left = city.trim();
    final String right = district.trim();
    if (left.isEmpty && right.isEmpty) {
      return '尚未設定';
    }
    if (left.isEmpty) {
      return right;
    }
    if (right.isEmpty) {
      return left;
    }
    return '$left・$right';
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
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color publicTone = isPublic
        ? (colors.brightness == Brightness.dark
              ? const Color(0xFF81C784)
              : const Color(0xFF2E7D32))
        : colors.onSurfaceVariant;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final List<Widget> leading = <Widget>[
          _MetaRow(
            icon: Icons.schedule_outlined,
            label: '營業時間',
            value: _businessTimeText,
          ),
          _MetaRow(
            icon: Icons.pets_outlined,
            label: '服務項目',
            value: _serviceText,
          ),
          _MetaRow(
            icon: Icons.visibility_outlined,
            label: '公開狀態',
            value: isPublic ? '公開中' : '未公開',
            valueColor: publicTone,
          ),
          _MetaRow(
            icon: Icons.location_on_outlined,
            label: '地址',
            value: _placeText,
          ),
        ];
        final List<Widget> trailing = <Widget>[
          _MetaRow(
            icon: Icons.badge_outlined,
            label: '店家字號',
            value: licenseNumber.isEmpty ? '尚未設定' : licenseNumber,
          ),
          _MetaRow(
            icon: Icons.receipt_long_outlined,
            label: '統一編號',
            value: taxId.isEmpty ? '尚未設定' : taxId,
          ),
          _MetaRow(
            icon: Icons.update_outlined,
            label: '最後更新',
            value: _formatUpdatedAt(updatedAt),
          ),
          const SizedBox(height: 8),
          MyShopIdLine(shopId: shopId),
        ];
        if (constraints.maxWidth >= 700) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: leading,
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: trailing,
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[...leading, ...trailing],
        );
      },
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
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
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 18, color: colors.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: text.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: valueColor ?? colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

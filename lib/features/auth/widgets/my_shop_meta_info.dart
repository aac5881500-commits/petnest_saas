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
      return businessType.trim().isEmpty ? '尚未設定' : businessType.trim();
    }
    final String type = businessType.trim();
    if (type.isNotEmpty && !modules.contains(type)) {
      return <String>[type, ...modules].join('、');
    }
    return modules.join('、');
  }

  String get _businessTimeText {
    if (openTime.trim().isEmpty || closeTime.trim().isEmpty) {
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
    if (value == null) return '尚未設定';

    DateTime? dateTime;

    if (value is Timestamp) {
      dateTime = value.toDate();
    } else if (value is DateTime) {
      dateTime = value;
    }

    if (dateTime == null) return '尚未設定';

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
    final colors = Theme.of(context).colorScheme;
    final publicTone = isPublic
        ? (colors.brightness == Brightness.dark
              ? const Color(0xFF81C784)
              : const Color(0xFF4E764A))
        : colors.onSurfaceVariant;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : (constraints.maxWidth >= 320 ? 2 : 1);
        const gap = 10.0;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        final fields = <Widget>[
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
            icon: Icons.badge_outlined,
            label: '店家字號',
            value: licenseNumber.trim().isEmpty ? '尚未設定' : licenseNumber,
          ),
          _MetaRow(
            icon: Icons.receipt_long_outlined,
            label: '統一編號',
            value: taxId.trim().isEmpty ? '尚未設定' : taxId,
          ),
          _MetaRow(
            icon: Icons.location_on_outlined,
            label: '地址',
            value: _placeText,
          ),
        ];
        final updated = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.update_outlined,
              size: 16,
              color: Color(0xFF9B845F),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                '最後更新 · ${_formatUpdatedAt(updatedAt)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (int index = 0; index < fields.length; index++)
                  SizedBox(
                    key: ValueKey('shop-profile-field-$index'),
                    width: tileWidth,
                    child: fields[index],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (constraints.maxWidth >= 700)
              Row(
                children: [
                  Expanded(child: updated),
                  const SizedBox(width: 16),
                  SizedBox(width: 240, child: MyShopIdLine(shopId: shopId)),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  updated,
                  const SizedBox(height: 8),
                  MyShopIdLine(shopId: shopId),
                ],
              ),
          ],
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
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dark = colors.brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF403A30) : const Color(0xFFF6F0E3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF4C5140) : const Color(0xFFE9EDDF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 17,
              color: dark ? const Color(0xFFBBC6A2) : const Color(0xFF778265),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: valueColor ?? colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

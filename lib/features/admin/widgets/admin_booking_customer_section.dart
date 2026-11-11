// 檔案名稱：lib/features/admin/widgets/admin_booking_customer_section.dart
// 功能說明：顯示顧客資料、頭像與緊急聯絡人資料

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/widgets/member_avatar.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminBookingCustomerSection extends StatelessWidget {
  const AdminBookingCustomerSection({
    super.key,
    required this.data,
    required this.emergency,
    this.shopId = '',
    this.compact = false,
  });

  final Map<String, dynamic> data;
  final Map<String, dynamic> emergency;
  final String shopId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String name = (data['customerName'] ?? data['name'] ?? '')
        .toString()
        .trim();
    final String userId = (data['userId'] ?? '').toString().trim();
    final String resolvedShopId = shopId.trim().isNotEmpty
        ? shopId.trim()
        : (data['shopId'] ?? '').toString().trim();
    final List<Widget> contact = <Widget>[
      _infoItem('姓名', data['customerName'] ?? data['name']),
      _infoItem('電話', data['customerPhone'] ?? data['phone']),
      _infoItem('地址', data['address']),
    ].where((Widget item) => item is! SizedBox).toList();
    final List<Widget> urgent = <Widget>[
      _infoItem('緊急聯絡人', emergency['name']),
      _infoItem('緊急電話', emergency['phone']),
      _infoItem('關係', emergency['relation']),
      _infoItem('緊急地址', emergency['address']),
    ].where((Widget item) => item is! SizedBox).toList();

    if (compact) {
      final List<Widget> rows = <Widget>[
        if ((data['customerPhone'] ?? data['phone'] ?? '')
            .toString()
            .trim()
            .isNotEmpty)
          _quickPhone(
            context,
            name.isEmpty ? '顧客' : name,
            (data['customerPhone'] ?? data['phone']).toString(),
          ),
        if ((emergency['phone'] ?? '').toString().trim().isNotEmpty)
          _quickPhone(
            context,
            '緊急・${emergency['name'] ?? '聯絡人'}',
            emergency['phone'].toString(),
          ),
      ];
      return AdminBookingDetailCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Text('尚無聯絡資料，請至資料分頁確認'),
              );
            }
            if (constraints.maxWidth >= 640 && rows.length == 2) {
              return Row(
                children: <Widget>[
                  Expanded(child: rows[0]),
                  const SizedBox(width: 24),
                  Expanded(child: rows[1]),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            );
          },
        ),
      );
    }
    final bool phone = AdminBookingDetailScope.of(context).isPhone;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ShopMemberLiveAvatar(
                shopId: resolvedShopId,
                userId: userId,
                name: name.isEmpty ? '會員' : name,
                size: 52,
                booking: data,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name.isEmpty ? '顧客資訊' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (phone)
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: false,
                title: const Text(
                  '一般聯絡與緊急聯絡',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  (data['customerPhone'] ?? data['phone'] ?? '').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                children: <Widget>[_contactGrid(contact, urgent)],
              ),
            )
          else
            _contactGrid(contact, urgent),
        ],
      ),
    );
  }

  Widget _quickPhone(BuildContext context, String label, String number) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  number,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: '複製 $label 電話',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: number));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已複製電話')));
            }
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
        ),
        IconButton(
          tooltip: '撥打 $label',
          onPressed: () async {
            await launchUrl(
              Uri(
                scheme: 'tel',
                path: number.replaceAll(RegExp(r'[^\d+]'), ''),
              ),
            );
          },
          icon: const Icon(Icons.call_outlined, size: 19),
        ),
      ],
    );
  }

  Widget _contactGrid(List<Widget> contact, List<Widget> urgent) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 520 || urgent.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _blockTitle('一般聯絡'),
              ...contact,
              if (urgent.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _blockTitle('緊急聯絡'),
                ...urgent,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[_blockTitle('一般聯絡'), ...contact],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[_blockTitle('緊急聯絡'), ...urgent],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _blockTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _infoItem(String label, dynamic value) {
    final String raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'null') {
      return const SizedBox.shrink();
    }
    final bool phone = label.contains('電話');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  raw,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (phone) ...<Widget>[
                IconButton(
                  tooltip: '複製',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: raw));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                ),
                IconButton(
                  tooltip: '撥號',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final Uri uri = Uri(
                      scheme: 'tel',
                      path: raw.replaceAll(RegExp(r'[^\d+]'), ''),
                    );
                    await launchUrl(uri);
                  },
                  icon: const Icon(Icons.call_outlined, size: 18),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

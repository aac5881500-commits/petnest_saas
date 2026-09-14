// 檔案名稱：lib/features/admin/widgets/admin_booking_detail_policy_card.dart
// 功能說明：店主訂單詳細條款摘要：住宿／安親共用歷史讀取規則

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/shop_policy_history.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/shop/pages/policy_version_detail_page.dart';

class AdminBookingDetailPolicyCard extends StatelessWidget {
  const AdminBookingDetailPolicyCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final bool daycare = BookingKind.isDaycare(data);
    final int version = ShopPolicyHistory.parseVersion(
      data['termsVersion'] ?? data['policyVersion'],
    );
    final bool missing = version <= 0;

    final String title = missing
        ? '舊訂單／尚無條款確認紀錄'
        : (data['policyTitle'] ??
                  data['termsTitle'] ??
                  (daycare ? '安親須知' : '入住須知'))
              .toString();

    final String subtitle = missing
        ? (daycare ? '舊安親訂單沒有條款確認資料' : '尚無版本紀錄')
        : '版本 v$version';

    return AdminBookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            daycare ? '安親條款' : '住宿條款',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: theme.titleColor,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.gavel_rounded, color: theme.primaryColor),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(subtitle),
          ),
          if (!missing)
            Text(
              '同意時間：${_formatAccepted(data['policyAcceptedAt'] ?? data['termsAcceptedAt'])}',
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _open(context),
              icon: const Icon(Icons.history, size: 18),
              label: const Text('查看當時條款內容'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final String shopId = (data['shopId'] ?? '').toString().trim();
    final bool daycare = BookingKind.isDaycare(data);
    final String serviceType = daycare
        ? PolicyApplicableService.daycare
        : PolicyApplicableService.accommodation;
    final int version = ShopPolicyHistory.parseVersion(
      data['termsVersion'] ?? data['policyVersion'],
    );
    final String preferred = (data['termsVersionDocumentId'] ??
            data['policyVersionId'] ??
            '')
        .toString()
        .trim();

    if (shopId.isEmpty || version <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(daycare ? '舊安親訂單／尚無條款確認紀錄' : '舊訂單／尚無條款確認紀錄')),
      );
      return;
    }

    final Map<String, dynamic> snapshot = await ShopPolicyService.instance
        .loadPolicyVersionSnapshot(
          shopId: shopId,
          serviceType: serviceType,
          version: version,
          preferredDocumentId: preferred,
        );

    if (!context.mounted) {
      return;
    }
    if (snapshot.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ShopPolicyHistory.notFoundMessage(serviceType))),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PolicyVersionDetailPage(
          data: snapshot,
          serviceType: serviceType,
        ),
      ),
    );
  }

  static String _formatAccepted(dynamic value) {
    if (value == null) {
      return '未記錄';
    }
    if (value is Timestamp) {
      final DateTime date = value.toDate();
      final String y = date.year.toString().padLeft(4, '0');
      final String m = date.month.toString().padLeft(2, '0');
      final String d = date.day.toString().padLeft(2, '0');
      final String h = date.hour.toString().padLeft(2, '0');
      final String min = date.minute.toString().padLeft(2, '0');
      return '$y-$m-$d $h:$min';
    }
    return value.toString();
  }
}

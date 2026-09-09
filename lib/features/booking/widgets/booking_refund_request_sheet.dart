// 檔案名稱：lib/features/booking/widgets/booking_refund_request_sheet.dart
// 功能說明：申請退款：閱讀退款條款後前往訂單留言或聯絡店家（不執行金流退款）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/shop_contact_shortcut_service.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';

Future<void> showBookingRefundRequestSheet({
  required BuildContext context,
  required String shopId,
  required VoidCallback onGoToMessages,
}) async {
  final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
  final Map<String, dynamic>? policy = await ShopPolicyService.instance
      .getRefundPolicy(shopId);
  if (!context.mounted) {
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      final bool hasPolicy =
          policy != null &&
          policy['enabled'] != false &&
          (policy['body'] ?? '').toString().trim().isNotEmpty;
      final String title = (policy?['title'] ?? '退款條款').toString();
      final int version =
          (policy?['refundPolicyVersion'] as num?)?.toInt() ??
          (policy?['version'] as num?)?.toInt() ??
          0;
      String updated = '';
      final dynamic rawAt = policy?['updatedAt'];
      if (rawAt is Timestamp) {
        final DateTime at = rawAt.toDate();
        updated =
            '${at.year}/${at.month.toString().padLeft(2, '0')}/${at.day.toString().padLeft(2, '0')}';
      }
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
              maxWidth: 560,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '申請退款',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasPolicy
                      ? '$title　版本 v$version${updated.isEmpty ? '' : '　更新 $updated'}'
                      : '店家尚未提供退款條款，請先聯絡店家協助處理',
                  style: TextStyle(color: theme.subtitleColor),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      hasPolicy
                          ? (policy['body'] ?? '').toString()
                          : '請透過訂單留言說明需求，或使用店家聯絡方式與我們聯繫。退款由店家人工處理，系統不會自動退款。',
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    onGoToMessages();
                  },
                  child: const Text('前往訂單留言'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await ShopContactShortcutService.instance.contactShop(
                      context: context,
                      shopId: shopId,
                    );
                  },
                  child: const Text('聯絡店家'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

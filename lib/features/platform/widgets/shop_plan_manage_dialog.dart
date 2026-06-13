// lib/features/platform/widgets/shop_plan_manage_dialog.dart
// 🧾 平台店家方案與權限管理彈窗
// 功能：調整店家到期日、限制模式與方案權限

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopPlanManageDialog extends StatelessWidget {
  const ShopPlanManageDialog({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.shop,
  });

  final String shopId;
  final String shopName;
  final Map<String, dynamic> shop;

  String _formatDate(dynamic value) {
    if (value == null) return '尚未設定';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return '尚未設定';

    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)}';
  }

  String _planLabel(String value) {
    switch (value) {
      case 'free':
        return '免費版';
      case 'basic':
        return '999方案';
      default:
        return '未設定';
    }
  }

  String _accountStatusLabel(String value) {
    switch (value) {
      case 'normal':
        return '正常';
      case 'restricted':
        return '限制模式';
      case 'suspended':
        return '停權';
      default:
        return '正常';
    }
  }

  Future<void> _extendPaidUntil(BuildContext context, int days) async {
    final paidUntil = shop['paidUntil'];

    DateTime baseDate;

    if (paidUntil is Timestamp) {
      baseDate = paidUntil.toDate();
    } else {
      baseDate = DateTime.now();
    }

    await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
      'paidUntil': Timestamp.fromDate(baseDate.add(Duration(days: days))),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已延長 $days 天')));
    }
  }

  Future<void> _updateAccountStatus(
    BuildContext context,
    String accountStatus,
  ) async {
    await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
      'accountStatus': accountStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accountStatus == 'restricted' ? '已設為限制模式' : '已解除限制'),
        ),
      );
    }
  }

  Future<void> _showCustomDaysDialog(BuildContext context) async {
    final controller = TextEditingController();

    final days = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('自訂延長天數'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '請輸入天數',
              hintText: '例如：15',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());

                if (value == null || value <= 0) {
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              child: const Text('確認'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (days == null) return;

    if (context.mounted) {
      await _extendPaidUntil(context, days);
    }
  }

  Future<void> _showRestrictionReasonDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: shop['restrictionReason']?.toString() ?? '',
    );

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('設定限制原因'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '限制原因',
              hintText: '例如：等待補件、欠款、客訴處理中',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reason == null) return;

    await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
      'restrictionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已更新限制原因')));
    }
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = shop['plan']?.toString() ?? 'free';
    final accountStatus = shop['accountStatus']?.toString() ?? 'normal';

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '方案與權限管理',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shopName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _infoRow('目前方案', _planLabel(plan)),
                const SizedBox(height: 10),
                _infoRow('到期日', _formatDate(shop['paidUntil'])),
                const SizedBox(height: 10),
                _infoRow('帳號狀態', _accountStatusLabel(accountStatus)),
                if (accountStatus == 'restricted') ...[
                  const SizedBox(height: 10),
                  _infoRow(
                    '限制原因',
                    (shop['restrictionReason']?.toString().trim().isNotEmpty ??
                            false)
                        ? shop['restrictionReason'].toString()
                        : '未填寫',
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            '延長方案',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionChip(
                label: '+7天',
                icon: Icons.add_circle_outline,
                color: Colors.blue,
                onTap: () => _extendPaidUntil(context, 7),
              ),
              _actionChip(
                label: '+30天',
                icon: Icons.add_circle_outline,
                color: Colors.blue,
                onTap: () => _extendPaidUntil(context, 30),
              ),
              _actionChip(
                label: '自訂天數',
                icon: Icons.edit_calendar_outlined,
                color: Colors.purple,
                onTap: () => _showCustomDaysDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Text(
            '帳號限制',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showRestrictionReasonDialog(context),
              icon: const Icon(Icons.edit_note_outlined, size: 18),
              label: const Text('設定限制原因'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueGrey,
                side: BorderSide(color: Colors.blueGrey.shade200),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _updateAccountStatus(context, 'restricted'),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('限制模式'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: BorderSide(color: Colors.orange.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _updateAccountStatus(context, 'normal'),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('解除限制'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: BorderSide(color: Colors.green.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ),
      ],
    );
  }
}

// 檔案名稱：lib/features/admin/pages/admin_payment_detail_page.dart
// 功能說明：顯示單筆付款交易的必要紀錄
// 💳 付款詳情
// 讓店主確認付款結果，並可使用交易編號到綠界後台進行對帳。

import 'package:flutter/material.dart';

import '../../../core/models/payment_model.dart';

class AdminPaymentDetailPage extends StatelessWidget {
  const AdminPaymentDetailPage({super.key, required this.payment});

  final PaymentModel payment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('付款詳情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DetailCard(
            title: '交易紀錄',
            children: [
              _DetailRow(label: '付款狀態', value: _statusLabel(payment.status)),
              _DetailRow(label: '付款金額', value: 'NT\$ ${payment.amount}'),
              _DetailRow(
                label: '付款用途',
                value: _purposeLabel(payment.paymentPurpose),
              ),
              _DetailRow(
                label: '付款方式',
                value: _methodLabel(payment.paymentMethod),
              ),
              _DetailRow(label: '付款時間', value: _formatDateTime(payment.paidAt)),
            ],
          ),
          const SizedBox(height: 16),
          _DetailCard(
            title: '訂單資料',
            children: [
              _DetailRow(label: '付款來源', value: payment.sourceTypeLabel),
              _DetailRow(
                label: '訂單編號',
                value: payment.displayOrderCode.isEmpty
                    ? '尚未寫入'
                    : payment.displayOrderCode,
              ),
              _DetailRow(
                label: '會員姓名',
                value: payment.customerName.isEmpty
                    ? '未提供'
                    : payment.customerName,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailCard(
            title: '綠界對帳資料',
            children: [
              _DetailRow(
                label: '商店交易編號',
                value: payment.merchantTradeNo.isEmpty
                    ? '尚未取得'
                    : payment.merchantTradeNo,
              ),
              _DetailRow(
                label: '綠界交易編號',
                value: payment.gatewayTradeNo.isEmpty
                    ? '尚未取得'
                    : payment.gatewayTradeNo,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _purposeLabel(String value) {
    switch (value) {
      case 'deposit':
        return '訂金';
      case 'balance':
        return '尾款';
      case 'full':
        return '全額付款';
      case 'additional':
        return '補款／加購';
      default:
        return '其他';
    }
  }

  String _methodLabel(String value) {
    switch (value) {
      case 'credit_card':
        return '信用卡';
      case 'atm':
        return 'ATM';
      case 'cvs_code':
        return '超商代碼';
      case 'transfer':
        return '銀行轉帳';
      case 'cash':
        return '到店付款';
      default:
        return value.isEmpty ? '未指定' : value;
    }
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'paid':
        return '付款成功';
      case 'pending':
      case 'awaiting_payment':
        return '待付款';
      case 'failed':
        return '付款失敗';
      case 'cancelled':
        return '已取消';
      case 'expired':
        return '已逾期';
      case 'refunded':
        return '已退款';
      default:
        return value.isEmpty ? '未知' : value;
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '—';
    }

    final DateTime local = value.toLocal();

    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${local.year}/'
        '${twoDigits(local.month)}/'
        '${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

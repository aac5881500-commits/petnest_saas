import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/models/payment_model.dart';

/// 原交易已取得繳費資料時，在既有付款頁提供可重新查看的內容。
class EcpayPaymentInformation extends StatelessWidget {
  const EcpayPaymentInformation({
    super.key,
    required this.payment,
    required this.onRetry,
    this.loading = false,
    this.error,
  });

  final PaymentModel? payment;
  final VoidCallback onRetry;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final data = payment;
    final hasInfo = data?.hasOfflinePaymentInfo ?? false;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (loading) const LinearProgressIndicator(),
        if (error != null) ...[Text(error!), const SizedBox(height: 16)],
        if (data != null) ...[
          Text(
            data.paymentMethod == PaymentMethodType.atm
                ? 'ATM 繳款資訊'
                : data.paymentMethod == PaymentMethodType.convenienceStoreCode
                ? '超商繳費資訊'
                : '付款狀態',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text('應付金額：NT\$ ${data.amount}'),
          const SizedBox(height: 16),
          if (hasInfo && data.paymentMethod == PaymentMethodType.atm) ...[
            _copyable(context, '銀行代碼', data.atmBankCode),
            _copyable(context, '繳款帳號', data.atmVirtualAccount),
          ],
          if (hasInfo &&
              data.paymentMethod == PaymentMethodType.convenienceStoreCode)
            _copyable(context, '超商繳費代碼', data.convenienceStorePaymentCode),
          if (data.expireAt != null) Text('付款期限：${_date(data.expireAt!)}'),
          const SizedBox(height: 16),
          Text(
            hasInfo
                ? '請依原付款資訊完成繳費。付款結果更新後，會自動返回訂單。'
                : '付款資訊尚未完成更新。請稍後重新讀取，或返回訂單繼續付款。',
          ),
        ] else if (!loading && error == null)
          const Text('目前沒有付款資訊，請重新讀取或返回訂單確認。'),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重新讀取付款資訊'),
          ),
        ),
      ],
    );
  }

  Widget _copyable(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        SelectableText(value, style: Theme.of(context).textTheme.titleMedium),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('已複製$label')));
          },
          icon: const Icon(Icons.copy, size: 18),
          label: Text('複製$label'),
        ),
      ],
    ),
  );

  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

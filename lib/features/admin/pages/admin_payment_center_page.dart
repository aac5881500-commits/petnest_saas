// lib/features/admin/pages/admin_payment_center_page.dart
// 💳 金流中心
// 功能：提供店主查看店家的付款交易紀錄，
// 支援單一訂單交易模式、關鍵字搜尋、付款狀態篩選與付款詳情。

import 'package:flutter/material.dart';

import '../../../core/models/payment_model.dart';
import '../../../core/services/payment_service.dart';
import 'admin_payment_detail_page.dart';
import '../../../core/widgets/shop_task_center_button.dart';

class AdminPaymentCenterPage extends StatefulWidget {
  const AdminPaymentCenterPage({
    super.key,
    required this.shopId,
    this.bookingId,
    this.bookingCode,
  });

  final String shopId;

  /// 有傳入時，只顯示這張訂單的交易。
  final String? bookingId;

  /// 單一訂單模式顯示用的訂單編號。
  final String? bookingCode;

  @override
  State<AdminPaymentCenterPage> createState() => _AdminPaymentCenterPageState();
}

class _AdminPaymentCenterPageState extends State<AdminPaymentCenterPage> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  /// all / paid / pending / failed / refunded
  String _statusFilter = 'all';

  bool get _isBookingMode {
    return widget.bookingId != null && widget.bookingId!.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isBookingMode ? '訂單交易紀錄' : '金流中心'),
        actions: <Widget>[
          ShopTaskCenterButton(shopId: widget.shopId),
        ],
      ),
      body: StreamBuilder<List<PaymentModel>>(
        stream: _isBookingMode
            ? PaymentService.instance.streamBookingPayments(
                shopId: widget.shopId,
                bookingId: widget.bookingId!,
              )
            : PaymentService.instance.streamShopPayments(shopId: widget.shopId),
        builder:
            (BuildContext context, AsyncSnapshot<List<PaymentModel>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '交易紀錄載入失敗\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final List<PaymentModel> payments =
                  snapshot.data ?? const <PaymentModel>[];

              if (payments.isEmpty) {
                return const Center(child: Text('目前沒有交易紀錄'));
              }

              final String keyword = _searchText.trim().toLowerCase();

              final List<PaymentModel> filteredPayments = payments.where((
                PaymentModel payment,
              ) {
                final bool matchesKeyword =
                    keyword.isEmpty ||
                    payment.displayOrderCode.toLowerCase().contains(keyword) ||
                    payment.bookingCode.toLowerCase().contains(keyword) ||
                    payment.storeOrderCode.toLowerCase().contains(keyword) ||
                    payment.merchantTradeNo.toLowerCase().contains(keyword) ||
                    payment.gatewayTradeNo.toLowerCase().contains(keyword) ||
                    payment.customerName.toLowerCase().contains(keyword);

                final bool matchesStatus;

                switch (_statusFilter) {
                  case 'paid':
                    matchesStatus = payment.status == 'paid';
                    break;

                  case 'pending':
                    matchesStatus =
                        payment.status == 'pending' ||
                        payment.status == 'awaiting_payment';
                    break;

                  case 'failed':
                    matchesStatus =
                        payment.status == 'failed' ||
                        payment.status == 'cancelled' ||
                        payment.status == 'expired';
                    break;

                  case 'refunded':
                    matchesStatus =
                        payment.status == 'refunded' ||
                        payment.refundedAmount > 0;
                    break;

                  default:
                    matchesStatus = true;
                }

                return matchesKeyword && matchesStatus;
              }).toList();

              return Column(
                children: <Widget>[
                  if (_isBookingMode) _buildBookingHeader(),

                  if (!_isBookingMode) _buildSearchField(),

                  if (!_isBookingMode) _buildStatusFilter(),

                  Expanded(
                    child: filteredPayments.isEmpty
                        ? const Center(child: Text('找不到符合的交易紀錄'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredPayments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (BuildContext context, int index) {
                              final PaymentModel payment =
                                  filteredPayments[index];

                              return _buildPaymentCard(context, payment);
                            },
                          ),
                  ),
                ],
              );
            },
      ),
    );
  }

  Widget _buildBookingHeader() {
    final String displayCode = widget.bookingCode?.trim().isNotEmpty == true
        ? widget.bookingCode!.trim()
        : widget.bookingId!;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.receipt_long_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '訂單編號：$displayCode',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: '搜尋交易',
          hintText: '訂單編號、交易編號、會員姓名',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchText.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除搜尋',
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchText = '';
                    });
                  },
                  icon: const Icon(Icons.clear),
                ),
          border: const OutlineInputBorder(),
        ),
        onChanged: (String value) {
          setState(() {
            _searchText = value;
          });
        },
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _statusFilterChip(label: '全部', value: 'all'),
            const SizedBox(width: 8),
            _statusFilterChip(label: '成功', value: 'paid'),
            const SizedBox(width: 8),
            _statusFilterChip(label: '待付款', value: 'pending'),
            const SizedBox(width: 8),
            _statusFilterChip(label: '失敗', value: 'failed'),
            const SizedBox(width: 8),
            _statusFilterChip(label: '已退款', value: 'refunded'),
          ],
        ),
      ),
    );
  }

  Widget _statusFilterChip({required String label, required String value}) {
    return ChoiceChip(
      label: Text(label),
      selected: _statusFilter == value,
      onSelected: (_) {
        setState(() {
          _statusFilter = value;
        });
      },
    );
  }

  Widget _buildPaymentCard(BuildContext context, PaymentModel payment) {
    return Card(
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminPaymentDetailPage(payment: payment),
            ),
          );
        },
        leading: Icon(_paymentStatusIcon(payment.status)),
        title: Text(
          'NT\$ ${payment.amount}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '來源：'
            '${payment.sourceTypeLabel}\n'
            '訂單編號：'
            '${payment.displayOrderCode.isEmpty ? '尚未寫入' : payment.displayOrderCode}\n'
            '會員：'
            '${payment.customerName.isEmpty ? '未提供' : payment.customerName}\n'
            '用途：'
            '${_purposeLabel(payment.paymentPurpose)}\n'
            '方式：'
            '${_methodLabel(payment.paymentMethod)}\n'
            '狀態：'
            '${_statusLabel(payment.status)}\n'
            '付款時間：'
            '${_formatDateTime(payment.paidAt)}\n'
            '商店交易編號：'
            '${payment.merchantTradeNo.isEmpty ? '尚未取得' : payment.merchantTradeNo}\n'
            '綠界交易編號：'
            '${payment.gatewayTradeNo.isEmpty ? '尚未取得' : payment.gatewayTradeNo}',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        isThreeLine: true,
      ),
    );
  }

  IconData _paymentStatusIcon(String status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle_outline;

      case 'failed':
      case 'cancelled':
      case 'expired':
        return Icons.error_outline;

      case 'refunded':
        return Icons.currency_exchange;

      default:
        return Icons.payments_outlined;
    }
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
      return '尚未付款';
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

// lib/features/booking/widgets/booking_detail/booking_detail_finance_section.dart
// 費用與付款：摘要、付款操作、明細展開、轉帳、付款紀錄、退房追加費用。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/models/payment_model.dart';
import 'package:petnest_saas/core/services/payment_service.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

class BookingDetailShopPaymentFlags {
  const BookingDetailShopPaymentFlags({
    required this.canCreateOnlinePayment,
    required this.creditCardEnabled,
    required this.atmEnabled,
    required this.cvsEnabled,
  });

  final bool canCreateOnlinePayment;
  final bool creditCardEnabled;
  final bool atmEnabled;
  final bool cvsEnabled;
}

class BookingDetailFinanceSection extends StatefulWidget {
  const BookingDetailFinanceSection({
    super.key,
    required this.view,
    required this.bookingId,
    required this.shopFlags,
    required this.last5Controller,
    required this.loading,
    required this.creatingPayment,
    required this.onUploadImage,
    required this.onSubmitDeposit,
    required this.onDeleteTransferImage,
    required this.onPayOnline,
  });

  final BookingDetailViewData view;
  final String bookingId;
  final BookingDetailShopPaymentFlags shopFlags;
  final TextEditingController last5Controller;
  final bool loading;
  final bool creatingPayment;
  final VoidCallback onUploadImage;
  final VoidCallback onSubmitDeposit;
  final void Function(String imageUrl) onDeleteTransferImage;
  final VoidCallback onPayOnline;

  @override
  State<BookingDetailFinanceSection> createState() =>
      _BookingDetailFinanceSectionState();
}

class _BookingDetailFinanceSectionState
    extends State<BookingDetailFinanceSection> {
  bool _detailsOpen = false;
  bool _paymentsOpen = false;
  bool _extraOpen = false;

  @override
  Widget build(BuildContext context) {
    final BookingDetailViewData view = widget.view;
    return BookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const BookingDetailSectionTitle('費用與付款'),
          const SizedBox(height: 12),
          _kv(
            view.totalAmountLabel,
            'NT\$ ${view.totalAmount}',
            emphasize: true,
          ),
          _kv('已付款', 'NT\$ ${view.paidAmount}'),
          _kv(
            '尚需付款',
            'NT\$ ${view.remainingAmount}',
            valueColor: view.remainingAmount > 0
                ? BookingDetailUi.of(context).primary
                : BookingDetailUi.of(context).success,
          ),
          _kv('付款方式', view.paymentMethodLabel),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '付款狀態',
                  style: TextStyle(
                    fontSize: BookingDetailUi.bodySize,
                    color: BookingDetailUi.of(context).muted,
                  ),
                ),
              ),
              if (view.isPaidInFull)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ShopFrontendTheme.successSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '已付清',
                    style: TextStyle(
                      color: BookingDetailUi.of(context).success,
                      fontWeight: FontWeight.w700,
                      fontSize: BookingDetailUi.captionSize,
                    ),
                  ),
                )
              else
                Text(
                  view.paymentStatusLabel,
                  style: TextStyle(
                    fontSize: BookingDetailUi.bodySize,
                    color: view.remainingAmount > 0
                        ? BookingDetailUi.of(context).primary
                        : BookingDetailUi.of(context).text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (view.remainingAmount > 0 &&
              widget.shopFlags.canCreateOnlinePayment) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.creatingPayment ? null : widget.onPayOnline,
                icon: widget.creatingPayment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.payment),
                label: Text(
                  widget.creatingPayment
                      ? '正在建立付款...'
                      : view.paidAmount > 0
                      ? '支付剩餘金額 NT\$ ${view.remainingAmount}'
                      : '立即付款 NT\$ ${view.remainingAmount}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BookingDetailUi.of(context).primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
          if (view.showBankTransferForm) ...<Widget>[
            const SizedBox(height: 12),
            _bankForm(view),
          ] else if (view.isBankTransfer &&
              view.depositStatus == 'pending_review') ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ShopFrontendTheme.warningSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '付款資料審核中',
                style: TextStyle(
                  color: BookingDetailUi.of(context).warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _toggle(
            title: '查看費用明細',
            open: _detailsOpen,
            onTap: () {
              setState(() {
                _detailsOpen = !_detailsOpen;
              });
            },
          ),
          if (_detailsOpen) _feeDetails(view),
          _toggle(
            title: '付款紀錄',
            open: _paymentsOpen,
            onTap: () {
              setState(() {
                _paymentsOpen = !_paymentsOpen;
              });
            },
          ),
          if (_paymentsOpen) _paymentHistory(view),
          if (view.hasExtraCharges) ...<Widget>[
            _toggle(
              title: '退房追加費用',
              open: _extraOpen,
              onTap: () {
                setState(() {
                  _extraOpen = !_extraOpen;
                });
              },
            ),
            if (_extraOpen) _extraCharges(view),
          ],
        ],
      ),
    );
  }

  Widget _kv(
    String label,
    String value, {
    bool emphasize = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: BookingDetailUi.bodySize,
                color: BookingDetailUi.of(context).muted,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: emphasize
                    ? BookingDetailUi.moneySize
                    : BookingDetailUi.bodySize,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ?? BookingDetailUi.of(context).text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggle({
    required String title,
    required bool open,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: BookingDetailUi.bodySize,
                  color: BookingDetailUi.of(context).primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              open ? Icons.expand_less : Icons.expand_more,
              color: BookingDetailUi.of(context).primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _feeDetails(BookingDetailViewData view) {
    final List<BookingDetailFeeLine> lines = view.feeLines;
    return Column(
      children: <Widget>[
        for (int i = 0; i < lines.length; i++) ...<Widget>[
          if (i > 0) const Divider(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      lines[i].label,
                      style: TextStyle(
                        fontSize: lines[i].isTotal
                            ? BookingDetailUi.bodySize
                            : BookingDetailUi.bodySize,
                        fontWeight: lines[i].isTotal
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: BookingDetailUi.of(context).text,
                      ),
                    ),
                    if (lines[i].subtitle.isNotEmpty)
                      Text(
                        lines[i].subtitle,
                        style: TextStyle(
                          fontSize: BookingDetailUi.captionSize,
                          color: BookingDetailUi.of(context).muted,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${lines[i].isDiscount ? '-' : ''}NT\$ ${lines[i].amount.abs()}',
                style: TextStyle(
                  fontSize: lines[i].isTotal ? 18 : BookingDetailUi.bodySize,
                  fontWeight: lines[i].isTotal
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: lines[i].isDiscount
                      ? BookingDetailUi.of(context).success
                      : BookingDetailUi.of(context).text,
                ),
              ),
            ],
          ),
        ],
        if (SafeParse.parseMapList(
          view.raw['specialDateSurchargeDetails'],
        ).isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          ...SafeParse.parseMapList(
            view.raw['specialDateSurchargeDetails'],
          ).map((Map<String, dynamic> item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${SafeParse.parseString(item['date'] ?? item['label'])}  NT\$ ${SafeParse.parseMoney(item['amount'])}',
                style: TextStyle(
                  fontSize: BookingDetailUi.captionSize,
                  color: BookingDetailUi.of(context).muted,
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _bankForm(BookingDetailViewData view) {
    final String bankName = SafeParse.parseString(view.raw['bankName']);
    final String accountName = SafeParse.parseString(view.raw['accountName']);
    final String accountNumber = SafeParse.parseString(
      view.raw['accountNumber'],
    );
    final String imageUrl = SafeParse.parseString(view.raw['transferImageUrl']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '銀行轉帳',
          style: TextStyle(
            fontSize: BookingDetailUi.bodySize,
            fontWeight: FontWeight.w600,
            color: BookingDetailUi.of(context).text,
          ),
        ),
        const SizedBox(height: 8),
        _copyRow('銀行', bankName),
        _copyRow('戶名', accountName),
        _copyRow('帳號', accountNumber),
        const SizedBox(height: 8),
        TextField(
          controller: widget.last5Controller,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          decoration: InputDecoration(
            labelText: '轉帳後五碼',
            helperText: '請輸入轉帳帳號後五碼',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: widget.loading ? null : widget.onUploadImage,
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: BookingDetailUi.of(context).background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BookingDetailUi.of(context).border),
            ),
            child: imageUrl.isEmpty
                ? const Center(child: Text('上傳轉帳截圖（JPG／PNG，5MB 內）'))
                : Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: BookingDetailSoftNetworkImage(
                          url: imageUrl,
                          fit: BoxFit.contain,
                          fallbackIcon: Icons.image_outlined,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: widget.loading
                              ? null
                              : () => widget.onDeleteTransferImage(imageUrl),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.loading ? null : widget.onSubmitDeposit,
            child: Text(widget.loading ? '送出中...' : '送出付款資料'),
          ),
        ),
      ],
    );
  }

  Widget _copyRow(String label, String value) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: TextStyle(
                fontSize: BookingDetailUi.captionSize,
                color: BookingDetailUi.of(context).muted,
              ),
            ),
          ),
          Expanded(child: Text(value)),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('已複製$label')));
            },
          ),
        ],
      ),
    );
  }

  Widget _paymentHistory(BookingDetailViewData view) {
    final String shopId = SafeParse.parseString(view.raw['shopId']);
    if (shopId.isEmpty) {
      return Text(
        '目前沒有可顯示的付款紀錄',
        style: TextStyle(
          fontSize: BookingDetailUi.captionSize,
          color: BookingDetailUi.of(context).muted,
        ),
      );
    }
    return StreamBuilder<List<PaymentModel>>(
      stream: PaymentService.instance.streamBookingPayments(
        shopId: shopId,
        bookingId: widget.bookingId,
      ),
      builder: (BuildContext context, AsyncSnapshot<List<PaymentModel>> snapshot) {
        if (snapshot.hasError) {
          return Text(
            '付款紀錄暫時無法載入',
            style: TextStyle(
              fontSize: BookingDetailUi.captionSize,
              color: BookingDetailUi.of(context).muted,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          );
        }
        final List<PaymentModel> payments = snapshot.data!;
        if (payments.isEmpty) {
          return Text(
            '尚無付款紀錄',
            style: TextStyle(
              fontSize: BookingDetailUi.captionSize,
              color: BookingDetailUi.of(context).muted,
            ),
          );
        }
        return Column(
          children: payments.map((PaymentModel payment) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${BookingDetailViewData.paymentPurposeLabel(payment.paymentPurpose)}・${_method(payment.paymentMethod)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('NT\$ ${payment.amount}'),
                  const SizedBox(width: 8),
                  Text(
                    BookingDetailViewData.paymentRecordStatusLabel(
                      payment.status,
                    ),
                    style: TextStyle(
                      fontSize: BookingDetailUi.captionSize,
                      color: BookingDetailUi.of(context).muted,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _method(String method) {
    switch (method) {
      case PaymentMethodType.creditCard:
        return '信用卡';
      case PaymentMethodType.atm:
        return 'ATM';
      case PaymentMethodType.convenienceStoreCode:
        return '超商代碼';
      case PaymentMethodType.bankTransfer:
        return '銀行轉帳';
      case PaymentMethodType.cash:
        return '到店付款';
      default:
        return method;
    }
  }

  Widget _extraCharges(BookingDetailViewData view) {
    return Column(
      children: view.extraCharges.map((Map<String, dynamic> item) {
        final String title = SafeParse.parseString(
          item['title'],
          fallback: '額外費用',
        );
        final int amount = SafeParse.parseMoney(item['amount']);
        final String note = SafeParse.parseString(item['note']);
        final List<dynamic> images = SafeParse.parseList(item['imageUrls']);
        final String paidLabel;
        if (item.containsKey('paid') || item.containsKey('isPaid')) {
          paidLabel = SafeParse.parseBool(item['paid'] ?? item['isPaid'])
              ? '已付款'
              : '未付款';
        } else {
          paidLabel = '';
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text(title)),
                  Text('NT\$ $amount'),
                ],
              ),
              if (note.isNotEmpty)
                Text(
                  note,
                  style: TextStyle(
                    fontSize: BookingDetailUi.captionSize,
                    color: BookingDetailUi.of(context).muted,
                  ),
                ),
              if (paidLabel.isNotEmpty)
                Text(
                  paidLabel,
                  style: TextStyle(
                    fontSize: BookingDetailUi.captionSize,
                    color: BookingDetailUi.of(context).muted,
                  ),
                ),
              if (images.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: images.map((dynamic url) {
                    final String src = url.toString();
                    return GestureDetector(
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => Dialog(
                            child: BookingDetailSoftNetworkImage(
                              url: src,
                              fit: BoxFit.contain,
                              fallbackIcon: Icons.broken_image_outlined,
                            ),
                          ),
                        );
                      },
                      child: BookingDetailSoftNetworkImage(
                        url: src,
                        width: 72,
                        height: 72,
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

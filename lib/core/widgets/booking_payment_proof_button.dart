// 檔案名稱：lib/core/widgets/booking_payment_proof_button.dart
// 功能說明：住宿／安親共用：查看付款回傳照片（相容舊欄位，失敗顯示空狀態）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/debug/chat_error_probe.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/services/shop_payment_methods.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class BookingPaymentProofRecord {
  const BookingPaymentProofRecord({
    required this.proofId,
    required this.imageUrl,
    required this.purpose,
    this.storagePath = '',
    this.amount = 0,
    this.last5 = '',
    this.submittedAt,
    this.confirmedAt,
    this.confirmedBy = '',
    this.legacy = false,
  });

  final String proofId;
  final String imageUrl;
  final String storagePath;
  final String purpose;
  final int amount;
  final String last5;
  final DateTime? submittedAt;
  final DateTime? confirmedAt;
  final String confirmedBy;
  final bool legacy;

  String get purposeLabel {
    switch (purpose) {
      case 'balance':
        return '尾款';
      case 'top_up':
        return '補款';
      default:
        return '訂金';
    }
  }

  bool get confirmed => confirmedAt != null;
}

class BookingPaymentProof {
  BookingPaymentProof._();

  static const List<String> urlKeys = <String>[
    'transferImageUrl',
    'transferScreenshotUrl',
    'transferProofUrl',
    'paymentProofUrl',
    'paymentImageUrl',
    'depositImageUrl',
    'depositProofUrl',
  ];

  static const List<String> listKeys = <String>[
    'transferImageUrls',
    'paymentProofUrls',
  ];

  static List<String> urls(Map<String, dynamic> data) {
    return records(data)
        .map((BookingPaymentProofRecord e) => e.imageUrl)
        .toList();
  }

  static List<BookingPaymentProofRecord> records(Map<String, dynamic> data) {
    final List<BookingPaymentProofRecord> out = <BookingPaymentProofRecord>[];
    final Set<String> seen = <String>{};

    void add(BookingPaymentProofRecord record) {
      if (record.imageUrl.isEmpty || seen.contains(record.imageUrl)) {
        return;
      }
      seen.add(record.imageUrl);
      out.add(record);
    }

    final Object? rawList = data['paymentProofs'];
    if (rawList is List) {
      for (final Object? item in rawList) {
        if (item is! Map) {
          continue;
        }
        final Map<String, dynamic> map = Map<String, dynamic>.from(item);
        add(
          BookingPaymentProofRecord(
            proofId: SafeParse.parseString(map['proofId']),
            imageUrl: SafeParse.parseString(map['imageUrl']),
            storagePath: SafeParse.parseString(map['storagePath']),
            purpose: SafeParse.parseString(map['purpose']).isEmpty
                ? 'deposit'
                : SafeParse.parseString(map['purpose']),
            amount: SafeParse.parseMoney(map['amount']),
            last5: SafeParse.parseString(map['last5'] ?? map['transferLast5']),
            submittedAt: SafeParse.parseDate(map['submittedAt']),
            confirmedAt: SafeParse.parseDate(map['confirmedAt']),
            confirmedBy: SafeParse.parseString(map['confirmedBy']),
          ),
        );
      }
    }

    final bool depositConfirmed = BookingPaymentStatus.isDepositConfirmed(data);
    final DateTime? depositPaidAt = SafeParse.parseDate(
      data['depositPaidAt'] ?? data['depositConfirmedAt'],
    );
    for (final String key in urlKeys) {
      final String url = SafeParse.parseString(data[key]);
      add(
        BookingPaymentProofRecord(
          proofId: 'legacy_$key',
          imageUrl: url,
          storagePath: SafeParse.parseString(data['transferImagePath']),
          purpose: 'deposit',
          amount: BookingPaymentStatus.resolveDepositAmount(data),
          last5: SafeParse.parseString(data['transferLast5']),
          submittedAt: SafeParse.parseDate(data['depositSubmittedAt']),
          confirmedAt: depositConfirmed ? depositPaidAt : null,
          confirmedBy: SafeParse.parseString(data['depositConfirmedBy']),
          legacy: true,
        ),
      );
    }
    for (final String key in listKeys) {
      final dynamic raw = data[key];
      if (raw is List) {
        for (int i = 0; i < raw.length; i++) {
          add(
            BookingPaymentProofRecord(
              proofId: 'legacy_${key}_$i',
              imageUrl: raw[i]?.toString() ?? '',
              purpose: 'deposit',
              last5: SafeParse.parseString(data['transferLast5']),
              legacy: true,
            ),
          );
        }
      }
    }
    final String topUpUrl = SafeParse.parseString(
      data['settlementTopUpTransferImageUrl'],
    );
    add(
      BookingPaymentProofRecord(
        proofId: 'legacy_settlement_top_up',
        imageUrl: topUpUrl,
        storagePath: SafeParse.parseString(
          data['settlementTopUpTransferImagePath'],
        ),
        purpose: BookingSettlementMath.isSettlementConfirmed(data)
            ? 'top_up'
            : 'balance',
        amount: BookingSettlementMath.remainingDue(data: data),
        last5: SafeParse.parseString(data['settlementTopUpTransferLast5']),
        submittedAt: SafeParse.parseDate(data['settlementTopUpSubmittedAt']),
        confirmedAt: SafeParse.parseDate(data['settlementTopUpCollectedAt']),
        legacy: true,
      ),
    );
    return out;
  }

  static bool shouldShow(Map<String, dynamic> data) {
    return ShopPaymentMethods.isManualBankTransferPayment(
      data['paymentMethod'],
    );
  }

  static bool canConfirmManualDeposit(Map<String, dynamic> data) {
    if (!shouldShow(data)) {
      return false;
    }
    if (BookingPaymentStatus.isDepositConfirmed(data)) {
      return false;
    }
    if (BookingPaymentStatus.resolveDepositAmount(data) <= 0) {
      return false;
    }
    return records(data).any(
      (BookingPaymentProofRecord e) => e.purpose == 'deposit' && e.imageUrl.isNotEmpty,
    );
  }
}

class BookingPaymentProofButton extends StatelessWidget {
  const BookingPaymentProofButton({
    super.key,
    required this.data,
    this.onConfirmDeposit,
  });

  final Map<String, dynamic> data;
  final Future<void> Function()? onConfirmDeposit;

  @override
  Widget build(BuildContext context) {
    if (!BookingPaymentProof.shouldShow(data) &&
        BookingPaymentProof.records(data).isEmpty) {
      return const SizedBox.shrink();
    }
    final List<BookingPaymentProofRecord> items =
        BookingPaymentProof.records(data);
    return OutlinedButton.icon(
      onPressed: () => _open(context, items),
      icon: const Icon(Icons.photo_outlined, size: 18),
      label: const Text('查看付款回傳照片'),
    );
  }

  Future<void> _open(
    BuildContext context,
    List<BookingPaymentProofRecord> items,
  ) {
    final bool showConfirm =
        onConfirmDeposit != null &&
        BookingPaymentProof.canConfirmManualDeposit(data);
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return _PaymentProofDialog(
          records: items,
          onConfirmDeposit: showConfirm ? onConfirmDeposit : null,
        );
      },
    );
  }
}

class _PaymentProofDialog extends StatefulWidget {
  const _PaymentProofDialog({required this.records, this.onConfirmDeposit});

  final List<BookingPaymentProofRecord> records;
  final Future<void> Function()? onConfirmDeposit;

  @override
  State<_PaymentProofDialog> createState() => _PaymentProofDialogState();
}

class _PaymentProofDialogState extends State<_PaymentProofDialog> {
  bool _busy = false;
  String? _error;
  BookingPaymentProofRecord? _preview;

  Future<void> _confirm() async {
    final Future<void> Function()? action = widget.onConfirmDeposit;
    if (action == null || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = ChatErrorProbe.describe(error);
      });
    }
  }

  String _timeLabel(DateTime? time) {
    if (time == null) {
      return '時間未記錄';
    }
    final String m = time.month.toString().padLeft(2, '0');
    final String d = time.day.toString().padLeft(2, '0');
    final String h = time.hour.toString().padLeft(2, '0');
    final String min = time.minute.toString().padLeft(2, '0');
    return '${time.year}-$m-$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _preview == null ? '付款回傳照片' : _preview!.purposeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_preview != null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _preview = null;
                            }),
                      child: const Text('返回清單'),
                    ),
                  IconButton(
                    tooltip: '關閉',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (widget.onConfirmDeposit != null && _preview == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: _busy ? null : _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_busy ? '確認中…' : '確認收到訂金'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (widget.records.isEmpty) {
      return const Center(child: Text('尚無付款回傳照片'));
    }
    if (_preview != null) {
      return InteractiveViewer(
        minScale: 0.8,
        maxScale: 4,
        child: Image.network(
          _preview!.imageUrl,
          fit: BoxFit.contain,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stack) {
                return const Center(child: Text('無法載入付款回傳照片'));
              },
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: widget.records.length,
      separatorBuilder: (BuildContext context, int index) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final BookingPaymentProofRecord item = widget.records[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${item.purposeLabel}　NT\$ ${item.amount}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${_timeLabel(item.submittedAt)}\n'
            '轉帳後五碼：${item.last5.isEmpty ? '—' : item.last5}　'
            '${item.confirmed ? '已確認' : '未確認'}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() {
            _preview = item;
          }),
        );
      },
    );
  }
}

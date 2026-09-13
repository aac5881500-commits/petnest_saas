// 檔案名稱：lib/features/admin/widgets/admin_stay_settle_sheet.dart
// 功能說明：住宿退房結算：原房費不動，手動加收／減免與證據照片，不按小時計費。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/services/settlement_adjust_display.dart';
import 'package:petnest_saas/core/services/shop_payment_methods.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class AdminStaySettleResult {
  const AdminStaySettleResult({
    required this.manualAdjust,
    required this.manualAdjustReason,
    required this.topUpMethod,
    required this.lockIfClear,
    required this.images,
  });

  final int manualAdjust;
  final String manualAdjustReason;
  final String topUpMethod;
  final bool lockIfClear;
  final List<XFile> images;
}

Future<AdminStaySettleResult?> showAdminStaySettleSheet({
  required BuildContext context,
  required String shopId,
  required String bookingId,
  required Map<String, dynamic> booking,
}) {
  return showModalBottomSheet<AdminStaySettleResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return AdminStaySettleSheet(
        shopId: shopId,
        bookingId: bookingId,
        booking: booking,
      );
    },
  );
}

class AdminStaySettleSheet extends StatefulWidget {
  const AdminStaySettleSheet({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.booking,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> booking;

  @override
  State<AdminStaySettleSheet> createState() => _AdminStaySettleSheetState();
}

class _AdminStaySettleSheetState extends State<AdminStaySettleSheet> {
  String _topUpMethod = '';
  String _refundMethod = '';
  final TextEditingController _unsignedAdjust = TextEditingController();
  final TextEditingController _manualReason = TextEditingController();
  final ScrollController _sheetScroll = ScrollController();
  final FocusNode _reasonFocus = FocusNode();
  final GlobalKey _reasonFieldKey = GlobalKey();
  DaycareManualAdjustKind _adjustKind = DaycareManualAdjustKind.none;
  bool _reasonError = false;
  final List<XFile> _images = <XFile>[];

  @override
  void initState() {
    super.initState();
    final DaycareManualAdjustInput existing = DaycareManualAdjustInput.fromSigned(
      SafeParse.parseMoney(widget.booking['manualAdjust']),
    );
    _adjustKind = existing.kind;
    if (existing.unsignedAmount > 0) {
      _unsignedAdjust.text = '${existing.unsignedAmount}';
    }
    _manualReason.text = SettlementAdjustDisplay.reasonOf(widget.booking);
    _topUpMethod = (widget.booking['settlementTopUpMethod'] ?? '').toString();
  }

  @override
  void dispose() {
    _unsignedAdjust.dispose();
    _manualReason.dispose();
    _sheetScroll.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  int get _quoted => BookingSettlementMath.quotedTotal(widget.booking);

  int get _paid => BookingSettlementMath.paidAmount(widget.booking);

  int get _refunded => BookingSettlementMath.refundedAmount(widget.booking);

  int get _net => BookingSettlementMath.netCollected(widget.booking);

  int get _unsignedAdjustAmount {
    return int.tryParse(_unsignedAdjust.text.trim()) ?? 0;
  }

  int get _manual {
    return DaycareManualAdjustInput(
      kind: _adjustKind,
      unsignedAmount: _unsignedAdjustAmount,
    ).signed;
  }

  int get _finalReceivable {
    return BookingSettlementMath.expectedTotal(
      data: widget.booking,
      manualAdjustOverride: _manual,
    );
  }

  int get _remaining {
    return BookingSettlementMath.remainingDue(
      data: widget.booking,
      manualAdjustOverride: _manual,
    );
  }

  int get _refundDue {
    return BookingSettlementMath.refundDue(
      data: widget.booking,
      manualAdjustOverride: _manual,
    );
  }

  bool get _showReasonError {
    return _reasonError &&
        SettlementAdjustDisplay.isReasonMissing(
          amount: _manual,
          reason: _manualReason.text,
        );
  }

  Future<void> _confirm() async {
    if (SettlementAdjustDisplay.isReasonMissing(
      amount: _manual,
      reason: _manualReason.text,
    )) {
      setState(() => _reasonError = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final BuildContext? target = _reasonFieldKey.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            alignment: 0.2,
            duration: const Duration(milliseconds: 240),
          );
        }
        _reasonFocus.requestFocus();
      });
      return;
    }
    if (_remaining > 0 && _topUpMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇補款方式，或先至付款設定開啟可用方式')),
      );
      return;
    }
    if (_refundDue > 0) {
      _refundMethod = SettlementAdjustDisplay.inStoreRefundMethod;
    }
    bool lockIfClear = false;
    if (_remaining <= 0 && _refundDue <= 0) {
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('確認鎖定訂單'),
            content: const Text('完成後訂單將鎖定，無法再修改，請確認金額與資料正確。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('確認鎖定'),
              ),
            ],
          );
        },
      );
      if (ok != true) {
        return;
      }
      lockIfClear = true;
    }
    if (!mounted) {
      return;
    }
    Navigator.pop(
      context,
      AdminStaySettleResult(
        manualAdjust: _manual,
        manualAdjustReason: _manualReason.text.trim(),
        topUpMethod: _remaining > 0 ? _topUpMethod : '',
        lockIfClear: lockIfClear,
        images: List<XFile>.from(_images),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final double bottom = MediaQuery.of(context).viewInsets.bottom;
    final double maxHeight = MediaQuery.of(context).size.height * 0.92;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Material(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: maxHeight,
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.borderColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '辦理退房／結算',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: theme.titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '服務結束後可釋放房間。有待補款或待退款時，訂單不會標示為已完成。',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.subtitleColor,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _sheetScroll,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _feeSection(theme),
                          const SizedBox(height: 14),
                          Text(
                            '手動調整金額',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: theme.titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              ChoiceChip(
                                label: const Text('＋ 加收'),
                                selected:
                                    _adjustKind ==
                                    DaycareManualAdjustKind.surcharge,
                                onSelected: (bool selected) {
                                  setState(() {
                                    _adjustKind = selected
                                        ? DaycareManualAdjustKind.surcharge
                                        : DaycareManualAdjustKind.none;
                                    if (_adjustKind ==
                                        DaycareManualAdjustKind.none) {
                                      _unsignedAdjust.clear();
                                      _reasonError = false;
                                    }
                                  });
                                },
                              ),
                              ChoiceChip(
                                label: const Text('－ 減免'),
                                selected:
                                    _adjustKind ==
                                    DaycareManualAdjustKind.discount,
                                onSelected: (bool selected) {
                                  setState(() {
                                    _adjustKind = selected
                                        ? DaycareManualAdjustKind.discount
                                        : DaycareManualAdjustKind.none;
                                    if (_adjustKind ==
                                        DaycareManualAdjustKind.none) {
                                      _unsignedAdjust.clear();
                                      _reasonError = false;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_adjustKind != DaycareManualAdjustKind.none) ...<
                            Widget
                          >[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _unsignedAdjust,
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText:
                                    _adjustKind ==
                                        DaycareManualAdjustKind.surcharge
                                    ? '加收金額'
                                    : '減免金額',
                                hintText: '請輸入 0 以上整數',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {
                                if (_manual == 0) {
                                  _reasonError = false;
                                }
                              }),
                            ),
                          ],
                          if (_manual != 0) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(
                              key: _reasonFieldKey,
                              '⚠ 調整原因（必填）',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _manualReason,
                              focusNode: _reasonFocus,
                              decoration: InputDecoration(
                                hintText: '請說明本次加收或減免原因',
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.red.shade400,
                                    width: 1.6,
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.red,
                                    width: 1.8,
                                  ),
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setState(() {
                                  if (_manualReason.text.trim().isNotEmpty) {
                                    _reasonError = false;
                                  }
                                });
                              },
                            ),
                            if (_showReasonError)
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text(
                                  '未填寫原因不可確認結算',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                '此說明會顯示給客戶，請清楚填寫加收或減免原因。',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: () async {
                              if (_images.length >= 3) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('最多只能上傳 3 張照片')),
                                );
                                return;
                              }
                              final XFile? picked = await ImagePicker()
                                  .pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 1200,
                                    imageQuality: 75,
                                  );
                              if (picked != null) {
                                setState(() => _images.add(picked));
                              }
                            },
                            icon: const Icon(Icons.photo_library),
                            label: Text(
                              _images.isEmpty
                                  ? '選擇證據照片（選填）'
                                  : '已選擇 ${_images.length} 張照片',
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_remaining > 0) ...<Widget>[
                            Text(
                              '補款方式',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: theme.titleColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: FirebaseFirestore.instance
                                  .collection('shops')
                                  .doc(widget.shopId)
                                  .snapshots(),
                              builder:
                                  (
                                    BuildContext context,
                                    AsyncSnapshot<
                                      DocumentSnapshot<Map<String, dynamic>>
                                    >
                                    snapshot,
                                  ) {
                                    final ShopPaymentCatalog catalog =
                                        ShopPaymentMethods.settlementTopUpCatalog(
                                          shopData:
                                              snapshot.data?.data() ??
                                              const <String, dynamic>{},
                                          serviceType: PolicyApplicableService
                                              .accommodation,
                                        );
                                    if (catalog.methods.isEmpty) {
                                      return const Text(
                                        '目前沒有可用補款方式，請先至店家付款設定開啟。待補款不可標成已結清。',
                                      );
                                    }
                                    return Column(
                                      children: catalog.methods.map((
                                        ShopPaymentMethodOption item,
                                      ) {
                                        return RadioListTile<String>(
                                          value: item.id,
                                          groupValue: _topUpMethod,
                                          title: Text(item.title),
                                          subtitle: Text(item.subtitle),
                                          onChanged: (String? value) {
                                            setState(
                                              () => _topUpMethod = value ?? '',
                                            );
                                          },
                                        );
                                      }).toList(),
                                    );
                                  },
                            ),
                          ] else if (_refundDue > 0) ...<Widget>[
                            Text(
                              '退款方式',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: theme.titleColor,
                              ),
                            ),
                            RadioListTile<String>(
                              value: SettlementAdjustDisplay.inStoreRefundMethod,
                              groupValue: _refundMethod.isEmpty
                                  ? SettlementAdjustDisplay.inStoreRefundMethod
                                  : _refundMethod,
                              title: const Text('店內退款'),
                              subtitle: const Text(
                                '店員實際完成退款後再於結算結果確認，不會自動退刷或匯款。',
                              ),
                              onChanged: (String? value) {
                                setState(() => _refundMethod = value ?? '');
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '結算確認摘要',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: theme.titleColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('原住宿費用 NT\$$_quoted'),
                                Text(
                                  _manual == 0
                                      ? '加收／減免 未調整'
                                      : SettlementAdjustDisplay.shopAmountLine(
                                          _manual,
                                        ),
                                ),
                                if (_manual != 0 &&
                                    _manualReason.text.trim().isNotEmpty)
                                  Text(
                                    '調整原因：${_manualReason.text.trim()}',
                                  ),
                                Text(
                                  '最終應收 NT\$$_finalReceivable',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text('已成功收款 NT\$$_paid'),
                                Text('已完成退款 NT\$$_refunded'),
                                Text('實收淨額 NT\$$_net'),
                                if (_remaining > 0)
                                  Text('待補款 NT\$$_remaining'),
                                if (_refundDue > 0)
                                  Text('待退款 NT\$$_refundDue'),
                                if (_remaining <= 0 && _refundDue <= 0)
                                  const Text('待補款／待退款 NT\$0'),
                                if (_remaining > 0 && _topUpMethod.isNotEmpty)
                                  Text(
                                    '補款方式 ${ShopPaymentMethods.historyLabel(_topUpMethod)}',
                                  ),
                                if (_refundDue > 0) const Text('退款方式 店內退款'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.buttonColor,
                            foregroundColor: theme.onPrimaryColor,
                          ),
                          onPressed: _confirm,
                          child: const Text('確認結算'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _feeSection(ShopFrontendTheme theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '費用明細',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.titleColor,
            ),
          ),
          const SizedBox(height: 8),
          _moneyRow(theme, '原住宿費用', _quoted),
          _moneyRow(theme, '已成功收款', _paid),
          _moneyRow(theme, '已完成退款', _refunded),
          _moneyRow(theme, '實收淨額', _net),
          _infoLine('手動調整', SettlementAdjustDisplay.signedLabel(_manual)),
          _moneyRow(theme, '最終應收', _finalReceivable, emphasize: true),
          _moneyRow(theme, '待補款', _remaining),
          _moneyRow(theme, '待退款', _refundDue),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label)),
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _moneyRow(
    ShopFrontendTheme theme,
    String label,
    int amount, {
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
                color: theme.titleColor,
              ),
            ),
          ),
          Text(
            'NT\$ $amount',
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

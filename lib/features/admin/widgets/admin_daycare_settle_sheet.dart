// 檔案名稱：lib/features/admin/widgets/admin_daycare_settle_sheet.dart
// 功能說明：安親結算 bottom sheet：完整日期時間、晚接回明細、手動調整與收款選項

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/booking_payment_labels.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/settlement_adjust_display.dart';
import 'package:petnest_saas/core/services/shop_payment_methods.dart';
import 'package:petnest_saas/features/admin/widgets/settlement_refund_method_picker.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class AdminDaycareSettleResult {
  const AdminDaycareSettleResult({
    required this.actualEndAt,
    required this.manualAdjust,
    required this.manualAdjustReason,
    required this.topUpMethod,
    this.refundMethod = '',
    this.refundNote = '',
    required this.lockIfClear,
  });

  final DateTime actualEndAt;
  final int manualAdjust;
  final String manualAdjustReason;
  final String topUpMethod;
  final String refundMethod;
  final String refundNote;
  final bool lockIfClear;
}

Future<AdminDaycareSettleResult?> showAdminDaycareSettleSheet({
  required BuildContext context,
  required String shopId,
  required String bookingId,
  required Map<String, dynamic> booking,
}) {
  return showModalBottomSheet<AdminDaycareSettleResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return AdminDaycareSettleSheet(
        shopId: shopId,
        bookingId: bookingId,
        booking: booking,
      );
    },
  );
}

class AdminDaycareSettleSheet extends StatefulWidget {
  const AdminDaycareSettleSheet({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.booking,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> booking;

  @override
  State<AdminDaycareSettleSheet> createState() =>
      _AdminDaycareSettleSheetState();
}

class _AdminDaycareSettleSheetState extends State<AdminDaycareSettleSheet> {
  late DateTime _actualEnd;
  late bool _freezeActualEnd;
  String _topUpMethod = '';
  bool _loadingPreview = true;
  String? _previewError;
  Map<String, dynamic> _preview = <String, dynamic>{};
  final TextEditingController _unsignedAdjust = TextEditingController();
  final TextEditingController _manualReason = TextEditingController();
  final TextEditingController _refundNote = TextEditingController();
  final ScrollController _sheetScroll = ScrollController();
  final FocusNode _reasonFocus = FocusNode();
  final GlobalKey _reasonFieldKey = GlobalKey();
  DaycareManualAdjustKind _adjustKind = DaycareManualAdjustKind.none;
  bool _reasonError = false;
  String _refundMethod = SettlementAdjustDisplay.inStoreRefundMethod;

  DateTime? get _scheduledStart => _ts(widget.booking['scheduledStartAt']);
  DateTime? get _scheduledEnd => _ts(widget.booking['scheduledEndAt']);
  DateTime? get _actualStart => _ts(widget.booking['actualStartAt']);

  @override
  void initState() {
    super.initState();
    _freezeActualEnd = BookingSettlementMath.isSettlementConfirmed(
      widget.booking,
    );
    _actualEnd = _ts(widget.booking['actualEndAt']) ?? DateTime.now();
    final DaycareManualAdjustInput existing =
        DaycareManualAdjustInput.fromSigned(
          SafeParse.parseMoney(widget.booking['manualAdjust']),
        );
    _adjustKind = existing.kind;
    if (existing.unsignedAmount > 0) {
      _unsignedAdjust.text = '${existing.unsignedAmount}';
    }
    _manualReason.text = SettlementAdjustDisplay.reasonOf(widget.booking);
    _unsignedAdjust.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _reloadPreview();
  }

  @override
  void dispose() {
    _unsignedAdjust.dispose();
    _manualReason.dispose();
    _refundNote.dispose();
    _sheetScroll.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  Future<void> _reloadPreview() async {
    setState(() {
      _loadingPreview = true;
      _previewError = null;
    });
    try {
      final Map<String, dynamic> preview = await DaycareFunctionService.instance
          .manage(
            shopId: widget.shopId,
            bookingId: widget.bookingId,
            action: 'previewSettle',
            extra: <String, dynamic>{
              'actualEndAt': DaycareTimeHelper.callableInstant(_actualEnd),
            },
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = preview;
        _loadingPreview = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _previewError = error.toString();
        _loadingPreview = false;
      });
    }
  }

  int get _quoted => SafeParse.parseMoney(
    _preview['quotedTotal'] ??
        widget.booking['quotedTotalPrice'] ??
        widget.booking['totalPrice'],
  );

  int get _overtime {
    return SafeParse.parseMoney(
      _preview['overtimeCharge'] ??
          _preview['overtimeAmount'] ??
          widget.booking['overtimeAmount'],
    );
  }

  int get _paid => BookingSettlementMath.paidAmount(<String, dynamic>{
    ...widget.booking,
    ..._preview,
  });

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
    final int value = _quoted + _overtime + _manual;
    return value < 0 ? 0 : value;
  }

  int get _remaining {
    return BookingSettlementMath.remainingDue(
      data: <String, dynamic>{
        ...widget.booking,
        ..._preview,
        'overtimeAmount': _overtime,
      },
      manualAdjustOverride: _manual,
    );
  }

  int get _refundDue {
    return BookingSettlementMath.refundDue(
      data: <String, dynamic>{
        ...widget.booking,
        ..._preview,
        'overtimeAmount': _overtime,
      },
      manualAdjustOverride: _manual,
    );
  }

  bool get _showTopUp =>
      SettlementAdjustDisplay.showTopUp(_remaining, _refundDue);

  bool get _showRefund =>
      SettlementAdjustDisplay.showRefund(_remaining, _refundDue);

  bool get _showReasonError {
    return _reasonError &&
        SettlementAdjustDisplay.isReasonMissing(
          amount: _manual,
          reason: _manualReason.text,
        );
  }

  Future<void> _pickActualEnd() async {
    if (_freezeActualEnd) {
      return;
    }
    final DateTime firstDate = _scheduledStart ?? DateTime(2020);
    final DateTime lastDate = DateTime.now();
    DateTime initialDate = _actualEnd;
    if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate.isAfter(lastDate) ? lastDate : firstDate,
      lastDate: lastDate,
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_actualEnd),
    );
    if (time == null) {
      return;
    }
    setState(() {
      _actualEnd = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
    final String? timeError = DaycareTimeHelper.actualTimesError(
      actualStartAt: _actualStart,
      actualEndAt: _actualEnd,
    );
    if (timeError != null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(timeError)));
      setState(() {
        _actualEnd = DateTime.now();
      });
      return;
    }
    await _reloadPreview();
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
    if (_showTopUp && _topUpMethod.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇補款方式，或先至付款設定開啟可用方式')));
      return;
    }
    if (_showRefund) {
      if (_refundMethod.isEmpty) {
        _refundMethod = SettlementAdjustDisplay.inStoreRefundMethod;
      }
      if (_refundMethod == SettlementAdjustDisplay.otherRefundMethod &&
          _refundNote.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('其他退款請填寫註記')));
        return;
      }
    }
    final String? timeError = DaycareTimeHelper.actualTimesError(
      actualStartAt: _actualStart,
      actualEndAt: _actualEnd,
    );
    if (timeError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(timeError)));
      return;
    }
    if (_showRefund) {
      if (_refundMethod.isEmpty) {
        _refundMethod = SettlementAdjustDisplay.inStoreRefundMethod;
      }
    } else {
      _refundMethod = '';
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
      AdminDaycareSettleResult(
        actualEndAt: _actualEnd,
        manualAdjust: _manual,
        manualAdjustReason: _manualReason.text.trim(),
        topUpMethod: _showTopUp ? _topUpMethod : '',
        refundMethod: _showRefund ? _refundMethod : '',
        refundNote:
            _showRefund &&
                _refundMethod == SettlementAdjustDisplay.otherRefundMethod
            ? _refundNote.text.trim()
            : '',
        lockIfClear: lockIfClear,
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
                          '結算安親',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: theme.titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '依實際接回時間計算晚接回費用，確認後完成此筆安親。',
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
                          _timeCard(
                            theme,
                            title: '預約時間',
                            rows: <List<String>>[
                              <String>[
                                '預約送達',
                                DaycareTimeHelper.formatDateTimeOrUnrecorded(
                                  _scheduledStart,
                                ),
                              ],
                              <String>[
                                '預約接回',
                                DaycareTimeHelper.formatDateTimeOrUnrecorded(
                                  _scheduledEnd,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          _timeCard(
                            theme,
                            title: '實際時間',
                            rows: <List<String>>[
                              <String>[
                                '實際送達',
                                DaycareTimeHelper.formatDateTimeOrUnrecorded(
                                  _actualStart,
                                ),
                              ],
                              <String>[
                                '實際接回',
                                DaycareTimeHelper.formatDateTime(_actualEnd),
                              ],
                            ],
                            trailing: _freezeActualEnd
                                ? const Text('以首次結算時間為準')
                                : TextButton(
                                    onPressed: _pickActualEnd,
                                    child: const Text('調整接回時間'),
                                  ),
                          ),
                          const SizedBox(height: 14),
                          if (_loadingPreview)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_previewError != null)
                            Text(
                              _previewError!,
                              style: TextStyle(color: theme.primaryColor),
                            )
                          else
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
                          if (_adjustKind !=
                              DaycareManualAdjustKind.none) ...<Widget>[
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
                          if (_showTopUp) ...<Widget>[
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
                                          serviceType:
                                              PolicyApplicableService.daycare,
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
                          ] else if (_showRefund) ...<Widget>[
                            Text(
                              '退款方式',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: theme.titleColor,
                              ),
                            ),
                            SettlementRefundMethodPicker(
                              value: _refundMethod,
                              noteController: _refundNote,
                              onChanged: (String value) {
                                setState(() => _refundMethod = value);
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
                                Text('原應收 NT\$$_quoted'),
                                Text(
                                  _manual == 0
                                      ? '加收／減免 未調整'
                                      : SettlementAdjustDisplay.shopAmountLine(
                                          _manual,
                                        ),
                                ),
                                if (_manual != 0 &&
                                    _manualReason.text.trim().isNotEmpty)
                                  Text('調整原因：${_manualReason.text.trim()}'),
                                Text(
                                  '最終應收 NT\$$_finalReceivable',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text('已收款 NT\$$_paid'),
                                if (_showTopUp) Text('待補款 NT\$$_remaining'),
                                if (_showRefund) Text('待退款 NT\$$_refundDue'),
                                if (!_showTopUp && !_showRefund)
                                  const Text('待補款／待退款 NT\$0'),
                                if (_showTopUp && _topUpMethod.isNotEmpty)
                                  Text(
                                    '補款方式：${BookingPaymentLabels.method(_topUpMethod)}　付款狀態：${BookingPaymentLabels.status(widget.booking['settlementTopUpStatus'] ?? 'selected')}',
                                  ),
                                if (_showRefund)
                                  Text(
                                    '退款方式 ${SettlementAdjustDisplay.refundMethodLabel(_refundMethod.isEmpty ? SettlementAdjustDisplay.inStoreRefundMethod : _refundMethod)}',
                                  ),
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
                          onPressed: _loadingPreview ? null : _confirm,
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
    final int extra = SafeParse.parseMoney(_preview['overtimeMinutes']);
    final int grace = SafeParse.parseMoney(_preview['overtimeGraceMinutes']);
    final int billable = SafeParse.parseMoney(_preview['billableMinutes']);
    final String formula = (_preview['overtimeFormula'] ?? '未加收').toString();
    final int scheduledMinutes = SafeParse.parseMoney(
      _preview['scheduledMinutes'],
    );
    final int actualMinutes = SafeParse.parseMoney(_preview['actualMinutes']);
    final int capAdjustment = SafeParse.parseMoney(_preview['capAdjustment']);
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
          _infoLine('預約時數', DaycareTimeHelper.durationLabel(scheduledMinutes)),
          _infoLine(
            '實際時數',
            _actualStart == null
                ? '尚未記錄'
                : DaycareTimeHelper.durationLabel(actualMinutes),
          ),
          _infoLine('晚接回分鐘數', '$extra 分鐘'),
          _infoLine('免費寬限分鐘', '$grace 分鐘'),
          _infoLine('實際計費分鐘數', '$billable 分鐘'),
          _infoLine('計費算式', formula),
          const Divider(height: 20),
          _moneyRow(theme, '預約費用', _quoted),
          _moneyRow(theme, '晚接回超時計費', _overtime),
          _infoLine('手動調整', SettlementAdjustDisplay.signedLabel(_manual)),
          if (capAdjustment != 0) _moneyRow(theme, '上限調整', capAdjustment),
          _moneyRow(theme, '最終應收', _finalReceivable, emphasize: true),
          _moneyRow(theme, '成功收款總額', _paid),
          _moneyRow(theme, '待補款', _remaining),
          _moneyRow(theme, '待退款', _refundDue),
        ],
      ),
    );
  }

  Widget _timeCard(
    ShopFrontendTheme theme, {
    required String title,
    required List<List<String>> rows,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.pageBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.titleColor,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          for (final List<String> row in rows) ...<Widget>[
            Text(
              row.first,
              style: TextStyle(fontSize: 12, color: theme.subtitleColor),
            ),
            Text(
              row.last,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.titleColor,
              ),
            ),
            const SizedBox(height: 6),
          ],
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
              fontSize: emphasize ? 18 : 14,
              color: emphasize ? theme.primaryColor : theme.titleColor,
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _ts(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return null;
  }
}

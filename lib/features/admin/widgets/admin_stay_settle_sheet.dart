import '../../../core/models/booking_medication_task.dart';
import '../../medication/medication_widgets.dart' show BookingMedicationPanel;
// 檔案名稱：lib/features/admin/widgets/admin_stay_settle_sheet.dart
// 功能說明：住宿退房結算：原房費不動，手動加收／減免與證據照片，不按小時計費。

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/booking_payment_labels.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/services/settlement_adjust_display.dart';
import 'package:petnest_saas/core/services/shop_payment_methods.dart';
import 'package:petnest_saas/features/admin/widgets/settlement_refund_method_picker.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class AdminStaySettleResult {
  const AdminStaySettleResult({
    required this.manualAdjust,
    required this.manualAdjustReason,
    required this.topUpMethod,
    this.refundMethod = '',
    this.refundNote = '',
    required this.lockIfClear,
    required this.images,
    this.rewardPointsAdjusted = false,
    this.rewardPointsFinal = 0,
    this.rewardPointsAdjustReason = '',
  });

  final int manualAdjust;
  final String manualAdjustReason;
  final String topUpMethod;
  final String refundMethod;
  final String refundNote;
  final bool lockIfClear;
  final List<XFile> images;
  final bool rewardPointsAdjusted;
  final int rewardPointsFinal;
  final String rewardPointsAdjustReason;
}

Future<AdminStaySettleResult?> showAdminStaySettleSheet({
  required BuildContext context,
  required String shopId,
  required String bookingId,
  required Map<String, dynamic> booking,
}) {
  final bool asDialog = MediaQuery.sizeOf(context).width >= 1024;
  if (asDialog) {
    return showDialog<AdminStaySettleResult>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: AdminStaySettleSheet(
            shopId: shopId,
            bookingId: bookingId,
            booking: booking,
            asDialog: true,
          ),
        );
      },
    );
  }
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
    this.asDialog = false,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> booking;
  final bool asDialog;

  @override
  State<AdminStaySettleSheet> createState() => _AdminStaySettleSheetState();
}

class _AdminStaySettleSheetState extends State<AdminStaySettleSheet> {
  late Map<String, dynamic> _booking = Map<String, dynamic>.from(
    widget.booking,
  );
  final _quickNote = TextEditingController();
  bool _refreshingCare = false;
  String? _careError;
  String? _lastRecordedNotice;
  bool _careExpanded = false;
  bool _adjustmentsExpanded = false;
  final _careReviewKey = GlobalKey();
  List<BookingMedicationTask> get _pendingMedication =>
      BookingMedicationTask.fromBooking(
        _booking,
      ).where((task) => task.pending).toList();
  bool get _needsMedicationFee {
    final medication = _booking['medication'];
    return medication is Map &&
        !['declined', 'cancelled'].contains(medication['state']) &&
        medication['finalized'] != true;
  }

  bool get _careBusy => _refreshingCare;

  String get _confirmLabel =>
      _careBusy ? '更新中…' : (_careBlocked ? '前往補登與核對' : '確認結算');
  String get _careBlockReason =>
      _careError ??
      (_pendingMedication.isNotEmpty
          ? '尚有 ${_pendingMedication.length} 項用藥未補登，不能結算'
          : '請先確認用藥最終費用');
  bool get _careBlocked =>
      _careBusy ||
      _careError != null ||
      _pendingMedication.isNotEmpty ||
      _needsMedicationFee;

  Future<void> _refreshCare() async {
    setState(() {
      _refreshingCare = true;
      _careError = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get(const GetOptions(source: Source.server));
      final latest = snapshot.data();
      if (latest == null || latest['shopId'] != widget.shopId) {
        throw StateError('訂單無法讀取');
      }
      if (mounted) {
        setState(() {
          final currentRevision =
              ((_booking['medication'] as Map?)?['revision'] as num?)
                  ?.toInt() ??
              0;
          final incomingRevision =
              ((latest['medication'] as Map?)?['revision'] as num?)?.toInt() ??
              0;
          if (incomingRevision >= currentRevision) _booking = latest;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _careError = '無法更新照護紀錄與金額，請重試。');
    } finally {
      if (mounted) setState(() => _refreshingCare = false);
    }
  }

  Future<void> _openMedicationEditor(Widget child) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 900,
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: 16),
                  const Expanded(child: Text('用藥結果補登')),
                  CloseButton(onPressed: () => Navigator.pop(context)),
                ],
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
    if (mounted) await _refreshCare();
  }

  Widget _careReview() {
    final tasks = _pendingMedication;
    if (!_needsMedicationFee && tasks.isEmpty && _lastRecordedNotice == null) {
      return const SizedBox.shrink();
    }
    final groups = <String, List<BookingMedicationTask>>{};
    for (final task in tasks) {
      groups.putIfAbsent(task.day, () => []).add(task);
    }
    return Card.outlined(
      key: _careReviewKey,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '結算前用藥核對',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              tasks.isEmpty
                  ? '用藥結果已補齊，請確認最終用藥費。'
                  : '尚有 ${tasks.length} 項未完成登錄，請補齊結果後再結算。',
            ),
            for (final group in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${group.key}・${group.value.length} 項待補登',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              for (final task in group.value)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${BookingMedicationTask.timeLabel(task.scheduledAt)}・${task.pet}・${task.types}',
                  ),
                  subtitle: Text(
                    task.scheduledAt.isBefore(DateTime.now())
                        ? '已過原訂時間・尚未完成登錄'
                        : '尚未完成登錄',
                  ),
                  trailing: OutlinedButton(
                    onPressed: _careBusy
                        ? null
                        : () => _openMedicationEditor(
                            BookingMedicationPanel(
                              bookingId: widget.bookingId,
                              booking: _booking,
                              staff: true,
                              taskId: task.id,
                              inlineTaskResult: true,
                              onTaskRecordSaved: (medication) {
                                if (mounted) {
                                  setState(() {
                                    _booking = {
                                      ..._booking,
                                      'medication': medication,
                                    };
                                    _lastRecordedNotice =
                                        '已儲存：${task.day} ${BookingMedicationTask.timeLabel(task.scheduledAt)} ${task.pet} ${task.types}';
                                  });
                                }
                              },
                              onTaskRecorded: () => Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(),
                            ),
                          ),
                    child: const Text('補登結果'),
                  ),
                ),
            ],
            if (tasks.isEmpty && _needsMedicationFee)
              FilledButton.icon(
                onPressed: _careBusy
                    ? null
                    : () => _openMedicationEditor(
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: BookingMedicationPanel(
                            bookingId: widget.bookingId,
                            booking: _booking,
                            staff: true,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('確認用藥最終費用'),
              ),
            if (_careBusy) const LinearProgressIndicator(),
            if (_careError != null) Text(_careError!),
            TextButton(
              onPressed: _careBusy ? null : _refreshCare,
              child: const Text('重新讀取紀錄與金額'),
            ),
          ],
        ),
      ),
    );
  }

  String _topUpMethod = '';
  String _refundMethod = SettlementAdjustDisplay.inStoreRefundMethod;
  final TextEditingController _unsignedAdjust = TextEditingController();
  final TextEditingController _manualReason = TextEditingController();
  final TextEditingController _refundNote = TextEditingController();
  final TextEditingController _rewardPoints = TextEditingController();
  final TextEditingController _rewardReason = TextEditingController();
  bool _adjustPoints = false;
  final ScrollController _sheetScroll = ScrollController();
  final FocusNode _reasonFocus = FocusNode();
  final GlobalKey _reasonFieldKey = GlobalKey();
  DaycareManualAdjustKind _adjustKind = DaycareManualAdjustKind.none;
  bool _reasonError = false;
  final List<XFile> _images = <XFile>[];

  @override
  void initState() {
    super.initState();
    final DaycareManualAdjustInput existing =
        DaycareManualAdjustInput.fromSigned(
          SafeParse.parseMoney(_booking['manualAdjust']),
        );
    _adjustKind = existing.kind;
    if (existing.unsignedAmount > 0) {
      _unsignedAdjust.text = '${existing.unsignedAmount}';
    }
    _manualReason.text = SettlementAdjustDisplay.reasonOf(_booking);
    _topUpMethod = (_booking['settlementTopUpMethod'] ?? '').toString();
    _unsignedAdjust.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _quickNote.dispose();
    _unsignedAdjust.dispose();
    _manualReason.dispose();
    _refundNote.dispose();
    _rewardPoints.dispose();
    _rewardReason.dispose();
    _sheetScroll.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  int get _quoted => BookingSettlementMath.quotedTotal(_booking);

  int get _paid => BookingSettlementMath.paidAmount(_booking);

  int get _refunded => BookingSettlementMath.refundedAmount(_booking);

  int get _net => BookingSettlementMath.netCollected(_booking);

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
      data: _booking,
      manualAdjustOverride: _manual,
    );
  }

  int get _remaining {
    return BookingSettlementMath.remainingDue(
      data: _booking,
      manualAdjustOverride: _manual,
    );
  }

  int get _refundDue {
    return BookingSettlementMath.refundDue(
      data: _booking,
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

  Future<void> _confirm() async {
    if (_careBlocked) {
      setState(() => _careExpanded = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_careBlockReason)));
      final target = _careReviewKey.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 240),
        );
      }
      return;
    }
    if (SettlementAdjustDisplay.isReasonMissing(
      amount: _manual,
      reason: _manualReason.text,
    )) {
      setState(() {
        _reasonError = true;
        _adjustmentsExpanded = true;
      });
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
    if (_adjustPoints && _rewardReason.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請填寫點數調整原因')));
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
      AdminStaySettleResult(
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
        images: List<XFile>.from(_images),
        rewardPointsAdjusted: _adjustPoints,
        rewardPointsFinal: int.tryParse(_rewardPoints.text.trim()) ?? 0,
        rewardPointsAdjustReason: _rewardReason.text.trim(),
      ),
    );
  }

  Widget _checkoutOverview(ShopFrontendTheme theme) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: theme.primarySoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _careBlocked ? '目前試算・用藥核對後更新' : '本次結算',
          style: TextStyle(color: theme.subtitleColor),
        ),
        const SizedBox(height: 6),
        Text(
          '${_showRefund
              ? '應退'
              : _showTopUp
              ? '應收'
              : '已付清'} NT\$${_showRefund ? _refundDue : _remaining}',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: theme.titleColor,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 20,
          runSpacing: 6,
          children: [
            Text('最終費用 NT\$$_finalReceivable'),
            Text('已收 NT\$$_paid'),
            if (_refunded > 0) Text('已退 NT\$$_refunded'),
          ],
        ),
        const Divider(height: 24),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            Text('${_pendingMedication.isEmpty ? '✓' : '①'} 用藥核對'),
            const Text('② 確認帳目'),
            const Text('③ 收款／退款'),
          ],
        ),
      ],
    ),
  );

  Widget _checkoutCare() => Card.outlined(
    margin: EdgeInsets.zero,
    child: ExpansionTile(
      key: ValueKey('checkout-care-$_careExpanded'),
      initiallyExpanded: _careExpanded,
      onExpansionChanged: (value) => _careExpanded = value,
      leading: Icon(
        _pendingMedication.isEmpty
            ? Icons.check_circle_outline
            : Icons.medication_outlined,
      ),
      title: Text(
        '用藥核對・${_pendingMedication.isEmpty ? '結果已補齊' : '${_pendingMedication.length} 項待補登'}',
      ),
      subtitle: Text(_needsMedicationFee ? '補齊結果並確認用藥費後，才能結算' : '用藥費已確認'),
      children: [_careReview()],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final MediaQueryData media = MediaQuery.of(context);
    final double available =
        media.size.height - media.viewInsets.bottom - media.padding.top - 16;
    final double maxHeight = math.min(
      media.size.height * (widget.asDialog ? 0.86 : 0.92),
      math.max(240, available),
    );
    final Widget sheet = Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(20),
        bottom: Radius.circular(widget.asDialog ? 20 : 0),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: maxHeight,
        child: Column(
          children: <Widget>[
            if (!widget.asDialog) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.borderColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ] else
              const SizedBox(height: 12),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _checkoutOverview(theme),
                    const SizedBox(height: 14),
                    if (_lastRecordedNotice != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '✓ $_lastRecordedNotice・剩餘 ${_pendingMedication.length} 項',
                          style: const TextStyle(color: Color(0xFF237546)),
                        ),
                      ),
                    _checkoutCare(),
                    const SizedBox(height: 14),
                    _feeSection(theme),
                    const SizedBox(height: 14),
                    Card.outlined(
                      margin: EdgeInsets.zero,
                      child: ExpansionTile(
                        key: ValueKey('checkout-adjust-$_adjustmentsExpanded'),
                        initiallyExpanded: _adjustmentsExpanded || _manual != 0,
                        onExpansionChanged: (value) =>
                            _adjustmentsExpanded = value,
                        leading: const Icon(Icons.tune),
                        title: const Text('加收、減免與附件'),
                        subtitle: Text(
                          _manual == 0
                              ? '需要調整時再展開'
                              : '已調整 ${SettlementAdjustDisplay.signedLabel(_manual)}',
                        ),
                        childrenPadding: const EdgeInsets.all(14),
                        children: [
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_showTopUp) ...<Widget>[
                      Text(
                        '補款方式',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.titleColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
                                        PolicyApplicableService.accommodation,
                                  );
                              if (catalog.methods.isEmpty) {
                                return const Text(
                                  '目前沒有可用補款方式，請先至店家付款設定開啟。待補款不可標成已結清。',
                                );
                              }
                              return RadioGroup<String>(
                                groupValue: _topUpMethod,
                                onChanged: (value) =>
                                    setState(() => _topUpMethod = value ?? ''),
                                child: Column(
                                  children: catalog.methods
                                      .map(
                                        (item) => RadioListTile<String>(
                                          value: item.id,
                                          title: Text(item.title),
                                          subtitle: Text(item.subtitle),
                                        ),
                                      )
                                      .toList(),
                                ),
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
                    Card.outlined(
                      margin: EdgeInsets.zero,
                      child: ExpansionTile(
                        leading: const Icon(Icons.stars_outlined),
                        title: const Text('會員點數'),
                        subtitle: Text(
                          '預計 ${_booking['rewardPointsSystem'] ?? _booking['expectedRewardPoints'] ?? 0} 點・需要調整再展開',
                        ),
                        childrenPadding: const EdgeInsets.all(14),
                        children: [
                          Text(
                            '系統計算可得 ${_booking['rewardPointsSystem'] ?? _booking['expectedRewardPoints'] ?? 0} 點',
                          ),
                          Text(
                            _adjustPoints
                                ? '最終發放以手動輸入為準（後端仍會依實收上限處理）'
                                : '最終發放將使用系統計算值',
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('手動調整點數'),
                            subtitle: const Text('需填寫調整原因；後端會驗證並寫入點數流水。'),
                            value: _adjustPoints,
                            onChanged: (bool value) {
                              setState(() => _adjustPoints = value);
                            },
                          ),
                          if (_adjustPoints) ...<Widget>[
                            TextField(
                              controller: _rewardPoints,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '最終發放點數',
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _rewardReason,
                              decoration: const InputDecoration(
                                labelText: '調整原因（必填）',
                                isDense: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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
                          Text(
                            '加收／減免 ${SettlementAdjustDisplay.signedLabel(_manual)}（已計入最終應收）',
                          ),
                          Text(
                            '最終應收 NT\$$_finalReceivable',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '已收 NT\$$_paid − 已退款 NT\$$_refunded = 實收 NT\$$_net',
                          ),
                          Text(
                            _showTopUp
                                ? '本次需補 NT\$$_remaining'
                                : _showRefund
                                ? '本次需退 NT\$$_refundDue'
                                : '本次無需補退款',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (_manual != 0)
                            Text('調整原因：${_manualReason.text.trim()}'),
                          if (_showTopUp && _topUpMethod.isNotEmpty)
                            Text(
                              '補款方式：${BookingPaymentLabels.method(_topUpMethod)}　付款狀態：${BookingPaymentLabels.status(_booking['settlementTopUpStatus'] ?? 'selected')}',
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${_careBlocked ? '試算 ' : ''}${_showRefund ? '本次應退' : '本次應收'} NT\$${_showRefund ? _refundDue : _remaining}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_careBlocked)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _careBlockReason,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    widget.asDialog
                        ? Row(
                            children: <Widget>[
                              TextButton(
                                onPressed: _refreshingCare
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('取消'),
                              ),
                              const Spacer(),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.buttonColor,
                                  foregroundColor: theme.onPrimaryColor,
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: _careBusy ? null : _confirm,
                                child: Text(_confirmLabel),
                              ),
                            ],
                          )
                        : SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.buttonColor,
                                foregroundColor: theme.onPrimaryColor,
                              ),
                              onPressed: _careBusy ? null : _confirm,
                              child: Text(_confirmLabel),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final guardedSheet = PopScope(canPop: !_refreshingCare, child: sheet);
    if (widget.asDialog) {
      return SizedBox(width: 760, child: guardedSheet);
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: guardedSheet,
      ),
    );
  }

  Widget _feeSection(ShopFrontendTheme theme) {
    final billingData = _booking;
    final extras =
        (billingData['extraCharges'] is List
                ? billingData['extraCharges'] as List
                : const [])
            .whereType<Map>()
            .toList();
    final listedExtra = extras.fold<int>(
      0,
      (total, item) => total + SafeParse.parseMoney(item['amount']),
    );
    final extra = BookingSettlementMath.extraChargeSum(billingData);
    final overtime = SafeParse.parseMoney(billingData['overtimeAmount']);
    final medication = billingData['medication'];
    final advance =
        medication is Map &&
            medication['finalized'] != true &&
            !['declined', 'cancelled'].contains(medication['state'])
        ? BookingSettlementMath.advanceMedicationAmount(billingData)
        : 0;
    final beforeAdjust = _quoted + extra + overtime + advance;
    final floorAdjustment = _finalReceivable - beforeAdjust - _manual;
    final nights = billingData['nights'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '費用明細',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            [
              if ('${billingData['roomName'] ?? ''}'.isNotEmpty)
                '房間 ${billingData['roomName']}',
              if (nights != null) '$nights 晚',
            ].join('・'),
            style: TextStyle(fontSize: 12, color: theme.subtitleColor),
          ),
          const SizedBox(height: 12),
          const Text('① 應收項目', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _moneyRow(theme, '原住宿費用', _quoted),
          for (final item in extras)
            _moneyRow(
              theme,
              '${item['title'] ?? item['label'] ?? item['name'] ?? item['reason'] ?? '加購／額外費用'}',
              SafeParse.parseMoney(item['amount']),
            ),
          if (extra != listedExtra)
            _moneyRow(
              theme,
              extras.isEmpty ? '加購／額外費用' : '額外費用差額（依訂單核算）',
              extra - listedExtra,
            ),
          if (overtime != 0) _moneyRow(theme, '超時費用', overtime),
          if (advance != 0) ...[
            _moneyRow(theme, '預約已列用藥費（最終待核對）', advance),
            const Text(
              '此金額暫列應收；依執行結果確認最終費用後重新核算，不會重複加收。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          if (medication is Map && medication['finalized'] == true) ...[
            const SizedBox(height: 6),
            Text(
              '用藥最終費用 NT\$${SafeParse.parseMoney(medication['finalAmount'])}（已含於上方應收項目，不再重複加收）',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (SafeParse.parseMoney(medication['advanceAmount']) > 0)
              Text(
                '預約原列 NT\$${SafeParse.parseMoney(medication['advanceAmount'])} → 最終 NT\$${SafeParse.parseMoney(medication['finalAmount'])}，差額 ${SettlementAdjustDisplay.signedLabel(SafeParse.parseMoney(medication['finalAmount']) - SafeParse.parseMoney(medication['advanceAmount']))} 已反映在應收。',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
          ],
          const Divider(height: 20),
          _moneyRow(theme, '費用小計', beforeAdjust),
          _moneyRow(theme, _manual < 0 ? '手動減免' : '手動加收', _manual),
          if (_manual != 0)
            Text(
              '調整原因：${_manualReason.text.trim().isEmpty ? '尚未填寫' : _manualReason.text.trim()}',
              style: const TextStyle(fontSize: 12),
            ),
          if (floorAdjustment != 0) _moneyRow(theme, '最低應收調整', floorAdjustment),
          _moneyRow(theme, '最終應收', _finalReceivable, emphasize: true),
          const Divider(height: 24),
          const Text('② 已收與退款', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _moneyRow(theme, '已成功收款', _paid),
          _moneyRow(theme, '已完成退款', _refunded),
          _moneyRow(theme, '實收淨額', _net),
          Text(
            '已收 NT\$$_paid − 已退款 NT\$$_refunded = 實收淨額 NT\$$_net',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const Divider(height: 24),
          const Text('③ 本次需處理', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_remaining > 0)
            _moneyRow(theme, '本次待補款', _remaining, emphasize: true)
          else if (_refundDue > 0)
            _moneyRow(theme, '本次待退款', _refundDue, emphasize: true)
          else
            _moneyRow(theme, '待補款／待退款', 0, emphasize: true),
          Text(
            _remaining > 0
                ? '應收 NT\$$_finalReceivable − 實收 NT\$$_net = 待補 NT\$$_remaining'
                : _refundDue > 0
                ? '實收 NT\$$_net − 應收 NT\$$_finalReceivable = 待退 NT\$$_refundDue'
                : '應收與實收淨額相同。',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          if (_careBlocked)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                '照護或用藥費尚未核對完成，以上為目前試算金額。',
                style: TextStyle(fontSize: 12, color: Color(0xFF986414)),
              ),
            ),
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

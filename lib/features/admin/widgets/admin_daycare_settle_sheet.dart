// 檔案名稱：lib/features/admin/widgets/admin_daycare_settle_sheet.dart
// 功能說明：安親結算 bottom sheet：完整日期時間、晚接回明細、手動調整與收款選項

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class AdminDaycareSettleResult {
  const AdminDaycareSettleResult({
    required this.actualEndAt,
    required this.completeMode,
    required this.waiveReason,
    required this.manualAdjust,
    required this.manualAdjustReason,
  });

  final DateTime actualEndAt;
  final String completeMode;
  final String waiveReason;
  final int manualAdjust;
  final String manualAdjustReason;
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
  String _mode = 'cash';
  bool _loadingPreview = true;
  String? _previewError;
  Map<String, dynamic> _preview = <String, dynamic>{};
  final TextEditingController _waiveReason = TextEditingController();
  final TextEditingController _manualAdjust = TextEditingController(text: '0');
  final TextEditingController _manualReason = TextEditingController();

  DateTime? get _scheduledStart => _ts(widget.booking['scheduledStartAt']);
  DateTime? get _scheduledEnd => _ts(widget.booking['scheduledEndAt']);
  DateTime? get _actualStart => _ts(widget.booking['actualStartAt']);

  @override
  void initState() {
    super.initState();
    _actualEnd = DateTime.now();
    _reloadPreview();
  }

  @override
  void dispose() {
    _waiveReason.dispose();
    _manualAdjust.dispose();
    _manualReason.dispose();
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
              'actualEndAt': _actualEnd.toIso8601String(),
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
    if (_mode == 'waive') {
      return 0;
    }
    return SafeParse.parseMoney(
      _preview['overtimeCharge'] ?? _preview['overtimeAmount'],
    );
  }

  int get _paid => SafeParse.parseMoney(
    _preview['paidAmount'] ?? widget.booking['paidAmount'],
  );

  int get _manual {
    return int.tryParse(_manualAdjust.text.trim()) ?? 0;
  }

  int get _finalReceivable {
    final int value = _quoted + _overtime + _manual;
    return value < 0 ? 0 : value;
  }

  int get _remaining {
    final int left = _finalReceivable - _paid;
    return left < 0 ? 0 : left;
  }

  Future<void> _pickActualEnd() async {
    final DateTime firstDate = _scheduledStart ?? DateTime(2020);
    final DateTime lastDate = DateTime.now().add(const Duration(days: 2));
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _actualEnd,
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
    await _reloadPreview();
  }

  void _confirm() {
    if (_mode == 'waive' && _waiveReason.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請填寫免收原因')));
      return;
    }
    if (_manual != 0 && _manualReason.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請填寫手動調整原因')));
      return;
    }
    Navigator.pop(
      context,
      AdminDaycareSettleResult(
        actualEndAt: _actualEnd,
        completeMode: _mode,
        waiveReason: _waiveReason.text.trim(),
        manualAdjust: _manual,
        manualAdjustReason: _manualReason.text.trim(),
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
                            trailing: TextButton(
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
                            '收款方式',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: theme.titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _modeTile(
                            theme,
                            value: 'cash',
                            title: '已到店收款並完成安親',
                            subtitle: '現場收齊尚待金額後結案',
                          ),
                          const SizedBox(height: 8),
                          _modeTile(
                            theme,
                            value: 'waive',
                            title: '免收本次逾時費並完成安親',
                            subtitle: '方案時間費用仍計入，僅免收晚接回加收',
                          ),
                          if (_mode == 'waive') ...<Widget>[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _waiveReason,
                              decoration: const InputDecoration(
                                labelText: '免收原因',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Text(
                            '手動調整金額',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: theme.titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _manualAdjust,
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                            ),
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^-?\d*'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: '可加價（正數）或減價（負數）',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _manualReason,
                            decoration: const InputDecoration(
                              labelText: '調整原因（金額不為 0 時必填）',
                              border: OutlineInputBorder(),
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
                                Text('原應收 NT\$$_quoted'),
                                Text(
                                  '手動調整 ${_manual >= 0 ? '+' : ''}NT\$$_manual',
                                ),
                                Text(
                                  '最終應收 NT\$$_finalReceivable',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
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
          _moneyRow(theme, '晚接回逾時加收', _overtime),
          _moneyRow(theme, '手動調整', _manual),
          if (_mode == 'waive') _infoLine('調整內容', '免收本次晚接回逾時費'),
          if (capAdjustment != 0) _moneyRow(theme, '上限調整', capAdjustment),
          _moneyRow(theme, '最終應收', _finalReceivable, emphasize: true),
          _moneyRow(theme, '已付款', _paid),
          _moneyRow(theme, '尚待收款', _remaining),
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

  Widget _modeTile(
    ShopFrontendTheme theme, {
    required String value,
    required String title,
    required String subtitle,
  }) {
    final bool selected = _mode == value;
    return InkWell(
      onTap: () => setState(() => _mode = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? theme.primarySoft : theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? theme.primaryColor : theme.borderColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? theme.primaryColor : theme.subtitleColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.titleColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: theme.subtitleColor),
                  ),
                ],
              ),
            ),
          ],
        ),
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

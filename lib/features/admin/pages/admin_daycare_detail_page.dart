// lib/features/admin/pages/admin_daycare_detail_page.dart
// 🐾 安親訂單詳情與操作

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/booking_inventory_function_service.dart';
import 'package:petnest_saas/core/services/daycare_booking_validator.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/features/admin/pages/admin_payment_center_page.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_action_log_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_customer_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_header_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_note_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_price_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_status_chip.dart';
import 'package:petnest_saas/features/admin/widgets/admin_daycare_assign_room_dialog.dart';
import 'package:petnest_saas/features/booking/pages/booking_detail_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/policy_sign_method_field.dart';

class AdminDaycareDetailPage extends StatelessWidget {
  const AdminDaycareDetailPage({
    super.key,
    required this.shopId,
    required this.bookingId,
  });

  final String shopId;
  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final Map<String, dynamic>? data = snapshot.data!.data();
            if (data == null) {
              return const Scaffold(body: Center(child: Text('找不到訂單')));
            }
            return _DaycareDetailBody(
              shopId: shopId,
              bookingId: bookingId,
              data: data,
            );
          },
    );
  }
}

class _DaycareDetailBody extends StatefulWidget {
  const _DaycareDetailBody({
    required this.shopId,
    required this.bookingId,
    required this.data,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> data;

  @override
  State<_DaycareDetailBody> createState() => _DaycareDetailBodyState();
}

class _DaycareDetailBodyState extends State<_DaycareDetailBody> {
  bool _busy = false;

  Future<void> _run(
    String action, {
    Map<String, dynamic> extra = const <String, dynamic>{},
    String confirm = '',
  }) async {
    if (confirm.isNotEmpty) {
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('確認操作'),
          content: Text(confirm),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確定'),
            ),
          ],
        ),
      );
      if (ok != true) {
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await DaycareFunctionService.instance.manage(
        shopId: widget.shopId,
        bookingId: widget.bookingId,
        action: action,
        requestId:
            '${widget.bookingId}_${action}_${DateTime.now().millisecondsSinceEpoch}',
        extra: extra,
      );
      if (action == 'cancel' || action == 'noShow') {
        try {
          await BookingInventoryFunctionService.instance.returnBookingInventory(
            shopId: widget.shopId,
            bookingId: widget.bookingId,
          );
        } catch (_) {}
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _assignRoom() async {
    await showDaycareAssignRoomDialog(
      context: context,
      shopId: widget.shopId,
      bookingId: widget.bookingId,
      booking: widget.data,
    );
  }

  Future<void> _openSettlement() async {
    final DateTime scheduledStart =
        _ts(widget.data['scheduledStartAt']) ?? DateTime.now();
    final DateTime scheduledEnd =
        _ts(widget.data['scheduledEndAt']) ?? DateTime.now();
    DateTime actualEnd = DateTime.now();
    final Map<String, dynamic> preview = await DaycareFunctionService.instance
        .manage(
          shopId: widget.shopId,
          bookingId: widget.bookingId,
          action: 'previewSettle',
          extra: <String, dynamic>{'actualEndAt': actualEnd.toIso8601String()},
        );
    if (!mounted) {
      return;
    }
    String mode = 'cash';
    final TextEditingController waiveReason = TextEditingController();
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '結算安親',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('預約送達：${DaycareTimeHelper.formatHm(scheduledStart)}'),
                    Text('預約接回：${DaycareTimeHelper.formatHm(scheduledEnd)}'),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('實際接回時間'),
                      subtitle: Text(DaycareTimeHelper.formatHm(actualEnd)),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(actualEnd),
                        );
                        if (picked == null) {
                          return;
                        }
                        actualEnd = DateTime(
                          actualEnd.year,
                          actualEnd.month,
                          actualEnd.day,
                          picked.hour,
                          picked.minute,
                        );
                        setModal(() {});
                      },
                    ),
                    Text(
                      '已確認預約時段費用：\$${preview['quotedTotal'] ?? widget.data['quotedTotalPrice'] ?? widget.data['totalPrice'] ?? 0}',
                    ),
                    Text('超時分鐘：${preview['overtimeMinutes'] ?? 0}'),
                    Text('超時規則：${preview['roundingLabel'] ?? '-'}'),
                    Text('超時費：\$${preview['overtimeAmount'] ?? 0}'),
                    Text('當日住宿費上限：\$${preview['capAmount'] ?? 0}'),
                    Text('最終費用：\$${preview['finalTotal'] ?? 0}'),
                    Text('已付款：\$${preview['paidAmount'] ?? 0}'),
                    Text('尚待收款：\$${preview['remainingAmount'] ?? 0}'),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      title: const Text('已到店收款並完成安親'),
                      value: 'cash',
                      groupValue: mode,
                      onChanged: (String? value) {
                        setModal(() => mode = value ?? 'cash');
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('發送線上補款通知'),
                      value: 'request_online',
                      groupValue: mode,
                      onChanged: (String? value) {
                        setModal(() => mode = value ?? 'request_online');
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('免收本次超時費並完成安親'),
                      value: 'waive',
                      groupValue: mode,
                      onChanged: (String? value) {
                        setModal(() => mode = value ?? 'waive');
                      },
                    ),
                    if (mode == 'waive')
                      TextField(
                        controller: waiveReason,
                        decoration: const InputDecoration(
                          labelText: '免收原因（將寫入操作紀錄）',
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, mode),
                      child: const Text('確認結算'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (choice == null) {
      return;
    }
    await _run(
      'settle',
      extra: <String, dynamic>{
        'actualEndAt': actualEnd.toIso8601String(),
        'completeMode': choice,
        'waiveOvertime': choice == 'waive',
        'waiveReason': waiveReason.text.trim(),
      },
    );
  }

  Future<void> _convert() async {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    final DateTime end = start.add(const Duration(days: 1));
    String policy = DaycareConversionHelper.keepDaycare;
    String? staySignMethod;
    final TextEditingController stayTotal = TextEditingController();
    final TextEditingController roomTypeId = TextEditingController();
    final TextEditingController custom = TextEditingController(text: '0');
    final Map<String, dynamic>? stayPolicy = await ShopPolicyService.instance
        .getCheckinPolicy(widget.shopId);
    bool stayPolicyRequired = false;
    int stayPolicyVersion = 0;
    if (stayPolicy != null) {
      final Map<String, dynamic> filtered = ShopPolicyService.instance
          .filterPolicyForService(
            policy: stayPolicy,
            serviceType: PolicyApplicableService.accommodation,
          );
      stayPolicyRequired = ShopPolicyService.instance.policyRequiresSignature(
        filteredPolicy: filtered,
      );
      stayPolicyVersion = (filtered['version'] as num?)?.toInt() ?? 0;
    }
    if (!mounted) {
      return;
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('轉為住宿'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('會新增一張住宿訂單，原安親簽署紀錄仍保留，不可把安親條款當成住宿條款。'),
                    TextField(
                      controller: roomTypeId,
                      decoration: const InputDecoration(labelText: '住宿房型 ID'),
                    ),
                    TextField(
                      controller: stayTotal,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '住宿總價'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: policy,
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: DaycareConversionHelper.keepDaycare,
                          child: Text('安親費照收，住宿另外計算'),
                        ),
                        DropdownMenuItem<String>(
                          value: DaycareConversionHelper.creditAll,
                          child: Text('安親費全部折抵住宿'),
                        ),
                        DropdownMenuItem<String>(
                          value: DaycareConversionHelper.custom,
                          child: Text('自訂折抵金額'),
                        ),
                        DropdownMenuItem<String>(
                          value: DaycareConversionHelper.cancelFee,
                          child: Text('取消安親費，只收住宿'),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          policy = value;
                        }
                      },
                    ),
                    TextField(
                      controller: custom,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '自訂折抵'),
                    ),
                    if (stayPolicyRequired) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        '目前住宿條款版本 v$stayPolicyVersion，轉住宿前必須補簽，不可自動同意。',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      PolicySignMethodField(
                        title: '住宿條款簽署方式',
                        value: staySignMethod,
                        onChanged: (String value) {
                          setDialogState(() => staySignMethod = value);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('轉住宿'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true) {
      return;
    }
    if (stayPolicyRequired &&
        (staySignMethod == null || staySignMethod!.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('轉住宿前請完成住宿條款簽署或記錄現場簽署')));
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await DaycareFunctionService.instance
          .convertToAccommodation(<String, dynamic>{
            'shopId': widget.shopId,
            'bookingId': widget.bookingId,
            'requestId': 'convert_${widget.bookingId}',
            'startDate': start.toIso8601String(),
            'endDate': end.toIso8601String(),
            'nights': 1,
            'roomTypeId': roomTypeId.text.trim(),
            'stayTotalPrice': int.tryParse(stayTotal.text) ?? 0,
            'conversionPolicy': policy,
            'conversionCreditAmount': int.tryParse(custom.text) ?? 0,
            if (stayPolicyRequired)
              'accommodationPolicySignMethod':
                  staySignMethod ?? PolicySignMethods.staffWitness,
          });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data = widget.data;
    final String status = (data['status'] ?? '').toString();
    final DateTime? start = _ts(data['scheduledStartAt']);
    final DateTime? end = _ts(data['scheduledEndAt']);
    final DateTime? actualStart = _ts(data['actualStartAt']);
    final DateTime? actualEnd = _ts(data['actualEndAt']);
    final Map<String, dynamic> emergency = Map<String, dynamic>.from(
      data['emergencyContact'] ?? <String, dynamic>{},
    );
    final List<Map<String, dynamic>> pets = (data['pets'] is List)
        ? (data['pets'] as List)
              .whereType<Map>()
              .map((Map e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];
    final bool locked = status == 'cancelled' || status == 'completed';
    return Scaffold(
      appBar: AppBar(
        title: const Text('安親訂單詳細'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      BookingDetailPage(data: data, docId: widget.bookingId),
                ),
              );
            },
            child: const Text('聊天／會員視角'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          AdminBookingHeaderCard(data: data, bookingId: widget.bookingId),
          AdminBookingStatusChip(status: status),
          const SizedBox(height: 8),
          Text(
            '付款狀態：${data['paymentStatus'] ?? 'unpaid'}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          if (status == 'pending')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('請先確認訂單，確認後才能分配房間'),
            ),
          if (status == 'confirmed' &&
              (data['assignStatus'] ?? 'unassigned') != 'assigned')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('訂單已確認，請完成分房後再辦理入住'),
            ),
          const SizedBox(height: 16),
          const Text('顧客資訊', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          AdminBookingCustomerSection(data: data, emergency: emergency),
          const SizedBox(height: 16),
          Text(
            '寵物資訊（${pets.length}隻）',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (pets.isEmpty)
            const Text('沒有寵物資料', style: TextStyle(color: Colors.grey))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pets.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.52,
              ),
              itemBuilder: (BuildContext context, int index) {
                return AdminBookingPetCard(pet: pets[index]);
              },
            ),
          const SizedBox(height: 16),
          const Text('安親時間', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('安親日期：${data['serviceDate'] ?? '-'}'),
          Text(
            '送達／接回：${start == null ? '-' : DaycareTimeHelper.formatHm(start)}'
            ' - ${end == null ? '-' : DaycareTimeHelper.formatHm(end)}',
          ),
          if (actualStart != null)
            Text('實際開始：${DaycareTimeHelper.formatHm(actualStart)}'),
          if (actualEnd != null)
            Text('實際完成／接回：${DaycareTimeHelper.formatHm(actualEnd)}'),
          Text(
            '方案：${data['daycarePlanSnapshot'] is Map ? (data['daycarePlanSnapshot']['name'] ?? '-') : '-'}',
          ),
          Text(
            '房型：${data['roomTypeName'] ?? '-'}　實際房號：${(data['roomName'] ?? '').toString().isEmpty ? '尚未分房' : data['roomName']}',
          ),
          Text('分房狀態：${data['assignStatus'] ?? 'unassigned'}'),
          if ((data['convertedBookingId'] ?? '').toString().isNotEmpty)
            Text('已轉住宿：${data['convertedBookingId']}'),
          if ((data['overtimeMinutes'] ?? 0) != 0)
            Text(
              '超時 ${data['overtimeMinutes']} 分鐘　超時費 \$${data['overtimeAmount'] ?? 0}',
            ),
          const SizedBox(height: 16),
          const Text('價格', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          AdminBookingPriceSection(data: data, pets: pets),
          const SizedBox(height: 16),
          const Text('付款摘要', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AdminPaymentCenterPage(
                    shopId: widget.shopId,
                    bookingId: widget.bookingId,
                    bookingCode: (data['bookingCode'] ?? '').toString(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('查看完整交易'),
          ),
          const SizedBox(height: 16),
          const Text('訂單備註', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          AdminBookingNoteSection(data: data),
          Card(
            child: ListTile(
              leading: const Icon(Icons.gavel_rounded),
              title: Text(
                (data['policyVersion'] == null || data['policyVersion'] == 0)
                    ? '舊訂單／尚無條款確認紀錄'
                    : ((data['signatureUrl'] ?? data['signatureImageUrl'] ?? '')
                              .toString()
                              .isNotEmpty
                          ? (data['policyTitle'] ?? '安親須知').toString()
                          : '已確認條款'),
              ),
              subtitle: Text(
                (data['policyVersion'] == null || data['policyVersion'] == 0)
                    ? '舊安親訂單沒有條款確認資料'
                    : '條款版本 v${data['termsVersion'] ?? data['policyVersion']}',
              ),
            ),
          ),
          if (status == 'cancelled') ...<Widget>[
            const SizedBox(height: 12),
            Text(
              '取消原因：${data['cancelReason'] ?? '未填寫'}',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '取消來源：${data['cancelBy'] ?? '未填寫'}',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (!locked && status == 'pending')
                FilledButton(
                  onPressed: _busy ? null : () => _run('confirm'),
                  child: const Text('確認訂單'),
                ),
              if (!locked &&
                  status == 'confirmed' &&
                  (data['assignStatus'] ?? 'unassigned') != 'assigned')
                FilledButton.icon(
                  onPressed: _busy ? null : _assignRoom,
                  icon: const Icon(Icons.meeting_room),
                  label: const Text('分配房間'),
                ),
              if (!locked &&
                  status == 'confirmed' &&
                  (data['assignStatus'] ?? '') == 'assigned')
                FilledButton(
                  onPressed: _busy ? null : () => _run('start'),
                  child: const Text('入住'),
                ),
              if (!locked &&
                  (data['assignStatus'] ?? '') == 'assigned' &&
                  (status == 'confirmed' || status == 'checked_in'))
                OutlinedButton.icon(
                  onPressed: _busy ? null : _assignRoom,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('換房'),
                ),
              if (!locked && status == 'checked_in')
                FilledButton(
                  onPressed: _busy ? null : _openSettlement,
                  child: const Text('結算安親／退房'),
                ),
              if (!locked && (status == 'confirmed' || status == 'pending'))
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run('noShow', confirm: '標記未到並依設定沒收訂金？'),
                  child: const Text('No-show'),
                ),
              if (!locked)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run('cancel', confirm: '確定取消此安親訂單？'),
                  child: const Text('取消訂單'),
                ),
              if (status != 'cancelled')
                OutlinedButton(
                  onPressed: _busy ? null : _convert,
                  child: const Text('轉為住宿'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('操作紀錄', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          AdminBookingActionLogSection(
            shopId: widget.shopId,
            bookingId: widget.bookingId,
          ),
        ],
      ),
    );
  }

  DateTime? _ts(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    return null;
  }
}

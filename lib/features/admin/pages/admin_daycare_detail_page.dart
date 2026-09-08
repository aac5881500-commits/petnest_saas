// 檔案名稱：lib/features/admin/pages/admin_daycare_detail_page.dart
// 功能說明：安親訂單詳情與操作

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/custom_form/widgets/custom_form_answer_view.dart';
import 'package:petnest_saas/core/services/booking_inventory_function_service.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';
import 'package:petnest_saas/core/services/daycare_assign_room_rules.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_payment_display.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';
import 'package:petnest_saas/core/services/daycare_status_labels.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_action_log_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_customer_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_payment_aside.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_policy_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_header_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_note_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_strip.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_price_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_status_chip.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_timeline.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_message_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_daycare_assign_room_dialog.dart';
import 'package:petnest_saas/features/admin/widgets/admin_daycare_settle_sheet.dart';
import 'package:petnest_saas/features/booking/pages/booking_detail_page.dart';

class AdminDaycareDetailPage extends StatelessWidget {
  const AdminDaycareDetailPage({
    super.key,
    required this.shopId,
    required this.bookingId,
    this.canEdit = true,
  });

  final String shopId;
  final String bookingId;
  final bool canEdit;

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
              canEdit: canEdit,
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
    this.canEdit = true,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> data;
  final bool canEdit;

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
      final Map<String, dynamic>
      result = await DaycareFunctionService.instance.manage(
        shopId: widget.shopId,
        bookingId: widget.bookingId,
        action: action,
        requestId:
            '${widget.bookingId}_${action}_${DateTime.now().millisecondsSinceEpoch}',
        extra: extra,
      );
      if (action == 'confirmDeposit') {
        final bool written =
            result['depositPaid'] == true ||
            (result['depositStatus'] ?? '').toString() == 'confirmed';
        if (!written) {
          throw const DaycareFunctionException('確認訂金未寫入付款狀態，請重試');
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已確認訂金')));
        }
      }
      if (action == 'cancel') {
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
    final AdminDaycareSettleResult? choice = await showAdminDaycareSettleSheet(
      context: context,
      shopId: widget.shopId,
      bookingId: widget.bookingId,
      booking: widget.data,
    );
    if (choice == null) {
      return;
    }
    await _run(
      'settle',
      extra: <String, dynamic>{
        'actualEndAt': choice.actualEndAt.toIso8601String(),
        'completeMode': choice.completeMode,
        'waiveOvertime': choice.completeMode == 'waive',
        'waiveReason': choice.waiveReason,
        'manualAdjust': choice.manualAdjust,
        'manualAdjustReason': choice.manualAdjustReason,
      },
    );
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
    final bool roomBased = DaycareAssignRoomRules.isRoomBased(data);
    final int durationMinutes = start != null && end != null
        ? end.difference(start).inMinutes
        : DaycarePaymentDisplay.toInt(
            data['daycarePricingSnapshot'] is Map
                ? (data['daycarePricingSnapshot'] as Map)['durationMinutes']
                : 0,
          );
    final DaycareHourlyDisplayInfo hourlyDisplay = DaycarePricingService
        .instance
        .hourlyDisplayFromBooking(data, startAt: start, endAt: end);
    final Widget actionBar = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        if (!locked &&
            (status == 'pending' || status == 'pending_confirmation') &&
            DaycarePaymentDisplay.toInt(data['depositAmount']) > 0 &&
            !BookingPaymentStatus.isDepositConfirmed(data))
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
            onPressed: _busy
                ? null
                : () => _run('confirmDeposit', confirm: '確認已收到訂金？'),
            child: const Text('確認訂金'),
          ),
        if (!locked &&
            (status == 'pending' || status == 'pending_confirmation') &&
            (DaycarePaymentDisplay.toInt(data['depositAmount']) <= 0 ||
                BookingPaymentStatus.isDepositConfirmed(data)))
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
            onPressed: _busy ? null : () => _run('confirm'),
            child: const Text('確認'),
          ),
        if (!locked &&
            status == 'confirmed' &&
            (data['assignStatus'] ?? 'unassigned') != 'assigned')
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
            onPressed: _busy ? null : _assignRoom,
            icon: const Icon(Icons.meeting_room),
            label: const Text('分配房間'),
          ),
        if (!locked &&
            status == 'confirmed' &&
            (data['assignStatus'] ?? '') == 'assigned')
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
            onPressed: _busy ? null : () => _run('start'),
            child: const Text('入住'),
          ),
        if (!locked &&
            (data['assignStatus'] ?? '') == 'assigned' &&
            (status == 'confirmed' || status == 'checked_in'))
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 44)),
            onPressed: _busy ? null : _assignRoom,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('換房'),
          ),
        if (!locked && status == 'checked_in')
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
            onPressed: _busy ? null : _openSettlement,
            child: const Text('結算安親／退房'),
          ),
        if (!locked)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 44),
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            onPressed: _busy
                ? null
                : () => _run('cancel', confirm: '確定取消此安親訂單？'),
            child: const Text('取消訂單'),
          ),
      ],
    );

    return ShopFrontendThemeScope(
      shopId: widget.shopId,
      builder: (BuildContext context) {
        return AdminBookingDetailScaffold(
          title: '訂單詳細',
          bookingCode: (data['bookingCode'] ?? '').toString(),
          appBarActions: <Widget>[
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
          overview: AdminBookingHeaderCard(
            data: data,
            bookingId: widget.bookingId,
          ),
          actions: widget.canEdit
              ? AdminBookingDetailCard(child: actionBar)
              : null,
          left: <Widget>[
            if (status == 'pending' || status == 'pending_confirmation')
              const Text('請先確認訂單，確認後才能分配房間'),
            if (status == 'confirmed' &&
                (data['assignStatus'] ?? 'unassigned') != 'assigned')
              const Text('訂單已確認，請完成分房後再辦理入住'),
            AdminBookingDetailSection(
              title: '顧客資訊',
              child: AdminBookingCustomerSection(
                data: data,
                emergency: emergency,
                shopId: widget.shopId,
              ),
            ),
            AdminBookingDetailSection(
              title: '寵物資訊（${pets.length}隻）',
              child: AdminBookingPetStrip(
                pets: pets,
                shopId: widget.shopId,
                userId: (data['userId'] ?? '').toString(),
              ),
            ),
            AdminBookingDetailSection(
              title: '安親時間',
              child: AdminBookingDetailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '安親日期：${data['serviceDate'] ?? (start == null ? '未填' : DaycareTimeHelper.formatDate(start))}',
                    ),
                    Text(
                      '預約送達：${DaycareTimeHelper.formatDateTimeOrUnrecorded(start)}',
                    ),
                    Text(
                      '預約接回：${DaycareTimeHelper.formatDateTimeOrUnrecorded(end)}',
                    ),
                    Text(
                      '預計時數：${DaycareTimeHelper.durationLabel(durationMinutes)}',
                    ),
                    const SizedBox(height: 8),
                    Text(hourlyDisplay.reservationText),
                    Text(hourlyDisplay.thisChargeText),
                    Text(
                      '實際送達：${DaycareTimeHelper.formatDateTimeOrUnrecorded(actualStart)}',
                    ),
                    Text(
                      '實際接回／結算完成：${DaycareTimeHelper.formatDateTimeOrUnrecorded(actualEnd)}',
                    ),
                  ],
                ),
              ),
            ),
            AdminBookingDetailSection(
              title: '安親方案與房間安排',
              child: AdminBookingDetailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(hourlyDisplay.billingModeLabel),
                    if (hourlyDisplay.startRuleText.isNotEmpty)
                      Text(hourlyDisplay.startRuleText),
                    if (hourlyDisplay.extraRuleText.isNotEmpty)
                      Text(hourlyDisplay.extraRuleText),
                    if (hourlyDisplay.capText.isNotEmpty)
                      Text(hourlyDisplay.capText),
                    if (hourlyDisplay.ruleText.isNotEmpty)
                      Text(hourlyDisplay.ruleText),
                    if (!roomBased)
                      Text(
                        '安親方案：${data['daycarePlanSnapshot'] is Map ? ((data['daycarePlanSnapshot']['name'] ?? '').toString().trim().isEmpty ? '未填' : data['daycarePlanSnapshot']['name']) : '未填'}',
                      ),
                    if (roomBased)
                      Text(
                        '客戶選擇房型：${(data['requestedRoomTypeName'] ?? '').toString().trim().isEmpty ? '未填' : data['requestedRoomTypeName']}',
                      )
                    else
                      Text(
                        '分配房型：${(data['roomTypeName'] ?? '').toString().trim().isEmpty ? '尚未選擇' : data['roomTypeName']}',
                      ),
                    Text(
                      '實際房間：${(data['roomName'] ?? '').toString().trim().isEmpty ? '尚未分房' : data['roomName']}',
                    ),
                    Text('分房狀態：${DaycareStatusLabels.assignLabel(data)}'),
                    if ((data['convertedBookingId'] ?? '')
                        .toString()
                        .isNotEmpty)
                      Text('已轉住宿：${data['convertedBookingId']}'),
                  ],
                ),
              ),
            ),
            CustomFormAnswerView(
              raw:
                  data['customFormAnswers'] ??
                  data['bookingFormAnswers'] ??
                  data['formAnswers'],
              title: '本次照護交代',
              theme: HomeThemeModel.classicDefault,
              collapsible: true,
            ),
            AdminBookingDetailSection(
              title: '價格與加值服務',
              child: AdminBookingPriceSection(
                data: data,
                pets: pets,
                lineItemsOnly: true,
              ),
            ),
            AdminBookingDetailSection(
              title: '訂單備註',
              collapsible: true,
              initiallyExpanded: false,
              child: AdminBookingNoteSection(data: data),
            ),
            AdminBookingDetailSection(
              title: '訂單留言',
              collapsible: true,
              initiallyExpanded: false,
              child: BookingDetailMessageSection(
                bookingId: widget.bookingId,
                senderType: 'shop',
                bookingStatus: status,
              ),
            ),
          ],
          right: <Widget>[
            AdminBookingDetailPaymentAside(
              data: data,
              bookingId: widget.bookingId,
            ),
            AdminBookingDetailPolicyCard(data: data),
            AdminBookingDetailSection(
              title: '訂單時間軸',
              collapsible: true,
              child: AdminBookingTimeline(
                data: data,
                status: status,
                depositRequired: data['depositRequired'] == true,
                daycare: true,
              ),
            ),
            AdminBookingDetailSection(
              title: '狀態',
              collapsible: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AdminBookingStatusChip(status: status, daycare: true),
                  if (status == 'cancelled') ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      '取消原因：${(data['cancelReason'] ?? '').toString().trim().isEmpty ? '未填' : data['cancelReason']}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '取消來源：${(data['cancelBy'] ?? '').toString().trim().isEmpty ? '未填' : data['cancelBy']}',
                    ),
                  ],
                ],
              ),
            ),
            AdminBookingDetailSection(
              title: '操作紀錄',
              collapsible: true,
              initiallyExpanded: false,
              child: AdminBookingActionLogSection(
                shopId: widget.shopId,
                bookingId: widget.bookingId,
              ),
            ),
          ],
        );
      },
    );
  }

  DateTime? _ts(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    return null;
  }
}

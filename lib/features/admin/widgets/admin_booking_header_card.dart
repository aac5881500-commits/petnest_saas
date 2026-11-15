// 檔案名稱：lib/features/admin/widgets/admin_booking_header_card.dart
// 功能說明：店主訂單詳細橫向總覽：狀態、客戶、編號、日期與服務摘要

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';
import 'package:petnest_saas/core/services/daycare_payment_display.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/widgets/member_avatar.dart';
import 'package:petnest_saas/core/services/booking_current_room.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_date_helpers.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_status_chip.dart';
import 'package:petnest_saas/features/booking/widgets/booking_current_room_panel.dart';
import 'package:petnest_saas/features/shop/widgets/booking/policy_sign_method_field.dart';

class AdminBookingHeaderCard extends StatelessWidget {
  const AdminBookingHeaderCard({
    super.key,
    required this.data,
    required this.bookingId,
    this.dense = false,
  });

  final Map<String, dynamic> data;
  final String bookingId;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final bool daycare = BookingKind.isDaycare(data);
    final bool prominent = dense && !daycare;
    final bool phone = AdminBookingDetailScope.of(context).isPhone;
    final String code = _bookingCode(data, bookingId);
    final String name = (data['customerName'] ?? data['name'] ?? '')
        .toString()
        .trim();
    final Color ink =
        Color.lerp(theme.primaryColor, const Color(0xFF1F2A24), 0.45) ??
        theme.primaryColor;
    final Color panel =
        Color.lerp(ink, Colors.white, 0.88) ?? theme.primarySoft;
    final Widget identity = _identityRow(
      context,
      theme: theme,
      phone: phone,
      name: name,
      code: code,
    );
    final Widget roomPanel = BookingCurrentRoomPanel(
      data: data,
      audience: BookingCurrentRoomAudience.staff,
      compact: daycare ? phone : true,
      tight: !daycare,
      inline: dense,
      prominent: prominent,
      unassignedStaffLabel: daycare ? null : '尚未安排房間',
    );
    if (dense && !daycare) {
      final view = BookingDetailViewData.fromBooking(
        data: data,
        docId: bookingId,
      );
      final addons = data['addons'];
      final plan = addons is List
          ? addons
                .whereType<Map>()
                .where((item) => item['type'] == 'time')
                .map((item) => '${item['label'] ?? item['name'] ?? ''}'.trim())
                .where((label) => label.isNotEmpty)
                .join('、')
          : '';
      final String paymentType = view.payAmountType == 'full'
          ? '全額付款'
          : view.depositAmount > 0
          ? '先付訂金'
          : '無須訂金';
      final isCancelled = const {'cancelled', 'no_show'}.contains(view.status);
      return AdminBookingDetailCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                _pill('住宿', theme.primaryColor),
                _pill(_durationLabel(data, false), theme.primaryColor),
                AdminBookingStatusChip(
                  status: view.status,
                  daycare: false,
                  paymentPending: false,
                  data: data,
                ),
                if (data['source'] == 'admin')
                  _pill('手動建立', ShopFrontendTheme.warningColor),
              ],
            ),
            LayoutBuilder(
              builder: (context, bounds) {
                final dates = DecoratedBox(
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _stayDateJourney(context, theme, phone: phone),
                  ),
                );
                final planValue = _summaryValue(
                  theme,
                  '入退房方案',
                  plan.isEmpty ? '未記載' : plan,
                );
                final paymentValue = _summaryValue(
                  theme,
                  '結帳方式',
                  '${view.paymentMethodLabel} · $paymentType',
                );
                final options = bounds.maxWidth >= 300 && bounds.maxWidth < 780
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 12,
                        children: [
                          Expanded(child: planValue),
                          Expanded(child: paymentValue),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [planValue, paymentValue],
                      );
                if (bounds.maxWidth < 780) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [identity, dates, options],
                  );
                }
                return Row(
                  spacing: 20,
                  children: [
                    Expanded(flex: 2, child: identity),
                    Expanded(flex: 3, child: dates),
                    Expanded(flex: 2, child: options),
                  ],
                );
              },
            ),
            const Divider(height: 1),
            Wrap(
              spacing: 20,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _pill(
                  view.paymentStatusLabel,
                  theme.primaryColor,
                  fontSize: 14,
                ),
                if (!isCancelled && view.dueNowAmount > 0)
                  _meta(theme, '本次應收', 'NT\$ ${view.dueNowAmount}'),
                _meta(theme, '已收', 'NT\$ ${view.paidAmount}'),
              ],
            ),
            roomPanel,
          ],
        ),
      );
    }
    if (dense) {
      final dates = daycare
          ? _dateRow(context, daycare: true, phone: false)
          : _stayDateJourney(context, theme, phone: phone);
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE7E9EF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              color: Color.alphaBlend(
                theme.primaryColor.withValues(alpha: 0.08),
                Colors.white,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    daycare ? Icons.wb_sunny_outlined : Icons.hotel_outlined,
                    size: 19,
                    color: theme.primaryColor,
                  ),
                  Text(
                    daycare ? '安親預約' : '住宿預約',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.titleColor,
                    ),
                  ),
                  _pill(_durationLabel(data, daycare), theme.primaryColor),
                  AdminBookingStatusChip(
                    status: (data['status'] ?? 'pending').toString(),
                    daycare: daycare,
                    paymentPending: _paymentPending(data),
                    depositConfirmed: BookingPaymentStatus.isDepositConfirmed(
                      data,
                    ),
                    data: data,
                  ),
                  if ((data['source'] ?? '').toString() == 'admin')
                    _pill('手動建立', ShopFrontendTheme.warningColor),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final schedule = Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: dates,
                  );
                  if (constraints.maxWidth < 540) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identity,
                        const SizedBox(height: 16),
                        schedule,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 2, child: identity),
                      const SizedBox(width: 20),
                      Expanded(flex: 3, child: schedule),
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: roomPanel,
            ),
          ],
        ),
      );
    }
    return AdminBookingDetailCard(
      tint: panel,
      padding: EdgeInsets.symmetric(
        horizontal: phone ? 14 : 16,
        vertical: daycare ? (phone ? 12 : 14) : (phone ? 10 : 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              AdminBookingStatusChip(
                status: (data['status'] ?? 'pending').toString(),
                daycare: daycare,
                paymentPending: _paymentPending(data),
                depositConfirmed: BookingPaymentStatus.isDepositConfirmed(data),
                data: data,
              ),
              _pill(daycare ? '安親' : '住宿', theme.primaryColor),
              if ((data['source'] ?? '').toString() == 'admin')
                _pill('手動建立', ShopFrontendTheme.warningColor),
            ],
          ),
          SizedBox(height: daycare ? 12 : 10),
          if (!daycare && !phone)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      identity,
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: roomPanel,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: _stayDateJourney(context, theme, phone: false),
                ),
              ],
            )
          else ...<Widget>[
            identity,
            SizedBox(height: daycare ? 12 : 10),
            if (phone) ...<Widget>[
              roomPanel,
              SizedBox(height: daycare ? 12 : 10),
              daycare
                  ? _dateRow(context, daycare: true, phone: true)
                  : _stayDateJourney(context, theme, phone: true),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: roomPanel,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _dateRow(context, daycare: true, phone: false),
                  ),
                ],
              ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: <Widget>[
              _meta(theme, '建立', adminBookingFormatDateTime(data['createdAt'])),
              if ((data['source'] ?? '').toString() == 'admin') ...<Widget>[
                _meta(
                  theme,
                  '建立人',
                  (data['createdByEmail'] ?? '').toString().trim().isEmpty
                      ? '已移除店員'
                      : (data['createdByEmail'] ?? '').toString(),
                ),
                if ((data['policySignMethod'] ?? '').toString().isNotEmpty)
                  _meta(
                    theme,
                    '條款確認',
                    PolicySignMethods.label(
                      (data['policySignMethod'] ?? '').toString(),
                    ),
                  ),
                if ((data['note'] ?? '').toString().trim().isNotEmpty)
                  _meta(theme, '客戶備註', (data['note'] ?? '').toString()),
              ],
              if (daycare && _planLabel(data).isNotEmpty)
                _meta(theme, '方案', _planLabel(data)),
              if (daycare) _meta(theme, '時數', _durationLabel(data, true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _identityRow(
    BuildContext context, {
    required ShopFrontendTheme theme,
    required bool phone,
    required String name,
    required String code,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ShopMemberLiveAvatar(
          shopId: (data['shopId'] ?? '').toString(),
          userId: (data['userId'] ?? '').toString(),
          name: name.isEmpty ? '會員' : name,
          size: dense ? 36 : (phone ? 40 : 48),
          booking: data,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name.isEmpty ? '未填客戶姓名' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: dense && !BookingKind.isDaycare(data)
                      ? (phone ? 22 : 25)
                      : 16,
                  fontWeight: FontWeight.w800,
                  color: theme.titleColor,
                ),
              ),
              if (dense && !BookingKind.isDaycare(data))
                Builder(
                  builder: (context) {
                    final view = BookingDetailViewData.fromBooking(
                      data: data,
                      docId: bookingId,
                    );
                    final count = view.petCount;
                    return Text(
                      [
                        if (view.petNames.isNotEmpty) view.petNames,
                        if (count > 0) '$count 隻貓' else '貓咪資料未填',
                      ].join(' · '),
                      style: TextStyle(
                        color: theme.titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    );
                  },
                ),
              if (!dense) const SizedBox(height: 2),
              if (!dense)
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('已複製訂單編號')));
                    }
                  },
                  child: Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.copy_rounded, size: 14, color: theme.muted),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stayDateJourney(
    BuildContext context,
    ShopFrontendTheme theme, {
    required bool phone,
  }) {
    final String start = _formatStay(data['startDate']);
    final String end = _formatStay(data['endDate']);
    final String nights = _durationLabel(data, false);
    final entries = dense
        ? AdminBookingScheduleData(
            shopId: '${data['shopId'] ?? ''}',
            bookingId: bookingId,
            booking: data,
            canEdit: false,
          ).entries(showMedication: false)
        : const <BookingScheduleEntry>[];
    final arrival = entries
        .where((entry) => entry.kind == BookingScheduleKind.arrival)
        .firstOrNull;
    final departure = entries
        .where((entry) => entry.kind == BookingScheduleKind.departure)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _stayDateCell(
                theme,
                '入住',
                start,
                time: arrival?.timeLabel,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(6, phone ? 16 : 18, 6, 0),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: theme.primaryColor,
              ),
            ),
            Expanded(
              child: _stayDateCell(
                theme,
                '退房',
                end,
                alignEnd: true,
                time: departure?.timeLabel,
              ),
            ),
          ],
        ),
        if (!dense) const SizedBox(height: 8),
        if (!dense)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '晚數 $nights',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _stayDateCell(
    ShopFrontendTheme theme,
    String label,
    String value, {
    bool alignEnd = false,
    String? time,
  }) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: dense ? 14 : 12.5,
            fontWeight: FontWeight.w600,
            color: theme.muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: dense ? 20 : 16,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: theme.titleColor,
          ),
        ),
        if (time != null)
          Text(
            time,
            style: TextStyle(
              color: theme.titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _dateRow(
    BuildContext context, {
    required bool daycare,
    required bool phone,
  }) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final String startLabel = daycare ? '預約送達' : '入住';
    final String endLabel = daycare ? '預約接回' : '退房';
    final String start = daycare
        ? _formatTaipei(data['scheduledStartAt'] ?? data['startDate'])
        : _formatStay(data['startDate']);
    final String end = daycare
        ? _formatTaipei(data['scheduledEndAt'] ?? data['endDate'])
        : _formatStay(data['endDate']);
    final List<Widget> dates = <Widget>[
      Expanded(child: _dateCell(theme, startLabel, start)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.arrow_forward, size: 18, color: theme.primaryColor),
      ),
      Expanded(child: _dateCell(theme, endLabel, end, alignEnd: true)),
    ];
    if (phone) {
      return Column(
        children: <Widget>[
          _dateCell(theme, startLabel, start),
          Icon(Icons.arrow_downward, size: 16, color: theme.primaryColor),
          _dateCell(theme, endLabel, end),
        ],
      );
    }
    return Row(children: dates);
  }

  Widget _dateCell(
    ShopFrontendTheme theme,
    String label,
    String value, {
    bool alignEnd = false,
    String? time,
  }) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: TextStyle(fontSize: 11, color: theme.muted)),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.titleColor,
          ),
        ),
      ],
    );
  }

  Widget _meta(ShopFrontendTheme theme, String label, String value) {
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label  ',
            style: TextStyle(fontSize: 12, color: theme.muted),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: theme.titleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryValue(
    ShopFrontendTheme theme,
    String label,
    String value, {
    bool amount = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: theme.muted)),
        Text(
          value,
          style: TextStyle(
            fontSize: amount ? 23 : 17,
            fontWeight: FontWeight.w800,
            color: theme.titleColor,
          ),
        ),
      ],
    );
  }

  Widget _pill(String text, Color color, {double fontSize = 12}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
        ),
      ),
    );
  }

  static bool _paymentPending(Map<String, dynamic> data) {
    if ((data['status'] ?? '').toString() == 'cancelled') {
      return false;
    }
    final int total = DaycarePaymentDisplay.resolveTotal(data);
    final int paid = BookingPaymentStatus.resolvePaid(data);
    return total > 0 &&
        paid < total &&
        !BookingPaymentStatus.isDepositConfirmed(data);
  }

  static String _bookingCode(Map<String, dynamic> data, String bookingId) {
    final String code = (data['bookingCode'] ?? '').toString().trim();
    if (code.isNotEmpty) {
      return code;
    }
    if (bookingId.length >= 8) {
      return bookingId.substring(0, 8);
    }
    return bookingId;
  }

  static String _planLabel(Map<String, dynamic> data) {
    if (data['daycarePlanSnapshot'] is Map) {
      final String name = ((data['daycarePlanSnapshot'] as Map)['name'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) {
        return name;
      }
    }
    return '';
  }

  static String _durationLabel(Map<String, dynamic> data, bool daycare) {
    if (!daycare) {
      return '${data['nights'] ?? 0} 晚';
    }
    final DateTime? start = _ts(data['scheduledStartAt'] ?? data['startDate']);
    final DateTime? end = _ts(data['scheduledEndAt'] ?? data['endDate']);
    if (start != null && end != null) {
      return DaycareTimeHelper.durationLabel(end.difference(start).inMinutes);
    }
    return '未填';
  }

  static DateTime? _ts(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return null;
  }

  static String _formatStay(dynamic raw) {
    final DateTime? value = _ts(raw);
    if (value == null) {
      return '未填';
    }
    return adminBookingFormatDate(value);
  }

  static String _formatTaipei(dynamic raw) {
    final DateTime? value = _ts(raw);
    if (value == null) {
      return '未填';
    }
    return DaycareTimeHelper.formatDateTime(value);
  }
}

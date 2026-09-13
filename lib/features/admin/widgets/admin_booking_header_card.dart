// 檔案名稱：lib/features/admin/widgets/admin_booking_header_card.dart
// 功能說明：店主訂單詳細橫向總覽：狀態、客戶、編號、日期與服務摘要

import 'package:cloud_firestore/cloud_firestore.dart';
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
  });

  final Map<String, dynamic> data;
  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final bool daycare = BookingKind.isDaycare(data);
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
    return AdminBookingDetailCard(
      tint: panel,
      padding: EdgeInsets.symmetric(
        horizontal: phone ? 14 : 18,
        vertical: phone ? 12 : 14,
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
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ShopMemberLiveAvatar(
                shopId: (data['shopId'] ?? '').toString(),
                userId: (data['userId'] ?? '').toString(),
                name: name.isEmpty ? '會員' : name,
                size: phone ? 40 : 48,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已複製訂單編號')),
                          );
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
                          Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: theme.muted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BookingCurrentRoomPanel(
            data: data,
            audience: BookingCurrentRoomAudience.staff,
            compact: phone,
          ),
          const SizedBox(height: 12),
          _dateRow(context, daycare: daycare, phone: phone),
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
              _meta(
                theme,
                daycare ? '方案／房型' : '房型',
                _serviceLabel(data, daycare),
              ),
              _meta(
                theme,
                daycare ? '時數' : '晚數',
                _durationLabel(data, daycare),
              ),
            ],
          ),
        ],
      ),
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

  Widget _pill(String text, Color color) {
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
          fontSize: 12,
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

  static String _serviceLabel(Map<String, dynamic> data, bool daycare) {
    if (daycare) {
      if (data['daycarePlanSnapshot'] is Map) {
        final String name = ((data['daycarePlanSnapshot'] as Map)['name'] ?? '')
            .toString();
        if (name.trim().isNotEmpty) {
          return name;
        }
      }
      final String requested = (data['requestedRoomTypeName'] ?? '').toString();
      if (requested.trim().isNotEmpty) {
        return requested;
      }
    }
    final String room =
        (data['roomTypeNameSnapshot'] ?? data['roomTypeName'] ?? '').toString();
    return room.trim().isEmpty ? '尚未指定房型' : room;
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

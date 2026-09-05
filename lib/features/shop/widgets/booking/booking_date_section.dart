// 檔案名稱：lib/features/shop/widgets/booking/booking_date_section.dart
// 功能說明：前台預約日期區塊：顯示店名、預約狀態提示、已選日期與選擇日期按鈕

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';

class BookingDateSection extends StatelessWidget {
  const BookingDateSection({
    super.key,
    required this.shopName,
    required this.bookingEnabled,
    required this.onOpenCalendar,
    this.theme = HomeThemeModel.classicDefault,
    this.startDate,
    this.endDate,
    this.nights = 0,
  });

  final String shopName;
  final bool bookingEnabled;
  final VoidCallback onOpenCalendar;
  final HomeThemeModel theme;
  final DateTime? startDate;
  final DateTime? endDate;
  final int nights;

  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDate = startDate != null && endDate != null;

    return BookingThemedCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            shopName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '日期與貓咪',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            bookingEnabled ? '請先從月曆選擇入住與退房日期' : '目前店家暫停開放預約',
            style: TextStyle(
              fontSize: 12,
              color: bookingEnabled
                  ? theme.textColor.withValues(alpha: 0.7)
                  : Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          _dateRow('入住日', hasDate ? _formatDate(startDate!) : '尚未選擇'),
          const SizedBox(height: 8),
          _dateRow('退房日', hasDate ? _formatDate(endDate!) : '尚未選擇'),
          const SizedBox(height: 8),
          _dateRow('住宿晚數', hasDate ? '$nights 晚' : '—'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: bookingEnabled ? onOpenCalendar : null,
              icon: const Icon(Icons.calendar_month, size: 18),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.primaryColor,
                side: BorderSide(color: theme.cardBorderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              label: Text(
                hasDate ? '重新選擇日期' : '選擇日期',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateRow(String label, String value) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: theme.textColor.withValues(alpha: 0.7),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
        ),
      ],
    );
  }
}

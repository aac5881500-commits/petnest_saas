import 'booking_editorial_design.dart';
import 'booking_appearance_scope.dart';
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
    final style = BookingAppearanceScope.of(context).style;
    final bool hasDate = startDate != null && endDate != null;

    if (style == 'editorial') {
      Widget field(String title, DateTime? date) => Column(
        children: [
          Text(title, style: BookingEditorial.body(14, context)),
          const SizedBox(height: 3),
          Text(
            date == null ? '選擇日期' : '${date.month}/${date.day}',
            style: BookingEditorial.title(23, context),
          ),
        ],
      );
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: BookingEditorial.theme(context).cardBorderColor,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: field('入住', startDate)),
                Container(
                  width: 1,
                  height: 38,
                  color: BookingEditorial.theme(context).cardBorderColor,
                ),
                Expanded(child: field('退房', endDate)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: BookingEditorial.tint(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                hasDate ? '共 $nights 晚' : '請選擇住宿日期',
                textAlign: TextAlign.center,
                style: BookingEditorial.body(12, context),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: bookingEnabled ? onOpenCalendar : null,
              icon: const Icon(Icons.calendar_month_outlined, size: 20),
              label: Text(
                hasDate ? '修改日期' : '選擇日期',
                style: BookingEditorial.title(15, context),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: BookingEditorial.theme(context).primaryColor,
                side: BorderSide(
                  color: BookingEditorial.theme(context).primaryColor,
                ),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (style == 'cream' || style == 'house') {
      final cream = style == 'cream';
      Widget field(String label, DateTime? date) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: theme.textColor)),
          const SizedBox(height: 5),
          Text(
            date == null ? '選擇日期' : '${date.month}/${date.day}',
            style: TextStyle(
              fontSize: date == null ? 17 : 24,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
        ],
      );
      final control = Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cream ? 40 : 22),
        child: InkWell(
          key: const ValueKey('template-date-control'),
          onTap: bookingEnabled ? onOpenCalendar : null,
          borderRadius: BorderRadius.circular(cream ? 40 : 22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.cardBorderColor,
                width: cream ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(cream ? 40 : 22),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fields = [field('入住', startDate), field('退房', endDate)];
                if (constraints.maxWidth < 240 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [fields[0], const Divider(height: 22), fields[1]],
                  );
                }
                return Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 26,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: fields[0]),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '～',
                        style: TextStyle(color: theme.textColor),
                      ),
                    ),
                    Expanded(child: fields[1]),
                  ],
                );
              },
            ),
          ),
        ),
      );
      return Opacity(
        opacity: bookingEnabled ? 1 : .5,
        child: Container(
          padding: EdgeInsets.all(cream ? 0 : 16),
          decoration: BoxDecoration(
            color: cream ? null : const Color(0xFFE1EFF9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!cream) ...[
                Text(
                  '住宿日期',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              control,
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  !bookingEnabled
                      ? '目前店家暫停開放預約'
                      : hasDate
                      ? '共 $nights 晚・點日期可修改'
                      : '點選日期，安排入住與退房時間',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textColor.withValues(alpha: .65),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
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
          if (style == 'warm' || style == 'original') ...[
            _dateRow('入住日', hasDate ? _formatDate(startDate!) : '尚未選擇'),
            const SizedBox(height: 8),
            _dateRow('退房日', hasDate ? _formatDate(endDate!) : '尚未選擇'),
            const SizedBox(height: 8),
            _dateRow('住宿晚數', hasDate ? '$nights 晚' : '—'),
          ] else if (style == 'compact') ...[
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  '入住  ${hasDate ? _formatDate(startDate!) : '尚未選擇'}',
                  style: TextStyle(color: theme.textColor),
                ),
                Text(
                  '退房  ${hasDate ? _formatDate(endDate!) : '尚未選擇'}',
                  style: TextStyle(color: theme.textColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hasDate ? '$nights 晚住宿' : '選擇日期後顯示晚數',
              style: TextStyle(color: theme.textColor, fontSize: 12),
            ),
          ] else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final cells = [
                  _dateTile(
                    '入住日',
                    hasDate ? _formatDate(startDate!) : '尚未選擇',
                    style,
                  ),
                  _dateTile(
                    '退房日',
                    hasDate ? _formatDate(endDate!) : '尚未選擇',
                    style,
                  ),
                ];
                if (constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [cells[0], const SizedBox(height: 10), cells[1]],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cells[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cells[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              hasDate ? '$nights 晚・期待與貓咪相見' : '選好日期，開始安排貓咪的假期',
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
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

  Widget _dateTile(String label, String value, String style) => Container(
    padding: EdgeInsets.all(style == 'minimal' ? 0 : 14),
    decoration: BoxDecoration(
      color: style == 'minimal'
          ? null
          : theme.primaryColor.withValues(alpha: style == 'soft' ? 0.09 : 0.05),
      borderRadius: BorderRadius.circular(style == 'soft' ? 20 : 4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.textColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: style == 'boutique' ? 18 : 16,
            fontWeight: FontWeight.w700,
            color: theme.textColor,
          ),
        ),
      ],
    ),
  );

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

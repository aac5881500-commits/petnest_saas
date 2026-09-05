// 檔案名稱：lib/features/shop/widgets/booking/daycare_booking_summary_card.dart
// 功能說明：安親第三步預約摘要：沿用住宿確認卡視覺，金額改由費用明細顯示

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';

class DaycareBookingSummaryCard extends StatelessWidget {
  const DaycareBookingSummaryCard({
    super.key,
    required this.dateText,
    required this.dropOffText,
    required this.pickUpText,
    required this.durationMinutes,
    required this.petCount,
    required this.petNames,
    required this.planName,
    required this.roomTypeName,
    this.theme = HomeThemeModel.classicDefault,
  });

  final HomeThemeModel theme;
  final String dateText;
  final String dropOffText;
  final String pickUpText;
  final int durationMinutes;
  final int petCount;
  final List<String> petNames;
  final String planName;
  final String roomTypeName;

  @override
  Widget build(BuildContext context) {
    return BookingThemedCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '預約摘要',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 12),
          _infoRow('安親日期', dateText),
          const SizedBox(height: 6),
          _infoRow('送達時間', dropOffText),
          const SizedBox(height: 6),
          _infoRow('接回時間', pickUpText),
          const SizedBox(height: 6),
          _infoRow('預計安親時數', DaycareTimeHelper.durationLabel(durationMinutes)),
          const SizedBox(height: 6),
          _infoRow(
            '寵物資料與數量',
            petNames.isEmpty
                ? '$petCount 隻'
                : '${petNames.join('、')}（$petCount 隻）',
          ),
          const SizedBox(height: 6),
          _infoRow('安親房型／方案', planName),
          const SizedBox(height: 6),
          _infoRow('房間', roomTypeName.isEmpty ? '房間將由店家安排' : roomTypeName),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: TextStyle(color: theme.textColor)),
        ),
      ],
    );
  }
}

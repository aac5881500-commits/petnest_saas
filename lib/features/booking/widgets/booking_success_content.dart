import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_arrival_layout.dart';

/// Pure completion view: callbacks retain the existing navigation and data access.
class BookingSuccessContent extends StatelessWidget {
  const BookingSuccessContent({
    super.key,
    required this.shopName,
    required this.onViewOrder,
    required this.onReturnToShop,
    this.appearance,
    this.theme,
    this.frontendTheme,
    this.message,
    this.bookingId,
    this.startDate,
    this.endDate,
    this.petCount,
    this.roomTypeName,
    this.totalPrice,
  });
  final String shopName;
  final VoidCallback onViewOrder, onReturnToShop;
  final BookingPageAppearance? appearance;
  final HomeThemeModel? theme, frontendTheme;
  final String? message, bookingId, roomTypeName;
  final DateTime? startDate, endDate;
  final int? petCount, totalPrice;
  static HomeThemeModel resolveTheme(
    BookingPageAppearance? a,
    HomeThemeModel? fallback,
    HomeThemeModel? frontend,
  ) => a == null
      ? (fallback ??
            const HomeThemeModel(
              backgroundColorValue: 0xFFF5F6FA,
              cardColorValue: 0xFFFFFFFF,
              cardBorderColorValue: 0xFFE0E5EF,
              primaryColorValue: 0xFF4F6099,
              textColorValue: 0xFF253247,
            ))
      : BookingArrivalLayout.themeFor(
          a.style,
          appearance: a,
          originalTheme: frontend ?? fallback,
        );
  static String font(BookingPageAppearance? a) =>
      a?.look.font.isNotEmpty == true
      ? a!.look.font
      : a?.style == 'cream'
      ? 'jfOpenHuninn'
      : a?.style == 'editorial'
      ? 'NotoSerifTC'
      : 'NotoSansTC';
  @override
  Widget build(BuildContext context) {
    final a = appearance,
        t = resolveTheme(a, theme, frontendTheme),
        cream = a?.style == 'cream',
        editorial = a?.style == 'editorial';
    TextStyle text(double size, {bool bold = false}) => TextStyle(
      fontFamily: font(a),
      fontSize: size,
      height: 1.5,
      color: t.textColor,
      fontWeight: a?.look.fontWeight != null
          ? FontWeight.values[a!.look.fontWeight! ~/ 100 - 1]
          : bold
          ? FontWeight.w800
          : FontWeight.w500,
    );
    Widget info(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 15,
        runSpacing: 4,
        children: [
          Text(
            label,
            style: text(13).copyWith(color: t.textColor.withValues(alpha: .72)),
          ),
          Text(value, style: text(15, bold: true)),
        ],
      ),
    );
    String date(DateTime d) =>
        '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    final receipt = <Widget>[
      if (startDate != null && endDate != null)
        info('住宿日期', '${date(startDate!)} — ${date(endDate!)}'),
      if (startDate != null && endDate != null && endDate!.isAfter(startDate!))
        info('住宿晚數', '${endDate!.difference(startDate!).inDays} 晚'),
      if (roomTypeName?.trim().isNotEmpty == true) info('入住房型', roomTypeName!),
      if ((petCount ?? 0) > 0) info('入住貓咪', '$petCount 隻'),
      if (totalPrice != null) info('訂單金額', ShopReportFormat.money(totalPrice!)),
    ];
    final icon = cream
        ? SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              children: [
                Container(
                  width: 102,
                  height: 102,
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF5D6),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/booking_demo_ginger_chibi_v1.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: t.cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: t.primaryColor,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          )
        : Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: editorial
                  ? Colors.transparent
                  : t.primaryColor.withValues(alpha: .09),
              shape: BoxShape.circle,
              border: editorial
                  ? Border.all(color: t.primaryColor, width: 1.4)
                  : null,
            ),
            child: Icon(Icons.check_rounded, color: t.primaryColor, size: 52),
          );
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        key: const ValueKey('booking-success-scroll'),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              minHeight: math.max(0, c.maxHeight - 48),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: ValueKey('booking-success-${a?.style ?? 'default'}'),
                  padding: EdgeInsets.all(editorial ? 4 : 24),
                  decoration: BoxDecoration(
                    color: editorial ? Colors.transparent : t.cardColor,
                    borderRadius: editorial
                        ? null
                        : BorderRadius.circular(cream ? 30 : 24),
                    border: editorial
                        ? Border(
                            top: BorderSide(color: t.cardBorderColor),
                            bottom: BorderSide(color: t.cardBorderColor),
                          )
                        : Border.all(color: t.cardBorderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: editorial
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 14),
                      icon,
                      const SizedBox(height: 18),
                      Semantics(
                        liveRegion: true,
                        child: Text('預約已送出', style: text(30, bold: true)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '已送出至 $shopName',
                        textAlign: editorial
                            ? TextAlign.left
                            : TextAlign.center,
                        style: text(16, bold: true),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message ?? '你的預約資料已成功送出。',
                        textAlign: editorial
                            ? TextAlign.left
                            : TextAlign.center,
                        style: text(14),
                      ),
                      if (receipt.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cream
                                ? Color.alphaBlend(
                                    t.primaryColor.withValues(alpha: .055),
                                    t.cardColor,
                                  )
                                : t.backgroundColor,
                            borderRadius: BorderRadius.circular(cream ? 20 : 8),
                            border: Border.all(color: t.cardBorderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: receipt,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            color: t.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('查看訂單，可追蹤店家確認與付款進度。', style: text(13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  key: const ValueKey('success-view-order'),
                  onPressed: onViewOrder,
                  icon: const Icon(Icons.receipt_long_outlined, size: 20),
                  label: Text(
                    bookingId?.trim().isNotEmpty == true ? '查看此訂單' : '查看訂單',
                    style: text(17, bold: true).copyWith(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: t.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        cream
                            ? 28
                            : editorial
                            ? 8
                            : 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('success-return-shop'),
                  onPressed: onReturnToShop,
                  icon: Icon(
                    Icons.storefront_outlined,
                    color: t.primaryColor,
                    size: 20,
                  ),
                  label: Text('回到店家', style: text(16, bold: true)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 16,
                    ),
                    side: BorderSide(
                      color: t.primaryColor.withValues(alpha: .55),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        cream
                            ? 28
                            : editorial
                            ? 8
                            : 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

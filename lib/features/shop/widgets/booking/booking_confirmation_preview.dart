import 'booking_cream_header.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'booking_appearance_scope.dart';
import 'booking_arrival_layout.dart';
import 'booking_editorial_design.dart';
import 'booking_summary_helper.dart';
import 'booking_step_widgets.dart';

class BookingConfirmationPreview extends StatelessWidget {
  const BookingConfirmationPreview({
    super.key,
    required this.appearance,
    this.shopName = '貓咪旅館',
    this.frontendTheme,
  });
  final BookingPageAppearance appearance;
  final String shopName;
  final HomeThemeModel? frontendTheme;
  @override
  Widget build(BuildContext context) {
    final t = BookingArrivalLayout.themeFor(
      appearance.style,
      appearance: appearance,
      originalTheme: frontendTheme,
    );
    return BookingAppearanceScope(
      appearance: appearance,
      frontendTheme: frontendTheme,
      child: Builder(
        builder: (context) => Container(
          color: t.backgroundColor,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '即時預覽・費用確認（示範資料）',
                style: TextStyle(
                  color: t.textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              if (appearance.style == 'cream')
                BookingCreamHeader(
                  shopName: shopName,
                  step: 3,
                  title: '確認貓咪的小旅行',
                  subtitle: '最後核對住宿安排與本次費用。',
                )
              else
                BookingEditorial.brand(shopName: shopName),
              BookingStepIndicator(currentStep: 3, theme: t),
              BookingSummaryHelper.buildSummary(
                theme: t,
                startDateText: '2026/11/05',
                endDateText: '2026/11/07',
                nights: 2,
                selectedPetIds: const ['tea', 'sesame'],
                pets: const [
                  {'petId': 'tea', 'name': '奶茶'},
                  {'petId': 'sesame', 'name': '芝麻'},
                ],
                selectedRoomType: const {
                  'name': '標準雙貓房',
                  'price': 500,
                  'extraPrice': 100,
                },
                totalPrice: 1300,
                originalTotal: 1300,
                selectedTimeAddon: const {'label': '正常入住', 'price': 0},
                selectedValueServices: const [
                  {'name': '迎賓點心組', 'price': 100},
                ],
                selectedCustomServices: const {},
                selectedDailyTimedServices: const {},
                addonData: const {},
                couponSection: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.primaryColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 5,
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        color: t.primaryColor,
                      ),
                      Text('使用優惠券', style: BookingEditorial.title(17, context)),
                      Text(
                        '目前沒有可使用的優惠券',
                        style: BookingEditorial.body(13, context),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              BookingEditorialFooter(
                left: '應付金額',
                step: 3,
                right: 'NT\$ 1,300',
                label: '下一步・填寫資料',
                hint: '示範操作，不會建立預約。',
                onNext: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

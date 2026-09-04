// lib/features/booking/pages/booking_pet_care_info_page.dart
// 查看訂單寵物快照中的餵食／用藥／健康資料（不含店家內部備註）。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

class BookingPetCareInfoPage extends StatelessWidget {
  const BookingPetCareInfoPage({super.key, required this.view});

  final BookingDetailViewData view;

  @override
  Widget build(BuildContext context) {
    return ShopFrontendThemeScope(
      shopId: view.shopId,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: BookingDetailUi.of(context).background,
          appBar: AppBar(
            title: const Text('餵食與用藥安排'),
            backgroundColor: BookingDetailUi.of(context).background,
          ),
          body: BookingDetailUi.constrain(
            ListView(
              padding: const EdgeInsets.all(BookingDetailUi.pagePadding),
              children: <Widget>[
                if (view.petInfos.isEmpty)
                  BookingDetailCard(
                    child: Text(
                      '此訂單沒有可顯示的寵物照護資料。',
                      style: TextStyle(
                        color: BookingDetailUi.of(context).muted,
                      ),
                    ),
                  )
                else
                  for (final BookingDetailPetInfo pet in view.petInfos)
                    BookingDetailCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          BookingDetailSoftNetworkImage(
                            url: pet.photoUrl,
                            width: 56,
                            height: 56,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  pet.name,
                                  style: TextStyle(
                                    fontSize: BookingDetailUi.sectionTitleSize,
                                    fontWeight: FontWeight.w700,
                                    color: BookingDetailUi.of(context).text,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  pet.careSummary.isEmpty
                                      ? '尚未填寫餵食或用藥資料'
                                      : pet.careSummary,
                                  style: TextStyle(
                                    fontSize: BookingDetailUi.bodySize,
                                    color: BookingDetailUi.of(context).muted,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

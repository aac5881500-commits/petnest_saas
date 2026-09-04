// lib/features/shop/widgets/store/store_admin_summary_bar.dart
// 🛒 賣場後台 compact 概況

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/store_order_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/store_order_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_promotion_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';

class StoreAdminSummaryBar extends StatelessWidget {
  const StoreAdminSummaryBar({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StoreOrderModel>>(
      stream: StoreOrderService.instance.streamShopOrders(shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<StoreOrderModel>> orderSnap,
          ) {
            return StreamBuilder<List<StoreProductModel>>(
              stream: StoreProductService.instance.streamProducts(shopId),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<StoreProductModel>> productSnap,
                  ) {
                    return StreamBuilder<List<StorePromotionModel>>(
                      stream: StorePromotionService.instance.streamPromotions(
                        shopId,
                      ),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<List<StorePromotionModel>> promoSnap,
                          ) {
                            final DateTime now = DateTime.now();
                            final DateTime start = DateTime(
                              now.year,
                              now.month,
                              now.day,
                            );
                            final List<StoreOrderModel> orders =
                                orderSnap.data ?? const <StoreOrderModel>[];
                            final List<StoreOrderModel> today = orders
                                .where(
                                  (StoreOrderModel order) =>
                                      !order.createdAt.isBefore(start),
                                )
                                .toList();
                            final int pending = orders
                                .where(
                                  (StoreOrderModel order) =>
                                      order.status ==
                                          StoreConstants.statusPaid ||
                                      order.status ==
                                          StoreConstants.statusPreparing,
                                )
                                .length;
                            final int revenue = today
                                .where(
                                  (StoreOrderModel order) =>
                                      order.paymentStatus ==
                                      StoreConstants.paymentPaid,
                                )
                                .fold<int>(
                                  0,
                                  (int sum, StoreOrderModel order) =>
                                      sum + order.totalAmount,
                                );
                            final int activePromos =
                                (promoSnap.data ??
                                        const <StorePromotionModel>[])
                                    .where(
                                      (StorePromotionModel item) =>
                                          item.statusKey == 'active',
                                    )
                                    .length;
                            final int lowStock =
                                (productSnap.data ??
                                        const <StoreProductModel>[])
                                    .where((StoreProductModel product) {
                                      final String label =
                                          StoreStockHelper.adminStatusLabel(
                                            product,
                                          );
                                      return label == '低庫存' || label == '售罄';
                                    })
                                    .length;

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                              child: Row(
                                children: <Widget>[
                                  _cell('今日訂單', '${today.length}'),
                                  _cell('待處理', '$pending'),
                                  _cell('今日營業額', 'NT\$$revenue'),
                                  _cell('活動中', '$activePromos'),
                                  _cell('低庫存', '$lowStock'),
                                ],
                              ),
                            );
                          },
                    );
                  },
            );
          },
    );
  }

  Widget _cell(String label, String value) {
    return Container(
      width: 88,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

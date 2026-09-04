// lib/features/shop/pages/store/shop_store_order_list_page.dart
// 🛒 後台商城訂單

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/store_order_model.dart';
import 'package:petnest_saas/core/services/store_order_service.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_order_detail_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_empty_state.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_order_card.dart';

class ShopStoreOrderListPage extends StatefulWidget {
  const ShopStoreOrderListPage({
    super.key,
    required this.shopId,
    required this.canManage,
    required this.canView,
  });

  final String shopId;
  final bool canManage;
  final bool canView;

  @override
  State<ShopStoreOrderListPage> createState() => _ShopStoreOrderListPageState();
}

class _ShopStoreOrderListPageState extends State<ShopStoreOrderListPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    if (!widget.canView) {
      return const StoreEmptyState(
        title: '沒有權限查看商城訂單',
        subtitle: '請向店主申請查看或管理商城訂單權限。',
        icon: Icons.lock_outline,
      );
    }

    return Column(
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: <Widget>[
              _chip('全部', 'all'),
              _chip('待付款', StoreConstants.statusPendingPayment),
              _chip('待處理', StoreConstants.statusPaid),
              _chip('待備貨', StoreConstants.statusPreparing),
              _chip('可取貨', StoreConstants.statusReadyForPickup),
              _chip('已完成', StoreConstants.statusCompleted),
              _chip('已取消', StoreConstants.statusCancelled),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<StoreOrderModel>>(
            stream: StoreOrderService.instance.streamShopOrders(widget.shopId),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<StoreOrderModel>> snapshot,
                ) {
                  final List<StoreOrderModel> all =
                      snapshot.data ?? const <StoreOrderModel>[];
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      all.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (all.isEmpty) {
                    return const StoreEmptyState(
                      title: '目前沒有商城訂單',
                      subtitle: '客人下單後，會顯示訂單編號、付款與取貨狀態。',
                      icon: Icons.receipt_long_outlined,
                    );
                  }
                  final List<StoreOrderModel> orders = all.where((
                    StoreOrderModel order,
                  ) {
                    return _filter == 'all' || order.status == _filter;
                  }).toList();
                  if (orders.isEmpty) {
                    return const StoreEmptyState(
                      title: '這個狀態沒有訂單',
                      subtitle: '試試其他篩選。',
                      icon: Icons.filter_alt_outlined,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final StoreOrderModel order = orders[index];
                      return StoreOrderCard(
                        order: order,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ShopStoreOrderDetailPage(
                                shopId: widget.shopId,
                                orderId: order.id,
                                canManage: widget.canManage,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}

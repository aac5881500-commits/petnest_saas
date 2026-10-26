// 檔案名稱：lib/features/shop/pages/store/shop_store_order_list_page.dart
// 功能說明：後台商城訂單

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
  String _keyword = '';
  int _days = 0;

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            onChanged: (value) => setState(() => _keyword = value),
            decoration: const InputDecoration(
              hintText: '搜尋訂單編號、客人、電話或商品',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              for (final days in [0, 1, 7, 30])
                ChoiceChip(
                  label: Text(
                    days == 0
                        ? '全部日期'
                        : days == 1
                        ? '今天'
                        : '近 $days 天',
                  ),
                  selected: _days == days,
                  onSelected: (_) => setState(() => _days = days),
                ),
            ],
          ),
        ),
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
                  if (snapshot.hasError) {
                    return const StoreEmptyState(
                      title: '訂單讀取失敗',
                      subtitle: '請確認網路與訂單查看權限，再重新進入賣場。',
                      icon: Icons.cloud_off_outlined,
                    );
                  }
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
                    final key = _keyword.trim().toLowerCase();
                    final now = DateTime.now();
                    final start = DateTime(
                      now.year,
                      now.month,
                      now.day,
                    ).subtract(Duration(days: _days > 0 ? _days - 1 : 0));
                    return (_filter == 'all' || order.status == _filter) &&
                        (_days == 0 || !order.createdAt.isBefore(start)) &&
                        (key.isEmpty ||
                            [
                              order.orderCode,
                              order.customerName,
                              order.customerPhone,
                              ...order.items.map((item) => item.productName),
                            ].any(
                              (value) => value.toLowerCase().contains(key),
                            ));
                  }).toList();
                  if (orders.isEmpty) {
                    return const StoreEmptyState(
                      title: '沒有符合條件的訂單',
                      subtitle: '請調整搜尋文字、日期或訂單狀態。',
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

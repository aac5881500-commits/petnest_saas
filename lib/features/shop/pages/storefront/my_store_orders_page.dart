// lib/features/shop/pages/storefront/my_store_orders_page.dart
// 🛒 會員商城訂單（與住宿訂單分開）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_order_model.dart';
import 'package:petnest_saas/core/services/store_order_service.dart';
import 'package:petnest_saas/features/shop/pages/storefront/my_store_order_detail_page.dart';

class MyStoreOrdersPage extends StatefulWidget {
  const MyStoreOrdersPage({
    super.key,
    required this.shopId,
    this.theme = HomeThemeModel.modernDefault,
  });

  final String shopId;
  final HomeThemeModel theme;

  @override
  State<MyStoreOrdersPage> createState() => _MyStoreOrdersPageState();
}

class _MyStoreOrdersPageState extends State<MyStoreOrdersPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final HomeThemeModel theme = widget.theme;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        foregroundColor: theme.textColor,
        title: const Text('我的商城訂單'),
      ),
      body: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: <Widget>[
                _chip('全部', 'all'),
                _chip('待付款', StoreConstants.statusPendingPayment),
                _chip('備貨中', StoreConstants.statusPreparing),
                _chip('可取貨', StoreConstants.statusReadyForPickup),
                _chip('完成', StoreConstants.statusCompleted),
                _chip('取消', StoreConstants.statusCancelled),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<StoreOrderModel>>(
              stream: StoreOrderService.instance.streamMemberOrders(
                shopId: widget.shopId,
              ),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<StoreOrderModel>> snapshot,
              ) {
                if (snapshot.hasError) {
                  return Center(child: Text('讀取失敗：${snapshot.error}'));
                }
                final List<StoreOrderModel> orders =
                    (snapshot.data ?? const <StoreOrderModel>[])
                        .where((StoreOrderModel order) {
                          if (_filter == 'all') {
                            return true;
                          }
                          if (_filter == StoreConstants.statusPreparing) {
                            return order.status ==
                                    StoreConstants.statusPreparing ||
                                order.status == StoreConstants.statusPaid;
                          }
                          return order.status == _filter;
                        })
                        .toList();
                if (orders.isEmpty) {
                  return const Center(child: Text('目前沒有商城訂單'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final StoreOrderModel order = orders[index];
                    return Card(
                      child: ListTile(
                        title: Text(order.orderCode),
                        subtitle: Text(
                          '${StoreConstants.statusLabel(order.status)} · '
                          'NT\$ ${order.totalAmount} · ${order.itemCount} 件',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => MyStoreOrderDetailPage(
                                shopId: order.shopId,
                                orderId: order.id,
                                theme: theme,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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

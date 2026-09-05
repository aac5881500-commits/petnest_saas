// 檔案名稱：lib/features/shop/widgets/store/store_order_card.dart
// 功能說明：後台商城訂單卡

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/store_order_model.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_status_chip.dart';

class StoreOrderCard extends StatelessWidget {
  const StoreOrderCard({super.key, required this.order, required this.onTap});

  final StoreOrderModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final StoreStatusTone statusTone = switch (order.status) {
      StoreConstants.statusCancelled => StoreStatusTone.danger,
      StoreConstants.statusCompleted => StoreStatusTone.success,
      StoreConstants.statusPendingPayment => StoreStatusTone.warning,
      _ => StoreStatusTone.info,
    };

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      order.orderCode,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  StoreStatusChip(
                    label: StoreConstants.statusLabel(order.status),
                    tone: statusTone,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(order.customerName.isEmpty ? '會員' : order.customerName),
              Text(
                '${order.itemCount} 件　應付 NT\$ ${order.totalAmount}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              Text(
                '${StoreConstants.paymentStatusLabel(order.paymentStatus)}　'
                '${_time(order.createdAt)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _time(DateTime value) {
    return '${value.month}/${value.day} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

// lib/core/models/store_order_model.dart
// 🛒 商城訂單 Model
// 功能：與住宿 bookings 完全分開。商品明細使用購買當下 snapshot。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';

class StoreOrderItemModel {
  const StoreOrderItemModel({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.imageUrl = '',
    this.useInventory = false,
    this.inventoryItemId = '',
    this.inventoryItemName = '',
    this.inventoryUnit = '',
    this.inventoryQuantityPerSale = 1,
  });

  final String productId;
  final String productName;
  final String imageUrl;
  final int unitPrice;
  final int quantity;
  final int subtotal;
  final bool useInventory;
  final String inventoryItemId;
  final String inventoryItemName;
  final String inventoryUnit;
  final num inventoryQuantityPerSale;

  factory StoreOrderItemModel.fromMap(Map<String, dynamic> data) {
    return StoreOrderItemModel(
      productId: (data['productId'] ?? '').toString(),
      productName: (data['productName'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      unitPrice: _intFromValue(data['unitPrice']),
      quantity: _intFromValue(data['quantity']),
      subtotal: _intFromValue(data['subtotal']),
      useInventory: data['useInventory'] == true,
      inventoryItemId: (data['inventoryItemId'] ?? '').toString(),
      inventoryItemName: (data['inventoryItemName'] ?? '').toString(),
      inventoryUnit: (data['inventoryUnit'] ?? '').toString(),
      inventoryQuantityPerSale: data['inventoryQuantityPerSale'] is num
          ? data['inventoryQuantityPerSale'] as num
          : num.tryParse(data['inventoryQuantityPerSale']?.toString() ?? '') ??
                1,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'productId': productId,
      'productName': productName,
      'imageUrl': imageUrl,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'subtotal': subtotal,
      'useInventory': useInventory,
      'inventoryItemId': inventoryItemId,
      'inventoryItemName': inventoryItemName,
      'inventoryUnit': inventoryUnit,
      'inventoryQuantityPerSale': inventoryQuantityPerSale,
    };
  }

  static int _intFromValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class StoreOrderModel {
  const StoreOrderModel({
    required this.id,
    required this.orderCode,
    required this.shopId,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.shippingFee,
    required this.totalAmount,
    required this.fulfillmentType,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.shopNameSnapshot = '',
    this.customerName = '',
    this.customerPhone = '',
    this.pickupNote = '',
    this.shopAddressSnapshot = '',
    this.reservationExpireAt,
    this.paidAt,
    this.preparingAt,
    this.readyForPickupAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason = '',
    this.lastPaymentId = '',
    this.inventoryReturned = false,
  });

  final String id;
  final String orderCode;
  final String shopId;
  final String shopNameSnapshot;
  final String userId;
  final List<StoreOrderItemModel> items;
  final int subtotal;
  final int shippingFee;
  final int totalAmount;
  final String fulfillmentType;
  final String status;
  final String paymentStatus;
  final String customerName;
  final String customerPhone;
  final String pickupNote;
  final String shopAddressSnapshot;
  final DateTime createdAt;
  final DateTime? reservationExpireAt;
  final DateTime? paidAt;
  final DateTime? preparingAt;
  final DateTime? readyForPickupAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String cancelReason;
  final String lastPaymentId;
  final bool inventoryReturned;

  int get itemCount {
    return items.fold<int>(0, (int sum, StoreOrderItemModel item) {
      return sum + item.quantity;
    });
  }

  bool get isPendingPayment => status == StoreConstants.statusPendingPayment;
  bool get isPaid => paymentStatus == StoreConstants.paymentPaid;
  bool get isCancelled => status == StoreConstants.statusCancelled;

  factory StoreOrderModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final List<StoreOrderItemModel> items = <StoreOrderItemModel>[];
    final Object? rawItems = data['items'];
    if (rawItems is List) {
      for (final Object? raw in rawItems) {
        if (raw is Map) {
          items.add(
            StoreOrderItemModel.fromMap(Map<String, dynamic>.from(raw)),
          );
        }
      }
    }

    return StoreOrderModel(
      id: id,
      orderCode: (data['orderCode'] ?? '').toString(),
      shopId: (data['shopId'] ?? '').toString(),
      shopNameSnapshot: (data['shopNameSnapshot'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      items: items,
      subtotal: StoreOrderItemModel._intFromValue(data['subtotal']),
      shippingFee: StoreOrderItemModel._intFromValue(data['shippingFee']),
      totalAmount: StoreOrderItemModel._intFromValue(data['totalAmount']),
      fulfillmentType: (data['fulfillmentType'] ?? StoreConstants.fulfillmentPickup)
          .toString(),
      status: (data['status'] ?? StoreConstants.statusPendingPayment).toString(),
      paymentStatus:
          (data['paymentStatus'] ?? StoreConstants.paymentUnpaid).toString(),
      customerName: (data['customerName'] ?? '').toString(),
      customerPhone: (data['customerPhone'] ?? '').toString(),
      pickupNote: (data['pickupNote'] ?? '').toString(),
      shopAddressSnapshot: (data['shopAddressSnapshot'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      reservationExpireAt: _dateTimeFromValue(data['reservationExpireAt']),
      paidAt: _dateTimeFromValue(data['paidAt']),
      preparingAt: _dateTimeFromValue(data['preparingAt']),
      readyForPickupAt: _dateTimeFromValue(data['readyForPickupAt']),
      completedAt: _dateTimeFromValue(data['completedAt']),
      cancelledAt: _dateTimeFromValue(data['cancelledAt']),
      cancelReason: (data['cancelReason'] ?? '').toString(),
      lastPaymentId: (data['lastPaymentId'] ?? '').toString(),
      inventoryReturned: data['inventoryReturned'] == true,
    );
  }

  static DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value?.toString() ?? '');
  }
}

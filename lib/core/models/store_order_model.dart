// 檔案名稱：lib/core/models/store_order_model.dart
// 功能說明：與住宿 bookings 完全分開。商品明細使用購買當下 snapshot。
// 🛒 商城訂單 Model

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
    this.originalUnitPrice,
    this.discountUnitAmount = 0,
    this.finalUnitPrice,
    this.originalSubtotal,
    this.discountAmount = 0,
    this.finalSubtotal,
    this.promotionId = '',
    this.promotionName = '',
    this.promotionType = '',
    this.purchaseQuantity,
    this.freeQuantity = 0,
    this.fulfillmentQuantity,
    this.itemPromotionType = '',
    this.itemPromotionName = '',
    this.itemPromotionDiscount = 0,
    this.buyQuantity,
    this.freeQuantityPerGroup,
    this.inventoryDeductedQuantity,
    this.bundlePromotionId = '',
    this.bundlePromotionName = '',
    this.bundleQuantity,
    this.bundleOriginalPrice,
    this.bundleFinalPrice,
  });

  final String productId;
  final String productName;
  final String imageUrl;
  final int unitPrice;
  final int quantity;
  final int subtotal;
  final int? originalUnitPrice;
  final int discountUnitAmount;
  final int? finalUnitPrice;
  final int? originalSubtotal;
  final int discountAmount;
  final int? finalSubtotal;
  final String promotionId;
  final String promotionName;
  final String promotionType;
  final int? purchaseQuantity;
  final int freeQuantity;
  final int? fulfillmentQuantity;
  final String itemPromotionType;
  final String itemPromotionName;
  final int itemPromotionDiscount;
  final int? buyQuantity;
  final int? freeQuantityPerGroup;
  final num? inventoryDeductedQuantity;
  final bool useInventory;
  final String bundlePromotionId;
  final String bundlePromotionName;
  final int? bundleQuantity;
  final int? bundleOriginalPrice;
  final int? bundleFinalPrice;

  int get snapshotPurchaseQuantity => purchaseQuantity ?? quantity;
  int get snapshotFreeQuantity => freeQuantity < 0 ? 0 : freeQuantity;
  int get snapshotFulfillmentQuantity =>
      fulfillmentQuantity ?? (snapshotPurchaseQuantity + snapshotFreeQuantity);

  num get snapshotInventoryDeducted {
    if (inventoryDeductedQuantity != null) {
      return inventoryDeductedQuantity!;
    }
    if (!useInventory) {
      return 0;
    }
    return snapshotFulfillmentQuantity * inventoryQuantityPerSale;
  }

  int get snapshotOriginalUnitPrice => originalUnitPrice ?? unitPrice;
  int get snapshotFinalUnitPrice => finalUnitPrice ?? unitPrice;
  bool get hasPromotionSnapshot =>
      promotionName.trim().isNotEmpty ||
      itemPromotionName.trim().isNotEmpty ||
      snapshotFreeQuantity > 0 ||
      snapshotOriginalUnitPrice > snapshotFinalUnitPrice;
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
      originalUnitPrice: data['originalUnitPrice'] == null
          ? null
          : _intFromValue(data['originalUnitPrice']),
      discountUnitAmount: _intFromValue(data['discountUnitAmount']),
      finalUnitPrice: data['finalUnitPrice'] == null
          ? null
          : _intFromValue(data['finalUnitPrice']),
      originalSubtotal: data['originalSubtotal'] == null
          ? null
          : _intFromValue(data['originalSubtotal']),
      discountAmount: _intFromValue(data['discountAmount']),
      finalSubtotal: data['finalSubtotal'] == null
          ? null
          : _intFromValue(data['finalSubtotal']),
      promotionId: (data['promotionId'] ?? '').toString(),
      promotionName: (data['promotionName'] ?? '').toString(),
      promotionType: (data['promotionType'] ?? '').toString(),
      purchaseQuantity: data['purchaseQuantity'] == null
          ? null
          : _intFromValue(data['purchaseQuantity']),
      freeQuantity: _intFromValue(data['freeQuantity']),
      fulfillmentQuantity: data['fulfillmentQuantity'] == null
          ? (data['totalFulfillmentQuantity'] == null
                ? null
                : _intFromValue(data['totalFulfillmentQuantity']))
          : _intFromValue(data['fulfillmentQuantity']),
      itemPromotionType: (data['itemPromotionType'] ?? '').toString(),
      itemPromotionName: (data['itemPromotionName'] ?? '').toString(),
      itemPromotionDiscount: _intFromValue(data['itemPromotionDiscount']),
      buyQuantity: data['buyQuantity'] == null
          ? null
          : _intFromValue(data['buyQuantity']),
      freeQuantityPerGroup: data['freeQuantityPerGroup'] == null
          ? null
          : _intFromValue(data['freeQuantityPerGroup']),
      inventoryDeductedQuantity: data['inventoryDeductedQuantity'] == null
          ? null
          : (data['inventoryDeductedQuantity'] is num
                ? data['inventoryDeductedQuantity'] as num
                : num.tryParse(
                    data['inventoryDeductedQuantity']?.toString() ?? '',
                  )),
      useInventory: data['useInventory'] == true,
      inventoryItemId: (data['inventoryItemId'] ?? '').toString(),
      inventoryItemName: (data['inventoryItemName'] ?? '').toString(),
      inventoryUnit: (data['inventoryUnit'] ?? '').toString(),
      inventoryQuantityPerSale: data['inventoryQuantityPerSale'] is num
          ? data['inventoryQuantityPerSale'] as num
          : num.tryParse(data['inventoryQuantityPerSale']?.toString() ?? '') ??
                1,
      bundlePromotionId: (data['bundlePromotionId'] ?? '').toString(),
      bundlePromotionName: (data['bundlePromotionName'] ?? '').toString(),
      bundleQuantity: data['bundleQuantity'] == null
          ? null
          : _intFromValue(data['bundleQuantity']),
      bundleOriginalPrice: data['bundleOriginalPrice'] == null
          ? null
          : _intFromValue(data['bundleOriginalPrice']),
      bundleFinalPrice: data['bundleFinalPrice'] == null
          ? null
          : _intFromValue(data['bundleFinalPrice']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'productId': productId,
      'productName': productName,
      'imageUrl': imageUrl,
      'unitPrice': unitPrice,
      'originalUnitPrice': originalUnitPrice ?? unitPrice,
      'discountUnitAmount': discountUnitAmount,
      'finalUnitPrice': finalUnitPrice ?? unitPrice,
      'quantity': quantity,
      'purchaseQuantity': purchaseQuantity ?? quantity,
      'freeQuantity': freeQuantity,
      'fulfillmentQuantity':
          fulfillmentQuantity ??
          ((purchaseQuantity ?? quantity) + freeQuantity),
      'originalSubtotal': originalSubtotal ?? (unitPrice * quantity),
      'discountAmount': discountAmount,
      'finalSubtotal': finalSubtotal ?? subtotal,
      'subtotal': subtotal,
      'promotionId': promotionId,
      'promotionName': promotionName,
      'promotionType': promotionType,
      'itemPromotionType': itemPromotionType,
      'itemPromotionName': itemPromotionName,
      'itemPromotionDiscount': itemPromotionDiscount,
      'buyQuantity': buyQuantity,
      'freeQuantityPerGroup': freeQuantityPerGroup,
      'inventoryDeductedQuantity':
          inventoryDeductedQuantity ?? snapshotInventoryDeducted,
      'useInventory': useInventory,
      'inventoryItemId': inventoryItemId,
      'inventoryItemName': inventoryItemName,
      'inventoryUnit': inventoryUnit,
      'inventoryQuantityPerSale': inventoryQuantityPerSale,
      'bundlePromotionId': bundlePromotionId,
      'bundlePromotionName': bundlePromotionName,
      'bundleQuantity': bundleQuantity,
      'bundleOriginalPrice': bundleOriginalPrice,
      'bundleFinalPrice': bundleFinalPrice,
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

class StoreOrderBundleModel {
  const StoreOrderBundleModel({
    required this.bundlePromotionId,
    required this.bundlePromotionName,
    required this.bundleQuantity,
    required this.bundleOriginalPrice,
    required this.bundleFinalPrice,
  });

  final String bundlePromotionId;
  final String bundlePromotionName;
  final int bundleQuantity;
  final int bundleOriginalPrice;
  final int bundleFinalPrice;

  factory StoreOrderBundleModel.fromMap(Map<String, dynamic> data) {
    return StoreOrderBundleModel(
      bundlePromotionId: (data['bundlePromotionId'] ?? '').toString(),
      bundlePromotionName: (data['bundlePromotionName'] ?? '').toString(),
      bundleQuantity: StoreOrderItemModel._intFromValue(data['bundleQuantity']),
      bundleOriginalPrice: StoreOrderItemModel._intFromValue(
        data['bundleOriginalPrice'],
      ),
      bundleFinalPrice: StoreOrderItemModel._intFromValue(
        data['bundleFinalPrice'],
      ),
    );
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
    this.originalSubtotal,
    this.promotionDiscount = 0,
    this.finalSubtotal,
    this.itemPromotionDiscount = 0,
    this.campaignDiscount = 0,
    this.quantityDiscount = 0,
    this.amountDiscount = 0,
    this.bundleDiscount = 0,
    this.bundles = const <StoreOrderBundleModel>[],
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
  final int? originalSubtotal;
  final int promotionDiscount;
  final int? finalSubtotal;
  final int itemPromotionDiscount;
  final int campaignDiscount;
  final int quantityDiscount;
  final int amountDiscount;
  final int bundleDiscount;
  final List<StoreOrderBundleModel> bundles;

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
      fulfillmentType:
          (data['fulfillmentType'] ?? StoreConstants.fulfillmentPickup)
              .toString(),
      status: (data['status'] ?? StoreConstants.statusPendingPayment)
          .toString(),
      paymentStatus: (data['paymentStatus'] ?? StoreConstants.paymentUnpaid)
          .toString(),
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
      originalSubtotal: data['originalSubtotal'] == null
          ? null
          : StoreOrderItemModel._intFromValue(data['originalSubtotal']),
      promotionDiscount: StoreOrderItemModel._intFromValue(
        data['promotionDiscount'],
      ),
      finalSubtotal: data['finalSubtotal'] == null
          ? null
          : StoreOrderItemModel._intFromValue(data['finalSubtotal']),
      itemPromotionDiscount: StoreOrderItemModel._intFromValue(
        data['itemPromotionDiscount'],
      ),
      campaignDiscount: StoreOrderItemModel._intFromValue(
        data['campaignDiscount'],
      ),
      quantityDiscount: StoreOrderItemModel._intFromValue(
        data['quantityDiscount'],
      ),
      amountDiscount: StoreOrderItemModel._intFromValue(data['amountDiscount']),
      bundleDiscount: StoreOrderItemModel._intFromValue(data['bundleDiscount']),
      bundles: _bundlesFromValue(data['bundles']),
    );
  }

  static List<StoreOrderBundleModel> _bundlesFromValue(Object? raw) {
    if (raw is! List) {
      return const <StoreOrderBundleModel>[];
    }
    return raw
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> item) =>
              StoreOrderBundleModel.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
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

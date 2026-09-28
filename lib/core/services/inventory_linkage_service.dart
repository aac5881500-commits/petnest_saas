// 檔案名稱：lib/core/services/inventory_linkage_service.dart
// 功能說明：唯讀反查庫存品項被哪些加購、點數商品、商城與住宿耗材使用。
// 📦 不寫入、不改扣庫存

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/booking_supply_setting_model.dart';
import 'package:petnest_saas/core/models/inventory_binding_model.dart';
import 'package:petnest_saas/core/models/point_reward_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/booking_supply_setting_service.dart';
import 'package:petnest_saas/core/services/point_reward_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';

enum InventoryLinkageKind {
  addonTime,
  addonValue,
  addonCustom,
  addonDaily,
  pointReward,
  storeProduct,
  bookingSupply,
  daycareSupply,
}

enum InventoryLinkageGroup { addon, pointReward, storeProduct, bookingSupply }

class InventoryLinkage {
  const InventoryLinkage({
    required this.kind,
    required this.typeLabel,
    required this.sourceId,
    required this.title,
    required this.quantity,
    required this.unit,
    required this.extra,
    required this.isEnabled,
    required this.statusLabel,
    this.canNavigate = false,
  });

  final InventoryLinkageKind kind;
  final String typeLabel;
  final String sourceId;
  final String title;
  final num quantity;
  final String unit;
  final String extra;
  final bool isEnabled;
  final String statusLabel;
  final bool canNavigate;

  InventoryLinkageGroup get group {
    switch (kind) {
      case InventoryLinkageKind.addonTime:
      case InventoryLinkageKind.addonValue:
      case InventoryLinkageKind.addonCustom:
      case InventoryLinkageKind.addonDaily:
        return InventoryLinkageGroup.addon;
      case InventoryLinkageKind.pointReward:
        return InventoryLinkageGroup.pointReward;
      case InventoryLinkageKind.storeProduct:
        return InventoryLinkageGroup.storeProduct;
      case InventoryLinkageKind.bookingSupply:
      case InventoryLinkageKind.daycareSupply:
        return InventoryLinkageGroup.bookingSupply;
    }
  }

  String quantityPhrase(String fallbackUnit) {
    final String shownUnit = _unitOr(fallbackUnit);
    final String amount = _formatQuantity(quantity);
    switch (kind) {
      case InventoryLinkageKind.storeProduct:
        return '每售出 1 件扣除 $amount $shownUnit';
      case InventoryLinkageKind.pointReward:
        return '每次兌換扣除 $amount $shownUnit';
      case InventoryLinkageKind.bookingSupply:
      case InventoryLinkageKind.daycareSupply:
        final String mode = extra.trim();
        if (mode.isEmpty) {
          return '每次使用扣除 $amount $shownUnit';
        }
        return '$mode扣除 $amount $shownUnit';
      case InventoryLinkageKind.addonTime:
      case InventoryLinkageKind.addonValue:
      case InventoryLinkageKind.addonCustom:
      case InventoryLinkageKind.addonDaily:
        return '每次選購扣除 $amount $shownUnit';
    }
  }

  String _unitOr(String fallbackUnit) {
    final String own = unit.trim();
    if (own.isNotEmpty) {
      return own;
    }
    final String fallback = fallbackUnit.trim();
    return fallback.isEmpty ? '個' : fallback;
  }
}

class InventoryLinkageSnapshot {
  const InventoryLinkageSnapshot({
    required this.ready,
    required this.hasError,
    required this.byItemId,
  });

  const InventoryLinkageSnapshot.pending()
    : ready = false,
      hasError = false,
      byItemId = const <String, List<InventoryLinkage>>{};

  final bool ready;
  final bool hasError;
  final Map<String, List<InventoryLinkage>> byItemId;

  bool get canClassify => ready && !hasError;

  List<InventoryLinkage> of(String itemId) {
    return byItemId[itemId.trim()] ?? const <InventoryLinkage>[];
  }

  int countOf(String itemId) => of(itemId).length;

  int enabledCountOf(String itemId) {
    return of(itemId).where((InventoryLinkage link) => link.isEnabled).length;
  }
}

class InventoryLinkageService {
  InventoryLinkageService._();

  static final InventoryLinkageService instance = InventoryLinkageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<InventoryLinkageSnapshot> watchShop(String shopId) {
    final String normalizedShopId = shopId.trim();
    if (normalizedShopId.isEmpty) {
      return Stream<InventoryLinkageSnapshot>.value(
        const InventoryLinkageSnapshot(
          ready: true,
          hasError: false,
          byItemId: <String, List<InventoryLinkage>>{},
        ),
      );
    }

    return Stream<InventoryLinkageSnapshot>.multi((
      MultiStreamController<InventoryLinkageSnapshot> controller,
    ) {
      Map<String, dynamic>? addonData;
      List<PointRewardModel> rewards = const <PointRewardModel>[];
      List<StoreProductModel> products = const <StoreProductModel>[];
      List<BookingSupplySettingModel> supplies =
          const <BookingSupplySettingModel>[];
      var addonDone = false;
      var rewardDone = false;
      var productDone = false;
      var supplyDone = false;
      var hasError = false;

      void emit() {
        if (controller.isClosed) {
          return;
        }
        final bool ready = addonDone && rewardDone && productDone && supplyDone;
        controller.add(
          InventoryLinkageSnapshot(
            ready: ready,
            hasError: hasError,
            byItemId: ready
                ? _index(
                    addonData: addonData,
                    rewards: rewards,
                    products: products,
                    supplies: supplies,
                  )
                : const <String, List<InventoryLinkage>>{},
          ),
        );
      }

      void fail() {
        hasError = true;
      }

      final List<StreamSubscription<dynamic>> subscriptions =
          <StreamSubscription<dynamic>>[
            _firestore
                .collection('shops')
                .doc(normalizedShopId)
                .collection('addons')
                .doc('main')
                .snapshots()
                .listen(
                  (DocumentSnapshot<Map<String, dynamic>> snapshot) {
                    addonData = snapshot.data();
                    addonDone = true;
                    emit();
                  },
                  onError: (Object _) {
                    addonDone = true;
                    fail();
                    emit();
                  },
                ),
            PointRewardService.instance
                .streamShopRewards(normalizedShopId)
                .listen(
                  (List<PointRewardModel> value) {
                    rewards = value;
                    rewardDone = true;
                    emit();
                  },
                  onError: (Object _) {
                    rewardDone = true;
                    fail();
                    emit();
                  },
                ),
            StoreProductService.instance
                .streamProducts(normalizedShopId)
                .listen(
                  (List<StoreProductModel> value) {
                    products = value;
                    productDone = true;
                    emit();
                  },
                  onError: (Object _) {
                    productDone = true;
                    fail();
                    emit();
                  },
                ),
            BookingSupplySettingService.instance
                .streamSettings(normalizedShopId)
                .listen(
                  (List<BookingSupplySettingModel> value) {
                    supplies = value;
                    supplyDone = true;
                    emit();
                  },
                  onError: (Object _) {
                    supplyDone = true;
                    fail();
                    emit();
                  },
                ),
          ];

      controller.onCancel = () async {
        for (final StreamSubscription<dynamic> subscription in subscriptions) {
          await subscription.cancel();
        }
      };
      emit();
    });
  }

  static Map<String, List<InventoryLinkage>> _index({
    required Map<String, dynamic>? addonData,
    required List<PointRewardModel> rewards,
    required List<StoreProductModel> products,
    required List<BookingSupplySettingModel> supplies,
  }) {
    final Map<String, List<InventoryLinkage>> result =
        <String, List<InventoryLinkage>>{};

    void add(String itemId, InventoryLinkage linkage) {
      final String id = itemId.trim();
      if (id.isEmpty) {
        return;
      }
      result.putIfAbsent(id, () => <InventoryLinkage>[]).add(linkage);
    }

    final bool addonEnabled = addonData?['enabled'] == true;
    _readAddonList(
      addonData,
      'timeOptions',
      InventoryLinkageKind.addonTime,
      '時間加購',
      addonEnabled,
      add,
    );
    _readAddonList(
      addonData,
      'valueServices',
      InventoryLinkageKind.addonValue,
      '加值服務',
      addonEnabled,
      add,
    );
    _readAddonList(
      addonData,
      'customServices',
      InventoryLinkageKind.addonCustom,
      '客製服務',
      addonEnabled,
      add,
    );
    _readAddonList(
      addonData,
      'dailyTimedServices',
      InventoryLinkageKind.addonDaily,
      '每日分時段服務',
      addonEnabled,
      add,
    );

    for (final PointRewardModel reward in rewards) {
      if (!reward.isPhysicalProduct || !reward.useCentralInventory) {
        continue;
      }
      final String itemId = reward.inventoryItemId.trim();
      if (itemId.isEmpty) {
        continue;
      }
      final String name = reward.name.trim().isEmpty
          ? '未命名商品'
          : reward.name.trim();
      add(
        itemId,
        InventoryLinkage(
          kind: InventoryLinkageKind.pointReward,
          typeLabel: '點數實體商品',
          sourceId: reward.id,
          title: name,
          quantity: _positiveOrZero(reward.inventoryQuantityPerExchange),
          unit: reward.inventoryUnit,
          extra: '${reward.pointsCost} 點兌換',
          isEnabled: reward.enabled,
          statusLabel: reward.enabled ? '開放兌換' : '已停用',
        ),
      );
    }

    for (final StoreProductModel product in products) {
      if (!product.useInventory) {
        continue;
      }
      final String itemId = product.inventoryItemId.trim();
      if (itemId.isEmpty) {
        continue;
      }
      final String name = product.name.trim().isEmpty
          ? '未命名商品'
          : product.name.trim();
      add(
        itemId,
        InventoryLinkage(
          kind: InventoryLinkageKind.storeProduct,
          typeLabel: '商城商品',
          sourceId: product.id,
          title: name,
          quantity: _positiveOrZero(product.inventoryQuantityPerSale),
          unit: product.inventoryUnitSnapshot,
          extra: '售價 \$${product.price}',
          isEnabled: product.enabled,
          statusLabel: product.enabled ? '上架中' : '已下架',
        ),
      );
    }

    for (final BookingSupplySettingModel supply in supplies) {
      if (!supply.useInventory) {
        continue;
      }
      final String itemId = supply.inventoryItemId.trim();
      if (itemId.isEmpty) {
        continue;
      }
      final String name = supply.name.trim().isEmpty
          ? '未命名耗材'
          : supply.name.trim();
      final String unit = supply.unit;
      if (supply.appliesToStay) {
        add(
          itemId,
          InventoryLinkage(
            kind: InventoryLinkageKind.bookingSupply,
            typeLabel: '住宿耗材',
            sourceId: '${supply.id}:stay',
            title: name,
            quantity: _positiveOrZero(supply.stayQuantity),
            unit: unit,
            extra: InventoryConstants.deductionModeLabel(supply.stayMode),
            isEnabled: supply.enabled,
            statusLabel: supply.enabled ? '啟用中' : '已停用',
          ),
        );
      }
      if (supply.appliesToDaycare) {
        add(
          itemId,
          InventoryLinkage(
            kind: InventoryLinkageKind.daycareSupply,
            typeLabel: '安親耗材',
            sourceId: '${supply.id}:daycare',
            title: name,
            quantity: _positiveOrZero(supply.daycareQuantity),
            unit: unit,
            extra: InventoryConstants.daycareDeductionModeLabel(
              supply.daycareMode,
            ),
            isEnabled: supply.enabled,
            statusLabel: supply.enabled ? '啟用中' : '已停用',
          ),
        );
      }
    }

    return result;
  }

  static void _readAddonList(
    Map<String, dynamic>? data,
    String key,
    InventoryLinkageKind kind,
    String typeLabel,
    bool addonEnabled,
    void Function(String itemId, InventoryLinkage linkage) add,
  ) {
    final Object? raw = data?[key];
    if (raw is! List) {
      return;
    }
    for (int index = 0; index < raw.length; index++) {
      final Object? entry = raw[index];
      if (entry is! Map) {
        continue;
      }
      final Map<String, dynamic> item = Map<String, dynamic>.from(entry);
      if (item['useInventory'] != true) {
        continue;
      }
      final List<InventoryBindingModel> bindings =
          InventoryBindingModel.listFromValue(item['inventoryBindings']);
      final Map<String, _BindingTotal> totals = <String, _BindingTotal>{};
      for (final InventoryBindingModel binding in bindings) {
        final String itemId = binding.inventoryItemId.trim();
        if (itemId.isEmpty) {
          continue;
        }
        final _BindingTotal current = totals[itemId] ?? const _BindingTotal();
        totals[itemId] = _BindingTotal(
          quantity: current.quantity + binding.quantityPerUnit,
          unit: current.unit.isNotEmpty ? current.unit : binding.unit,
        );
      }
      if (totals.isEmpty) {
        continue;
      }
      final String id = (item['id'] ?? '').toString().trim();
      final String sourceId = id.isEmpty ? '$key:$index' : '$key:$id';
      final String title = _addonTitle(item);
      final bool serviceOn = item['enabled'] != false;
      final bool enabled = addonEnabled && serviceOn;
      totals.forEach((String itemId, _BindingTotal total) {
        add(
          itemId,
          InventoryLinkage(
            kind: kind,
            typeLabel: typeLabel,
            sourceId: sourceId,
            title: title,
            quantity: _positiveOrZero(total.quantity),
            unit: total.unit,
            extra: '',
            isEnabled: enabled,
            statusLabel: enabled ? '啟用中' : '已停用',
          ),
        );
      });
    }
  }

  static String _addonTitle(Map<String, dynamic> item) {
    final String name = (item['name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      return name;
    }
    final String label = (item['label'] ?? '').toString().trim();
    return label.isEmpty ? '未命名服務' : label;
  }
}

class _BindingTotal {
  const _BindingTotal({this.quantity = 0, this.unit = ''});

  final num quantity;
  final String unit;
}

num _positiveOrZero(num value) {
  if (value.isNaN || value.isInfinite || value < 0) {
    return 0;
  }
  return value;
}

String _formatQuantity(num value) {
  return InventoryConstants.formatQuantity(_positiveOrZero(value));
}

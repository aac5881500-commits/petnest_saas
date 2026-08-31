// lib/features/shop/pages/store/shop_store_promotion_form_page.dart
// 🛒 各活動類型專用表單（區塊式 Card，不是 5 步 wizard）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_category_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/store_category_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_promotion_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_product_picker_sheet.dart';

class ShopStorePromotionFormPage extends StatefulWidget {
  const ShopStorePromotionFormPage({
    super.key,
    required this.shopId,
    this.promotion,
    this.initialType,
    this.preselectedProductIds = const <String>[],
  });

  final String shopId;
  final StorePromotionModel? promotion;
  final String? initialType;
  final List<String> preselectedProductIds;

  @override
  State<ShopStorePromotionFormPage> createState() =>
      _ShopStorePromotionFormPageState();
}

class _ShopStorePromotionFormPageState
    extends State<ShopStorePromotionFormPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _discountValue = TextEditingController();
  final TextEditingController _minimumAmount = TextEditingController();
  final TextEditingController _minimumQuantity = TextEditingController();
  final TextEditingController _bundlePrice = TextEditingController();

  late String _type;
  String _discountMethod = StoreDiscountMethods.percent;
  bool _enabled = true;
  bool _saving = false;
  String _categoryId = '';
  List<String> _productIds = <String>[];
  List<StoreBundleItem> _bundleItems = <StoreBundleItem>[];
  DateTime? _startAt;
  DateTime? _endAt;
  bool _startImmediately = true;
  bool _endManually = true;
  bool _allowStack = false;

  bool get _isEditing => (widget.promotion?.id ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    final StorePromotionModel? promotion = widget.promotion;
    _type = promotion?.type ??
        widget.initialType ??
        StorePromotionTypes.bundle;
    if (promotion == null) {
      _productIds = List<String>.from(widget.preselectedProductIds);
      if (_type == StorePromotionTypes.quantity) {
        _discountMethod = StoreDiscountMethods.percent;
        _minimumQuantity.text = '3';
      }
      if (_type == StorePromotionTypes.amount) {
        _discountMethod = StoreDiscountMethods.amountOff;
      }
      if (_type == StorePromotionTypes.category) {
        _discountMethod = StoreDiscountMethods.percent;
      }
      if (_type == StorePromotionTypes.bundle) {
        _discountMethod = StoreDiscountMethods.specialPrice;
      }
      return;
    }
    _name.text = promotion.name;
    _description.text = promotion.description;
    _discountMethod = _defaultMethodForType(promotion);
    _discountValue.text = promotion.discountValue == 0
        ? ''
        : promotion.discountValue.toString();
    _bundlePrice.text = promotion.isBundle && promotion.discountValue > 0
        ? promotion.discountValue.round().toString()
        : '';
    _minimumAmount.text = promotion.minimumAmount == 0
        ? ''
        : promotion.minimumAmount.toString();
    _minimumQuantity.text = promotion.minimumQuantity == 0
        ? ''
        : promotion.minimumQuantity.toString();
    _enabled = promotion.enabled;
    _categoryId = promotion.categoryId;
    _productIds = List<String>.from(promotion.productIds);
    _bundleItems = List<StoreBundleItem>.from(promotion.bundleItems);
    _startAt = promotion.startAt;
    _endAt = promotion.endAt;
    _startImmediately = promotion.startAt == null;
    _endManually = promotion.endAt == null;
    _allowStack = promotion.allowStack;
  }

  String _defaultMethodForType(StorePromotionModel promotion) {
    if (promotion.type == StorePromotionTypes.category) {
      return StoreDiscountMethods.percent;
    }
    if (promotion.type == StorePromotionTypes.bundle) {
      return StoreDiscountMethods.specialPrice;
    }
    if (promotion.type == StorePromotionTypes.quantity &&
        promotion.discountMethod != StoreDiscountMethods.percent &&
        promotion.discountMethod != StoreDiscountMethods.specialPrice) {
      return StoreDiscountMethods.percent;
    }
    return promotion.discountMethod;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _discountValue.dispose();
    _minimumAmount.dispose();
    _minimumQuantity.dispose();
    _bundlePrice.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool start}) async {
    final DateTime initial = (start ? _startAt : _endAt) ?? DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) {
      return;
    }
    final DateTime value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _startAt = value;
        _startImmediately = false;
      } else {
        _endAt = value;
        _endManually = false;
      }
    });
  }

  Future<void> _pickProducts(
    List<StoreProductModel> products, {
    Map<String, String> categoryNames = const <String, String>{},
    required bool forBundle,
  }) async {
    final List<String> selected = forBundle
        ? _bundleItems.map((StoreBundleItem item) => item.productId).toList()
        : _productIds;
    final List<String>? result = await StoreProductPickerSheet.show(
      context: context,
      products: products,
      selectedIds: selected,
      categoryNames: categoryNames,
    );
    if (result == null) {
      return;
    }
    setState(() {
      if (forBundle) {
        final Map<String, int> current = <String, int>{
          for (final StoreBundleItem item in _bundleItems)
            item.productId: item.quantity,
        };
        _bundleItems = result.map((String id) {
          return StoreBundleItem(productId: id, quantity: current[id] ?? 1);
        }).toList();
      } else {
        _productIds = result;
      }
    });
  }

  StorePromotionModel _buildModel() {
    final num discountValue = _type == StorePromotionTypes.bundle
        ? (num.tryParse(_bundlePrice.text.trim()) ?? 0)
        : (num.tryParse(_discountValue.text.trim()) ?? 0);
    return StorePromotionModel(
      id: widget.promotion?.id ?? '',
      shopId: widget.shopId,
      name: _name.text.trim(),
      description: _description.text.trim(),
      type: _type,
      discountMethod: _type == StorePromotionTypes.bundle
          ? StoreDiscountMethods.specialPrice
          : _discountMethod,
      discountValue: discountValue,
      productIds: _type == StorePromotionTypes.quantity
          ? _productIds
          : _type == StorePromotionTypes.bundle
              ? _bundleItems
                  .map((StoreBundleItem item) => item.productId)
                  .toList()
              : const <String>[],
      bundleItems: _type == StorePromotionTypes.bundle
          ? _bundleItems
          : const <StoreBundleItem>[],
      categoryId: _type == StorePromotionTypes.category ? _categoryId : '',
      minimumAmount: _type == StorePromotionTypes.amount
          ? (int.tryParse(_minimumAmount.text.trim()) ?? 0)
          : 0,
      minimumQuantity: _type == StorePromotionTypes.quantity
          ? (int.tryParse(_minimumQuantity.text.trim()) ?? 0)
          : 0,
      startAt: _startImmediately ? null : _startAt,
      endAt: _endManually ? null : _endAt,
      allowStack: _allowStack,
      enabled: _enabled,
      createdAt: widget.promotion?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      usedOrderCount: widget.promotion?.usedOrderCount ?? 0,
    );
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) {
      return '請輸入活動名稱';
    }
    if (_type == StorePromotionTypes.bundle) {
      if (_bundleItems.length < 2) {
        return '套裝請至少選擇 2 件商品';
      }
      final int price = int.tryParse(_bundlePrice.text.trim()) ?? 0;
      if (price <= 0) {
        return '請輸入套裝售價';
      }
    }
    if (_type == StorePromotionTypes.quantity) {
      if (_productIds.isEmpty) {
        return '請選擇至少一件適用商品';
      }
      if ((int.tryParse(_minimumQuantity.text.trim()) ?? 0) <= 0) {
        return '請輸入任選件數';
      }
      final num value = num.tryParse(_discountValue.text.trim()) ?? 0;
      if (value <= 0) {
        return _discountMethod == StoreDiscountMethods.specialPrice
            ? '請輸入固定總價'
            : '請輸入折扣';
      }
    }
    if (_type == StorePromotionTypes.category) {
      if (_categoryId.isEmpty) {
        return '請選擇分類';
      }
      final num value = num.tryParse(_discountValue.text.trim()) ?? 0;
      if (value <= 0 || value > 100) {
        return '打折請填 8（八折）或 95（95折）';
      }
    }
    if (_type == StorePromotionTypes.amount) {
      if ((int.tryParse(_minimumAmount.text.trim()) ?? 0) <= 0) {
        return '請輸入滿額門檻';
      }
      final num value = num.tryParse(_discountValue.text.trim()) ?? 0;
      if (value <= 0) {
        return '請輸入優惠內容';
      }
    }
    if (!_startImmediately &&
        !_endManually &&
        _startAt != null &&
        _endAt != null &&
        !_startAt!.isBefore(_endAt!)) {
      return '結束時間必須晚於開始時間';
    }
    return null;
  }

  Future<void> _save() async {
    final String? error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _saving = true);
    try {
      await StorePromotionService.instance.savePromotion(
        shopId: widget.shopId,
        promotion: _buildModel(),
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(
          _isEditing
              ? '編輯${StorePromotionTypes.label(_type)}'
              : StorePromotionTypes.label(_type),
        ),
      ),
      body: StreamBuilder<List<StoreProductModel>>(
        stream: StoreProductService.instance.streamProducts(widget.shopId),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<StoreProductModel>> productSnapshot,
        ) {
          final List<StoreProductModel> products =
              productSnapshot.data ?? const <StoreProductModel>[];
          return StreamBuilder<List<StoreCategoryModel>>(
            stream: StoreCategoryService.instance.streamCategories(
              widget.shopId,
            ),
            builder: (
              BuildContext context,
              AsyncSnapshot<List<StoreCategoryModel>> categorySnapshot,
            ) {
              final List<StoreCategoryModel> categories =
                  categorySnapshot.data ?? const <StoreCategoryModel>[];
              final Map<String, String> categoryNames = <String, String>{
                for (final StoreCategoryModel item in categories)
                  item.id: item.name,
              };
              final Map<String, StoreProductModel> productsById =
                  <String, StoreProductModel>{
                for (final StoreProductModel item in products) item.id: item,
              };
              return Column(
                children: <Widget>[
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: <Widget>[
                        _FormCard(
                          title: '基本資料',
                          children: <Widget>[
                            TextField(
                              controller: _name,
                              decoration: const InputDecoration(
                                labelText: '活動名稱',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _description,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: '活動說明',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (_type == StorePromotionTypes.bundle)
                          _bundleSection(products, productsById, categoryNames),
                        if (_type == StorePromotionTypes.quantity)
                          _mixMatchSection(products, categoryNames),
                        if (_type == StorePromotionTypes.category)
                          _categorySection(categories),
                        if (_type == StorePromotionTypes.amount)
                          _amountSection(),
                        _FormCard(
                          title: '活動時間',
                          children: <Widget>[
                            const Text('開始'),
                            RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('立即生效'),
                              value: true,
                              groupValue: _startImmediately,
                              onChanged: (bool? value) {
                                setState(() {
                                  _startImmediately = true;
                                  _startAt = null;
                                });
                              },
                            ),
                            RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('指定時間'),
                              subtitle: Text(
                                _formatDate(_startAt) ?? '尚未選擇',
                              ),
                              value: false,
                              groupValue: _startImmediately,
                              onChanged: (bool? value) {
                                setState(() => _startImmediately = false);
                                _pickDateTime(start: true);
                              },
                            ),
                            const SizedBox(height: 8),
                            const Text('結束'),
                            RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('直到手動關閉'),
                              value: true,
                              groupValue: _endManually,
                              onChanged: (bool? value) {
                                setState(() {
                                  _endManually = true;
                                  _endAt = null;
                                });
                              },
                            ),
                            RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('指定時間'),
                              subtitle: Text(_formatDate(_endAt) ?? '尚未選擇'),
                              value: false,
                              groupValue: _endManually,
                              onChanged: (bool? value) {
                                setState(() => _endManually = false);
                                _pickDateTime(start: false);
                              },
                            ),
                          ],
                        ),
                        _FormCard(
                          title: '其他',
                          children: <Widget>[
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('啟用活動'),
                              value: _enabled,
                              onChanged: (bool value) {
                                setState(() => _enabled = value);
                              },
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('可與其他活動併用'),
                              subtitle: const Text(
                                '關閉時只取對客戶最有利的方案，不會全部自動疊加。',
                              ),
                              value: _allowStack,
                              onChanged: (bool value) {
                                setState(() => _allowStack = value);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? '儲存中...' : '儲存活動'),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _bundleSection(
    List<StoreProductModel> products,
    Map<String, StoreProductModel> productsById,
    Map<String, String> categoryNames,
  ) {
    int original = 0;
    for (final StoreBundleItem item in _bundleItems) {
      original += (productsById[item.productId]?.price ?? 0) * item.quantity;
    }
    final int bundlePrice = int.tryParse(_bundlePrice.text.trim()) ?? 0;
    final int saved = original - bundlePrice;

    return _FormCard(
      title: '優惠內容',
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () => _pickProducts(
            products,
            categoryNames: categoryNames,
            forBundle: true,
          ),
          icon: const Icon(Icons.add),
          label: const Text('加入商品'),
        ),
        const SizedBox(height: 10),
        if (_bundleItems.isEmpty)
          Text('尚未加入商品', style: TextStyle(color: Colors.grey.shade600)),
        ..._bundleItems.map((StoreBundleItem item) {
          final StoreProductModel? product = productsById[item.productId];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        product?.name ?? '商品',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'NT\$ ${product?.price ?? 0}'
                        '${product == null ? '' : '　${StoreStockHelper.adminStatusLabel(product)}'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: item.quantity <= 1
                      ? null
                      : () {
                          setState(() {
                            _bundleItems = _bundleItems.map((
                              StoreBundleItem line,
                            ) {
                              if (line.productId != item.productId) {
                                return line;
                              }
                              return StoreBundleItem(
                                productId: line.productId,
                                quantity: line.quantity - 1,
                              );
                            }).toList();
                          });
                        },
                  icon: const Icon(Icons.remove),
                ),
                Text('${item.quantity}'),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _bundleItems = _bundleItems.map((StoreBundleItem line) {
                        if (line.productId != item.productId) {
                          return line;
                        }
                        return StoreBundleItem(
                          productId: line.productId,
                          quantity: line.quantity + 1,
                        );
                      }).toList();
                    });
                  },
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _bundleItems = _bundleItems
                          .where(
                            (StoreBundleItem line) =>
                                line.productId != item.productId,
                          )
                          .toList();
                    });
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          );
        }),
        const Divider(),
        Text('商品原價總計：NT\$$original'),
        const SizedBox(height: 8),
        TextField(
          controller: _bundlePrice,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: '套裝價',
            prefixText: 'NT\$ ',
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        if (bundlePrice > 0 && original > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              saved > 0 ? '現省：NT\$$saved' : '套裝價需低於原價才有優惠',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: saved > 0
                    ? Theme.of(context).colorScheme.primary
                    : Colors.orange.shade800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _mixMatchSection(
    List<StoreProductModel> products,
    Map<String, String> categoryNames,
  ) {
    return Column(
      children: <Widget>[
        _FormCard(
          title: '優惠內容',
          children: <Widget>[
            TextField(
              controller: _minimumQuantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '任選件數',
                hintText: '例如 3',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: const Text('滿 X 件打折'),
              value: StoreDiscountMethods.percent,
              groupValue: _discountMethod,
              onChanged: (String? value) {
                setState(() => _discountMethod = value ?? _discountMethod);
              },
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: const Text('滿 X 件固定總價'),
              value: StoreDiscountMethods.specialPrice,
              groupValue: _discountMethod,
              onChanged: (String? value) {
                setState(() => _discountMethod = value ?? _discountMethod);
              },
            ),
            TextField(
              controller: _discountValue,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _discountMethod == StoreDiscountMethods.specialPrice
                    ? '固定總價，例如 199'
                    : '打折，例如 9＝九折',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
        _FormCard(
          title: '適用範圍',
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => _pickProducts(
                products,
                categoryNames: categoryNames,
                forBundle: false,
              ),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(
                _productIds.isEmpty ? '選擇商品' : '已選 ${_productIds.length} 款商品',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '這是多商品混搭，不是單一商品的買 X 送 Y。',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _categorySection(List<StoreCategoryModel> categories) {
    return Column(
      children: <Widget>[
        _FormCard(
          title: '優惠內容',
          children: <Widget>[
            TextField(
              controller: _discountValue,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '打折，例如 9＝九折',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
        _FormCard(
          title: '適用範圍',
          children: <Widget>[
            DropdownButtonFormField<String>(
              initialValue: categories.any(
                    (StoreCategoryModel item) => item.id == _categoryId,
                  )
                  ? _categoryId
                  : '',
              decoration: const InputDecoration(
                labelText: '商品分類',
                filled: true,
                fillColor: Colors.white,
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('請選擇分類'),
                ),
                ...categories.map((StoreCategoryModel category) {
                  return DropdownMenuItem<String>(
                    value: category.id,
                    child: Text(category.name),
                  );
                }),
              ],
              onChanged: (String? value) {
                setState(() => _categoryId = value ?? '');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _amountSection() {
    return _FormCard(
      title: '優惠內容',
      children: <Widget>[
        TextField(
          controller: _minimumAmount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '滿額門檻（NT\$）',
            hintText: '例如 1000',
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          title: const Text('折固定金額'),
          value: StoreDiscountMethods.amountOff,
          groupValue: _discountMethod,
          onChanged: (String? value) {
            setState(() => _discountMethod = value ?? _discountMethod);
          },
        ),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          title: const Text('打折'),
          value: StoreDiscountMethods.percent,
          groupValue: _discountMethod,
          onChanged: (String? value) {
            setState(() => _discountMethod = value ?? _discountMethod);
          },
        ),
        TextField(
          controller: _discountValue,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _discountMethod == StoreDiscountMethods.percent
                ? '打折，例如 95＝95折'
                : '折抵金額，例如 100',
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  String? _formatDate(DateTime? value) {
    if (value == null) {
      return null;
    }
    return '${value.year}/${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

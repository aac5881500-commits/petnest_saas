// lib/features/shop/pages/store/shop_store_product_form_page.dart
// 🛒 商品新增 / 編輯

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/models/store_category_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';
import 'package:petnest_saas/core/services/store_promotion_service.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_promotion_form_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_product_price_view.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/core/services/store_category_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_item_picker_page.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_item_cover.dart';

class ShopStoreProductFormPage extends StatefulWidget {
  const ShopStoreProductFormPage({
    super.key,
    required this.shopId,
    this.product,
  });

  final String shopId;
  final StoreProductModel? product;

  @override
  State<ShopStoreProductFormPage> createState() =>
      _ShopStoreProductFormPageState();
}

class _ShopStoreProductFormPageState extends State<ShopStoreProductFormPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _qty = TextEditingController(text: '1');
  final TextEditingController _itemPromoValue = TextEditingController();

  bool _enabled = true;
  bool _featured = false;
  bool _saving = false;
  String _categoryId = '';
  String _categoryName = '';
  String _imageUrl = '';
  String _imagePath = '';
  String _inventoryItemId = '';
  String _inventoryItemName = '';
  String _inventoryUnit = '';
  InventoryItemModel? _linkedItem;
  StreamSubscription<InventoryItemModel?>? _linkedItemSub;
  String _committedImagePath = '';
  String _sessionUploadedPath = '';
  String _sessionUploadedUrl = '';
  late final String _productId;
  bool _itemPromoEnabled = false;
  String _itemPromoType = StoreItemPromotionTypes.specialPrice;
  int _itemBuy = 1;
  int _itemFree = 1;
  bool _itemAllowStack = false;
  DateTime? _itemStartAt;
  DateTime? _itemEndAt;

  @override
  void initState() {
    super.initState();
    _productId = widget.product?.id ??
        StoreProductService.instance.productsRef(widget.shopId).doc().id;
    final StoreProductModel? product = widget.product;
    if (product != null) {
      _name.text = product.name;
      _desc.text = product.description;
      _price.text = product.price.toString();
      _qty.text = InventoryConstants.formatQuantity(
        product.inventoryQuantityPerSale,
      );
      _enabled = product.enabled;
      _featured = product.featured;
      _categoryId = product.categoryId;
      _categoryName = product.categoryNameSnapshot;
      _imageUrl = product.imageUrl;
      _imagePath = product.imageStoragePath;
      _committedImagePath = product.imageStoragePath;
      _inventoryItemId = product.inventoryItemId;
      _inventoryItemName = product.inventoryItemNameSnapshot;
      _inventoryUnit = product.inventoryUnitSnapshot;
      if (_inventoryItemId.isNotEmpty) {
        _listenLinkedItem();
      }
      _itemPromoEnabled = product.itemPromotionEnabled;
      _itemPromoType = product.itemPromotionType == StoreItemPromotionTypes.none
          ? StoreItemPromotionTypes.specialPrice
          : product.itemPromotionType;
      _itemPromoValue.text = product.itemPromotionValue == 0
          ? ''
          : product.itemPromotionValue.toString();
      _itemBuy = product.itemPromotionBuyQuantity < 1
          ? 1
          : product.itemPromotionBuyQuantity;
      _itemFree = product.itemPromotionFreeQuantity < 1
          ? 1
          : product.itemPromotionFreeQuantity;
      _itemAllowStack = product.itemPromotionAllowStack;
      _itemStartAt = product.itemPromotionStartAt;
      _itemEndAt = product.itemPromotionEndAt;
    }
  }

  void _listenLinkedItem() {
    _linkedItemSub?.cancel();
    _linkedItemSub = InventoryService.instance
        .streamItem(shopId: widget.shopId, itemId: _inventoryItemId)
        .listen((InventoryItemModel? item) {
      if (!mounted || item == null) {
        return;
      }
      setState(() {
        _linkedItem = item;
        _inventoryItemName = item.name.trim().isEmpty
            ? _inventoryItemName
            : item.name.trim();
        _inventoryUnit = item.unit.trim().isEmpty
            ? _inventoryUnit
            : item.unit.trim();
      });
    });
  }

  @override
  void dispose() {
    _linkedItemSub?.cancel();
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _qty.dispose();
    _itemPromoValue.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image =
          await InventoryImageService.instance.pickAndValidateImage();
      if (image == null) {
        return;
      }
      final result = await InventoryImageService.instance.uploadImage(
        shopId: widget.shopId,
        itemId: _productId,
        image: image,
        folder: StoreConstants.imageFolder,
        imageType: 'store_cover',
        idMetadataKey: 'productId',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _imageUrl = result.imageUrl;
        _imagePath = result.imageStoragePath;
        _sessionUploadedPath = result.imageStoragePath;
        _sessionUploadedUrl = result.imageUrl;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<InventoryItemModel?> _readInventoryForSave() async {
    final String path =
        'shops/${widget.shopId.trim()}/inventory_items/${_inventoryItemId.trim()}';
    debugPrint('[StoreProductSave] STEP 0 inventory read start\npath=$path');
    try {
      final InventoryItemModel? item = await InventoryService.instance.getItem(
        shopId: widget.shopId,
        itemId: _inventoryItemId,
      );
      debugPrint(
        '[StoreProductSave] STEP 0 inventory read success\npath=$path\nfound=${item != null}',
      );
      return item;
    } catch (error, stackTrace) {
      debugPrint(
        '[StoreProductSave] STEP 0 inventory read failed\n'
        'path=$path\n'
        'code=${error is FirebaseException ? error.code : ''}\n'
        'message=$error\n'
        'stack=$stackTrace',
      );
      throw StoreProductSaveException(
        step: 'STEP 0 inventory read',
        path: path,
        cause: error,
      );
    }
  }

  Future<void> _cleanupUncommittedStoreImage() async {
    final String path = _sessionUploadedPath.trim();
    if (path.isEmpty || path == _committedImagePath.trim()) {
      return;
    }
    if (!path.contains('/store/')) {
      return;
    }
    await InventoryImageService.instance.tryDeleteImage(
      imageUrl: _sessionUploadedUrl,
      imageStoragePath: path,
    );
  }

  bool get _allowDecimal => _linkedItem?.allowDecimal == true;

  bool get _hasInventoryBound => _inventoryItemId.trim().isNotEmpty;

  bool get _showCommerceFields =>
      _hasInventoryBound || widget.product != null;

  Future<void> _pickInventoryItem() async {
    final InventoryItemModel? selected =
        await Navigator.push<InventoryItemModel>(
      context,
      MaterialPageRoute<InventoryItemModel>(
        builder: (_) => ShopInventoryItemPickerPage(
          shopId: widget.shopId,
          selectedItemId: _inventoryItemId,
        ),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }

    final bool isFirstBind = _inventoryItemId.trim().isEmpty;
    final bool isSameItem = selected.id == _inventoryItemId;
    if (isSameItem) {
      return;
    }
    if (!isFirstBind) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('確定更換庫存來源？'),
            content: const Text(
              '商品名稱、圖片、介紹與售價不會自動變更。\n'
              '若要帶入新品項名稱、圖片與介紹，請再按「套用新庫存資料」。',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('更換'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) {
        return;
      }
      _bindInventoryMeta(selected);
      return;
    }

    _bindInventoryMeta(selected);
    _applyInventoryCatalog(selected, overwrite: false);
  }

  void _bindInventoryMeta(InventoryItemModel item) {
    setState(() {
      _inventoryItemId = item.id;
      _inventoryItemName = item.name.trim();
      _inventoryUnit = item.unit.trim();
      _linkedItem = item;
      if (!item.allowDecimal) {
        final num qty = num.tryParse(_qty.text.trim()) ?? 1;
        _qty.text = InventoryConstants.formatQuantity(qty.round() < 1 ? 1 : qty.round());
      }
    });
    _listenLinkedItem();
  }

  Future<void> _maybeApplyInventoryCatalog(InventoryItemModel item) async {
    final bool wouldOverwrite = _catalogWouldOverwrite(item);
    if (!wouldOverwrite) {
      _applyInventoryCatalog(item, overwrite: false);
      return;
    }

    final bool? apply = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('套用庫存商品資料？'),
          content: const Text(
            '庫存品項已有商品名稱、說明或圖片。\n是否帶入商城商品？\n\n售價不會帶入成本。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('保留目前內容'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('套用庫存資料'),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    _applyInventoryCatalog(item, overwrite: apply == true);
  }

  bool _catalogWouldOverwrite(InventoryItemModel item) {
    final bool nameConflict =
        _name.text.trim().isNotEmpty && item.name.trim().isNotEmpty;
    final bool descConflict =
        _desc.text.trim().isNotEmpty && item.description.trim().isNotEmpty;
    final bool imageConflict =
        _imageUrl.trim().isNotEmpty && item.hasCoverImage;
    return nameConflict || descConflict || imageConflict;
  }

  void _applyInventoryCatalog(
    InventoryItemModel item, {
    required bool overwrite,
  }) {
    setState(() {
      final String inventoryName = item.name.trim();
      if (inventoryName.isNotEmpty &&
          (overwrite || _name.text.trim().isEmpty)) {
        _name.text = inventoryName;
      }

      final String inventoryDesc = item.description.trim();
      if (inventoryDesc.isNotEmpty &&
          (overwrite || _desc.text.trim().isEmpty)) {
        _desc.text = inventoryDesc;
      }

      if (item.hasCoverImage && (overwrite || _imageUrl.trim().isEmpty)) {
        _imageUrl = item.imageUrl.trim();
        _imagePath = item.imageStoragePath.trim();
      }
    });
  }

  void _adjustQty(num delta) {
    num current = num.tryParse(_qty.text.trim()) ?? 1;
    current += delta;
    final num minValue = _allowDecimal ? 0.5 : 1;
    if (current < minValue) {
      current = minValue;
    }
    if (!_allowDecimal) {
      current = current.round();
    }
    setState(() {
      _qty.text = InventoryConstants.formatQuantity(
        InventoryConstants.roundQuantity(current),
      );
    });
  }

  String _formStockStatusLabel(InventoryItemModel item) {
    switch (item.stockStatus) {
      case InventoryStockStatus.normal:
        return '正常';
      case InventoryStockStatus.low:
        return '低庫存';
      case InventoryStockStatus.outOfStock:
        return '無庫存';
      case InventoryStockStatus.disabled:
        return '已停用';
    }
  }

  Color _formStockStatusColor(InventoryItemModel item) {
    switch (item.stockStatus) {
      case InventoryStockStatus.normal:
        return const Color(0xFF2E7D32);
      case InventoryStockStatus.low:
        return const Color(0xFFC45C26);
      case InventoryStockStatus.outOfStock:
      case InventoryStockStatus.disabled:
        return const Color(0xFFB3261E);
    }
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    final int price = int.tryParse(_price.text.trim()) ?? -1;
    if (name.isEmpty || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入商品名稱與正確價格')),
      );
      return;
    }
    num qty = num.tryParse(_qty.text.trim()) ?? 1;
    final bool linked = _hasInventoryBound;
    if (!linked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先從中央庫存選擇商品')),
      );
      return;
    }
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('每出貨 1 件扣除數量必須大於 0')),
      );
      return;
    }
    if (!_allowDecimal && qty % 1 != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此庫存品項只能輸入整數扣除數量')),
      );
      return;
    }
    final String? promoError = _validateItemPromotion(price);
    if (promoError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(promoError)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final Map<String, dynamic> data = <String, dynamic>{
      'name': name,
      'description': _desc.text.trim(),
      'price': price,
      'enabled': _enabled,
      'featured': _featured,
      'useInventory': true,
      'categoryId': _categoryId,
      'categoryNameSnapshot': _categoryName,
      'imageUrl': _imageUrl,
      'imageStoragePath': _imagePath,
      'inventoryItemId': _inventoryItemId,
      'inventoryItemNameSnapshot': _inventoryItemName,
      'inventoryUnitSnapshot': _inventoryUnit,
      'inventoryQuantityPerSale': qty,
      'sortOrder': widget.product?.sortOrder ?? 0,
      'itemPromotionEnabled': _itemPromoEnabled,
      'itemPromotionType': _itemPromoType,
      'itemPromotionValue': num.tryParse(_itemPromoValue.text.trim()) ?? 0,
      'itemPromotionBuyQuantity': _itemBuy < 1 ? 1 : _itemBuy,
      'itemPromotionFreeQuantity': _itemFree < 1 ? 1 : _itemFree,
      'itemPromotionAllowStack': _itemAllowStack,
      'itemPromotionStartAt': _itemStartAt == null
          ? null
          : Timestamp.fromDate(_itemStartAt!),
      'itemPromotionEndAt': _itemEndAt == null
          ? null
          : Timestamp.fromDate(_itemEndAt!),
    };

    final InventoryItemModel? item = await _readInventoryForSave();
    data.addAll(
      StoreStockHelper.publicStockFields(
        useInventory: true,
        item: item,
        inventoryQuantityPerSale: qty,
      ),
    );

      debugPrint(
        '[StoreProductSave] form payload keys=${(data.keys.toList()..sort()).join(',')}\n'
        'pageShopId=${widget.shopId}\n'
        'productShopId=${widget.product?.shopId}\n'
        'uid=${FirebaseAuth.instance.currentUser?.uid}',
      );

      if (widget.product == null) {
        await StoreProductService.instance.createProduct(
          shopId: widget.shopId,
          productId: _productId,
          data: data,
        );
      } else {
        await StoreProductService.instance.updateProduct(
          shopId: widget.shopId,
          productId: widget.product!.id,
          data: data,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } catch (error) {
      await _cleanupUncommittedStoreImage();
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
      appBar: AppBar(
        title: Text(widget.product == null ? '新增商品' : '編輯商品'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (!_hasInventoryBound) _buildUnboundInventoryPrompt(),
          if (_hasInventoryBound) ...<Widget>[
            _buildInventoryLinkSection(),
            const SizedBox(height: 16),
          ],
          if (_showCommerceFields) ..._buildCommerceFields(),
        ],
      ),
    );
  }

  List<Widget> _buildCommerceFields() {
    return <Widget>[
      Center(
        child: InkWell(
          onTap: _pickImage,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 120,
              height: 120,
              color: Colors.grey.shade100,
              child: _imageUrl.isEmpty
                  ? const Icon(Icons.add_a_photo_outlined, size: 32)
                  : Image.network(_imageUrl, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
      TextButton(
        onPressed: _pickImage,
        child: Text(_imageUrl.isEmpty ? '選擇商品圖片' : '更換商品圖片'),
      ),
      TextButton(
        onPressed: _imageUrl.isEmpty
            ? null
            : () {
                setState(() {
                  _imageUrl = '';
                  _imagePath = '';
                });
              },
        child: const Text('刪除圖片'),
      ),
      TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: '商品名稱'),
      ),
      TextField(
        controller: _price,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: '售價',
          helperText: '商城售價由店家自行輸入，不會帶入庫存成本。',
        ),
        onChanged: (_) => setState(() {}),
      ),
      TextField(
        controller: _desc,
        maxLines: 4,
        decoration: const InputDecoration(labelText: '商品介紹'),
      ),
      const SizedBox(height: 8),
      StreamBuilder<List<StoreCategoryModel>>(
        stream: StoreCategoryService.instance.streamCategories(widget.shopId),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<StoreCategoryModel>> snapshot,
        ) {
          final List<StoreCategoryModel> categories =
              snapshot.data ?? const <StoreCategoryModel>[];
          return DropdownButtonFormField<String>(
            initialValue: categories.any(
                  (StoreCategoryModel item) => item.id == _categoryId,
                )
                ? _categoryId
                : '',
            decoration: const InputDecoration(labelText: '分類'),
            items: <DropdownMenuItem<String>>[
              const DropdownMenuItem<String>(value: '', child: Text('未分類')),
              ...categories.map((StoreCategoryModel item) {
                return DropdownMenuItem<String>(
                  value: item.id,
                  child: Text(item.name),
                );
              }),
            ],
            onChanged: (String? value) {
              final StoreCategoryModel? selected = categories
                  .where((StoreCategoryModel item) => item.id == value)
                  .firstOrNull;
              setState(() {
                _categoryId = value ?? '';
                _categoryName = selected?.name ?? '';
              });
            },
          );
        },
      ),
      SwitchListTile(
        title: const Text('上架'),
        subtitle: _hasInventoryBound
            ? null
            : const Text('尚未連結中央庫存，無法上架販售。'),
        value: _enabled && _hasInventoryBound,
        onChanged: (bool value) {
          if (value && !_hasInventoryBound) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('請先選擇庫存品項後才能上架販售')),
            );
            return;
          }
          setState(() => _enabled = value);
        },
      ),
      SwitchListTile(
        title: const Text('精選商品'),
        value: _featured,
        onChanged: (bool value) => setState(() => _featured = value),
      ),
      _buildCurrentPromotionSection(),
      const SizedBox(height: 12),
      _buildItemPromotionSection(),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: const Text('儲存'),
      ),
    ];
  }

  Widget _buildUnboundInventoryPrompt() {
    final bool isLegacy = widget.product != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '選擇商品庫存',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              isLegacy
                  ? '此商品尚未連結中央庫存，請先選擇庫存品項後才能繼續上架販售。'
                  : '商城商品必須連結中央庫存，售出後系統才能正確扣庫存並顯示售罄狀態。',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isLegacy
                    ? const Color(0xFFC45C26)
                    : Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _pickInventoryItem,
              icon: const Icon(Icons.add),
              label: const Text('從中央庫存選擇商品'),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateItemPromotion(int price) {
    if (!_itemPromoEnabled) {
      return null;
    }
    if (_itemStartAt != null &&
        _itemEndAt != null &&
        !_itemStartAt!.isBefore(_itemEndAt!)) {
      return '商品優惠結束時間必須晚於開始時間';
    }
    final num value = num.tryParse(_itemPromoValue.text.trim()) ?? 0;
    if (_itemPromoType == StoreItemPromotionTypes.specialPrice) {
      if (value <= 0) {
        return '請輸入特價金額';
      }
      if (value >= price) {
        return '特價不得高於或等於原價';
      }
    }
    if (_itemPromoType == StoreItemPromotionTypes.percent) {
      if (value <= 0 || value >= 100) {
        return '打折請填 8（八折）、85（八五折）或 95（九五折）';
      }
    }
    if (_itemPromoType == StoreItemPromotionTypes.amountOff) {
      if (value <= 0) {
        return '請輸入每件減價金額';
      }
    }
    if (_itemPromoType == StoreItemPromotionTypes.buyXGetY) {
      if (_itemBuy < 1 || _itemFree < 1) {
        return '買 X 送 Y 的數量必須大於 0';
      }
    }
    return null;
  }

  StoreProductModel _previewProduct() {
    return StoreProductModel(
      id: _productId,
      shopId: widget.shopId,
      name: _name.text.trim().isEmpty ? '商品' : _name.text.trim(),
      price: int.tryParse(_price.text.trim()) ?? 0,
      enabled: _enabled,
      featured: _featured,
      useInventory: _hasInventoryBound,
      inventoryItemId: _inventoryItemId,
      sortOrder: widget.product?.sortOrder ?? 0,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      categoryId: _categoryId,
      itemPromotionEnabled: _itemPromoEnabled,
      itemPromotionType: _itemPromoEnabled
          ? _itemPromoType
          : StoreItemPromotionTypes.none,
      itemPromotionValue: num.tryParse(_itemPromoValue.text.trim()) ?? 0,
      itemPromotionBuyQuantity: _itemBuy,
      itemPromotionFreeQuantity: _itemFree,
      itemPromotionAllowStack: _itemAllowStack,
      itemPromotionStartAt: _itemStartAt,
      itemPromotionEndAt: _itemEndAt,
    );
  }

  Future<void> _pickItemPromoDate({required bool start}) async {
    final DateTime initial = (start ? _itemStartAt : _itemEndAt) ?? DateTime.now();
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
    setState(() {
      final DateTime value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _itemStartAt = value;
      } else {
        _itemEndAt = value;
      }
    });
  }

  String _itemPromoDateLabel(DateTime? value, {required String empty}) {
    if (value == null) {
      return empty;
    }
    return '${value.year}/${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildItemPromotionSection() {
    final int price = int.tryParse(_price.text.trim()) ?? 0;
    final num value = num.tryParse(_itemPromoValue.text.trim()) ?? 0;
    final bool specialTooHigh = _itemPromoEnabled &&
        _itemPromoType == StoreItemPromotionTypes.specialPrice &&
        value > 0 &&
        price > 0 &&
        value >= price;
    final StorePricedLine preview = StorePricingService.instance.quoteProduct(
      product: _previewProduct(),
      quantity: _itemPromoType == StoreItemPromotionTypes.buyXGetY
          ? _itemBuy
          : 1,
      promotions: const <StorePromotionModel>[],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '商品優惠',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '只套用在這一個商品。關閉後會保留設定，只是不再套用。',
              style: TextStyle(fontSize: 12),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('啟用商品優惠'),
              value: _itemPromoEnabled,
              onChanged: (bool next) {
                setState(() => _itemPromoEnabled = next);
              },
            ),
            if (_itemPromoEnabled) ...<Widget>[
              const Text('優惠方式', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (_itemPromoType == StoreItemPromotionTypes.amountOff)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '此商品使用舊版固定減價優惠，建議改用特價。',
                    style: TextStyle(color: Color(0xFFB45309)),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <String>[
                  ...StoreItemPromotionTypes.selectable,
                  if (_itemPromoType == StoreItemPromotionTypes.amountOff)
                    StoreItemPromotionTypes.amountOff,
                ].map((String type) {
                  return ChoiceChip(
                    label: Text(StoreItemPromotionTypes.label(type)),
                    selected: _itemPromoType == type,
                    onSelected: (_) {
                      setState(() => _itemPromoType = type);
                    },
                  );
                }).toList(),
              ),
              if (_itemPromoType == StoreItemPromotionTypes.specialPrice)
                TextField(
                  controller: _itemPromoValue,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '特價（NT\$）'),
                  onChanged: (_) => setState(() {}),
                ),
              if (_itemPromoType == StoreItemPromotionTypes.percent)
                TextField(
                  controller: _itemPromoValue,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '打折',
                    hintText: '8＝八折、85＝八五折、95＝九五折',
                    helperText: '請輸入 8、85、95，不要輸入 0.8',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              if (_itemPromoType == StoreItemPromotionTypes.amountOff)
                TextField(
                  controller: _itemPromoValue,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '舊版每件折抵（NT\$）',
                    helperText: '新商品請改用特價，例如原價 999 減 100 就設特價 899',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              if (_itemPromoType == StoreItemPromotionTypes.buyXGetY) ...<Widget>[
                const SizedBox(height: 8),
                _qtyStepper(
                  label: '買',
                  value: _itemBuy,
                  onChanged: (int next) {
                    setState(() => _itemBuy = next < 1 ? 1 : next);
                  },
                ),
                _qtyStepper(
                  label: '送',
                  value: _itemFree,
                  onChanged: (int next) {
                    setState(() => _itemFree = next < 1 ? 1 : next);
                  },
                ),
              ],
              if (specialTooHigh)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '特價不得高於或等於原價',
                    style: TextStyle(color: Color(0xFFB3261E)),
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('開始時間'),
                subtitle: Text(
                  _itemPromoDateLabel(_itemStartAt, empty: '未設定（立即生效）'),
                ),
                trailing: TextButton(
                  onPressed: () => _pickItemPromoDate(start: true),
                  child: const Text('選擇'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('結束時間'),
                subtitle: Text(
                  _itemPromoDateLabel(_itemEndAt, empty: '未設定（直到手動關閉）'),
                ),
                trailing: TextButton(
                  onPressed: () => _pickItemPromoDate(start: false),
                  child: const Text('選擇'),
                ),
              ),
              if (_itemStartAt != null || _itemEndAt != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _itemStartAt = null;
                      _itemEndAt = null;
                    });
                  },
                  child: const Text('清除時間'),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('可與其他商城優惠併用'),
                subtitle: const Text('關閉時，此商品不再吃分類／滿額等後續活動。'),
                value: _itemAllowStack,
                onChanged: (bool? next) {
                  setState(() => _itemAllowStack = next == true);
                },
              ),
              const Text('即時預覽', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('原價 NT\$$price'),
              if (_itemPromoType == StoreItemPromotionTypes.buyXGetY)
                Text(
                  '買 $_itemBuy 送 $_itemFree　每組省 NT\$${price * _itemFree}',
                )
              else
                StoreProductPriceView(
                  line: preview,
                  compact: true,
                  showSaved: true,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _qtyStepper({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(width: 32, child: Text(label)),
        IconButton(
          onPressed: value <= 1 ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(
          onPressed: value >= 99 ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  Widget _buildCurrentPromotionSection() {
    return StreamBuilder<List<StorePromotionModel>>(
      stream: StorePromotionService.instance.streamEnabledPromotions(
        widget.shopId,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<StorePromotionModel>> snapshot,
      ) {
        final StoreProductModel preview = _previewProduct();
        final StorePricedLine line = StorePricingService.instance.quoteProduct(
          product: preview,
          promotions: snapshot.data ?? const <StorePromotionModel>[],
        );
        final StorePromotionModel? promo = line.promotion;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '跨商品促銷活動',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  '單一商品特價、打折、買X送Y請在下方「商品優惠」設定。此處只顯示分類／多商品／全館活動。',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 6),
                if (promo == null)
                  const Text('目前沒有套用跨商品活動')
                else ...<Widget>[
                  Text(promo.name),
                  Text('${promo.offerLabel}　${promo.periodLabel}'),
                  StoreProductPriceView(line: line, compact: true, showSaved: true),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: promo == null
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ShopStorePromotionFormPage(
                                  shopId: widget.shopId,
                                  preselectedProductIds: <String>[_productId],
                                ),
                              ),
                            );
                          }
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ShopStorePromotionFormPage(
                                  shopId: widget.shopId,
                                  promotion: promo,
                                ),
                              ),
                            );
                          },
                    child: Text(promo == null ? '前往促銷活動' : '查看促銷活動'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInventoryLinkSection() {
    return StreamBuilder<InventoryItemModel?>(
      stream: InventoryService.instance.streamItem(
        shopId: widget.shopId,
        itemId: _inventoryItemId,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<InventoryItemModel?> snapshot,
      ) {
        final InventoryItemModel? item = snapshot.data ?? _linkedItem;
        return _buildInventoryCard(item);
      },
    );
  }

  Widget _buildInventoryCard(InventoryItemModel? item) {
    final String name = item?.name.trim().isNotEmpty == true
        ? item!.name.trim()
        : (_inventoryItemName.isEmpty ? '未命名庫存品項' : _inventoryItemName);
    final String unit = (item?.unit.trim().isNotEmpty == true
            ? item!.unit.trim()
            : _inventoryUnit)
        .trim();
    final String unitLabel = unit.isEmpty ? '個' : unit;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '中央庫存',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '已連結：$name',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (item != null)
                  InventoryItemCover(item: item, size: 64, borderRadius: 12)
                else
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: colors.primary,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if ((item?.sku ?? '').trim().isNotEmpty) ...<Widget>[
                        Text(
                          'SKU：${item!.sku.trim()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      if (item != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          '目前庫存：${InventoryConstants.formatQuantity(item.currentStock)} $unitLabel',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '安全庫存：${InventoryConstants.formatQuantity(item.safetyStock)} $unitLabel',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _stockChip(item),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (item != null && !item.enabled) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBE8DC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '此庫存品項目前已停用',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC45C26),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '每出貨 1 件扣除庫存',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '每實際交付 1 件商品，要扣除多少中央庫存。贈送商品也會計入實際出貨數量。\n'
              '例如：每出貨 1 件扣 1 $unitLabel，買2送1 實際交付 3 件 → 庫存自動扣 3 $unitLabel。',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                IconButton.outlined(
                  onPressed: () => _adjustQty(_allowDecimal ? -0.5 : -1),
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: TextField(
                    controller: _qty,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: _allowDecimal,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => _adjustQty(_allowDecimal ? 0.5 : 1),
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 8),
                Text(unitLabel),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: _pickInventoryItem,
                  child: const Text('更換庫存品項'),
                ),
                TextButton(
                  onPressed: item == null
                      ? null
                      : () => _maybeApplyInventoryCatalog(item),
                  child: const Text('套用新庫存資料'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockChip(InventoryItemModel item) {
    final Color color = _formStockStatusColor(item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _formStockStatusLabel(item),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

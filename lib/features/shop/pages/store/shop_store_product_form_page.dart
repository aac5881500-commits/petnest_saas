// lib/features/shop/pages/store/shop_store_product_form_page.dart
// 🛒 商品新增 / 編輯

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/models/store_category_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/core/services/store_category_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_item_picker_page.dart';

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

  bool _enabled = true;
  bool _featured = false;
  bool _useInventory = false;
  bool _saving = false;
  String _categoryId = '';
  String _categoryName = '';
  String _imageUrl = '';
  String _imagePath = '';
  String _inventoryItemId = '';
  String _inventoryItemName = '';
  String _inventoryUnit = '';
  late final String _productId;

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
      _useInventory = product.useInventory;
      _categoryId = product.categoryId;
      _categoryName = product.categoryNameSnapshot;
      _imageUrl = product.imageUrl;
      _imagePath = product.imageStoragePath;
      _inventoryItemId = product.inventoryItemId;
      _inventoryItemName = product.inventoryItemNameSnapshot;
      _inventoryUnit = product.inventoryUnitSnapshot;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _qty.dispose();
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
    if (_useInventory && qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('每件扣除數量必須大於 0')),
      );
      return;
    }
    if (_useInventory && _inventoryItemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇要連動的庫存品項')),
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
      'useInventory': _useInventory,
      'categoryId': _categoryId,
      'categoryNameSnapshot': _categoryName,
      'imageUrl': _imageUrl,
      'imageStoragePath': _imagePath,
      'inventoryItemId': _useInventory ? _inventoryItemId : '',
      'inventoryItemNameSnapshot': _useInventory ? _inventoryItemName : '',
      'inventoryUnitSnapshot': _useInventory ? _inventoryUnit : '',
      'inventoryQuantityPerSale': _useInventory ? qty : 1,
      'sortOrder': widget.product?.sortOrder ?? 0,
    };

    if (_useInventory) {
      final InventoryItemModel? item = await InventoryService.instance.getItem(
        shopId: widget.shopId,
        itemId: _inventoryItemId,
      );
      data.addAll(
        StoreStockHelper.publicStockFields(
          useInventory: true,
          item: item,
          inventoryQuantityPerSale: qty,
        ),
      );
    } else {
      data.addAll(
        StoreStockHelper.publicStockFields(useInventory: false),
      );
    }

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
            decoration: const InputDecoration(labelText: '售價'),
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
            value: _enabled,
            onChanged: (bool value) => setState(() => _enabled = value),
          ),
          SwitchListTile(
            title: const Text('精選商品'),
            value: _featured,
            onChanged: (bool value) => setState(() => _featured = value),
          ),
          SwitchListTile(
            title: const Text('庫存連動'),
            subtitle: const Text('開啟後售出會扣除指定中央庫存'),
            value: _useInventory,
            onChanged: (bool value) => setState(() => _useInventory = value),
          ),
          if (_useInventory) ...<Widget>[
            ListTile(
              title: Text(
                _inventoryItemName.isEmpty ? '選擇庫存品項' : _inventoryItemName,
              ),
              subtitle: Text(
                _inventoryUnit.isEmpty ? '尚未選擇' : '單位：$_inventoryUnit',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
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
                if (selected == null) {
                  return;
                }
                setState(() {
                  _inventoryItemId = selected.id;
                  _inventoryItemName = selected.name;
                  _inventoryUnit = selected.unit;
                });
              },
            ),
            TextField(
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '每售出 1 件扣除數量',
                suffixText: _inventoryUnit.isEmpty ? null : _inventoryUnit,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }
}

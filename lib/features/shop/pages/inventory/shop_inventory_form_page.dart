// lib/features/shop/pages/inventory/shop_inventory_form_page.dart
// 📦 庫存品項新增／編輯頁
// 功能：維護品項主檔與代表圖。currentStock 不可在此直接覆蓋，需透過進貨、出庫或盤點。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_pick_flow.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_spec_hint.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';

class ShopInventoryFormPage extends StatefulWidget {
  const ShopInventoryFormPage({super.key, required this.shopId, this.item});

  final String shopId;
  final InventoryItemModel? item;

  @override
  State<ShopInventoryFormPage> createState() => _ShopInventoryFormPageState();
}

class _ShopInventoryFormPageState extends State<ShopInventoryFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _skuController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _unitController;
  late final TextEditingController _safetyStockController;
  late bool _allowDecimal;
  late bool _enabled;
  late final String _legacyCategory;
  String? _selectedCategory;
  Uint8List? _selectedImageBytes;
  bool _removeExistingImage = false;
  bool _selectingImage = false;
  bool _saving = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final InventoryItemModel? item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _skuController = TextEditingController(text: item?.sku ?? '');
    _barcodeController = TextEditingController(text: item?.barcode ?? '');
    _unitController = TextEditingController(text: item?.unit ?? '個');
    _safetyStockController = TextEditingController(
      text: item == null ? '0' : item.safetyStock.toString(),
    );
    _allowDecimal = item?.allowDecimal ?? true;
    _enabled = item?.enabled ?? true;
    _legacyCategory = (item?.category ?? '').trim();
    _selectedCategory = _legacyCategory.isEmpty ? null : _legacyCategory;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
    _safetyStockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectingImage || _saving) {
      return;
    }

    setState(() => _selectingImage = true);

    try {
      final Uint8List? cropped = await FixedImagePickFlow.pickAndCrop(
        context: context,
        spec: FixedImageSpec.inventoryItem,
        title: '裁切庫存品項圖片',
      );

      if (cropped == null || !mounted) {
        return;
      }

      setState(() {
        _selectedImageBytes = cropped;
        _removeExistingImage = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(InventoryException.userMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _selectingImage = false);
      }
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImageBytes = null;
      _removeExistingImage = true;
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true || _saving) {
      return;
    }

    setState(() => _saving = true);

    try {
      final num safetyStock =
          num.tryParse(_safetyStockController.text.trim()) ?? 0;
      final String itemId;
      bool createdNewItem = false;

      if (_isEditing) {
        itemId = widget.item!.id;
        await InventoryService.instance.updateItem(
          shopId: widget.shopId,
          itemId: itemId,
          name: _nameController.text,
          description: _descriptionController.text,
          category: _selectedCategory ?? '',
          sku: _skuController.text,
          barcode: _barcodeController.text,
          unit: _unitController.text,
          safetyStock: safetyStock,
          allowDecimal: _allowDecimal,
          enabled: _enabled,
        );
      } else {
        itemId = await InventoryService.instance.createItem(
          shopId: widget.shopId,
          name: _nameController.text,
          description: _descriptionController.text,
          category: _selectedCategory ?? '',
          sku: _skuController.text,
          barcode: _barcodeController.text,
          unit: _unitController.text,
          safetyStock: safetyStock,
          allowDecimal: _allowDecimal,
          enabled: _enabled,
        );
        createdNewItem = true;
      }

      try {
        await _saveCoverImage(itemId);
      } catch (error) {
        if (createdNewItem && mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '品項已建立，但圖片上傳失敗：${InventoryException.userMessage(error)}',
              ),
            ),
          );
          return;
        }

        rethrow;
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? '已更新庫存品項' : '已新增庫存品項')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(InventoryException.userMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveCoverImage(String itemId) async {
    final InventoryItemModel? existing = widget.item;
    final Uint8List? selectedBytes = _selectedImageBytes;

    if (selectedBytes != null) {
      final InventoryImageUploadResult uploaded = await InventoryImageService
          .instance
          .uploadBytes(
            shopId: widget.shopId,
            itemId: itemId,
            bytes: selectedBytes,
          );

      try {
        await InventoryService.instance.updateItemCover(
          shopId: widget.shopId,
          itemId: itemId,
          imageUrl: uploaded.imageUrl,
          imageStoragePath: uploaded.imageStoragePath,
        );
      } catch (error) {
        await InventoryImageService.instance.tryDeleteImage(
          imageUrl: uploaded.imageUrl,
          imageStoragePath: uploaded.imageStoragePath,
        );
        rethrow;
      }

      final String oldPath = existing?.imageStoragePath ?? '';
      if (oldPath.isNotEmpty && oldPath != uploaded.imageStoragePath) {
        await InventoryImageService.instance.tryDeleteImage(
          imageUrl: existing?.imageUrl ?? '',
          imageStoragePath: oldPath,
        );
      }
      return;
    }

    if (_isEditing && _removeExistingImage && existing != null) {
      await InventoryService.instance.clearItemCover(
        shopId: widget.shopId,
        itemId: itemId,
      );
      await InventoryImageService.instance.tryDeleteImage(
        imageUrl: existing.imageUrl,
        imageStoragePath: existing.imageStoragePath,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '編輯庫存品項' : '新增庫存品項')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (_isEditing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('目前庫存不可在此直接修改。請使用進貨、手動出庫或盤點調整。'),
              ),
            _buildImagePicker(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '品項名稱',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                if ((value ?? '').trim().isEmpty) {
                  return '請輸入品項名稱';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '說明',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory ?? '',
              decoration: const InputDecoration(
                labelText: '分類',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text(InventoryConstants.categoryUnspecifiedLabel),
                ),
                ...InventoryConstants.categoryDropdownOptions(
                  _legacyCategory,
                ).map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }),
              ],
              onChanged: (String? value) {
                setState(() {
                  _selectedCategory = (value == null || value.isEmpty)
                      ? null
                      : value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _skuController,
              decoration: const InputDecoration(
                labelText: 'SKU',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcodeController,
              decoration: const InputDecoration(
                labelText: '條碼',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: '單位',
                hintText: '例如：包、罐、個',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _safetyStockController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '安全庫存',
                helperText: '庫存低於或等於此數量時顯示低庫存',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('允許小數數量'),
              subtitle: const Text('例如每房每晚扣除 0.5 包貓砂'),
              value: _allowDecimal,
              onChanged: (bool value) {
                setState(() => _allowDecimal = value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('啟用'),
              subtitle: const Text('停用後不可再被新功能選取，歷史紀錄仍可顯示'),
              value: _enabled,
              onChanged: (bool value) {
                setState(() => _enabled = value);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '儲存中...' : '儲存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final Uint8List? selectedBytes = _selectedImageBytes;
    final String existingImageUrl = _removeExistingImage
        ? ''
        : (widget.item?.imageUrl ?? '').trim();
    final bool hasSelectedImage = selectedBytes != null;
    final bool hasExistingImage = existingImageUrl.isNotEmpty;
    final bool hasImage = hasSelectedImage || hasExistingImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '品項圖片',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const FixedImageSpecHint(spec: FixedImageSpec.inventoryItem),
        if (hasImage)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 160, maxHeight: 240),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasSelectedImage
                ? Image.memory(selectedBytes, fit: BoxFit.contain)
                : Image.network(
                    existingImageUrl,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return const Center(child: Text('原圖片載入失敗'));
                        },
                  ),
          )
        else
          Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.inventory_2_outlined, size: 40),
                SizedBox(height: 8),
                Text('尚未選擇品項圖片'),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed: _selectingImage || _saving ? null : _pickImage,
              icon: _selectingImage
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined),
              label: Text(hasImage ? '更換圖片' : '選擇圖片'),
            ),
            if (hasImage)
              OutlinedButton.icon(
                onPressed: _selectingImage || _saving ? null : _clearImage,
                icon: const Icon(Icons.delete_outline),
                label: const Text('刪除圖片'),
              ),
          ],
        ),
      ],
    );
  }
}

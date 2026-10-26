// 檔案名稱：lib/features/shop/pages/inventory/shop_inventory_form_page.dart
// 功能說明：維護品項主檔與代表圖。currentStock 不可在此直接覆蓋，需透過進貨、出庫或盤點。
// 📦 庫存品項新增／編輯頁

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
    if (_saving ||
        _selectingImage ||
        _formKey.currentState?.validate() != true) {
      return;
    }

    FocusScope.of(context).unfocus();
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
    final busy = _saving || _selectingImage;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        appBar: AppBar(title: Text(_isEditing ? '編輯庫存品項' : '新增庫存品項')),
        bottomNavigationBar: _buildSaveBar(busy),
        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: AbsorbPointer(
            absorbing: _saving,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 800;
                    final details = Column(
                      children: [
                        _buildBasicInfo(),
                        const SizedBox(height: 16),
                        _buildStockSettings(),
                      ],
                    );
                    final image = _section(
                      title: '品項圖片',
                      icon: Icons.photo_library_outlined,
                      subtitle: '選填，方便在庫存列表辨識用品',
                      child: _buildImagePicker(),
                    );
                    return ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.all(wide ? 24 : 16),
                      children: [
                        Text(
                          _isEditing ? '更新品項資料' : '建立新的庫存品項',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '填寫品項名稱與計量單位，再設定庫存提醒。標示 * 為必填。',
                          style: TextStyle(
                            color: Color(0xFF667085),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: details),
                              const SizedBox(width: 20),
                              SizedBox(width: 280, child: image),
                            ],
                          )
                        else ...[
                          details,
                          const SizedBox(height: 16),
                          image,
                        ],
                        const SizedBox(height: 16),
                        _buildStockNotice(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, {String? hint, String? helper}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        errorMaxLines: 2,
        border: const OutlineInputBorder(),
      );

  Widget _buildBasicInfo() => _section(
    title: '基本資料',
    subtitle: '清楚命名，方便搜尋與分類管理',
    icon: Icons.inventory_2_outlined,
    child: Column(
      children: [
        TextFormField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          decoration: _decoration('品項名稱 *', hint: '例如：豆腐砂 6L、主食罐 80g'),
          validator: (value) => (value ?? '').trim().isEmpty ? '請輸入品項名稱' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategory ?? '',
          isExpanded: true,
          decoration: _decoration('分類', helper: '選填，可依用品類型整理'),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text(InventoryConstants.categoryUnspecifiedLabel),
            ),
            ...InventoryConstants.categoryDropdownOptions(_legacyCategory).map(
              (category) => DropdownMenuItem(
                value: category,
                child: Text(category, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (value) => setState(
            () => _selectedCategory = (value == null || value.isEmpty)
                ? null
                : value,
          ),
        ),
        const SizedBox(height: 16),
        _fieldPair(
          TextFormField(
            controller: _skuController,
            textInputAction: TextInputAction.next,
            decoration: _decoration(
              '品項編號（SKU）',
              hint: '例如：CAT-LITTER-001',
              helper: '選填，店內使用的識別編號',
            ),
          ),
          TextFormField(
            controller: _barcodeController,
            textInputAction: TextInputAction.next,
            decoration: _decoration(
              '條碼',
              hint: '輸入商品條碼',
              helper: '選填，保留條碼開頭的 0',
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          minLines: 2,
          maxLines: 4,
          decoration: _decoration('品項說明', hint: '選填，例如品牌、規格或保存注意事項'),
        ),
      ],
    ),
  );

  Widget _buildStockSettings() => _section(
    title: '庫存設定',
    subtitle: '設定計量方式與補貨提醒',
    icon: Icons.tune,
    child: Column(
      children: [
        _fieldPair(
          TextFormField(
            controller: _unitController,
            textInputAction: TextInputAction.next,
            decoration: _decoration(
              '計量單位 *',
              hint: '例如：包、罐、瓶、個',
              helper: '進貨、出庫與耗材共用此單位',
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? '請輸入計量單位' : null,
          ),
          TextFormField(
            controller: _safetyStockController,
            textInputAction: TextInputAction.done,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration(
              '安全庫存 *',
              hint: '例如：5',
              helper: '0 表示不設低庫存門檻；缺貨仍會提醒',
            ),
            validator: (value) {
              final quantity = num.tryParse((value ?? '').trim());
              if (quantity == null || !quantity.isFinite) return '請輸入有效數字';
              if (quantity < 0) return '安全庫存不可為負數';
              return null;
            },
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '存量低於或等於安全庫存時，系統會顯示低庫存提醒。',
          style: TextStyle(fontSize: 12, color: Color(0xFF667085), height: 1.5),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('允許小數用量'),
          subtitle: const Text('適合分裝用品，例如每房每晚使用 0.5 包貓砂'),
          value: _allowDecimal,
          onChanged: (value) => setState(() => _allowDecimal = value),
        ),
        const Divider(height: 1),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('啟用品項'),
          subtitle: const Text('停用後無法供新設定選取，歷史紀錄仍會保留'),
          value: _enabled,
          onChanged: (value) => setState(() => _enabled = value),
        ),
      ],
    ),
  );

  Widget _fieldPair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 460) {
        return Column(children: [first, const SizedBox(height: 16), second]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 16),
          Expanded(child: second),
        ],
      );
    },
  );

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE4E7EC)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF667085),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );

  Widget _buildStockNotice() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _isEditing
                ? '此頁只更新品項資料。調整現有存量，請使用進貨、出庫或盤點。'
                : '新建品項的存量為 0。儲存後，請至品項頁使用「進貨」登錄實際數量。',
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
      ],
    ),
  );

  Widget _buildSaveBar(bool busy) => Material(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE4E7EC))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1072),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => Navigator.maybePop(context),
                  child: const Text('取消'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: busy ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(
                    _saving ? '儲存中…' : (_isEditing ? '儲存變更' : '建立品項'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

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
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0E5ED)),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasSelectedImage
                ? Image.memory(selectedBytes, fit: BoxFit.contain)
                : hasExistingImage
                ? Image.network(
                    existingImageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text(
                        '原圖片載入失敗，可重新選擇圖片',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 40,
                        color: Color(0xFF65749B),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '尚未選擇品項圖片',
                        style: TextStyle(color: Color(0xFF667085)),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        const Text(
          '建議使用正方形圖片，選擇後可裁切。',
          style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF667085)),
        ),
        const ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text('查看圖片規格', style: TextStyle(fontSize: 12)),
          children: [FixedImageSpecHint(spec: FixedImageSpec.inventoryItem)],
        ),
      ],
    );
  }
}

// lib/features/admin/pages/admin_point_reward_form_page.dart
// 🎁 後台點數兌換商品新增／編輯頁
// 功能：建立優惠券型點數兌換商品，
// 並綁定既有優惠券模板、設定點數、兌換限制與上架狀態。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/coupon_template_model.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/models/point_reward_model.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/core/services/point_reward_service.dart';
import 'package:petnest_saas/core/services/point_reward_image_service.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_item_picker_page.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_item_cover.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_status_chip.dart';
import 'admin_coupon_template_picker_page.dart';

class AdminPointRewardFormPage extends StatefulWidget {
  const AdminPointRewardFormPage({
    super.key,
    required this.shopId,
    this.reward,
  });

  final String shopId;

  /// 有傳入代表編輯模式，沒有傳入代表新增模式。
  final PointRewardModel? reward;

  @override
  State<AdminPointRewardFormPage> createState() =>
      _AdminPointRewardFormPageState();
}

class _AdminPointRewardFormPageState extends State<AdminPointRewardFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _pointsCostController;
  late final TextEditingController _memberLimitController;
  late final TextEditingController _totalLimitController;
  late final TextEditingController _sortOrderController;
  late final TextEditingController _stockQuantityController;
  late final TextEditingController _fulfillmentNoteController;

  CouponTemplateModel? _selectedTemplate;

  String _selectedTemplateId = '';

  bool _enabled = true;
  bool _saving = false;
  late PointRewardFulfillmentType _fulfillmentType;
  bool _useCentralInventory = false;
  String _inventoryItemId = '';
  String _inventoryItemName = '';
  String _inventoryUnit = '';
  InventoryItemModel? _selectedInventoryItem;
  String _importedInventoryImageUrl = '';
  bool _didPrefillFromInventory = false;
  late final TextEditingController _inventoryQuantityController;
  XFile? _selectedProductImage;
  bool _removeExistingProductImage = false;
  bool _selectingImage = false;
  bool _requiresStaffVerification = true;
  bool get _isEditing => widget.reward != null;

  @override
  void initState() {
    super.initState();

    final PointRewardModel? reward = widget.reward;

    _nameController = TextEditingController(text: reward?.name ?? '');

    _descriptionController = TextEditingController(
      text: reward?.description ?? '',
    );

    _pointsCostController = TextEditingController(
      text: reward == null ? '' : reward.pointsCost.toString(),
    );

    _memberLimitController = TextEditingController(
      text: reward == null ? '0' : reward.exchangeLimitPerMember.toString(),
    );

    _totalLimitController = TextEditingController(
      text: reward == null ? '0' : reward.totalExchangeLimit.toString(),
    );

    _sortOrderController = TextEditingController(
      text: reward == null ? '0' : reward.sortOrder.toString(),
    );

    _stockQuantityController = TextEditingController(
      text: reward == null ? '0' : reward.stockQuantity.toString(),
    );

    _fulfillmentNoteController = TextEditingController(
      text: reward?.fulfillmentNote ?? '',
    );

    _selectedTemplateId = reward?.couponTemplateId ?? '';
    _enabled = reward?.enabled ?? true;
    _fulfillmentType =
        reward?.fulfillmentType ?? PointRewardFulfillmentType.coupon;
    _useCentralInventory = reward?.useCentralInventory ?? false;
    _inventoryItemId = reward?.inventoryItemId ?? '';
    _inventoryItemName = reward?.inventoryItemName ?? '';
    _inventoryUnit = reward?.inventoryUnit ?? '';
    _didPrefillFromInventory = _inventoryItemId.trim().isNotEmpty;
    _inventoryQuantityController = TextEditingController(
      text: reward == null
          ? '1'
          : reward.inventoryQuantityPerExchange.toString(),
    );
    _requiresStaffVerification = reward?.requiresStaffVerification ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pointsCostController.dispose();
    _memberLimitController.dispose();
    _totalLimitController.dispose();
    _sortOrderController.dispose();
    _stockQuantityController.dispose();
    _fulfillmentNoteController.dispose();
    _inventoryQuantityController.dispose();

    super.dispose();
  }

  Future<void> _selectCouponTemplate() async {
    final CouponTemplateModel? template = await Navigator.of(context)
        .push<CouponTemplateModel>(
          MaterialPageRoute<CouponTemplateModel>(
            builder: (BuildContext context) {
              return AdminCouponTemplatePickerPage(
                shopId: widget.shopId,
                selectedTemplateId: _selectedTemplateId,
              );
            },
          ),
        );

    if (template == null || !mounted) {
      return;
    }

    setState(() {
      _selectedTemplate = template;
      _selectedTemplateId = template.id;

      if (_nameController.text.trim().isEmpty) {
        _nameController.text = template.name;
      }

      if (_descriptionController.text.trim().isEmpty) {
        _descriptionController.text = template.description;
      }
    });
  }

  Future<void> _selectProductImage() async {
    if (_selectingImage || _saving) {
      return;
    }

    setState(() {
      _selectingImage = true;
    });

    try {
      final XFile? selectedImage = await PointRewardImageService.instance
          .pickAndValidateImage();

      if (selectedImage == null || !mounted) {
        return;
      }

      setState(() {
        _selectedProductImage = selectedImage;
        _removeExistingProductImage = false;
      });
    } on PointRewardImageException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('選擇圖片失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _selectingImage = false;
        });
      }
    }
  }

  void _removeProductImage() {
    if (_saving) {
      return;
    }

    setState(() {
      _selectedProductImage = null;
      _removeExistingProductImage = true;
      _importedInventoryImageUrl = '';
    });
  }

  String _networkPreviewImageUrl() {
    if (_removeExistingProductImage) {
      return '';
    }

    final String importedImageUrl = _importedInventoryImageUrl.trim();
    if (importedImageUrl.isNotEmpty) {
      return importedImageUrl;
    }

    return (widget.reward?.imageUrl ?? '').trim();
  }

  String _inventoryUnitLabel([String? unit]) {
    final String normalized = (unit ?? _inventoryUnit).trim();
    return normalized.isEmpty ? '個' : normalized;
  }

  Future<void> _selectCentralInventoryItem() async {
    if (_saving) {
      return;
    }

    final InventoryItemModel? selected = await Navigator.of(context)
        .push<InventoryItemModel>(
          MaterialPageRoute<InventoryItemModel>(
            builder: (BuildContext context) {
              return ShopInventoryItemPickerPage(
                shopId: widget.shopId,
                selectedItemId: _inventoryItemId,
              );
            },
          ),
        );

    if (selected == null || !mounted) {
      return;
    }

    final bool shouldPrefill = !_didPrefillFromInventory;

    setState(() {
      _useCentralInventory = true;
      _inventoryItemId = selected.id;
      _inventoryItemName = selected.name;
      _inventoryUnit = selected.unit;
      _selectedInventoryItem = selected;

      if (!shouldPrefill) {
        return;
      }

      _didPrefillFromInventory = true;
      _nameController.text = selected.name;
      _descriptionController.text = selected.description;

      final String inventoryImageUrl = selected.imageUrl.trim();
      if (inventoryImageUrl.isNotEmpty && _selectedProductImage == null) {
        _importedInventoryImageUrl = inventoryImageUrl;
        _removeExistingProductImage = false;
      }
    });
  }

  Future<void> _saveReward() async {
    if (_saving) {
      return;
    }

    final FormState? form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    final bool isCouponReward =
        _fulfillmentType == PointRewardFulfillmentType.coupon;

    final bool isPhysicalProduct =
        _fulfillmentType == PointRewardFulfillmentType.physicalProduct;

    if (isCouponReward && _selectedTemplateId.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先選擇優惠券模板')));
      return;
    }

    if (isPhysicalProduct && _useCentralInventory && _inventoryItemId.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇中央庫存品項')));
      return;
    }

    final CouponTemplateModel? template = _selectedTemplate;
    final PointRewardModel? currentReward = widget.reward;

    if (isCouponReward && !_isEditing && template == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('無法取得優惠券模板內容，請重新選擇')));
      return;
    }

    final int pointsCost = int.tryParse(_pointsCostController.text.trim()) ?? 0;

    final int exchangeLimitPerMember =
        int.tryParse(_memberLimitController.text.trim()) ?? 0;

    final int totalExchangeLimit =
        int.tryParse(_totalLimitController.text.trim()) ?? 0;

    final int sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;

    final int stockQuantity =
        int.tryParse(_stockQuantityController.text.trim()) ?? 0;
    final num inventoryQuantity =
        num.tryParse(_inventoryQuantityController.text.trim()) ?? 1;

    final MemberCouponType couponType =
        template?.type ??
        currentReward?.couponType ??
        MemberCouponType.fixedAmount;

    final MemberCouponApplyTarget applyTarget =
        template?.applyTarget ??
        currentReward?.applyTarget ??
        MemberCouponApplyTarget.total;

    final num discountValue =
        template?.discountValue ?? currentReward?.discountValue ?? 0;

    final int minimumAmount =
        template?.minimumAmount ?? currentReward?.minimumAmount ?? 0;

    final int maximumDiscountAmount =
        template?.maximumDiscountAmount ??
        currentReward?.maximumDiscountAmount ??
        0;

    final int freeStayNights =
        template?.freeStayNights ?? currentReward?.freeStayNights ?? 0;

    final String serviceId =
        template?.serviceId ?? currentReward?.serviceId ?? '';

    final String serviceName =
        template?.serviceName ?? currentReward?.serviceName ?? '';

    final List<String> roomTypeIds =
        template?.roomTypeIds ?? currentReward?.roomTypeIds ?? const <String>[];

    final int validDays = template?.validDays ?? currentReward?.validDays ?? 30;

    final int usageLimit =
        template?.usageLimit ?? currentReward?.usageLimit ?? 1;

    setState(() {
      _saving = true;
    });

    String? createdRewardId;
    String uploadedImageUrl = '';

    try {
      if (_isEditing) {
        final String oldImageUrl = currentReward!.imageUrl.trim();
        String finalImageUrl = '';

        if (isPhysicalProduct && !_removeExistingProductImage) {
          final String importedImageUrl = _importedInventoryImageUrl.trim();
          finalImageUrl = importedImageUrl.isNotEmpty
              ? importedImageUrl
              : oldImageUrl;
        }

        if (isPhysicalProduct && _selectedProductImage != null) {
          uploadedImageUrl = await PointRewardImageService.instance.uploadImage(
            shopId: widget.shopId,
            rewardId: currentReward.id,
            image: _selectedProductImage!,
          );
          finalImageUrl = uploadedImageUrl;
        }

        await PointRewardService.instance.updateReward(
          shopId: widget.shopId,
          rewardId: currentReward.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          pointsCost: pointsCost,
          fulfillmentType: _fulfillmentType,
          couponTemplateId: isCouponReward ? _selectedTemplateId : '',
          imageUrl: finalImageUrl,
          stockQuantity: isPhysicalProduct ? stockQuantity : 0,
          useCentralInventory:
              isPhysicalProduct && _useCentralInventory,
          inventoryItemId: isPhysicalProduct && _useCentralInventory
              ? _inventoryItemId
              : '',
          inventoryItemName: isPhysicalProduct && _useCentralInventory
              ? _inventoryItemName
              : '',
          inventoryUnit: isPhysicalProduct && _useCentralInventory
              ? _inventoryUnit
              : '',
          inventoryQuantityPerExchange:
              isPhysicalProduct && _useCentralInventory
              ? inventoryQuantity
              : 1,
          fulfillmentNote: isPhysicalProduct
              ? _fulfillmentNoteController.text.trim()
              : '',
          requiresStaffVerification:
              isPhysicalProduct && _requiresStaffVerification,
          couponType: couponType,
          applyTarget: applyTarget,
          discountValue: discountValue,
          minimumAmount: minimumAmount,
          maximumDiscountAmount: maximumDiscountAmount,
          freeStayNights: freeStayNights,
          serviceId: serviceId,
          serviceName: serviceName,
          roomTypeIds: roomTypeIds,
          validDays: validDays,
          usageLimit: usageLimit,
          exchangeLimitPerMember: exchangeLimitPerMember,
          totalExchangeLimit: totalExchangeLimit,
          enabled: _enabled,
          sortOrder: sortOrder,
        );

        final bool oldImageShouldBeDeleted =
            oldImageUrl.isNotEmpty &&
            (finalImageUrl.isEmpty ||
                (uploadedImageUrl.isNotEmpty &&
                    uploadedImageUrl != oldImageUrl));

        if (oldImageShouldBeDeleted) {
          await PointRewardImageService.instance.tryDeleteImageByUrl(
            oldImageUrl,
          );
        }
      } else {
        final String importedImageUrl =
            isPhysicalProduct &&
                _selectedProductImage == null &&
                !_removeExistingProductImage
            ? _importedInventoryImageUrl.trim()
            : '';

        createdRewardId = await PointRewardService.instance.createReward(
          shopId: widget.shopId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          pointsCost: pointsCost,
          fulfillmentType: _fulfillmentType,
          couponTemplateId: isCouponReward ? _selectedTemplateId : '',
          imageUrl: importedImageUrl,
          stockQuantity: isPhysicalProduct ? stockQuantity : 0,
          useCentralInventory:
              isPhysicalProduct && _useCentralInventory,
          inventoryItemId: isPhysicalProduct && _useCentralInventory
              ? _inventoryItemId
              : '',
          inventoryItemName: isPhysicalProduct && _useCentralInventory
              ? _inventoryItemName
              : '',
          inventoryUnit: isPhysicalProduct && _useCentralInventory
              ? _inventoryUnit
              : '',
          inventoryQuantityPerExchange:
              isPhysicalProduct && _useCentralInventory
              ? inventoryQuantity
              : 1,
          fulfillmentNote: isPhysicalProduct
              ? _fulfillmentNoteController.text.trim()
              : '',
          requiresStaffVerification:
              isPhysicalProduct && _requiresStaffVerification,
          couponType: couponType,
          applyTarget: applyTarget,
          discountValue: discountValue,
          minimumAmount: minimumAmount,
          maximumDiscountAmount: maximumDiscountAmount,
          freeStayNights: freeStayNights,
          serviceId: serviceId,
          serviceName: serviceName,
          roomTypeIds: roomTypeIds,
          validDays: validDays,
          usageLimit: usageLimit,
          exchangeLimitPerMember: exchangeLimitPerMember,
          totalExchangeLimit: totalExchangeLimit,
          enabled: _enabled,
          sortOrder: sortOrder,
        );

        if (isPhysicalProduct && _selectedProductImage != null) {
          uploadedImageUrl = await PointRewardImageService.instance.uploadImage(
            shopId: widget.shopId,
            rewardId: createdRewardId,
            image: _selectedProductImage!,
          );

          await PointRewardService.instance.updateReward(
            shopId: widget.shopId,
            rewardId: createdRewardId,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            pointsCost: pointsCost,
            fulfillmentType: _fulfillmentType,
            couponTemplateId: isCouponReward ? _selectedTemplateId : '',
            imageUrl: uploadedImageUrl,
            stockQuantity: stockQuantity,
            useCentralInventory:
                isPhysicalProduct && _useCentralInventory,
            inventoryItemId: isPhysicalProduct && _useCentralInventory
                ? _inventoryItemId
                : '',
            inventoryItemName: isPhysicalProduct && _useCentralInventory
                ? _inventoryItemName
                : '',
            inventoryUnit: isPhysicalProduct && _useCentralInventory
                ? _inventoryUnit
                : '',
            inventoryQuantityPerExchange:
                isPhysicalProduct && _useCentralInventory
                ? inventoryQuantity
                : 1,
            fulfillmentNote: _fulfillmentNoteController.text.trim(),
            requiresStaffVerification: _requiresStaffVerification,
            couponType: couponType,
            applyTarget: applyTarget,
            discountValue: discountValue,
            minimumAmount: minimumAmount,
            maximumDiscountAmount: maximumDiscountAmount,
            freeStayNights: freeStayNights,
            serviceId: serviceId,
            serviceName: serviceName,
            roomTypeIds: roomTypeIds,
            validDays: validDays,
            usageLimit: usageLimit,
            exchangeLimitPerMember: exchangeLimitPerMember,
            totalExchangeLimit: totalExchangeLimit,
            enabled: _enabled,
            sortOrder: sortOrder,
          );
        }
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? '點數兌換商品已更新' : '點數兌換商品已建立')),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!_isEditing && createdRewardId != null) {
        if (uploadedImageUrl.isNotEmpty) {
          await PointRewardImageService.instance.tryDeleteImageByUrl(
            uploadedImageUrl,
          );
        }

        try {
          await PointRewardService.instance.deleteReward(
            shopId: widget.shopId,
            rewardId: createdRewardId,
          );
        } catch (_) {
          // 建立失敗時盡力清理尚未完成的商品資料。
        }
      } else if (_isEditing && uploadedImageUrl.isNotEmpty) {
        final String oldImageUrl = currentReward?.imageUrl.trim() ?? '';

        if (uploadedImageUrl != oldImageUrl) {
          await PointRewardImageService.instance.tryDeleteImageByUrl(
            uploadedImageUrl,
          );
        }
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: Text(_isEditing ? '編輯點數兌換商品' : '建立點數兌換商品')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: <Widget>[
            _buildBasicSection(),
            const SizedBox(height: 16),

            _buildFulfillmentTypeSection(),

            const SizedBox(height: 16),

            if (_fulfillmentType == PointRewardFulfillmentType.coupon)
              _buildCouponTemplateSection(),

            if (_fulfillmentType == PointRewardFulfillmentType.physicalProduct)
              _buildPhysicalProductSection(),
            const SizedBox(height: 16),
            _buildExchangeLimitSection(),
            const SizedBox(height: 16),
            _buildPublishSection(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(
                blurRadius: 12,
                offset: Offset(0, -2),
                color: Color(0x14000000),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: _saving ? null : _saveReward,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving
                  ? '儲存中'
                  : _isEditing
                  ? '儲存修改'
                  : '建立商品',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicSection() {
    return _SectionCard(
      title: '基本資料',
      children: <Widget>[
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '商品名稱',
            hintText: '例如：1000 點兌換免費住宿券',
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
          validator: (String? value) {
            if ((value ?? '').trim().isEmpty) {
              return '請輸入商品名稱';
            }

            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: '商品說明',
            hintText: '顯示給會員查看的兌換說明',
            border: OutlineInputBorder(),
          ),
          minLines: 3,
          maxLines: 5,
          maxLength: 300,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _pointsCostController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '需要點數',
            hintText: '例如：1000',
            suffixText: '點',
            border: OutlineInputBorder(),
          ),
          validator: (String? value) {
            final int? points = int.tryParse((value ?? '').trim());

            if (points == null || points <= 0) {
              return '兌換點數必須大於 0';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFulfillmentTypeSection() {
    return _SectionCard(
      title: '商品類型',
      children: <Widget>[
        RadioListTile<PointRewardFulfillmentType>(
          title: const Text('優惠券'),
          subtitle: const Text('兌換後立即發送優惠券'),
          value: PointRewardFulfillmentType.coupon,
          groupValue: _fulfillmentType,
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _fulfillmentType = value;
            });
          },
        ),
        RadioListTile<PointRewardFulfillmentType>(
          title: const Text('實體商品'),
          subtitle: const Text('店員到店核銷後領取'),
          value: PointRewardFulfillmentType.physicalProduct,
          groupValue: _fulfillmentType,
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _fulfillmentType = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildProductImagePicker() {
    final XFile? selectedImage = _selectedProductImage;

    final String existingImageUrl = _networkPreviewImageUrl();

    final bool hasSelectedImage = selectedImage != null;
    final bool hasExistingImage = existingImageUrl.isNotEmpty;
    final bool hasImage = hasSelectedImage || hasExistingImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '商品圖片',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          '僅支援 JPG、JPEG、PNG、WEBP，單張最大 5 MB',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (hasImage)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 180, maxHeight: 280),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasSelectedImage
                ? FutureBuilder<Uint8List>(
                    future: selectedImage.readAsBytes(),
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<Uint8List> snapshot,
                        ) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Text('無法預覽圖片'));
                          }

                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (
                                  BuildContext context,
                                  Object error,
                                  StackTrace? stackTrace,
                                ) {
                                  return const Center(child: Text('無法預覽圖片'));
                                },
                          );
                        },
                  )
                : Image.network(
                    existingImageUrl,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return const Center(child: Text('原商品圖片載入失敗'));
                        },
                  ),
          )
        else
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.add_photo_alternate_outlined, size: 48),
                SizedBox(height: 8),
                Text('尚未選擇商品圖片'),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.icon(
              onPressed: _selectingImage || _saving
                  ? null
                  : _selectProductImage,
              icon: _selectingImage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined),
              label: Text(hasImage ? '更換圖片' : '選擇圖片'),
            ),
            if (hasImage)
              OutlinedButton.icon(
                onPressed: _selectingImage || _saving
                    ? null
                    : _removeProductImage,
                icon: const Icon(Icons.delete_outline),
                label: const Text('移除圖片'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhysicalProductSection() {
    return _SectionCard(
      title: '實體商品設定',
      children: <Widget>[
        _buildProductImagePicker(),
        const SizedBox(height: 16),
        RadioListTile<bool>(
          contentPadding: EdgeInsets.zero,
          title: const Text('自行管理兌換數量'),
          subtitle: const Text('由此兌換商品自行設定可兌換數量，不會連動中央庫存。'),
          value: false,
          groupValue: _useCentralInventory,
          onChanged: (bool? value) {
            setState(() {
              _useCentralInventory = value ?? false;
            });
          },
        ),
        RadioListTile<bool>(
          contentPadding: EdgeInsets.zero,
          title: const Text('使用中央庫存品項'),
          subtitle: const Text('連動中央庫存，兌換成功時會自動扣除指定庫存品項。'),
          value: true,
          groupValue: _useCentralInventory,
          onChanged: (bool? value) {
            setState(() {
              _useCentralInventory = value ?? false;
            });
          },
        ),
        if (_useCentralInventory) ...<Widget>[
          _buildCentralInventorySelector(),
        ] else ...<Widget>[
          TextFormField(
            controller: _stockQuantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '可兌換數量',
              helperText: '輸入 0 代表不限兌換數量。',
              suffixText: '份',
              border: OutlineInputBorder(),
            ),
            validator: (String? value) {
              if (_fulfillmentType !=
                      PointRewardFulfillmentType.physicalProduct ||
                  _useCentralInventory) {
                return null;
              }

              final int? stock = int.tryParse((value ?? '').trim());

              if (stock == null || stock < 0) {
                return '請輸入 0 或大於 0 的整數';
              }

              return null;
            },
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: _fulfillmentNoteController,
          decoration: const InputDecoration(
            labelText: '領取說明',
            hintText: '例如：請至櫃檯出示領取碼，由店員確認後領取',
            border: OutlineInputBorder(),
          ),
          minLines: 3,
          maxLines: 5,
          maxLength: 300,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('需要店員核銷'),
          subtitle: const Text('會員出示領取碼後，由店員確認商品已交付'),
          value: _requiresStaffVerification,
          onChanged: (bool value) {
            setState(() {
              _requiresStaffVerification = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCentralInventorySelector() {
    return StreamBuilder<InventoryItemModel?>(
      stream: InventoryService.instance.streamItem(
        shopId: widget.shopId,
        itemId: _inventoryItemId,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<InventoryItemModel?> snapshot,
          ) {
            final InventoryItemModel? item =
                snapshot.data ?? _selectedInventoryItem;
            final bool hasSelection = _inventoryItemId.trim().isNotEmpty;
            final String displayName =
                (item?.name ?? _inventoryItemName).trim().isEmpty
                ? '未命名品項'
                : (item?.name ?? _inventoryItemName).trim();
            final String unit = _inventoryUnitLabel(item?.unit);
            final String stockText = item == null
                ? ''
                : '目前庫存 ${InventoryConstants.formatQuantity(item.currentStock)} $unit';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _selectCentralInventoryItem,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: <Widget>[
                        if (hasSelection && item != null) ...<Widget>[
                          InventoryItemCover(
                            item: item,
                            size: 48,
                            borderRadius: 10,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '中央庫存品項',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (!hasSelection)
                                Text(
                                  '尚未選擇',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                )
                              else ...<Widget>[
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (stockText.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(
                                    stockText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                                if (item != null) ...<Widget>[
                                  const SizedBox(height: 6),
                                  InventoryStatusChip(item: item),
                                ],
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey.shade500,
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasSelection) ...<Widget>[
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '目前中央庫存',
                      border: OutlineInputBorder(),
                      enabled: false,
                    ),
                    child: Text(
                      item == null
                          ? '載入中…'
                          : '${InventoryConstants.formatQuantity(item.currentStock)} $unit',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _inventoryQuantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '每次兌換扣除',
                      helperText: '實際可兌換數量依中央庫存為準。',
                      suffixText: unit,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            );
          },
    );
  }

  Widget _buildCouponTemplateSection() {
    final CouponTemplateModel? template = _selectedTemplate;

    return _SectionCard(
      title: '優惠券模板',
      children: <Widget>[
        if (_selectedTemplateId.isEmpty)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _selectCouponTemplate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Column(
                children: <Widget>[
                  Icon(Icons.confirmation_number_outlined, size: 42),
                  SizedBox(height: 8),
                  Text(
                    '尚未選擇優惠券模板',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('點擊選擇已建立的優惠券'),
                ],
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        template?.name ?? widget.reward?.name ?? '已綁定優惠券模板',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  template == null
                      ? '目前沿用原本綁定的優惠券模板'
                      : _templateDescription(template),
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _selectCouponTemplate,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('更換優惠券模板'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(
          '優惠內容、有效天數、使用次數與適用範圍，'
          '會依優惠券模板設定帶入。',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildExchangeLimitSection() {
    return _SectionCard(
      title: '兌換限制',
      children: <Widget>[
        TextFormField(
          controller: _memberLimitController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '每位會員最多兌換次數',
            helperText: '輸入 0 代表不限制',
            border: OutlineInputBorder(),
          ),
          validator: _validateNonNegativeInteger,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _totalLimitController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '全店總兌換上限',
            helperText: '輸入 0 代表不限制',
            border: OutlineInputBorder(),
          ),
          validator: _validateNonNegativeInteger,
        ),
      ],
    );
  }

  Widget _buildPublishSection() {
    return _SectionCard(
      title: '上架設定',
      children: <Widget>[
        TextFormField(
          controller: _sortOrderController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '顯示順序',
            helperText: '數字越小越前面',
            border: OutlineInputBorder(),
          ),
          validator: (String? value) {
            if (int.tryParse((value ?? '').trim()) == null) {
              return '請輸入整數';
            }

            return null;
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('開放會員兌換'),
          subtitle: Text(_enabled ? '商品建立後會直接顯示在會員點數商城' : '商品會先保存，但會員暫時看不到'),
          value: _enabled,
          onChanged: (bool value) {
            setState(() {
              _enabled = value;
            });
          },
        ),
      ],
    );
  }

  String? _validateNonNegativeInteger(String? value) {
    final int? number = int.tryParse((value ?? '').trim());

    if (number == null || number < 0) {
      return '請輸入 0 或大於 0 的整數';
    }

    return null;
  }

  String _templateDescription(CouponTemplateModel template) {
    switch (template.type) {
      case MemberCouponType.fixedAmount:
        return '固定折抵 NT\$${_formatNumber(template.discountValue)}';

      case MemberCouponType.percent:
        return '折扣 ${_formatNumber(template.discountValue)}%';

      case MemberCouponType.freeStay:
        return '免費住宿 ${template.freeStayNights} 晚';

      case MemberCouponType.freeService:
        if (template.serviceName.trim().isEmpty) {
          return '免費指定服務';
        }

        return '免費服務：${template.serviceName}';
    }
  }

  String _formatNumber(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value.toString();
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

// 檔案名稱：lib/features/admin/pages/admin_point_reward_form_page.dart
// 功能說明：建立優惠券型點數兌換商品
// 🎁 後台點數兌換商品新增／編輯頁
// 並綁定既有優惠券模板、設定點數、兌換限制與上架狀態。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/coupon_template_model.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/models/point_reward_model.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/core/services/point_reward_service.dart';
import 'package:petnest_saas/core/services/point_reward_image_service.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_item_picker_page.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_item_cover.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_status_chip.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_pick_flow.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_spec_hint.dart';
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
  Uint8List? _selectedProductImageBytes;
  bool _removeExistingProductImage = false;
  bool _selectingImage = false;
  bool _requiresStaffVerification = true;
  bool _advancedOpen = false;
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

    for (final TextEditingController controller in <TextEditingController>[
      _nameController,
      _descriptionController,
      _pointsCostController,
      _totalLimitController,
      _stockQuantityController,
    ]) {
      controller.addListener(_onPreviewFieldChanged);
    }
  }

  void _onPreviewFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _nameController,
      _descriptionController,
      _pointsCostController,
      _totalLimitController,
      _stockQuantityController,
    ]) {
      controller.removeListener(_onPreviewFieldChanged);
    }

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
      final Uint8List? cropped = await FixedImagePickFlow.pickAndCrop(
        context: context,
        spec: FixedImageSpec.pointReward,
        title: '裁切兌換商品圖片',
      );

      if (cropped == null || !mounted) {
        return;
      }

      setState(() {
        _selectedProductImageBytes = cropped;
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
      _selectedProductImageBytes = null;
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
      if (inventoryImageUrl.isNotEmpty && _selectedProductImageBytes == null) {
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

    if (isPhysicalProduct &&
        _useCentralInventory &&
        _inventoryItemId.trim().isEmpty) {
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

        if (isPhysicalProduct && _selectedProductImageBytes != null) {
          uploadedImageUrl = await PointRewardImageService.instance.uploadBytes(
            shopId: widget.shopId,
            rewardId: currentReward.id,
            bytes: _selectedProductImageBytes!,
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
          useCentralInventory: isPhysicalProduct && _useCentralInventory,
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
              isPhysicalProduct && _useCentralInventory ? inventoryQuantity : 1,
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
                _selectedProductImageBytes == null &&
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
          useCentralInventory: isPhysicalProduct && _useCentralInventory,
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
              isPhysicalProduct && _useCentralInventory ? inventoryQuantity : 1,
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

        if (isPhysicalProduct && _selectedProductImageBytes != null) {
          uploadedImageUrl = await PointRewardImageService.instance.uploadBytes(
            shopId: widget.shopId,
            rewardId: createdRewardId,
            bytes: _selectedProductImageBytes!,
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
            useCentralInventory: isPhysicalProduct && _useCentralInventory,
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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool desktop = constraints.maxWidth >= 720;

        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(title: Text(_isEditing ? '編輯點數兌換商品' : '建立點數兌換商品')),
          body: Form(
            key: _formKey,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    desktop ? 20 : 16,
                    16,
                    desktop ? 20 : 16,
                    24,
                  ),
                  children: <Widget>[
                    _buildSummaryHeader(),
                    const SizedBox(height: 12),
                    _buildBasicSection(),
                    const SizedBox(height: 12),
                    _buildFulfillmentTypeSection(),
                    const SizedBox(height: 12),
                    if (_fulfillmentType == PointRewardFulfillmentType.coupon)
                      _buildCouponTemplateSection(),
                    if (_fulfillmentType ==
                        PointRewardFulfillmentType.physicalProduct)
                      _buildPhysicalProductSection(),
                    const SizedBox(height: 12),
                    _buildExchangeLimitSection(),
                    const SizedBox(height: 12),
                    _buildAdvancedSection(),
                    const SizedBox(height: 12),
                    _buildPreviewSection(),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: _buildActionBar(desktop: desktop),
        );
      },
    );
  }

  Widget _buildActionBar({required bool desktop}) {
    final Widget saveButton = FilledButton.icon(
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
            ? '儲存變更'
            : '建立商品',
      ),
    );

    return SafeArea(
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
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: desktop
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      saveButton,
                    ],
                  )
                : SizedBox(width: double.infinity, child: saveButton),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final String name = _nameController.text.trim();

    return _SectionCard(
      compact: true,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name.isEmpty ? '新的點數兌換商品' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fulfillmentType == PointRewardFulfillmentType.coupon
                        ? '優惠券・兌換後立即發券'
                        : '實體商品・店內領取',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                const Text('開放會員兌換', style: TextStyle(fontSize: 12)),
                Switch.adaptive(
                  value: _enabled,
                  onChanged: (bool value) {
                    setState(() {
                      _enabled = value;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        Text(
          _enabled ? '儲存後會顯示在會員點數商城。' : '商品會先保存，但會員暫時看不到。',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
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
            isDense: true,
          ),
          maxLength: 50,
          validator: (String? value) {
            if ((value ?? '').trim().isEmpty) {
              return '請輸入商品名稱';
            }

            return null;
          },
        ),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: '商品說明',
            hintText: '顯示給會員查看的兌換說明',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          minLines: 2,
          maxLines: 5,
          maxLength: 300,
        ),
        TextFormField(
          controller: _pointsCostController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '需要點數',
            hintText: '例如：1000',
            suffixText: '點',
            border: OutlineInputBorder(),
            isDense: true,
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
    // onsiteService 目前沒有完整流程，這裡只提供兩種可用類型。
    return _SectionCard(
      title: '商品類型',
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _ChoiceCard(
                icon: Icons.confirmation_number_outlined,
                title: '優惠券',
                subtitle: '兌換後立即發券',
                selected: _fulfillmentType == PointRewardFulfillmentType.coupon,
                onTap: () {
                  setState(() {
                    _fulfillmentType = PointRewardFulfillmentType.coupon;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChoiceCard(
                icon: Icons.inventory_2_outlined,
                title: '實體商品',
                subtitle: '店員核銷後領取',
                selected:
                    _fulfillmentType ==
                    PointRewardFulfillmentType.physicalProduct,
                onTap: () {
                  setState(() {
                    _fulfillmentType =
                        PointRewardFulfillmentType.physicalProduct;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductImagePicker() {
    final Uint8List? selectedBytes = _selectedProductImageBytes;

    final String existingImageUrl = _networkPreviewImageUrl();

    final bool hasSelectedImage = selectedBytes != null;
    final bool hasExistingImage = existingImageUrl.isNotEmpty;
    final bool hasImage = hasSelectedImage || hasExistingImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '商品圖片',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const FixedImageSpecHint(spec: FixedImageSpec.pointReward),
        if (hasImage)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 160, maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
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
                          return const Center(child: Text('原商品圖片載入失敗'));
                        },
                  ),
          )
        else
          Container(
            width: double.infinity,
            height: 160,
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
        Row(
          children: <Widget>[
            Expanded(
              child: _ChoiceCard(
                icon: Icons.tune,
                title: '自行設定可兌換數量',
                subtitle: '不連動中央庫存',
                selected: !_useCentralInventory,
                onTap: () {
                  setState(() {
                    _useCentralInventory = false;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChoiceCard(
                icon: Icons.warehouse_outlined,
                title: '連動中央庫存',
                subtitle: '兌換成功自動扣庫存',
                selected: _useCentralInventory,
                onTap: () {
                  setState(() {
                    _useCentralInventory = true;
                  });
                },
              ),
            ),
          ],
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
              isDense: true,
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
        TextFormField(
          controller: _fulfillmentNoteController,
          decoration: const InputDecoration(
            labelText: '領取說明',
            hintText: '例如：請於營業時間至櫃檯領取',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          minLines: 2,
          maxLines: 5,
          maxLength: 300,
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            '此商品為店內自取；會員到店領取時，由店員完成交付核銷。',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
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
      builder: (BuildContext context, AsyncSnapshot<InventoryItemModel?> snapshot) {
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
                    Icon(Icons.chevron_right, color: Colors.grey.shade500),
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
    final bool hasTemplate = _selectedTemplateId.trim().isNotEmpty;

    return _SectionCard(
      title: '優惠券設定',
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _selectCouponTemplate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasTemplate ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasTemplate
                    ? Colors.green.shade200
                    : Colors.orange.shade200,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  hasTemplate
                      ? Icons.check_circle
                      : Icons.confirmation_number_outlined,
                  size: 22,
                  color: hasTemplate
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        hasTemplate
                            ? (template?.name ??
                                  widget.reward?.name ??
                                  '已綁定優惠券模板')
                            : '尚未選擇模板',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        !hasTemplate
                            ? '點擊選擇已建立的優惠券'
                            : template == null
                            ? '目前沿用原本綁定的優惠券模板'
                            : '${_templateDescription(template)}　'
                                  '${template.validDays > 0 ? '有效 ${template.validDays} 天' : '不限有效天數'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  hasTemplate ? '更換' : '選擇',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        Text(
          '優惠內容、有效天數、使用次數與適用範圍，會依優惠券模板設定帶入。',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildExchangeLimitSection() {
    final int totalLimit = int.tryParse(_totalLimitController.text.trim()) ?? 0;
    final int exchangedCount = widget.reward?.exchangedCount ?? 0;
    final bool full = totalLimit > 0 && exchangedCount >= totalLimit;

    return _SectionCard(
      title: '兌換限制',
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: _memberLimitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '每位會員上限',
                  hintText: '0 代表不限',
                  helperText: '輸入 0 代表不限',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: _validateNonNegativeInteger,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _totalLimitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '全店總上限',
                  hintText: '0 代表不限',
                  helperText: '輸入 0 代表不限',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: _validateNonNegativeInteger,
              ),
            ),
          ],
        ),
        if (_isEditing)
          Text(
            full
                ? '已兌換 $exchangedCount / $totalLimit，目前已額滿'
                : '已兌換 $exchangedCount / ${totalLimit > 0 ? '$totalLimit' : '不限'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: full ? FontWeight.w700 : FontWeight.w400,
              color: full ? const Color(0xFFC62828) : Colors.grey.shade700,
            ),
          ),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    return _SectionCard(
      compact: true,
      children: <Widget>[
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            initiallyExpanded: _advancedOpen,
            onExpansionChanged: (bool value) {
              _advancedOpen = value;
            },
            title: const Text(
              '進階設定',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            children: <Widget>[
              TextFormField(
                controller: _sortOrderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '顯示順序',
                  helperText: '數字越小越前面',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (String? value) {
                  if (int.tryParse((value ?? '').trim()) == null) {
                    return '請輸入整數';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    final String name = _nameController.text.trim();
    final int points = int.tryParse(_pointsCostController.text.trim()) ?? 0;
    final bool couponReady =
        _fulfillmentType != PointRewardFulfillmentType.coupon ||
        _selectedTemplateId.trim().isNotEmpty;
    final bool inventoryReady =
        _fulfillmentType != PointRewardFulfillmentType.physicalProduct ||
        !_useCentralInventory ||
        _inventoryItemId.trim().isNotEmpty;
    final bool ready =
        name.isNotEmpty && points > 0 && couponReady && inventoryReady;

    return _SectionCard(
      title: '會員看到的兌換預覽',
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ready
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$points 點',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEF6C00),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _previewDeliveryLine(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (_descriptionController.text
                        .trim()
                        .isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        _descriptionController.text.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                )
              : Text(
                  '完成必要設定後會顯示預覽',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
        ),
      ],
    );
  }

  String _previewDeliveryLine() {
    if (_fulfillmentType == PointRewardFulfillmentType.coupon) {
      final CouponTemplateModel? template = _selectedTemplate;
      if (template == null) {
        return '兌換後立即發券';
      }
      return '兌換後立即發券・${_templateDescription(template)}';
    }

    if (_useCentralInventory) {
      return '店內領取・需出示領取碼・連動中央庫存';
    }

    final int stock = int.tryParse(_stockQuantityController.text.trim()) ?? 0;

    return stock > 0 ? '店內領取・可兌換 $stock 份' : '店內領取・不限兌換數量';
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
  const _SectionCard({
    this.title = '',
    required this.children,
    this.compact = false,
  });

  final String title;
  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: <Widget>[
          if (title.isNotEmpty)
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ...children,
        ],
      ),
    );
  }
}

/// 類型選擇卡。取代原本的 RadioListTile。
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : Colors.grey.shade300,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: selected ? accent : null),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 檔案名稱：lib/features/admin/pages/admin_coupon_template_form_page.dart
// 功能說明：建立與修改固定金額券、百分比券、免費住宿券及免費服務券
// 🎟️ 後台優惠券模板新增／編輯頁
// 並可指定房型、加購服務、有效天數、使用次數與優惠併用設定。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/models/coupon_template_model.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/services/coupon_template_service.dart';
import 'package:petnest_saas/core/services/discount_promo_preview.dart';
import 'package:petnest_saas/features/shop/widgets/discount_promo_preview_card.dart';

class AdminCouponTemplateFormPage extends StatefulWidget {
  const AdminCouponTemplateFormPage({
    super.key,
    required this.shopId,
    this.template,
  });

  final String shopId;
  final CouponTemplateModel? template;

  bool get isEditing => template != null;

  @override
  State<AdminCouponTemplateFormPage> createState() {
    return _AdminCouponTemplateFormPageState();
  }
}

class _AdminCouponTemplateFormPageState
    extends State<AdminCouponTemplateFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _discountValueController;
  late final TextEditingController _minimumAmountController;
  late final TextEditingController _maximumDiscountController;
  late final TextEditingController _freeStayNightsController;
  late final TextEditingController _validDaysController;
  late final TextEditingController _usageLimitController;
  late final TextEditingController _sortOrderController;

  late MemberCouponType _type;
  late MemberCouponApplyTarget _applyTarget;
  late bool _enabled;
  late Set<String> _selectedRoomTypeIds;

  String _selectedServiceId = '';
  String _selectedServiceName = '';
  CouponServiceCategory _selectedServiceCategory = CouponServiceCategory.value;

  bool _isLoadingOptions = true;
  bool _isSaving = false;
  bool _specifyRoomTypes = false;
  bool _advancedOpen = false;

  List<_RoomTypeOption> _roomTypes = const <_RoomTypeOption>[];
  List<_ServiceOption> _services = const <_ServiceOption>[];

  @override
  void initState() {
    super.initState();

    final CouponTemplateModel? template = widget.template;

    _nameController = TextEditingController(text: template?.name ?? '');

    _descriptionController = TextEditingController(
      text: template?.description ?? '',
    );

    _discountValueController = TextEditingController(
      text: template == null || template.discountValue == 0
          ? ''
          : _formatNumber(template.discountValue),
    );

    _minimumAmountController = TextEditingController(
      text: template == null || template.minimumAmount == 0
          ? ''
          : template.minimumAmount.toString(),
    );

    _maximumDiscountController = TextEditingController(
      text: template == null || template.maximumDiscountAmount == 0
          ? ''
          : template.maximumDiscountAmount.toString(),
    );

    _freeStayNightsController = TextEditingController(
      text: template == null || template.freeStayNights == 0
          ? '1'
          : template.freeStayNights.toString(),
    );

    _validDaysController = TextEditingController(
      text: (template?.validDays ?? 30).toString(),
    );

    _usageLimitController = TextEditingController(
      text: (template?.usageLimit ?? 1).toString(),
    );

    _sortOrderController = TextEditingController(
      text: (template?.sortOrder ?? 0).toString(),
    );

    _type = template?.type ?? MemberCouponType.fixedAmount;

    _applyTarget = template?.applyTarget ?? MemberCouponApplyTarget.total;

    _enabled = template?.enabled ?? true;

    _selectedRoomTypeIds = <String>{...?template?.roomTypeIds};
    _specifyRoomTypes = _selectedRoomTypeIds.isNotEmpty;

    _selectedServiceId = template?.serviceId ?? '';
    _selectedServiceName = template?.serviceName ?? '';
    _selectedServiceCategory =
        template?.serviceCategory ?? CouponServiceCategory.value;

    for (final TextEditingController controller in _draftControllers) {
      controller.addListener(_handleDraftChanged);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadOptions();
      }
    });
  }

  List<TextEditingController> get _draftControllers {
    return <TextEditingController>[
      _nameController,
      _descriptionController,
      _discountValueController,
      _minimumAmountController,
      _maximumDiscountController,
      _freeStayNightsController,
      _validDaysController,
      _usageLimitController,
      _sortOrderController,
    ];
  }

  void _handleDraftChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _draftControllers) {
      controller.removeListener(_handleDraftChanged);
    }
    _nameController.dispose();
    _descriptionController.dispose();
    _discountValueController.dispose();
    _minimumAmountController.dispose();
    _maximumDiscountController.dispose();
    _freeStayNightsController.dispose();
    _validDaysController.dispose();
    _usageLimitController.dispose();
    _sortOrderController.dispose();

    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final DocumentReference<Map<String, dynamic>> shopReference =
          FirebaseFirestore.instance.collection('shops').doc(widget.shopId);

      final List<dynamic> results =
          await Future.wait<dynamic>(<Future<dynamic>>[
            shopReference.collection('room_types').get(),
            shopReference.collection('addons').doc('main').get(),
          ]);

      final QuerySnapshot<Map<String, dynamic>> roomSnapshot =
          results[0] as QuerySnapshot<Map<String, dynamic>>;

      final DocumentSnapshot<Map<String, dynamic>> addonSnapshot =
          results[1] as DocumentSnapshot<Map<String, dynamic>>;

      final List<_RoomTypeOption> roomTypes =
          roomSnapshot.docs.map((
            QueryDocumentSnapshot<Map<String, dynamic>> document,
          ) {
            final Map<String, dynamic> data = document.data();

            return _RoomTypeOption(
              id: document.id,
              name: (data['name'] ?? '未命名房型').toString(),
            );
          }).toList()..sort((_RoomTypeOption a, _RoomTypeOption b) {
            return a.name.compareTo(b.name);
          });

      final Map<String, dynamic> addonData =
          addonSnapshot.data() ?? <String, dynamic>{};

      final List<_ServiceOption> services = <_ServiceOption>[];

      _appendServiceOptions(
        services,
        addonData['valueServices'],
        categoryLabel: '整張訂單免費一次',
        category: CouponServiceCategory.value,
      );

      _appendServiceOptions(
        services,
        addonData['customServices'],
        categoryLabel: '每隻寵物免費一次',
        category: CouponServiceCategory.custom,
      );

      services.sort((_ServiceOption a, _ServiceOption b) {
        final int categoryCompare = a.categoryLabel.compareTo(b.categoryLabel);

        if (categoryCompare != 0) {
          return categoryCompare;
        }

        return a.name.compareTo(b.name);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _roomTypes = roomTypes;
        _services = services;
        _isLoadingOptions = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingOptions = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('房型或服務資料讀取失敗：${_cleanError(error)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 將 Firestore 服務資料轉成免費服務券可選項目。
  ///
  /// 只接受已經有固定 ID 的服務，避免使用陣列位置作為服務識別，
  /// 導致店家刪除或調整服務後，優惠券綁定到錯誤項目。
  void _appendServiceOptions(
    List<_ServiceOption> target,
    dynamic rawList, {
    required String categoryLabel,
    required CouponServiceCategory category,
  }) {
    if (rawList is! List) {
      return;
    }

    for (final dynamic rawItem in rawList) {
      if (rawItem is! Map) {
        continue;
      }

      final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);

      final String serviceId = (item['id'] ?? '').toString().trim();

      final String serviceName = (item['name'] ?? item['label'] ?? '')
          .toString()
          .trim();

      // 沒有固定 ID 的舊服務先不提供優惠券綁定。
      if (serviceId.isEmpty || serviceName.isEmpty) {
        continue;
      }

      // 避免同一份資料出現重複 ID。
      final bool alreadyExists = target.any((_ServiceOption option) {
        return option.id == serviceId;
      });

      if (alreadyExists) {
        continue;
      }

      target.add(
        _ServiceOption(
          id: serviceId,
          name: serviceName,
          categoryLabel: categoryLabel,
          category: category,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (_type == MemberCouponType.freeService &&
        _selectedServiceId.trim().isEmpty) {
      _showMessage('請選擇免費服務項目');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final num discountValue =
          num.tryParse(_discountValueController.text.trim()) ?? 0;

      final int minimumAmount =
          int.tryParse(_minimumAmountController.text.trim()) ?? 0;

      final int maximumDiscountAmount =
          int.tryParse(_maximumDiscountController.text.trim()) ?? 0;

      final int freeStayNights =
          int.tryParse(_freeStayNightsController.text.trim()) ?? 0;

      final int validDays = int.tryParse(_validDaysController.text.trim()) ?? 0;

      final int usageLimit =
          int.tryParse(_usageLimitController.text.trim()) ?? 1;

      final int sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;

      if (widget.isEditing) {
        await CouponTemplateService.instance.updateTemplate(
          shopId: widget.shopId,
          templateId: widget.template!.id,
          name: _nameController.text,
          description: _descriptionController.text,
          type: _type,
          applyTarget: _effectiveApplyTarget,
          discountValue: discountValue,
          minimumAmount: minimumAmount,
          maximumDiscountAmount: maximumDiscountAmount,
          freeStayNights: freeStayNights,
          serviceId: _selectedServiceId,
          serviceName: _selectedServiceName,
          serviceCategory: _selectedServiceCategory,
          roomTypeIds: _selectedRoomTypeIds.toList(),
          validDays: validDays,
          usageLimit: usageLimit,
          enabled: _enabled,
          sortOrder: sortOrder,
        );
      } else {
        await CouponTemplateService.instance.createTemplate(
          shopId: widget.shopId,
          name: _nameController.text,
          description: _descriptionController.text,
          type: _type,
          applyTarget: _effectiveApplyTarget,
          discountValue: discountValue,
          minimumAmount: minimumAmount,
          maximumDiscountAmount: maximumDiscountAmount,
          freeStayNights: freeStayNights,
          serviceId: _selectedServiceId,
          serviceName: _selectedServiceName,
          serviceCategory: _selectedServiceCategory,
          roomTypeIds: _selectedRoomTypeIds.toList(),
          validDays: validDays,
          usageLimit: usageLimit,
          enabled: _enabled,
          sortOrder: sortOrder,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  MemberCouponApplyTarget get _effectiveApplyTarget {
    switch (_type) {
      case MemberCouponType.freeStay:
        return MemberCouponApplyTarget.room;

      case MemberCouponType.freeService:
        return MemberCouponApplyTarget.service;

      case MemberCouponType.fixedAmount:
      case MemberCouponType.percent:
        return _applyTarget;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }

  String _formatNumber(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool desktop = constraints.maxWidth >= 720;
        final bool compact = constraints.maxWidth < 720;
        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: desktop
              ? null
              : AppBar(title: Text(widget.isEditing ? '編輯優惠券' : '新增優惠券')),
          body: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 12 : 20,
                          compact ? 12 : 20,
                          compact ? 12 : 20,
                          24,
                        ),
                        children: <Widget>[
                          _buildHeader(compact: compact),
                          SizedBox(height: compact ? 10 : 14),
                          _buildBasicSection(compact: compact),
                          SizedBox(height: compact ? 10 : 14),
                          _buildTypeSection(compact: compact),
                          SizedBox(height: compact ? 10 : 14),
                          _buildRuleSection(compact: compact),
                          SizedBox(height: compact ? 10 : 14),
                          _buildScopeSection(compact: compact),
                          SizedBox(height: compact ? 10 : 14),
                          _buildUsageSection(compact: compact),
                          SizedBox(height: compact ? 10 : 14),
                          DiscountPromoPreviewCard(
                            heading: '客戶看到的優惠預覽',
                            lines: _previewLines(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildActionBar(desktop: desktop),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader({required bool compact}) {
    final String title = widget.isEditing ? '編輯優惠券' : '新增優惠券';
    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!compact)
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        if (!compact) const SizedBox(height: 4),
        Text(
          '製作模板後，可由店主手動發送、點數兌換或活動贈送給會員。',
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            color: Colors.grey.shade700,
            height: 1.35,
          ),
        ),
      ],
    );
    final Widget toggle = _buildEnabledSwitch(compact: compact);
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[copy, const SizedBox(height: 10), toggle],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: copy),
        const SizedBox(width: 16),
        toggle,
      ],
    );
  }

  Widget _buildEnabledSwitch({required bool compact}) {
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? double.infinity : 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _enabled ? '啟用中：可繼續發放' : '已停用：不可再發放，已發出的優惠券仍有效',
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
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
    );
  }

  Widget _buildActionBar({required bool desktop}) {
    final Widget saveButton = FilledButton(
      onPressed: _isSaving ? null : _save,
      child: _isSaving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('儲存優惠券'),
    );
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: desktop
              ? Row(
                  children: <Widget>[
                    const Spacer(),
                    OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    saveButton,
                  ],
                )
              : SizedBox(width: double.infinity, height: 46, child: saveButton),
        ),
      ),
    );
  }

  List<DiscountPromoPreviewLine> _previewLines() {
    return buildCouponFormPreview(
      type: _type,
      couponName: _nameController.text,
      discountText: _discountValueController.text,
      minimumText: _minimumAmountController.text,
      maximumText: _maximumDiscountController.text,
      nightsText: _freeStayNightsController.text,
      serviceName: _selectedServiceName,
      validDaysText: _validDaysController.text,
      usageLimitText: _usageLimitController.text,
      roomLimited: _type != MemberCouponType.freeService && _specifyRoomTypes,
      roomCount: _selectedRoomTypeIds.length,
    );
  }

  Widget _buildBasicSection({required bool compact}) {
    return _SectionCard(
      title: '基本資料',
      icon: Icons.confirmation_number_outlined,
      compact: compact,
      children: <Widget>[
        TextFormField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          style: TextStyle(fontSize: compact ? 14 : 15),
          decoration: _fieldDecoration(
            compact: compact,
            labelText: '優惠券名稱 *',
            hintText: '例如：新會員 300 元折價券',
          ),
          validator: (String? value) {
            if ((value ?? '').trim().isEmpty) {
              return '請輸入優惠券名稱';
            }
            return null;
          },
        ),
        SizedBox(height: compact ? 10 : 12),
        TextFormField(
          controller: _descriptionController,
          minLines: 2,
          maxLines: 3,
          style: TextStyle(fontSize: compact ? 14 : 15),
          decoration: _fieldDecoration(
            compact: compact,
            labelText: '活動說明',
            hintText: '選填，顯示給店員與會員看的使用說明',
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSection({required bool compact}) {
    return _SectionCard(
      title: '優惠類型',
      icon: Icons.dashboard_customize_outlined,
      compact: compact,
      children: <Widget>[
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 78,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          children: MemberCouponType.values.map((MemberCouponType type) {
            return _ChoiceCard(
              selected: _type == type,
              icon: _typeIcon(type),
              title: _typeLabel(type),
              subtitle: _typeHint(type),
              onTap: () {
                setState(() {
                  _type = type;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRuleSection({required bool compact}) {
    final List<Widget> children = <Widget>[];
    if (CouponTemplateFormFields.showsDiscountAmount(_type)) {
      children.add(
        _numberField(
          compact: compact,
          controller: _discountValueController,
          label: '折抵金額 *',
          suffixText: 'NT\$',
          allowDecimal: false,
          validator: (num value) {
            return value > 0 ? null : '折抵金額必須大於 0';
          },
        ),
      );
    }
    if (CouponTemplateFormFields.showsPercent(_type)) {
      children.add(
        _numberField(
          compact: compact,
          controller: _discountValueController,
          label: '折扣百分比 *',
          suffixText: '%',
          allowDecimal: true,
          validator: (num value) {
            if (value <= 0 || value > 100) {
              return '請輸入 1 到 100';
            }
            return null;
          },
        ),
      );
      children.add(SizedBox(height: compact ? 10 : 12));
      children.add(
        _numberField(
          compact: compact,
          controller: _maximumDiscountController,
          label: '最高折抵金額',
          suffixText: 'NT\$',
          allowDecimal: false,
          helperText: _unlimitedHint(_maximumDiscountController, '不限最高折抵'),
          validator: (num value) {
            return value >= 0 ? null : '不可小於 0';
          },
        ),
      );
    }
    if (CouponTemplateFormFields.showsFreeStayNights(_type)) {
      children.add(
        _numberField(
          compact: compact,
          controller: _freeStayNightsController,
          label: '免費住宿晚數 *',
          suffixText: '晚',
          allowDecimal: false,
          validator: (num value) {
            return value > 0 ? null : '住宿晚數必須大於 0';
          },
        ),
      );
      children.add(SizedBox(height: compact ? 8 : 10));
      children.add(
        Text(
          '適用範圍固定為住宿。',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      );
    }
    if (CouponTemplateFormFields.showsApplyTarget(_type)) {
      if (children.isNotEmpty) {
        children.add(SizedBox(height: compact ? 10 : 12));
      }
      children.add(_buildApplyTargetPicker());
      children.add(SizedBox(height: compact ? 10 : 12));
      children.add(
        _numberField(
          compact: compact,
          controller: _minimumAmountController,
          label: '最低消費金額',
          suffixText: 'NT\$',
          allowDecimal: false,
          helperText: _unlimitedHint(_minimumAmountController, '不限最低消費'),
          validator: (num value) {
            return value >= 0 ? null : '不可小於 0';
          },
        ),
      );
    }
    return _SectionCard(
      title: '折抵規則',
      icon: Icons.rule_folder_outlined,
      compact: compact,
      children: children,
    );
  }

  Widget _buildApplyTargetPicker() {
    const List<MemberCouponApplyTarget> targets = <MemberCouponApplyTarget>[
      MemberCouponApplyTarget.room,
      MemberCouponApplyTarget.roomAndPet,
      MemberCouponApplyTarget.total,
    ];
    return Row(
      children: targets.map((MemberCouponApplyTarget target) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: target == targets.last ? 0 : 8),
            child: _ChoiceCard(
              selected: _applyTarget == target,
              icon: Icons.sell_outlined,
              title: _targetLabel(target),
              subtitle: '',
              height: 64,
              onTap: () {
                setState(() {
                  _applyTarget = target;
                });
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServiceSelector() {
    if (_isLoadingOptions) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final bool selectedServiceStillExists = _services.any((
      _ServiceOption service,
    ) {
      return service.id == _selectedServiceId;
    });

    final List<_ServiceOption> options = <_ServiceOption>[..._services];

    if (_selectedServiceId.isNotEmpty && !selectedServiceStillExists) {
      options.insert(
        0,
        _ServiceOption(
          id: _selectedServiceId,
          name: _selectedServiceName.isEmpty ? '原指定服務' : _selectedServiceName,
          categoryLabel: '舊資料',
          category: _selectedServiceCategory,
        ),
      );
    }

    if (options.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: const Text(
          '目前沒有可選擇的服務。\n'
          '請先到「加購服務管理」建立服務，'
          '或將舊服務儲存一次以補上固定 ID。',
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedServiceId.isEmpty ? null : _selectedServiceId,
      decoration: const InputDecoration(
        labelText: '指定免費服務 *',
        border: OutlineInputBorder(),
      ),
      items: options.map<DropdownMenuItem<String>>((_ServiceOption service) {
        return DropdownMenuItem<String>(
          value: service.id,
          child: Text('${service.name}（${service.categoryLabel}）'),
        );
      }).toList(),
      onChanged: (String? value) {
        _ServiceOption? selected;

        for (final _ServiceOption item in options) {
          if (item.id == value) {
            selected = item;
            break;
          }
        }

        setState(() {
          _selectedServiceId = selected?.id ?? '';
          _selectedServiceName = selected?.name ?? '';
          _selectedServiceCategory =
              selected?.category ?? CouponServiceCategory.value;
        });
      },
      validator: (String? value) {
        if (_type == MemberCouponType.freeService &&
            (value ?? '').trim().isEmpty) {
          return '請選擇免費服務項目';
        }

        return null;
      },
    );
  }

  Widget _buildScopeSection({required bool compact}) {
    if (CouponTemplateFormFields.showsServicePicker(_type)) {
      return _SectionCard(
        title: '適用範圍',
        icon: Icons.room_service_outlined,
        compact: compact,
        children: <Widget>[
          Text(
            '適用範圍固定為指定服務。',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          SizedBox(height: compact ? 8 : 10),
          const Text('指定免費服務', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: compact ? 8 : 10),
          _buildServiceSummary(),
          SizedBox(height: compact ? 8 : 10),
          _buildServiceSelector(),
        ],
      );
    }
    return _SectionCard(
      title: '適用範圍',
      icon: Icons.meeting_room_outlined,
      compact: compact,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _ChoiceCard(
                selected: !_specifyRoomTypes,
                icon: Icons.home_outlined,
                title: '全部房型可用',
                subtitle: '不限制房型',
                height: 64,
                onTap: () {
                  setState(() {
                    _specifyRoomTypes = false;
                    _selectedRoomTypeIds.clear();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChoiceCard(
                selected: _specifyRoomTypes,
                icon: Icons.meeting_room_outlined,
                title: '指定房型',
                subtitle: '只限選取房型',
                height: 64,
                onTap: () {
                  setState(() {
                    _specifyRoomTypes = true;
                  });
                },
              ),
            ),
          ],
        ),
        if (_specifyRoomTypes) ...<Widget>[
          SizedBox(height: compact ? 8 : 10),
          if (_isLoadingOptions)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_roomTypes.isEmpty)
            const Text('目前尚未建立房型，優惠券將視為不限房型。')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _roomTypes.map((_RoomTypeOption roomType) {
                final bool selected = _selectedRoomTypeIds.contains(
                  roomType.id,
                );
                return FilterChip(
                  label: Text(roomType.name),
                  avatar: selected ? const Icon(Icons.check, size: 16) : null,
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: const Color(
                    0xFF6A1B9A,
                  ).withValues(alpha: 0.08),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF6A1B9A)
                        : Colors.grey.shade300,
                  ),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        _selectedRoomTypeIds.add(roomType.id);
                      } else {
                        _selectedRoomTypeIds.remove(roomType.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
        ],
      ],
    );
  }

  Widget _buildServiceSummary() {
    final bool missing =
        _selectedServiceId.isNotEmpty &&
        !_services.any((_ServiceOption service) {
          return service.id == _selectedServiceId;
        });
    final String name = _selectedServiceName.trim().isEmpty
        ? '尚未指定服務'
        : _selectedServiceName.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: missing ? Colors.orange.shade50 : const Color(0xFFF6F1FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: missing ? Colors.orange.shade200 : const Color(0xFFE1D4EE),
        ),
      ),
      child: Text(
        missing ? '找不到原指定服務「$name」，請重新選擇。' : '已選服務：$name',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildUsageSection({required bool compact}) {
    return _SectionCard(
      title: '有效與發放規則',
      icon: Icons.event_available_outlined,
      compact: compact,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _numberField(
                compact: compact,
                controller: _validDaysController,
                label: '發放後有效天數',
                suffixText: '天',
                allowDecimal: false,
                helperText: '0＝永久有效',
                validator: (num value) {
                  return value >= 0 ? null : '不可小於 0';
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _numberField(
                compact: compact,
                controller: _usageLimitController,
                label: '每張可使用次數 *',
                suffixText: '次',
                allowDecimal: false,
                validator: (num value) {
                  return value > 0 ? null : '必須大於 0';
                },
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 6 : 8),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 4),
            initiallyExpanded: _advancedOpen,
            onExpansionChanged: (bool value) {
              setState(() {
                _advancedOpen = value;
              });
            },
            title: const Text(
              '進階設定',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            children: <Widget>[
              _numberField(
                compact: compact,
                controller: _sortOrderController,
                label: '排序',
                allowDecimal: false,
                helperText: '數字越小越前面，可輸入 0',
                allowNegative: true,
                validator: (num value) {
                  return null;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _unlimitedHint(TextEditingController controller, String label) {
    final String text = controller.text.trim();
    final num value = num.tryParse(text) ?? 0;
    if (text.isEmpty || value == 0) {
      return label;
    }
    return null;
  }

  InputDecoration _fieldDecoration({
    required bool compact,
    required String labelText,
    String? hintText,
    String? suffixText,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      suffixText: suffixText,
      helperText: helperText,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compact ? 10 : 12,
      ),
      border: const OutlineInputBorder(),
    );
  }

  Widget _numberField({
    required bool compact,
    required TextEditingController controller,
    required String label,
    required bool allowDecimal,
    required String? Function(num value) validator,
    String? suffixText,
    String? helperText,
    bool allowNegative = false,
  }) {
    final String pattern;

    if (allowDecimal && allowNegative) {
      pattern = r'^-?\d*\.?\d{0,2}';
    } else if (allowDecimal) {
      pattern = r'^\d*\.?\d{0,2}';
    } else if (allowNegative) {
      pattern = r'^-?\d*';
    } else {
      pattern = r'^\d*';
    }

    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(
        decimal: allowDecimal,
        signed: allowNegative,
      ),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(pattern)),
      ],
      style: TextStyle(fontSize: compact ? 14 : 15),
      decoration: _fieldDecoration(
        compact: compact,
        labelText: label,
        suffixText: suffixText,
        helperText: helperText,
      ),
      validator: (String? rawValue) {
        final String text = (rawValue ?? '').trim();

        final num value = num.tryParse(text) ?? 0;

        return validator(value);
      },
    );
  }

  String _typeLabel(MemberCouponType type) {
    switch (type) {
      case MemberCouponType.fixedAmount:
        return '固定金額折價券';
      case MemberCouponType.percent:
        return '百分比折扣券';
      case MemberCouponType.freeStay:
        return '免費住宿券';
      case MemberCouponType.freeService:
        return '免費服務券';
    }
  }

  String _typeHint(MemberCouponType type) {
    switch (type) {
      case MemberCouponType.fixedAmount:
        return '折抵固定金額';
      case MemberCouponType.percent:
        return '依比例折抵';
      case MemberCouponType.freeStay:
        return '免費指定晚數';
      case MemberCouponType.freeService:
        return '指定服務免費';
    }
  }

  IconData _typeIcon(MemberCouponType type) {
    switch (type) {
      case MemberCouponType.fixedAmount:
        return Icons.payments_outlined;
      case MemberCouponType.percent:
        return Icons.percent;
      case MemberCouponType.freeStay:
        return Icons.hotel_outlined;
      case MemberCouponType.freeService:
        return Icons.room_service_outlined;
    }
  }

  String _targetLabel(MemberCouponApplyTarget target) {
    switch (target) {
      case MemberCouponApplyTarget.room:
        return '僅房價';
      case MemberCouponApplyTarget.roomAndPet:
        return '房價＋寵物費';
      case MemberCouponApplyTarget.total:
        return '整張訂單';
      case MemberCouponApplyTarget.service:
        return '指定服務';
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    required this.compact,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: compact ? 18 : 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: compact ? 15 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          ...children,
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.height = 78,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    const Color accent = Color(0xFF6A1B9A);
    return Material(
      color: selected ? accent.withValues(alpha: 0.08) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? accent : Colors.grey.shade300,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 22, 8),
                child: Row(
                  children: <Widget>[
                    Icon(
                      icon,
                      size: 18,
                      color: selected ? accent : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(Icons.check_circle, size: 14, color: accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 優惠券表單依類型顯示的欄位。儲存與計價邏輯不在這裡。
class CouponTemplateFormFields {
  const CouponTemplateFormFields._();

  static bool showsDiscountAmount(MemberCouponType type) {
    return type == MemberCouponType.fixedAmount;
  }

  static bool showsPercent(MemberCouponType type) {
    return type == MemberCouponType.percent;
  }

  static bool showsMaximumDiscount(MemberCouponType type) {
    return type == MemberCouponType.percent;
  }

  static bool showsApplyTarget(MemberCouponType type) {
    return type == MemberCouponType.fixedAmount ||
        type == MemberCouponType.percent;
  }

  static bool showsMinimumAmount(MemberCouponType type) {
    return showsApplyTarget(type);
  }

  static bool showsFreeStayNights(MemberCouponType type) {
    return type == MemberCouponType.freeStay;
  }

  static bool showsServicePicker(MemberCouponType type) {
    return type == MemberCouponType.freeService;
  }

  static bool showsRoomScope(MemberCouponType type) {
    return type != MemberCouponType.freeService;
  }
}

/// 表單上的客戶預覽，只做示意，不寫入訂單、不改計價。
List<DiscountPromoPreviewLine> buildCouponFormPreview({
  required MemberCouponType type,
  required String couponName,
  required String discountText,
  required String minimumText,
  required String maximumText,
  required String nightsText,
  required String serviceName,
  required String validDaysText,
  required String usageLimitText,
  required bool roomLimited,
  required int roomCount,
}) {
  const int example = DiscountPromoPreview.sampleStayBase;
  final String title = couponName.trim().isEmpty ? '優惠券' : couponName.trim();
  final int minimum = int.tryParse(minimumText.trim()) ?? 0;
  final int maximum = int.tryParse(maximumText.trim()) ?? 0;
  final num discountValue = num.tryParse(discountText.trim()) ?? 0;
  final int nights = int.tryParse(nightsText.trim()) ?? 0;
  final int validDays = int.tryParse(validDaysText.trim()) ?? 0;
  final int usageLimit = int.tryParse(usageLimitText.trim()) ?? 0;
  final bool belowMinimum =
      CouponTemplateFormFields.showsMinimumAmount(type) &&
      minimum > 0 &&
      example < minimum;

  bool ready = false;
  String offer = '';
  int discountAmount = 0;
  switch (type) {
    case MemberCouponType.fixedAmount:
      ready = discountValue > 0;
      discountAmount = discountValue.round().clamp(0, example).toInt();
      offer = '折抵 ${DiscountPromoPreview.nt(discountAmount)}';
      break;
    case MemberCouponType.percent:
      ready = discountValue > 0 && discountValue <= 100;
      final int raw = (example * discountValue / 100).round();
      final int capped = maximum > 0 && raw > maximum ? maximum : raw;
      discountAmount = capped.clamp(0, example).toInt();
      offer = '折抵 ${DiscountPromoPreview.nt(discountAmount)}';
      break;
    case MemberCouponType.freeStay:
      ready = nights > 0;
      final int covered = nights >= DiscountPromoPreview.sampleStayNights
          ? example
          : (example * nights / DiscountPromoPreview.sampleStayNights).round();
      discountAmount = covered;
      offer = '免費住宿 $nights 晚';
      break;
    case MemberCouponType.freeService:
      ready = serviceName.trim().isNotEmpty;
      discountAmount = 0;
      offer = '免費服務：${serviceName.trim()}';
      break;
  }

  final List<DiscountPromoPreviewLine> lines = <DiscountPromoPreviewLine>[
    DiscountPromoPreviewLine(
      label:
          '範例訂單　住宿 ${DiscountPromoPreview.sampleStayNights} 晚 ${DiscountPromoPreview.nt(example)}',
      amount: example,
    ),
  ];

  if (!ready) {
    lines.add(
      const DiscountPromoPreviewLine(
        label: '完成優惠內容後會顯示預估',
        amount: 0,
        kind: DiscountPromoPreviewKind.hint,
      ),
    );
  } else if (belowMinimum) {
    lines.add(
      const DiscountPromoPreviewLine(
        label: '尚未達可使用門檻',
        amount: 0,
        kind: DiscountPromoPreviewKind.hint,
      ),
    );
    lines.add(
      DiscountPromoPreviewLine(
        label: '預估應付 ${DiscountPromoPreview.nt(example)}',
        amount: example,
        kind: DiscountPromoPreviewKind.total,
      ),
    );
  } else if (type == MemberCouponType.freeService) {
    lines.add(
      DiscountPromoPreviewLine(
        label: offer,
        amount: 0,
        kind: DiscountPromoPreviewKind.discount,
      ),
    );
    lines.add(
      DiscountPromoPreviewLine(
        label: '預估應付 ${DiscountPromoPreview.nt(example)}',
        amount: example,
        kind: DiscountPromoPreviewKind.total,
      ),
    );
  } else if (discountAmount <= 0) {
    lines.add(
      const DiscountPromoPreviewLine(
        label: '完成優惠內容後會顯示預估',
        amount: 0,
        kind: DiscountPromoPreviewKind.hint,
      ),
    );
  } else {
    lines.add(
      DiscountPromoPreviewLine(
        label: '$title　$offer',
        amount: -discountAmount,
        kind: DiscountPromoPreviewKind.discount,
      ),
    );
    final int payable = example - discountAmount;
    lines.add(
      DiscountPromoPreviewLine(
        label: '預估應付 ${DiscountPromoPreview.nt(payable)}',
        amount: payable,
        kind: DiscountPromoPreviewKind.total,
      ),
    );
  }

  final String expiry = validDays <= 0 ? '永久有效' : '發放後 $validDays 天';
  final String rooms = type == MemberCouponType.freeService
      ? '指定服務'
      : roomLimited
      ? '指定 $roomCount 種房型'
      : '全部房型可用';
  final String usage = usageLimit <= 0 ? '使用次數未填' : '每張可用 $usageLimit 次';
  lines.add(
    DiscountPromoPreviewLine(
      label: '期限 $expiry　・　$rooms　・　$usage',
      amount: 0,
      kind: DiscountPromoPreviewKind.hint,
    ),
  );
  return lines;
}

class _RoomTypeOption {
  const _RoomTypeOption({required this.id, required this.name});

  final String id;
  final String name;
}

class _ServiceOption {
  const _ServiceOption({
    required this.id,
    required this.name,
    required this.categoryLabel,
    required this.category,
  });

  final String id;
  final String name;
  final String categoryLabel;
  final CouponServiceCategory category;
}

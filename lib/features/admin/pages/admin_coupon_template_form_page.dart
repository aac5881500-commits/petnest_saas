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

    _selectedServiceId = template?.serviceId ?? '';
    _selectedServiceName = template?.serviceName ?? '';
    _selectedServiceCategory =
        template?.serviceCategory ?? CouponServiceCategory.value;

    _loadOptions();
  }

  @override
  void dispose() {
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
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(widget.isEditing ? '編輯優惠券' : '製作優惠券'),
        actions: <Widget>[
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('儲存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: <Widget>[
            _buildBasicSection(),
            const SizedBox(height: 16),
            _buildCouponContentSection(),
            const SizedBox(height: 16),
            _buildRoomTypeSection(),
            const SizedBox(height: 16),
            _buildUsageSection(),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(widget.isEditing ? '儲存修改' : '建立優惠券'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicSection() {
    return _SectionCard(
      title: '基本資料',
      icon: Icons.confirmation_number_outlined,
      children: <Widget>[
        TextFormField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '優惠券名稱 *',
            hintText: '例如：新會員 300 元折價券',
            border: OutlineInputBorder(),
          ),
          validator: (String? value) {
            if ((value ?? '').trim().isEmpty) {
              return '請輸入優惠券名稱';
            }

            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '優惠券說明',
            hintText: '顯示給店員與會員看的使用說明',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<MemberCouponType>(
          initialValue: _type,
          decoration: const InputDecoration(
            labelText: '優惠券類型 *',
            border: OutlineInputBorder(),
          ),
          items: MemberCouponType.values.map((MemberCouponType type) {
            return DropdownMenuItem<MemberCouponType>(
              value: type,
              child: Text(_typeLabel(type)),
            );
          }).toList(),
          onChanged: (MemberCouponType? value) {
            if (value == null) {
              return;
            }

            setState(() {
              _type = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCouponContentSection() {
    final List<Widget> children = <Widget>[];

    if (_type == MemberCouponType.fixedAmount) {
      children.add(
        _numberField(
          controller: _discountValueController,
          label: '折抵金額 *',
          suffixText: '元',
          allowDecimal: false,
          validator: (num value) {
            return value > 0 ? null : '折抵金額必須大於 0';
          },
        ),
      );
    }

    if (_type == MemberCouponType.percent) {
      children.add(
        _numberField(
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

      children.add(const SizedBox(height: 16));

      children.add(
        _numberField(
          controller: _maximumDiscountController,
          label: '最高折抵金額',
          suffixText: '元',
          allowDecimal: false,
          helperText: '輸入 0 或留空代表不限',
          validator: (num value) {
            return value >= 0 ? null : '不可小於 0';
          },
        ),
      );
    }

    if (_type == MemberCouponType.freeStay) {
      children.add(
        _numberField(
          controller: _freeStayNightsController,
          label: '免費住宿晚數 *',
          suffixText: '晚',
          allowDecimal: false,
          validator: (num value) {
            return value > 0 ? null : '住宿晚數必須大於 0';
          },
        ),
      );
    }

    if (_type == MemberCouponType.freeService) {
      children.add(_buildServiceSelector());
    }

    if (_type == MemberCouponType.fixedAmount ||
        _type == MemberCouponType.percent) {
      children.add(const SizedBox(height: 16));

      children.add(
        DropdownButtonFormField<MemberCouponApplyTarget>(
          initialValue: _applyTarget,
          decoration: const InputDecoration(
            labelText: '折抵範圍 *',
            border: OutlineInputBorder(),
          ),
          items:
              const <MemberCouponApplyTarget>[
                MemberCouponApplyTarget.room,
                MemberCouponApplyTarget.roomAndPet,
                MemberCouponApplyTarget.total,
              ].map((MemberCouponApplyTarget target) {
                return DropdownMenuItem<MemberCouponApplyTarget>(
                  value: target,
                  child: Text(_targetLabel(target)),
                );
              }).toList(),
          onChanged: (MemberCouponApplyTarget? value) {
            if (value == null) {
              return;
            }

            setState(() {
              _applyTarget = value;
            });
          },
        ),
      );
    }

    children.add(const SizedBox(height: 16));

    children.add(
      _numberField(
        controller: _minimumAmountController,
        label: '最低消費金額',
        suffixText: '元',
        allowDecimal: false,
        helperText: '輸入 0 或留空代表不限',
        validator: (num value) {
          return value >= 0 ? null : '不可小於 0';
        },
      ),
    );

    return _SectionCard(
      title: '優惠內容',
      icon: Icons.redeem_outlined,
      children: children,
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

  Widget _buildRoomTypeSection() {
    final bool suitableForRoomTypes =
        _type != MemberCouponType.freeService &&
        _effectiveApplyTarget != MemberCouponApplyTarget.service;

    return _SectionCard(
      title: '適用房型',
      icon: Icons.meeting_room_outlined,
      children: <Widget>[
        Text(
          suitableForRoomTypes ? '不選代表所有房型皆可使用。' : '免費服務券不需要指定房型。',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        if (suitableForRoomTypes) ...<Widget>[
          const SizedBox(height: 12),
          if (_isLoadingOptions)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_roomTypes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('目前尚未建立房型，優惠券將視為不限房型。'),
            )
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
                  selected: selected,
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

  Widget _buildUsageSection() {
    return _SectionCard(
      title: '使用與顯示設定',
      icon: Icons.settings_outlined,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _numberField(
                controller: _validDaysController,
                label: '發放後有效天數',
                suffixText: '天',
                allowDecimal: false,
                helperText: '0 代表永久有效',
                validator: (num value) {
                  return value >= 0 ? null : '不可小於 0';
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _numberField(
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
        const SizedBox(height: 16),
        _numberField(
          controller: _sortOrderController,
          label: '排序',
          allowDecimal: false,
          helperText: '數字越小越前面，可輸入 0',
          allowNegative: true,
          validator: (num value) {
            return null;
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('啟用優惠券模板'),
          subtitle: const Text('停用後不可再用此模板發券，但已發出的會員優惠券不受影響。'),
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

  Widget _numberField({
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
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffixText,
        helperText: helperText,
        border: const OutlineInputBorder(),
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

  String _targetLabel(MemberCouponApplyTarget target) {
    switch (target) {
      case MemberCouponApplyTarget.room:
        return '只折房價';

      case MemberCouponApplyTarget.roomAndPet:
        return '房價與寵物費';

      case MemberCouponApplyTarget.total:
        return '整張訂單';

      case MemberCouponApplyTarget.service:
        return '指定加購服務';
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

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
              Icon(icon, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
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

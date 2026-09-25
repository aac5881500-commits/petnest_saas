// 檔案名稱：lib/features/shop/pages/shop_discount_campaign_form_page.dart
// 功能說明：依優惠類型顯示對應條件，完成設定後才建立優惠活動
// 🏷️ 新增優惠活動設定頁

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/daycare_plan_model.dart';
import '../../../core/models/daycare_settings_model.dart';
import '../../../core/models/discount_campaign_model.dart';
import '../../../core/models/policy_applicable_service.dart';
import '../../../core/services/daycare_settings_service.dart';
import '../../../core/services/discount_campaign_service.dart';
import '../../../core/services/discount_promo_preview.dart';
import '../../../core/services/shop_room_service.dart';
import '../../../features/shop/widgets/discount_campaign_type_picker.dart';
import '../../../features/shop/widgets/discount_hub_host.dart';
import '../../../features/shop/widgets/discount_promo_preview_card.dart';

class ShopDiscountCampaignComposer extends StatefulWidget {
  const ShopDiscountCampaignComposer({
    super.key,
    required this.shopId,
    this.onDismiss,
  });

  final String shopId;
  final VoidCallback? onDismiss;

  @override
  State<ShopDiscountCampaignComposer> createState() =>
      _ShopDiscountCampaignComposerState();
}

class _ShopDiscountCampaignComposerState
    extends State<ShopDiscountCampaignComposer> {
  DiscountCampaignType? _type;

  @override
  Widget build(BuildContext context) {
    final DiscountCampaignType? type = _type;
    if (type == null) {
      return DiscountCampaignTypePickerPage(
        onPicked: (DiscountCampaignType value) {
          setState(() {
            _type = value;
          });
        },
        onDismiss: widget.onDismiss,
      );
    }
    return ShopDiscountCampaignFormPage(
      shopId: widget.shopId,
      campaignType: type,
      onBackToTypePicker: () {
        setState(() {
          _type = null;
        });
      },
      onDismiss: widget.onDismiss,
    );
  }
}

class ShopDiscountCampaignFormPage extends StatefulWidget {
  const ShopDiscountCampaignFormPage({
    super.key,
    required this.shopId,
    required this.campaignType,
    this.campaign,
    this.onBackToTypePicker,
    this.onDismiss,
  });

  final String shopId;
  final DiscountCampaignType campaignType;
  final DiscountCampaignModel? campaign;
  final VoidCallback? onBackToTypePicker;
  final VoidCallback? onDismiss;

  @override
  State<ShopDiscountCampaignFormPage> createState() =>
      _ShopDiscountCampaignFormPageState();
}

class _ShopDiscountCampaignFormPageState
    extends State<ShopDiscountCampaignFormPage> {
  static const OutlineInputBorder _fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final DiscountCampaignService _campaignService =
      DiscountCampaignService.instance;
  final ShopRoomService _roomService = ShopRoomService.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _discountValueController =
      TextEditingController();
  final TextEditingController _minimumNightsController =
      TextEditingController();
  final TextEditingController _newMemberDiscountNightsController =
      TextEditingController(text: '3');
  final TextEditingController _minimumAmountController =
      TextEditingController();
  final TextEditingController _maximumDiscountController =
      TextEditingController();
  final TextEditingController _memberUsageLimitController =
      TextEditingController(text: '1');
  final TextEditingController _totalUsageLimitController =
      TextEditingController(text: '0');

  DiscountValueType _valueType = DiscountValueType.percent;
  DiscountApplyTarget _applyTarget = DiscountApplyTarget.room;
  DiscountDateMatchType _dateMatchType =
      DiscountDateMatchType.matchingStayDates;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _limitStayDate = false;
  DateTime? _stayStartAt;
  DateTime? _stayEndAt;
  final Set<String> _selectedRoomTypeIds = <String>{};
  bool _enabled = true;
  NewMemberEligibilityMode _newMemberEligibilityMode =
      NewMemberEligibilityMode.createdAfterCampaign;
  bool _allowCouponTogether = false;
  bool _saving = false;
  bool _previewDaycare = false;
  bool _limitedTimeHelpOpen = false;
  List<String> _applicableServices = List<String>.from(
    PolicyApplicableService.accommodationOnly,
  );

  bool get _needsDateRange {
    return widget.campaignType == DiscountCampaignType.stayDate ||
        widget.campaignType == DiscountCampaignType.limitedTime;
  }

  bool get _needsRoomTypes {
    return widget.campaignType == DiscountCampaignType.roomType;
  }

  bool get _needsMinimumNights {
    return widget.campaignType == DiscountCampaignType.longStay;
  }

  bool get _needsMinimumAmount {
    return widget.campaignType == DiscountCampaignType.minimumAmount;
  }

  bool get _isNewMember {
    return widget.campaignType == DiscountCampaignType.newMember;
  }

  bool get _applyTargetLocked {
    return _isNewMember || _needsRoomTypes;
  }

  bool get _includesStay {
    return PolicyApplicableService.appliesTo(
      _applicableServices,
      PolicyApplicableService.accommodation,
    );
  }

  bool get _includesDaycare {
    return PolicyApplicableService.appliesTo(
      _applicableServices,
      PolicyApplicableService.daycare,
    );
  }

  @override
  void initState() {
    super.initState();
    final DiscountCampaignModel? campaign = widget.campaign;
    if (campaign == null) {
      _setDefaultName();
      if (widget.campaignType == DiscountCampaignType.longStay) {
        _applicableServices = List<String>.from(
          PolicyApplicableService.accommodationOnly,
        );
      }
    } else {
      _nameController.text = campaign.name;
      _descriptionController.text = campaign.description;
      _discountValueController.text = campaign.discountValue == 0
          ? ''
          : campaign.discountValue.toString();
      _valueType = campaign.valueType;
      _applyTarget = campaign.applyTarget;
      _enabled = campaign.enabled;
      _startAt = campaign.startAt;
      _endAt = campaign.endAt;
      _dateMatchType =
          campaign.dateMatchType ?? DiscountDateMatchType.matchingStayDates;
      _minimumNightsController.text = campaign.minimumNights == 0
          ? ''
          : campaign.minimumNights.toString();
      _minimumAmountController.text = campaign.minimumAmount == 0
          ? ''
          : campaign.minimumAmount.toString();
      _maximumDiscountController.text = campaign.maximumDiscountAmount == 0
          ? ''
          : campaign.maximumDiscountAmount.toString();
      _memberUsageLimitController.text = campaign.memberUsageLimit.toString();
      _totalUsageLimitController.text = campaign.totalUsageLimit.toString();
      _newMemberDiscountNightsController.text =
          campaign.newMemberDiscountNights == 0
          ? ''
          : campaign.newMemberDiscountNights.toString();
      _newMemberEligibilityMode = campaign.newMemberEligibilityMode;
      _allowCouponTogether = campaign.allowCouponTogether;
      _selectedRoomTypeIds.addAll(campaign.roomTypeIds);
      _limitStayDate = campaign.limitStayDate;
      _stayStartAt = campaign.stayStartAt;
      _stayEndAt = campaign.stayEndAt;
      _applicableServices = List<String>.from(campaign.applicableServices);
      if (widget.campaignType == DiscountCampaignType.longStay) {
        _applicableServices = List<String>.from(
          PolicyApplicableService.accommodationOnly,
        );
      }
    }
    _previewDaycare = _includesDaycare && !_includesStay;
    _nameController.addListener(_refresh);
    _descriptionController.addListener(_refresh);
    _discountValueController.addListener(_refresh);
    _minimumNightsController.addListener(_refresh);
    _newMemberDiscountNightsController.addListener(_refresh);
    _minimumAmountController.addListener(_refresh);
    _maximumDiscountController.addListener(_refresh);
    _memberUsageLimitController.addListener(_refresh);
    _totalUsageLimitController.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setDefaultName() {
    _nameController.text = DiscountCampaignTypeMeta.of(
      widget.campaignType,
    ).title;
  }

  @override
  void dispose() {
    _nameController.removeListener(_refresh);
    _descriptionController.removeListener(_refresh);
    _discountValueController.removeListener(_refresh);
    _minimumNightsController.removeListener(_refresh);
    _newMemberDiscountNightsController.removeListener(_refresh);
    _minimumAmountController.removeListener(_refresh);
    _maximumDiscountController.removeListener(_refresh);
    _memberUsageLimitController.removeListener(_refresh);
    _totalUsageLimitController.removeListener(_refresh);
    _nameController.dispose();
    _descriptionController.dispose();
    _discountValueController.dispose();
    _minimumNightsController.dispose();
    _newMemberDiscountNightsController.dispose();
    _minimumAmountController.dispose();
    _maximumDiscountController.dispose();
    _memberUsageLimitController.dispose();
    _totalUsageLimitController.dispose();
    super.dispose();
  }

  int _readInt(TextEditingController controller, {int defaultValue = 0}) {
    return int.tryParse(controller.text.trim()) ?? defaultValue;
  }

  num _readNum(TextEditingController controller) {
    return num.tryParse(controller.text.trim()) ?? 0;
  }

  String _campaignTypeLabel() {
    return DiscountCampaignTypeMeta.of(widget.campaignType).title;
  }

  String _dateText(DateTime? date, {bool withTime = false}) {
    if (date == null) {
      return '尚未選擇';
    }
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    if (!withTime) {
      return '${date.year}/$month/$day';
    }
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}/$month/$day $hour:$minute';
  }

  String get _headlineSummary {
    final num discount = _readNum(_discountValueController);
    if (discount <= 0 ||
        (_valueType == DiscountValueType.percent && discount >= 100)) {
      return '請完成優惠內容與適用條件。';
    }
    if (_needsMinimumNights && _readInt(_minimumNightsController) <= 0) {
      return '請完成優惠內容與適用條件。';
    }
    if (_needsMinimumAmount && _readInt(_minimumAmountController) <= 0) {
      return '請完成優惠內容與適用條件。';
    }
    if (_needsDateRange && (_startAt == null || _endAt == null)) {
      return '請完成優惠內容與適用條件。';
    }
    if (_needsRoomTypes && _selectedRoomTypeIds.isEmpty) {
      return '請完成優惠內容與適用條件。';
    }
    if (_isNewMember &&
        _includesStay &&
        _readInt(_newMemberDiscountNightsController) <= 0) {
      return '請完成優惠內容與適用條件。';
    }
    final String benefit = _valueType == DiscountValueType.percent
        ? '享 ${_foldLabel(discount)}'
        : '折抵 ${DiscountPromoPreview.nt(discount.round())}';
    final int maxOff = _readInt(_maximumDiscountController);
    final String maxPart = _valueType == DiscountValueType.percent && maxOff > 0
        ? '｜最高折抵 ${DiscountPromoPreview.nt(maxOff)}'
        : '';
    return '${_campaignTypeLabel()}｜${PolicyApplicableService.displayLabel(_applicableServices)}｜$benefit$maxPart｜${_enabled ? '啟用中' : '未啟用'}';
  }

  String _foldLabel(num percent) {
    final num pay = 100 - percent;
    if (pay % 10 == 0) {
      return '${(pay / 10).toStringAsFixed(0)} 折';
    }
    return '折扣 ${percent.toString()}%';
  }

  Future<void> _pickStartDate({bool withTime = false}) async {
    final DateTime now = DateTime.now();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _startAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (selected == null || !mounted) {
      return;
    }
    TimeOfDay time = TimeOfDay(
      hour: _startAt?.hour ?? 0,
      minute: _startAt?.minute ?? 0,
    );
    if (withTime) {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: time,
      );
      if (picked != null) {
        time = picked;
      }
    }
    setState(() {
      _startAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        time.hour,
        time.minute,
      );
      if (_endAt != null && _endAt!.isBefore(_startAt!)) {
        _endAt = null;
      }
    });
  }

  Future<void> _pickEndDate({bool withTime = false}) async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = _startAt ?? now;
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _endAt ?? firstDate,
      firstDate: DateTime(firstDate.year, firstDate.month, firstDate.day),
      lastDate: DateTime(now.year + 10),
    );
    if (selected == null || !mounted) {
      return;
    }
    TimeOfDay time = TimeOfDay(
      hour: _endAt?.hour ?? 23,
      minute: _endAt?.minute ?? 59,
    );
    if (withTime) {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: time,
      );
      if (picked != null) {
        time = picked;
      }
    } else {
      time = const TimeOfDay(hour: 23, minute: 59);
    }
    setState(() {
      _endAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        time.hour,
        time.minute,
        withTime ? 0 : 59,
      );
    });
  }

  Future<void> _pickStayStartDate() async {
    final DateTime now = DateTime.now();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _stayStartAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _stayStartAt = DateTime(selected.year, selected.month, selected.day);
      if (_stayEndAt != null && _stayEndAt!.isBefore(_stayStartAt!)) {
        _stayEndAt = null;
      }
    });
  }

  Future<void> _pickStayEndDate() async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = _stayStartAt ?? now;
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _stayEndAt ?? firstDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 10),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _stayEndAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        23,
        59,
        59,
      );
    });
  }

  String? _validateDiscountValue(String? value) {
    final num? number = num.tryParse(value?.trim() ?? '');
    if (number == null || number <= 0) {
      return '請輸入正確的折扣數值';
    }
    if (_valueType == DiscountValueType.percent && number >= 100) {
      return '折扣百分比必須小於 100';
    }
    return null;
  }

  bool _validateSpecialConditions() {
    if (_needsMinimumNights && _readInt(_minimumNightsController) <= 0) {
      _showMessage('請設定最低入住晚數');
      return false;
    }
    if (_needsMinimumAmount && _readInt(_minimumAmountController) <= 0) {
      _showMessage('請設定最低消費金額');
      return false;
    }
    if (_isNewMember &&
        _includesStay &&
        _readInt(_newMemberDiscountNightsController) <= 0) {
      _showMessage('請設定新會員優惠晚數');
      return false;
    }
    if (_needsDateRange && (_startAt == null || _endAt == null)) {
      _showMessage('請選擇活動開始與結束日期');
      return false;
    }
    if (_needsRoomTypes && _selectedRoomTypeIds.isEmpty) {
      _showMessage(
        _includesDaycare && !_includesStay ? '請至少選擇一個安親方案／房型' : '請至少選擇一個適用房型',
      );
      return false;
    }
    if (_needsRoomTypes && _limitStayDate) {
      if (_stayStartAt == null || _stayEndAt == null) {
        _showMessage('請選擇指定房型優惠的住宿開始日與結束日');
        return false;
      }
      if (_stayEndAt!.isBefore(_stayStartAt!)) {
        _showMessage('住宿結束日不可早於住宿開始日');
        return false;
      }
    }
    return true;
  }

  DiscountCampaignModel get _previewCampaign {
    return DiscountCampaignModel(
      id: widget.campaign?.id ?? 'preview',
      shopId: widget.shopId,
      name: _nameController.text.trim().isEmpty
          ? _campaignTypeLabel()
          : _nameController.text.trim(),
      type: widget.campaignType,
      valueType: _valueType,
      applyTarget: _applyTargetLocked ? DiscountApplyTarget.room : _applyTarget,
      discountValue: _readNum(_discountValueController),
      enabled: _enabled,
      createdAt: widget.campaign?.createdAt ?? DateTime(2026, 1, 1),
      updatedAt: DateTime.now(),
      description: _descriptionController.text.trim(),
      startAt: _startAt,
      endAt: _endAt,
      dateMatchType: widget.campaignType == DiscountCampaignType.stayDate
          ? _dateMatchType
          : null,
      minimumNights: _readInt(_minimumNightsController),
      minimumAmount: _readInt(_minimumAmountController),
      maximumDiscountAmount: _readInt(_maximumDiscountController),
      memberUsageLimit: _readInt(_memberUsageLimitController),
      totalUsageLimit: _readInt(_totalUsageLimitController),
      newMemberEligibilityMode: _newMemberEligibilityMode,
      allowCouponTogether: _allowCouponTogether,
      roomTypeIds: _selectedRoomTypeIds.toList(),
      applicableServices: widget.campaignType == DiscountCampaignType.longStay
          ? PolicyApplicableService.accommodationOnly
          : _applicableServices,
      newMemberDiscountNights: _readInt(_newMemberDiscountNightsController),
      limitStayDate: _limitStayDate,
      stayStartAt: _stayStartAt,
      stayEndAt: _stayEndAt,
    );
  }

  Future<void> _saveCampaign() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_validateSpecialConditions()) {
      return;
    }
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      final List<String> services =
          widget.campaignType == DiscountCampaignType.longStay
          ? List<String>.from(PolicyApplicableService.accommodationOnly)
          : PolicyApplicableService.parse(_applicableServices);
      if (widget.campaign == null) {
        await _campaignService.createCampaign(
          shopId: widget.shopId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          type: widget.campaignType,
          valueType: _valueType,
          applyTarget: _applyTargetLocked
              ? DiscountApplyTarget.room
              : _applyTarget,
          discountValue: num.parse(_discountValueController.text.trim()),
          enabled: _enabled,
          startAt: _startAt,
          endAt: _endAt,
          dateMatchType: widget.campaignType == DiscountCampaignType.stayDate
              ? _dateMatchType
              : null,
          minimumNights: _needsMinimumNights
              ? _readInt(_minimumNightsController)
              : 0,
          minimumAmount: _needsMinimumAmount
              ? _readInt(_minimumAmountController)
              : 0,
          maximumDiscountAmount: _valueType == DiscountValueType.percent
              ? _readInt(_maximumDiscountController)
              : 0,
          memberUsageLimit: _readInt(_memberUsageLimitController),
          totalUsageLimit: _readInt(_totalUsageLimitController),
          firstBookingOnly: false,
          newMemberEligibilityMode: _newMemberEligibilityMode,
          allowCouponTogether: _allowCouponTogether,
          roomTypeIds: _selectedRoomTypeIds.toList(),
          applicableServices: services,
          newMemberDiscountNights: _isNewMember && _includesStay
              ? _readInt(_newMemberDiscountNightsController)
              : (_isNewMember
                    ? widget.campaign?.newMemberDiscountNights ?? 0
                    : 0),
          limitStayDate: _needsRoomTypes ? _limitStayDate : false,
          stayStartAt: _needsRoomTypes && _limitStayDate ? _stayStartAt : null,
          stayEndAt: _needsRoomTypes && _limitStayDate ? _stayEndAt : null,
        );
      } else {
        await _campaignService.updateCampaign(
          shopId: widget.shopId,
          campaignId: widget.campaign!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          type: widget.campaignType,
          valueType: _valueType,
          applyTarget: _applyTargetLocked
              ? DiscountApplyTarget.room
              : _applyTarget,
          discountValue: num.parse(_discountValueController.text.trim()),
          enabled: _enabled,
          startAt: _startAt,
          endAt: _endAt,
          dateMatchType: widget.campaignType == DiscountCampaignType.stayDate
              ? _dateMatchType
              : null,
          minimumNights: _needsMinimumNights
              ? _readInt(_minimumNightsController)
              : 0,
          minimumAmount: _needsMinimumAmount
              ? _readInt(_minimumAmountController)
              : 0,
          maximumDiscountAmount: _valueType == DiscountValueType.percent
              ? _readInt(_maximumDiscountController)
              : 0,
          memberUsageLimit: _readInt(_memberUsageLimitController),
          totalUsageLimit: _readInt(_totalUsageLimitController),
          firstBookingOnly: false,
          newMemberEligibilityMode: _newMemberEligibilityMode,
          allowCouponTogether: _allowCouponTogether,
          roomTypeIds: _selectedRoomTypeIds.toList(),
          applicableServices: services,
          newMemberDiscountNights: _isNewMember && _includesStay
              ? _readInt(_newMemberDiscountNightsController)
              : widget.campaign!.newMemberDiscountNights,
          limitStayDate: _needsRoomTypes ? _limitStayDate : false,
          stayStartAt: _needsRoomTypes && _limitStayDate ? _stayStartAt : null,
          stayEndAt: _needsRoomTypes && _limitStayDate ? _stayEndAt : null,
        );
      }
      if (!mounted) {
        return;
      }
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      _leave(saved: true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(widget.campaign == null ? '優惠活動建立成功' : '優惠活動已更新'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('儲存失敗，請稍後再試');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _leave({bool saved = false}) {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
      return;
    }
    Navigator.pop(context, saved);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _input(String label, {String? hint, String? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      border: _fieldBorder,
      enabledBorder: _fieldBorder.copyWith(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _enabledRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: _enabled
            ? const Color(0xFF2E7D32).withValues(alpha: 0.08)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _enabled ? '儲存後，符合資格的新訂單可套用此優惠。' : '活動會保留，但新訂單不會套用。',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _enabled
                    ? const Color(0xFF2E7D32)
                    : Colors.grey.shade700,
              ),
            ),
          ),
          Switch(
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

  Widget _choiceCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final bool enabled = onTap != null;
    return Material(
      color: selected ? const Color(0xFFE3F2FD) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF1565C0) : Colors.grey.shade300,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: enabled ? Colors.black87 : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: enabled ? Colors.grey.shade700 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceRow(List<Widget> cards) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: <Widget>[
              for (int i = 0; i < cards.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: 8),
                cards[i],
              ],
            ],
          );
        }
        return Row(
          children: <Widget>[
            for (int i = 0; i < cards.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _dateCard({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _narrowField(Widget child) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: child,
      ),
    );
  }

  Widget _buildBasicCard() {
    return _card('基本資料', <Widget>[
      TextFormField(
        controller: _nameController,
        decoration: _input('優惠名稱', hint: '例如：暑假住房優惠'),
        validator: (String? value) {
          if (value == null || value.trim().isEmpty) {
            return '請輸入優惠名稱';
          }
          return null;
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _descriptionController,
        maxLines: 2,
        decoration: _input('活動說明', hint: '會員在預約時可以看到這段說明'),
      ),
      const SizedBox(height: 8),
      _enabledRow(),
    ]);
  }

  Widget _buildDiscountCard() {
    return _card('優惠內容', <Widget>[
      const Text('折扣方式', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      _choiceRow(<Widget>[
        _choiceCard(
          title: '百分比折扣',
          subtitle: '例如 10 即享 9 折',
          selected: _valueType == DiscountValueType.percent,
          onTap: () {
            setState(() {
              _valueType = DiscountValueType.percent;
            });
          },
        ),
        _choiceCard(
          title: '固定金額折抵',
          subtitle: '直接折抵指定金額',
          selected: _valueType == DiscountValueType.fixedAmount,
          onTap: () {
            setState(() {
              _valueType = DiscountValueType.fixedAmount;
            });
          },
        ),
      ]),
      const SizedBox(height: 12),
      if (_valueType == DiscountValueType.percent)
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 560;
            final Widget percent = _narrowField(
              TextFormField(
                controller: _discountValueController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: _input('折扣百分比', hint: '例如 10', suffix: '%'),
                validator: _validateDiscountValue,
              ),
            );
            final Widget maxField = _narrowField(
              TextFormField(
                controller: _maximumDiscountController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: _input('最高折抵金額（可選）', hint: '空白為不限制', suffix: '元'),
              ),
            );
            if (!wide) {
              return Column(
                children: <Widget>[
                  percent,
                  const SizedBox(height: 12),
                  maxField,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: percent),
                const SizedBox(width: 12),
                Expanded(child: maxField),
              ],
            );
          },
        )
      else
        _narrowField(
          TextFormField(
            controller: _discountValueController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: _input('折抵金額', hint: '例如 300', suffix: '元'),
            validator: _validateDiscountValue,
          ),
        ),
      const SizedBox(height: 14),
      const Text('折扣套用範圍', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      _choiceRow(<Widget>[
        _choiceCard(
          title: '只房價',
          subtitle: _applyTargetLocked ? '此類型固定只折房價／方案' : '只計算房價或方案金額',
          selected: _applyTarget == DiscountApplyTarget.room,
          onTap: _applyTargetLocked
              ? null
              : () {
                  setState(() {
                    _applyTarget = DiscountApplyTarget.room;
                  });
                },
        ),
        _choiceCard(
          title: '房價＋加購',
          subtitle: _applyTargetLocked ? '此類型不可改為含加購' : '含寵物加價與加值服務',
          selected: _applyTarget == DiscountApplyTarget.total,
          onTap: _applyTargetLocked
              ? null
              : () {
                  setState(() {
                    _applyTarget = DiscountApplyTarget.total;
                  });
                },
        ),
        if (_applyTarget == DiscountApplyTarget.roomAndPet)
          _choiceCard(
            title: '房價＋寵物',
            subtitle: '沿用既有設定',
            selected: true,
            onTap: _applyTargetLocked
                ? null
                : () {
                    setState(() {
                      _applyTarget = DiscountApplyTarget.roomAndPet;
                    });
                  },
          ),
      ]),
      if (_applyTargetLocked) ...<Widget>[
        const SizedBox(height: 8),
        Text(
          _isNewMember ? '新會員優惠固定只折房價。' : '指定房型／方案優惠固定只折房價或方案金額。',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    ]);
  }

  Widget _buildServiceCard() {
    final bool longStay = widget.campaignType == DiscountCampaignType.longStay;
    return _card('適用服務與條件', <Widget>[
      DiscountServiceChoice(
        services: _applicableServices,
        lockedStayOnly: longStay,
        lockReason: '此類型不適用',
        onChanged: (List<String> value) {
          setState(() {
            _applicableServices = value;
            _previewDaycare = _includesDaycare && !_includesStay;
            if (!_includesStay) {
              _newMemberDiscountNightsController.text = '0';
            } else if (_isNewMember &&
                _readInt(_newMemberDiscountNightsController) <= 0) {
              _newMemberDiscountNightsController.text = '3';
            }
          });
        },
      ),
    ]);
  }

  Widget _buildTypeConditionCard() {
    return _card('此優惠專屬條件', <Widget>[
      if (_needsMinimumNights) ...<Widget>[
        _narrowField(
          TextFormField(
            controller: _minimumNightsController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: _input('最低入住晚數', hint: '例如 7', suffix: '晚'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '以住宿晚數計算，安親不適用。',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
      if (_needsMinimumAmount) ...<Widget>[
        _narrowField(
          TextFormField(
            controller: _minimumAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: _input('最低消費金額', hint: '例如 3000', suffix: '元'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _applyTarget == DiscountApplyTarget.room
              ? '門檻依「只房價／方案金額」判定。'
              : _applyTarget == DiscountApplyTarget.roomAndPet
              ? '門檻依「房價＋寵物加價」判定。'
              : '門檻依「房價＋加購（整張訂單）」判定。',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
      if (_isNewMember) ...<Widget>[
        const Text('新會員資格判斷方式', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _choiceRow(<Widget>[
          _choiceCard(
            title: '活動建立後加入',
            subtitle: '僅新加入本店的會員',
            selected:
                _newMemberEligibilityMode ==
                NewMemberEligibilityMode.createdAfterCampaign,
            onTap: () {
              setState(() {
                _newMemberEligibilityMode =
                    NewMemberEligibilityMode.createdAfterCampaign;
              });
            },
          ),
          _choiceCard(
            title: '本店無有效訂單',
            subtitle: '尚未有有效訂單即可使用',
            selected:
                _newMemberEligibilityMode ==
                NewMemberEligibilityMode.noPreviousBooking,
            onTap: () {
              setState(() {
                _newMemberEligibilityMode =
                    NewMemberEligibilityMode.noPreviousBooking;
              });
            },
          ),
        ]),
        if (_includesStay) ...<Widget>[
          const SizedBox(height: 12),
          _narrowField(
            TextFormField(
              controller: _newMemberDiscountNightsController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: _input('可使用的優惠晚數', hint: '例如 3', suffix: '晚'),
              validator: (String? value) {
                if (!_includesStay) {
                  return null;
                }
                final int nights = int.tryParse(value?.trim() ?? '') ?? 0;
                if (nights <= 0) {
                  return '請輸入正確的優惠晚數';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '住宿優惠晚數可分次使用。安親不會使用免費住宿晚數。',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
        if (_includesDaycare) ...<Widget>[
          const SizedBox(height: 12),
          _narrowField(
            TextFormField(
              controller: _memberUsageLimitController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: _input('安親折抵次數', hint: '0 為不限次數', suffix: '次'),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _readInt(_memberUsageLimitController) <= 0
                ? '安親折抵次數：不限次數'
                : '安親每完成一筆符合資格的訂單計 1 次。',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ],
      if (_needsDateRange) ...<Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _dateCard(
                label: widget.campaignType == DiscountCampaignType.limitedTime
                    ? '下單開始'
                    : '開始日期',
                value: _dateText(
                  _startAt,
                  withTime:
                      widget.campaignType == DiscountCampaignType.limitedTime,
                ),
                onTap: () => _pickStartDate(
                  withTime:
                      widget.campaignType == DiscountCampaignType.limitedTime,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('至', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: _dateCard(
                label: widget.campaignType == DiscountCampaignType.limitedTime
                    ? '下單結束'
                    : '結束日期',
                value: _dateText(
                  _endAt,
                  withTime:
                      widget.campaignType == DiscountCampaignType.limitedTime,
                ),
                onTap: () => _pickEndDate(
                  withTime:
                      widget.campaignType == DiscountCampaignType.limitedTime,
                ),
              ),
            ),
          ],
        ),
      ],
      if (widget.campaignType == DiscountCampaignType.stayDate) ...<Widget>[
        const SizedBox(height: 12),
        const Text('日期涵蓋方式', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _choiceRow(<Widget>[
          _choiceCard(
            title: '重疊日期',
            subtitle: '只折活動日期內的房價',
            selected: _dateMatchType == DiscountDateMatchType.matchingStayDates,
            onTap: () {
              setState(() {
                _dateMatchType = DiscountDateMatchType.matchingStayDates;
              });
            },
          ),
          _choiceCard(
            title: '入住日',
            subtitle: '入住日落在期間即可',
            selected: _dateMatchType == DiscountDateMatchType.checkInDate,
            onTap: () {
              setState(() {
                _dateMatchType = DiscountDateMatchType.checkInDate;
              });
            },
          ),
          _choiceCard(
            title: '整段住宿',
            subtitle: '全程都要在期間內',
            selected: _dateMatchType == DiscountDateMatchType.entireStay,
            onTap: () {
              setState(() {
                _dateMatchType = DiscountDateMatchType.entireStay;
              });
            },
          ),
        ]),
      ],
      if (widget.campaignType == DiscountCampaignType.limitedTime) ...<Widget>[
        const SizedBox(height: 12),
        Material(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _limitedTimeHelpOpen = !_limitedTimeHelpOpen;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.info_outline, color: Color(0xFFF9A825)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '限時下單怎麼判斷？',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Icon(
                        _limitedTimeHelpOpen
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                    ],
                  ),
                  if (_limitedTimeHelpOpen) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      '會員必須在你設定的下單期間內完成預約才享有優惠。住宿或安親服務日期可以在期間結束之後。例如活動 7/20–7/25，7/23 下單、8 月入住仍可套用。',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
      if (_needsRoomTypes) _buildRoomTypeSelector(),
    ]);
  }

  Widget _chipWrap({
    required String title,
    required List<Map<String, String>> items,
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(emptyText),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((Map<String, String> item) {
            final String id = item['id'] ?? '';
            final bool selected = _selectedRoomTypeIds.contains(id);
            return FilterChip(
              label: Text(item['name'] ?? '未命名'),
              selected: selected,
              onSelected: (bool value) {
                setState(() {
                  if (value) {
                    _selectedRoomTypeIds.add(id);
                  } else {
                    _selectedRoomTypeIds.remove(id);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRoomTypeSelector() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _roomService.streamRoomTypes(widget.shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> roomSnap,
          ) {
            return StreamBuilder<DaycareSettingsModel>(
              stream: DaycareSettingsService.instance.stream(widget.shopId),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<DaycareSettingsModel> daycareSnap,
                  ) {
                    final List<Map<String, String>> lodging =
                        <Map<String, String>>[
                          for (final Map<String, dynamic> room
                              in roomSnap.data ??
                                  const <Map<String, dynamic>>[])
                            <String, String>{
                              'id': (room['id'] ?? '').toString(),
                              'name': (room['name'] ?? '未命名房型').toString(),
                            },
                        ];
                    final DaycareSettingsModel? daycare = daycareSnap.data;
                    final List<Map<String, String>> daycareItems =
                        <Map<String, String>>[];
                    if (daycare != null) {
                      if (daycare.isRoomBased) {
                        for (final DaycareRoomTypeSetting setting
                            in daycare.roomTypes) {
                          final String id = setting.roomTypeId.trim();
                          if (id.isEmpty) {
                            continue;
                          }
                          String name = id;
                          for (final Map<String, String> room in lodging) {
                            if (room['id'] == id) {
                              name = room['name'] ?? id;
                              break;
                            }
                          }
                          daycareItems.add(<String, String>{
                            'id': id,
                            'name': name,
                          });
                        }
                      } else {
                        for (final DaycarePlanModel plan in daycare.plans) {
                          daycareItems.add(<String, String>{
                            'id': plan.id,
                            'name': plan.name,
                          });
                        }
                      }
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: 12),
                        if (_includesStay)
                          _chipWrap(
                            title: '住宿房型',
                            items: lodging,
                            emptyText: '目前尚未建立住宿房型。',
                          ),
                        if (_includesStay && _includesDaycare)
                          const SizedBox(height: 14),
                        if (_includesDaycare)
                          _chipWrap(
                            title: daycare?.isRoomBased == true
                                ? '安親房型'
                                : '安親方案',
                            items: daycareItems,
                            emptyText: '目前尚未設定安親房型或方案。',
                          ),
                        if (_includesStay) ...<Widget>[
                          const SizedBox(height: 12),
                          DiscountToggleCard(
                            title: '限制住宿優惠日期',
                            subtitle: _limitStayDate
                                ? '開啟後，只有住宿日期落在指定期間內才會套用。'
                                : '關閉時不限制住宿日期。',
                            value: _limitStayDate,
                            onLabel: '限制日期',
                            offLabel: '不限制',
                            onChanged: (bool value) {
                              setState(() {
                                _limitStayDate = value;
                                if (!value) {
                                  _stayStartAt = null;
                                  _stayEndAt = null;
                                }
                              });
                            },
                          ),
                          if (_limitStayDate)
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _dateCard(
                                    label: '住宿開始',
                                    value: _dateText(_stayStartAt),
                                    onTap: _pickStayStartDate,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '至',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _dateCard(
                                    label: '住宿結束',
                                    value: _dateText(_stayEndAt),
                                    onTap: _pickStayEndDate,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ],
                    );
                  },
            );
          },
    );
  }

  Widget _buildLimitCard() {
    final int total = _readInt(_totalUsageLimitController);
    final int member = _readInt(_memberUsageLimitController);
    return _card('使用限制', <Widget>[
      if (!_isNewMember) ...<Widget>[
        _narrowField(
          TextFormField(
            controller: _memberUsageLimitController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: _input('每位會員最多使用次數', hint: '0 為不限次數', suffix: '次'),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          member <= 0 ? '每位會員：不限次數' : '每位會員最多 $member 次',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
      ],
      _narrowField(
        TextFormField(
          controller: _totalUsageLimitController,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: _input('活動總使用次數', hint: '0 為不限次數', suffix: '次'),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        total <= 0 ? '活動總量：不限次數' : '全店最多 $total 次',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      ),
      const SizedBox(height: 12),
      DiscountToggleCard(
        title: '允許搭配會員折價券',
        subtitle: _allowCouponTogether
            ? '符合資格的會員券可與此自動優惠同時使用。'
            : '會員持有優惠券時，本活動不與優惠券併用。',
        value: _allowCouponTogether,
        onChanged: (bool value) {
          setState(() {
            _allowCouponTogether = value;
          });
        },
      ),
    ]);
  }

  Widget _previewCard() {
    final bool both = _includesStay && _includesDaycare;
    final DiscountPromoPreviewResult result =
        DiscountPromoPreview.forCampaignResult(
          campaign: _previewCampaign,
          previewDaycare: both ? _previewDaycare : _includesDaycare,
        );
    return DiscountPromoPreviewCard.fromResult(
      result,
      header: both
          ? SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text('住宿示意')),
                ButtonSegment<bool>(value: true, label: Text('安親示意')),
              ],
              selected: <bool>{_previewDaycare},
              onSelectionChanged: (Set<bool> value) {
                setState(() {
                  _previewDaycare = value.first;
                });
              },
            )
          : null,
    );
  }

  Widget _formCards() {
    return Column(
      children: <Widget>[
        _buildBasicCard(),
        const SizedBox(height: 12),
        _buildDiscountCard(),
        const SizedBox(height: 12),
        _buildServiceCard(),
        const SizedBox(height: 12),
        _buildTypeConditionCard(),
        const SizedBox(height: 12),
        _buildLimitCard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final DiscountCampaignTypeMeta meta = DiscountCampaignTypeMeta.of(
      widget.campaignType,
    );
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(
            widget.onBackToTypePicker == null ? Icons.close : Icons.arrow_back,
          ),
          onPressed: widget.onBackToTypePicker ?? _leave,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.campaign == null
                  ? '建立${_campaignTypeLabel()}'
                  : '編輯${_campaignTypeLabel()}',
            ),
            Text(
              _headlineSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (widget.onBackToTypePicker != null)
            IconButton(icon: const Icon(Icons.close), onPressed: _leave),
        ],
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool split = constraints.maxWidth >= 760;
            final Widget preview = _previewCard();
            if (!split) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: <Widget>[
                      _typeBanner(meta),
                      const SizedBox(height: 12),
                      _formCards(),
                      const SizedBox(height: 12),
                      preview,
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        flex: 11,
                        child: ListView(
                          children: <Widget>[
                            _typeBanner(meta),
                            const SizedBox(height: 12),
                            _formCards(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 360,
                        child: SingleChildScrollView(child: preview),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _saveCampaign,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(
              _saving ? '儲存中…' : (widget.campaign == null ? '確認建立優惠' : '儲存變更'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeBanner(DiscountCampaignTypeMeta meta) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: meta.tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: meta.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          Icon(meta.icon, color: meta.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  meta.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '適用服務：${PolicyApplicableService.displayLabel(_applicableServices)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

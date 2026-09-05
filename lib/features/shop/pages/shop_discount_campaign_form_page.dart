// 檔案名稱：lib/features/shop/pages/shop_discount_campaign_form_page.dart
// 功能說明：依優惠類型顯示對應條件，完成設定後才建立優惠活動
// 🏷️ 新增優惠活動設定頁

import 'package:flutter/material.dart';

import '../../../core/models/discount_campaign_model.dart';
import '../../../core/services/discount_campaign_service.dart';
import '../../../core/services/shop_room_service.dart';

class ShopDiscountCampaignFormPage extends StatefulWidget {
  const ShopDiscountCampaignFormPage({
    super.key,
    required this.shopId,
    required this.campaignType,
  });

  final String shopId;
  final DiscountCampaignType campaignType;

  @override
  State<ShopDiscountCampaignFormPage> createState() =>
      _ShopDiscountCampaignFormPageState();
}

class _ShopDiscountCampaignFormPageState
    extends State<ShopDiscountCampaignFormPage> {
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

  /// 指定房型優惠是否限制住宿日期
  bool _limitStayDate = false;

  /// 指定房型優惠適用的住宿開始日期
  DateTime? _stayStartAt;

  /// 指定房型優惠適用的住宿結束日期
  DateTime? _stayEndAt;

  final Set<String> _selectedRoomTypeIds = <String>{};

  bool _enabled = true;

  NewMemberEligibilityMode _newMemberEligibilityMode =
      NewMemberEligibilityMode.createdAfterCampaign;

  bool _allowCouponTogether = false;
  bool _saving = false;

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

  @override
  void initState() {
    super.initState();
    _setDefaultName();
  }

  void _setDefaultName() {
    switch (widget.campaignType) {
      case DiscountCampaignType.longStay:
        _nameController.text = '長住優惠';
        break;

      case DiscountCampaignType.newMember:
        _nameController.text = '新會員優惠';
        break;

      case DiscountCampaignType.googleReview:
        _nameController.text = 'Google 評論優惠';
        break;

      case DiscountCampaignType.stayDate:
        _nameController.text = '特定住宿日期優惠';
        break;

      case DiscountCampaignType.roomType:
        _nameController.text = '指定房型優惠';
        break;

      case DiscountCampaignType.minimumAmount:
        _nameController.text = '滿額優惠';
        break;

      case DiscountCampaignType.limitedTime:
        _nameController.text = '限時下單優惠';
        break;
    }
  }

  @override
  void dispose() {
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

  String _campaignTypeLabel() {
    switch (widget.campaignType) {
      case DiscountCampaignType.longStay:
        return '長住優惠';

      case DiscountCampaignType.newMember:
        return '新會員優惠';
      case DiscountCampaignType.googleReview:
        return 'Google 評論優惠';

      case DiscountCampaignType.stayDate:
        return '特定住宿日期';

      case DiscountCampaignType.roomType:
        return '指定房型';

      case DiscountCampaignType.minimumAmount:
        return '滿額優惠';

      case DiscountCampaignType.limitedTime:
        return '限時下單優惠';
    }
  }

  String _dateText(DateTime? date) {
    if (date == null) {
      return '尚未選擇';
    }

    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '${date.year}/$month/$day';
  }

  Future<void> _pickStartDate() async {
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

    setState(() {
      _startAt = DateTime(selected.year, selected.month, selected.day);

      if (_endAt != null && _endAt!.isBefore(_startAt!)) {
        _endAt = null;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = _startAt ?? now;

    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _endAt ?? firstDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 10),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      // 結束日期設為當天最後一秒
      _endAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        23,
        59,
        59,
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

    if (_isNewMember && _readInt(_newMemberDiscountNightsController) <= 0) {
      _showMessage('請設定新會員優惠晚數');
      return false;
    }

    if (_needsDateRange && (_startAt == null || _endAt == null)) {
      _showMessage('請選擇活動開始與結束日期');
      return false;
    }

    if (_needsRoomTypes && _selectedRoomTypeIds.isEmpty) {
      _showMessage('請至少選擇一個適用房型');
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

  Future<void> _createCampaign() async {
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
      await _campaignService.createCampaign(
        shopId: widget.shopId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: widget.campaignType,
        valueType: _valueType,
        applyTarget: (_isNewMember || _needsRoomTypes)
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
        newMemberDiscountNights: _isNewMember
            ? _readInt(_newMemberDiscountNightsController)
            : 0,
        limitStayDate: _needsRoomTypes ? _limitStayDate : false,
        stayStartAt: _needsRoomTypes && _limitStayDate ? _stayStartAt : null,
        stayEndAt: _needsRoomTypes && _limitStayDate ? _stayEndAt : null,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('優惠活動建立成功')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('建立失敗：$error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildCommonSection() {
    return _SectionCard(
      title: '基本資料',
      children: <Widget>[
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '優惠名稱',
            hintText: '例如：暑假住房優惠',
            border: OutlineInputBorder(),
          ),
          validator: (String? value) {
            if (value == null || value.trim().isEmpty) {
              return '請輸入優惠名稱';
            }

            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '活動說明',
            hintText: '會員在預約時可以看到這段說明',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountSection() {
    return _SectionCard(
      title: '折扣內容',
      children: <Widget>[
        DropdownButtonFormField<DiscountValueType>(
          initialValue: _valueType,
          decoration: const InputDecoration(
            labelText: '折扣方式',
            border: OutlineInputBorder(),
          ),
          items: const <DropdownMenuItem<DiscountValueType>>[
            DropdownMenuItem<DiscountValueType>(
              value: DiscountValueType.percent,
              child: Text('百分比折扣'),
            ),
            DropdownMenuItem<DiscountValueType>(
              value: DiscountValueType.fixedAmount,
              child: Text('固定金額折抵'),
            ),
          ],
          onChanged: (DiscountValueType? value) {
            if (value == null) {
              return;
            }

            setState(() {
              _valueType = value;
              _discountValueController.clear();
            });
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _discountValueController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _valueType == DiscountValueType.percent
                ? '折扣百分比'
                : '折抵金額',
            hintText: _valueType == DiscountValueType.percent
                ? '例如：輸入 15，代表折扣 15%，會員享 85 折'
                : '例如：輸入 300，代表折抵 300 元',
            suffixText: _valueType == DiscountValueType.percent ? '%' : '元',
            border: const OutlineInputBorder(),
          ),
          validator: _validateDiscountValue,
        ),
        const SizedBox(height: 14),
        if (_isNewMember || _needsRoomTypes)
          InputDecorator(
            decoration: const InputDecoration(
              labelText: '折扣套用範圍',
              border: OutlineInputBorder(),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.hotel_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isNewMember ? '只折房價（新會員優惠固定）' : '只折房價（指定房型優惠固定）',
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<DiscountApplyTarget>(
            initialValue: _applyTarget,
            decoration: const InputDecoration(
              labelText: '折扣套用範圍',
              border: OutlineInputBorder(),
            ),
            items: const <DropdownMenuItem<DiscountApplyTarget>>[
              DropdownMenuItem<DiscountApplyTarget>(
                value: DiscountApplyTarget.room,
                child: Text('只折房價'),
              ),
              DropdownMenuItem<DiscountApplyTarget>(
                value: DiscountApplyTarget.roomAndPet,
                child: Text('房價＋寵物加價'),
              ),
              DropdownMenuItem<DiscountApplyTarget>(
                value: DiscountApplyTarget.total,
                child: Text('整張訂單（包含加值服務）'),
              ),
            ],
            onChanged: (DiscountApplyTarget? value) {
              if (value == null) {
                return;
              }

              setState(() {
                _applyTarget = value;
              });
            },
          ),
        if (_valueType == DiscountValueType.percent) ...[
          const SizedBox(height: 14),
          TextFormField(
            controller: _maximumDiscountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '最高折抵金額',
              hintText: '輸入 0 代表不限制',
              suffixText: '元',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTypeConditionSection() {
    return _SectionCard(
      title: '${_campaignTypeLabel()}條件',
      children: <Widget>[
        if (_needsMinimumNights)
          TextFormField(
            controller: _minimumNightsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '最低入住晚數',
              hintText: '例如：入住滿 7 晚',
              suffixText: '晚',
              border: OutlineInputBorder(),
            ),
          ),

        if (_needsMinimumAmount)
          TextFormField(
            controller: _minimumAmountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '最低消費金額',
              hintText: '例如：消費滿 3000 元',
              suffixText: '元',
              border: OutlineInputBorder(),
            ),
          ),

        if (_isNewMember) ...<Widget>[
          DropdownButtonFormField<NewMemberEligibilityMode>(
            initialValue: _newMemberEligibilityMode,
            decoration: const InputDecoration(
              labelText: '新會員資格判斷',
              border: OutlineInputBorder(),
            ),
            items: const <DropdownMenuItem<NewMemberEligibilityMode>>[
              DropdownMenuItem<NewMemberEligibilityMode>(
                value: NewMemberEligibilityMode.createdAfterCampaign,
                child: Text('活動建立後才加入的新會員'),
              ),
              DropdownMenuItem<NewMemberEligibilityMode>(
                value: NewMemberEligibilityMode.noPreviousBooking,
                child: Text('本店尚未有有效訂單的會員'),
              ),
            ],
            onChanged: (NewMemberEligibilityMode? value) {
              if (value == null) {
                return;
              }

              setState(() {
                _newMemberEligibilityMode = value;
              });
            },
          ),

          const SizedBox(height: 14),
          TextFormField(
            controller: _newMemberDiscountNightsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '新會員優惠總晚數',
              hintText: '例如：輸入 3，代表共有 3 晚優惠額度',
              suffixText: '晚',
              border: OutlineInputBorder(),
            ),
            validator: (String? value) {
              final int nights = int.tryParse(value?.trim() ?? '') ?? 0;

              if (nights <= 0) {
                return '請輸入正確的優惠晚數';
              }

              return null;
            },
          ),
          const SizedBox(height: 12),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.bedtime_outlined),
            title: Text('優惠晚數可以分次使用'),
            subtitle: Text(
              '例如共有 3 晚額度，第一次住宿使用 1 晚後，'
              '下次仍可繼續使用剩餘 2 晚。',
            ),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.payments_outlined),
            title: Text('此優惠固定只折房價'),
            subtitle: Text('寵物加價與其他加購服務不會套用新會員優惠。'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_user_outlined),
            title: Text(
              _newMemberEligibilityMode ==
                      NewMemberEligibilityMode.createdAfterCampaign
                  ? '僅限活動建立後加入的新會員'
                  : '僅限本店尚未有有效訂單的會員',
            ),
            subtitle: Text(
              _newMemberEligibilityMode ==
                      NewMemberEligibilityMode.createdAfterCampaign
                  ? '既有會員不會取得此活動資格；符合資格的會員一旦開始使用，仍可繼續使用剩餘優惠晚數。'
                  : '只要會員在本店從未有過有效訂單即可取得資格；開始使用後仍可繼續使用剩餘優惠晚數。',
            ),
          ),
        ],

        if (_needsDateRange) ...[
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickStartDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('開始：${_dateText(_startAt)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickEndDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text('結束：${_dateText(_endAt)}'),
                ),
              ),
            ],
          ),

          if (widget.campaignType == DiscountCampaignType.limitedTime) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.20),
                ),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                leading: const Icon(Icons.help_outline),
                title: const Text(
                  '使用說明',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('點開查看套用方式與範例'),
                children: const <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '什麼時候會套用？',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text('會員必須在你設定的活動期間內完成預約，才會享有優惠。'),
                        SizedBox(height: 14),
                        Text(
                          '住宿日期有限制嗎？',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text('沒有限制。住宿日期可以安排在活動結束後。'),
                        SizedBox(height: 14),
                        Text(
                          '範例',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '活動設定為 7/20～7/25，會員在 7/23 完成預約，'
                          '即使預約 8 月入住，仍可套用此優惠。',
                        ),
                        SizedBox(height: 14),
                        Text(
                          '適合用途',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text('適合淡季促銷、週年慶、開幕活動、早鳥預訂或短期提升訂單。'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],

        if (widget.campaignType == DiscountCampaignType.stayDate) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<DiscountDateMatchType>(
            initialValue: _dateMatchType,
            decoration: const InputDecoration(
              labelText: '住宿日期符合方式',
              border: OutlineInputBorder(),
            ),
            items: const <DropdownMenuItem<DiscountDateMatchType>>[
              DropdownMenuItem<DiscountDateMatchType>(
                value: DiscountDateMatchType.matchingStayDates,
                child: Text('只折活動日期內的住宿房價'),
              ),
              DropdownMenuItem<DiscountDateMatchType>(
                value: DiscountDateMatchType.checkInDate,
                child: Text('入住日落在活動期間即可'),
              ),
              DropdownMenuItem<DiscountDateMatchType>(
                value: DiscountDateMatchType.entireStay,
                child: Text('整段住宿都要在活動期間內'),
              ),
            ],
            onChanged: (DiscountDateMatchType? value) {
              if (value == null) {
                return;
              }

              setState(() {
                _dateMatchType = value;
              });
            },
          ),
        ],

        if (_needsRoomTypes) _buildRoomTypeSelector(),
      ],
    );
  }

  Widget _buildRoomTypeSelector() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _roomService.streamRoomTypes(widget.shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Text(
                '房型讀取失敗：${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              );
            }

            final List<Map<String, dynamic>> roomTypes =
                snapshot.data ?? const <Map<String, dynamic>>[];

            if (roomTypes.isEmpty) {
              return const Text('目前尚未建立房型，請先建立房型後再設定此優惠。');
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '選擇適用房型',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: roomTypes.map((Map<String, dynamic> roomType) {
                    final String roomTypeId = (roomType['id'] ?? '').toString();

                    final String roomTypeName = (roomType['name'] ?? '未命名房型')
                        .toString();

                    final bool selected = _selectedRoomTypeIds.contains(
                      roomTypeId,
                    );

                    return FilterChip(
                      label: Text(roomTypeName),
                      selected: selected,
                      onSelected: (bool value) {
                        setState(() {
                          if (value) {
                            _selectedRoomTypeIds.add(roomTypeId);
                          } else {
                            _selectedRoomTypeIds.remove(roomTypeId);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '限制住宿優惠日期',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('開啟後，只有住宿日期落在指定期間內才會套用此房型優惠。'),
                  value: _limitStayDate,
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
                if (_limitStayDate) ...<Widget>[
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickStayStartDate,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text('開始：${_dateText(_stayStartAt)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickStayEndDate,
                          icon: const Icon(Icons.event_outlined),
                          label: Text('結束：${_dateText(_stayEndAt)}'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
    );
  }

  Widget _buildLimitSection() {
    return _SectionCard(
      title: '使用限制',
      children: <Widget>[
        if (!_isNewMember) ...[
          TextFormField(
            controller: _memberUsageLimitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '每位會員最多使用次數',
              hintText: '輸入 0 代表不限制',
              suffixText: '次',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
        ],
        TextFormField(
          controller: _totalUsageLimitController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '活動總使用次數',
            hintText: '輸入 0 代表不限制',
            suffixText: '次',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('允許搭配會員折價券'),
          subtitle: const Text('開啟後，自動折扣與一張會員折價券可以同時使用。'),
          value: _allowCouponTogether,
          onChanged: (bool value) {
            setState(() {
              _allowCouponTogether = value;
            });
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('建立後立即啟用'),
          subtitle: const Text('關閉時會先保存活動，但會員預約不會套用。'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('建立${_campaignTypeLabel()}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: <Widget>[
            _CampaignTypeHeader(typeLabel: _campaignTypeLabel()),
            const SizedBox(height: 14),
            _buildCommonSection(),
            const SizedBox(height: 14),
            _buildDiscountSection(),
            const SizedBox(height: 14),
            _buildTypeConditionSection(),
            const SizedBox(height: 14),
            _buildLimitSection(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _createCampaign,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? '建立中…' : '確認建立優惠'),
          ),
        ),
      ),
    );
  }
}

class _CampaignTypeHeader extends StatelessWidget {
  const _CampaignTypeHeader({required this.typeLabel});

  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.local_offer_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                const Text('完成以下設定後，才會正式建立優惠活動。'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

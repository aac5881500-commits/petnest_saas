// 檔案名稱：lib/features/shop/pages/shop_special_date_surcharge_form_page.dart
// 功能說明：特殊日期加價建立／編輯，分段卡片與示意預覽。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/debug/chat_error_probe.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/special_date_surcharge_model.dart';
import 'package:petnest_saas/core/services/discount_promo_preview.dart';
import 'package:petnest_saas/core/services/special_date_surcharge_service.dart';
import 'package:petnest_saas/features/shop/widgets/discount_hub_host.dart';
import 'package:petnest_saas/features/shop/widgets/discount_promo_preview_card.dart';

class ShopSpecialDateSurchargeFormPage extends StatefulWidget {
  const ShopSpecialDateSurchargeFormPage({
    super.key,
    required this.shopId,
    this.surcharge,
  });

  final String shopId;
  final SpecialDateSurchargeModel? surcharge;

  @override
  State<ShopSpecialDateSurchargeFormPage> createState() =>
      _ShopSpecialDateSurchargeFormPageState();
}

class _ShopSpecialDateSurchargeFormPageState
    extends State<ShopSpecialDateSurchargeFormPage> {
  static const OutlineInputBorder _fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  final SpecialDateSurchargeService _service =
      SpecialDateSurchargeService.instance;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _stayAmount;
  late final TextEditingController _daycareAmount;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _enabled = true;
  bool _allowCampaignDiscount = true;
  bool _allowCoupon = true;
  bool _applyToAllRoomTypes = true;
  bool _previewDaycare = false;
  List<String> _roomTypeIds = <String>[];
  List<String> _applicableServices = List<String>.from(
    PolicyApplicableService.accommodationOnly,
  );
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final SpecialDateSurchargeModel? item = widget.surcharge;
    _name = TextEditingController(text: item?.name ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    final String amountText = item == null
        ? ''
        : item.amountPerNight.toString();
    _stayAmount = TextEditingController(text: amountText);
    _daycareAmount = TextEditingController(text: amountText);
    _startDate = item?.startDate;
    _endDate = item?.endDate;
    _enabled = item?.enabled ?? true;
    _allowCampaignDiscount = item?.allowCampaignDiscount ?? true;
    _allowCoupon = item?.allowCoupon ?? true;
    _roomTypeIds = List<String>.from(item?.roomTypeIds ?? const <String>[]);
    _applyToAllRoomTypes = _roomTypeIds.isEmpty;
    _applicableServices = List<String>.from(
      item?.applicableServices ?? PolicyApplicableService.accommodationOnly,
    );
    _previewDaycare = _serviceGroup == 'daycare';
    _name.addListener(_refresh);
    _stayAmount.addListener(_refresh);
    _daycareAmount.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _name.removeListener(_refresh);
    _stayAmount.removeListener(_refresh);
    _daycareAmount.removeListener(_refresh);
    _name.dispose();
    _description.dispose();
    _stayAmount.dispose();
    _daycareAmount.dispose();
    super.dispose();
  }

  int _parseAmount(TextEditingController controller) {
    return int.tryParse(controller.text.trim()) ?? 0;
  }

  String _dateText(DateTime? date, {String empty = '尚未選擇'}) {
    if (date == null) {
      return empty;
    }
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  int? get _rangeDays {
    if (_startDate == null || _endDate == null) {
      return null;
    }
    return _endDate!.difference(_startDate!).inDays.abs() + 1;
  }

  String get _serviceLabel {
    return PolicyApplicableService.displayLabel(_applicableServices);
  }

  String get _headlineSummary {
    final int stayAmt = _parseAmount(_stayAmount);
    final int daycareAmt = _parseAmount(_daycareAmount);
    if (_startDate == null || _endDate == null) {
      return '請完成日期、服務與加價金額設定';
    }
    if (_serviceGroup != 'daycare' && stayAmt <= 0) {
      return '請完成日期、服務與加價金額設定';
    }
    if (_serviceGroup != 'stay' && daycareAmt <= 0) {
      return '請完成日期、服務與加價金額設定';
    }
    final String amountPart = switch (_serviceGroup) {
      'daycare' => '每次 +${DiscountPromoPreview.nt(daycareAmt)}',
      'both' =>
        '每晚 +${DiscountPromoPreview.nt(stayAmt)}・每次 +${DiscountPromoPreview.nt(daycareAmt)}',
      _ => '每晚 +${DiscountPromoPreview.nt(stayAmt)}',
    };
    return '$_serviceLabel｜${_dateText(_startDate)}–${_dateText(_endDate)}｜$amountPart｜${_enabled ? '啟用中' : '未啟用'}';
  }

  Future<void> _pickStart() async {
    final DateTime now = DateTime.now();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _startDate = DateTime(selected.year, selected.month, selected.day);
      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
        _endDate = null;
      }
    });
  }

  Future<void> _pickEnd() async {
    final DateTime now = DateTime.now();
    final DateTime first = _startDate ?? now;
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _endDate ?? first,
      firstDate: first,
      lastDate: DateTime(now.year + 10),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _endDate = DateTime(selected.year, selected.month, selected.day);
    });
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    final int stayAmt = _parseAmount(_stayAmount);
    final int daycareAmt = _parseAmount(_daycareAmount);
    if (name.isEmpty) {
      _toast('請輸入加價名稱');
      return;
    }
    if (_startDate == null || _endDate == null) {
      _toast('請選擇加價日期');
      return;
    }
    if (_serviceGroup != 'daycare' && stayAmt <= 0) {
      _toast('住宿每晚加價必須大於 0');
      return;
    }
    if (_serviceGroup != 'stay' && daycareAmt <= 0) {
      _toast('安親每次加價必須大於 0');
      return;
    }
    if (_serviceGroup == 'both' && stayAmt != daycareAmt) {
      _toast('目前住宿每晚與安親每次使用同一加價金額，請輸入相同數字。');
      return;
    }
    if (_serviceGroup != 'daycare' &&
        !_applyToAllRoomTypes &&
        _roomTypeIds.isEmpty) {
      _toast('請至少選擇一個適用房型');
      return;
    }
    final List<String> roomTypeIds = _serviceGroup == 'daycare'
        ? <String>[]
        : (_applyToAllRoomTypes ? <String>[] : _roomTypeIds);
    final int amount = _serviceGroup == 'daycare' ? daycareAmt : stayAmt;
    setState(() {
      _saving = true;
    });
    try {
      if (widget.surcharge == null) {
        await _service.createSurcharge(
          shopId: widget.shopId,
          name: name,
          description: _description.text.trim(),
          startDate: _startDate!,
          endDate: _endDate!,
          amountPerNight: amount,
          enabled: _enabled,
          allowCampaignDiscount: _allowCampaignDiscount,
          allowCoupon: _allowCoupon,
          roomTypeIds: roomTypeIds,
          applicableServices: _applicableServices,
        );
      } else {
        await _service.updateSurcharge(
          shopId: widget.shopId,
          surchargeId: widget.surcharge!.id,
          name: name,
          description: _description.text.trim(),
          startDate: _startDate!,
          endDate: _endDate!,
          amountPerNight: amount,
          enabled: _enabled,
          allowCampaignDiscount: _allowCampaignDiscount,
          allowCoupon: _allowCoupon,
          roomTypeIds: roomTypeIds,
          applicableServices: _applicableServices,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _toast(ChatErrorProbe.userFacing(error));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  InputDecoration _input(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: _fieldBorder,
      enabledBorder: _fieldBorder.copyWith(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool stay = _serviceGroup != 'daycare';
    final bool daycare = _serviceGroup != 'stay';
    final bool both = _serviceGroup == 'both';
    final DiscountPromoPreviewResult preview =
        DiscountPromoPreview.forSurcharge(
          stayAmountPerNight: _parseAmount(_stayAmount),
          daycareAmountPerSession: _parseAmount(_daycareAmount),
          applicableServices: _applicableServices,
          enabled: _enabled,
          allowCampaignDiscount: _allowCampaignDiscount,
          allowCoupon: _allowCoupon,
          previewDaycare: both ? _previewDaycare : daycare && !stay,
        );
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.surcharge == null ? '新增特殊日期加價' : '編輯特殊日期加價'),
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
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: <Widget>[
              _card('基本資料', <Widget>[
                TextField(
                  controller: _name,
                  decoration: _input('名稱', hint: '例如：中秋連假加價'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _description,
                  maxLines: 2,
                  decoration: _input('說明', hint: '例如：連假期間住宿每晚加價'),
                ),
                const SizedBox(height: 8),
                _enabledRow(),
              ]),
              const SizedBox(height: 12),
              _card('加價內容', <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _dateCard(
                        label: '開始日期',
                        value: _dateText(_startDate),
                        onTap: _pickStart,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '至',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: _dateCard(
                        label: '結束日期',
                        value: _dateText(_endDate),
                        onTap: _pickEnd,
                      ),
                    ),
                  ],
                ),
                if (_rangeDays != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    _rangeHint(_rangeDays!),
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (stay) ...<Widget>[
                  const SizedBox(height: 14),
                  _amountField(label: '每晚加價', controller: _stayAmount),
                ],
                if (daycare) ...<Widget>[
                  const SizedBox(height: 14),
                  _amountField(label: '每次安親加價', controller: _daycareAmount),
                ],
              ]),
              const SizedBox(height: 12),
              _card('適用服務與範圍', <Widget>[
                DiscountServiceChoice(
                  services: _applicableServices,
                  onChanged: (List<String> value) {
                    setState(() {
                      _applicableServices = value;
                      _previewDaycare =
                          value.length == 1 &&
                          value.contains(PolicyApplicableService.daycare);
                      if (_serviceGroup == 'daycare') {
                        _applyToAllRoomTypes = true;
                      }
                    });
                  },
                ),
                if (_serviceGroup != 'daycare') ...<Widget>[
                  const SizedBox(height: 12),
                  DiscountToggleCard(
                    title: '全部房型／方案適用',
                    subtitle: '關閉後可指定住宿房型或安親方案',
                    value: _applyToAllRoomTypes,
                    onLabel: '全部適用',
                    offLabel: '指定範圍',
                    onChanged: (bool value) {
                      setState(() {
                        _applyToAllRoomTypes = value;
                        if (value) {
                          _roomTypeIds = <String>[];
                        }
                      });
                    },
                  ),
                  if (!_applyToAllRoomTypes) ...<Widget>[
                    if (both)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '以下僅限制住宿房型。安親每次加價不套用住宿房型清單。',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance
                          .collection('shops')
                          .doc(widget.shopId)
                          .collection('room_types')
                          .get(),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                            snapshot,
                          ) {
                            if (snapshot.hasError) {
                              return const Text('房型讀取失敗，請稍後再試。');
                            }
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            return Column(
                              children: snapshot.data!.docs.map((
                                QueryDocumentSnapshot<Map<String, dynamic>> doc,
                              ) {
                                final String name =
                                    (doc.data()['name'] ?? '未命名房型').toString();
                                return CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _roomTypeIds.contains(doc.id),
                                  title: Text(name),
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        _roomTypeIds.add(doc.id);
                                      } else {
                                        _roomTypeIds.remove(doc.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            );
                          },
                    ),
                  ],
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '安親加價依服務日每次加一次，不套用住宿房型。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              _card('優惠併用規則', <Widget>[
                DiscountToggleCard(
                  title: '可與自動優惠併用',
                  subtitle: _allowCampaignDiscount
                      ? '符合特殊日期時，仍可套用自動優惠活動。'
                      : '符合特殊日期加價時，不會再套用自動優惠活動。',
                  value: _allowCampaignDiscount,
                  onChanged: (bool value) {
                    setState(() {
                      _allowCampaignDiscount = value;
                    });
                  },
                ),
                DiscountToggleCard(
                  title: '可使用優惠券',
                  subtitle: _allowCoupon
                      ? '符合特殊日期時，會員可使用符合資格的優惠券。'
                      : '符合特殊日期加價時，會員不可使用優惠券。',
                  value: _allowCoupon,
                  onChanged: (bool value) {
                    setState(() {
                      _allowCoupon = value;
                    });
                  },
                ),
              ]),
              const SizedBox(height: 12),
              DiscountPromoPreviewCard.fromResult(
                preview,
                header: both ? _previewSwitch() : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '儲存中…' : '儲存'),
                ),
              ),
            ],
          ),
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
              _enabled ? '啟用後，符合日期的訂單會自動計算加價' : '規則會保留，但新訂單不會套用',
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

  Widget _amountField({
    required String label,
    required TextEditingController controller,
  }) {
    final int value = _parseAmount(controller);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: _input(label).copyWith(suffixText: '元'),
        ),
        const SizedBox(height: 6),
        Text(
          value > 0 ? DiscountPromoPreview.nt(value) : 'NT\$0',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFFE65100),
          ),
        ),
      ],
    );
  }

  Widget _previewSwitch() {
    return SegmentedButton<bool>(
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
    );
  }

  String _rangeHint(int days) {
    if (_serviceGroup == 'daycare') {
      return '共 $days 個服務日（每次安親加一次）';
    }
    if (_serviceGroup == 'both') {
      return '共 $days 天／住宿 $days 晚；安親依服務日每次加一次';
    }
    return '共 $days 天／住宿 $days 晚';
  }

  String get _serviceGroup {
    final bool stay = _applicableServices.contains(
      PolicyApplicableService.accommodation,
    );
    final bool daycare = _applicableServices.contains(
      PolicyApplicableService.daycare,
    );
    if (stay && daycare) {
      return 'both';
    }
    if (daycare) {
      return 'daycare';
    }
    return 'stay';
  }
}

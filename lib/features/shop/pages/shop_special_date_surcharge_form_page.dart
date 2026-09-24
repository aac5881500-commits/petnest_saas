// 檔案名稱：lib/features/shop/pages/shop_special_date_surcharge_form_page.dart
// 功能說明：特殊日期加價建立／編輯，分段卡片與示意預覽。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/debug/chat_error_probe.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/special_date_surcharge_model.dart';
import 'package:petnest_saas/core/services/discount_promo_preview.dart';
import 'package:petnest_saas/core/services/special_date_surcharge_service.dart';
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
  final SpecialDateSurchargeService _service =
      SpecialDateSurchargeService.instance;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _enabled = true;
  bool _allowCampaignDiscount = true;
  bool _allowCoupon = true;
  bool _applyToAllRoomTypes = true;
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
    _amount = TextEditingController(
      text: item == null ? '' : item.amountPerNight.toString(),
    );
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
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  String _dateText(DateTime? date) {
    if (date == null) {
      return '尚未選擇';
    }
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String get _amountLabel {
    final bool stay = _applicableServices.contains(
      PolicyApplicableService.accommodation,
    );
    final bool daycare = _applicableServices.contains(
      PolicyApplicableService.daycare,
    );
    if (stay && daycare) {
      return '住宿每晚加價／安親每次加價';
    }
    if (daycare) {
      return '每次安親加價';
    }
    return '每晚加價';
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
    final int amount = int.tryParse(_amount.text.trim()) ?? 0;
    if (name.isEmpty) {
      _toast('請輸入加價名稱');
      return;
    }
    if (_startDate == null || _endDate == null) {
      _toast('請選擇加價日期');
      return;
    }
    if (amount <= 0) {
      _toast('加價金額必須大於 0');
      return;
    }
    if (!_applyToAllRoomTypes && _roomTypeIds.isEmpty) {
      _toast('請至少選擇一個適用房型');
      return;
    }
    if (_applicableServices.contains(PolicyApplicableService.daycare) &&
        !_applicableServices.contains(PolicyApplicableService.accommodation) &&
        !_applyToAllRoomTypes) {
      _applyToAllRoomTypes = true;
      _roomTypeIds = <String>[];
    }
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
          roomTypeIds: _roomTypeIds,
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
          roomTypeIds: _roomTypeIds,
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

  @override
  Widget build(BuildContext context) {
    final int amount = int.tryParse(_amount.text.trim()) ?? 0;
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(widget.surcharge == null ? '新增特殊日期加價' : '編輯特殊日期加價'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: <Widget>[
          _card('基本資料', <Widget>[
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '名稱',
                hintText: '例如：中秋連假加價',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '說明',
                hintText: '例如：連假期間住宿每晚加價',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('啟用'),
              subtitle: const Text('開啟後，符合日期時會自動計算加價。'),
              value: _enabled,
              onChanged: (bool value) {
                setState(() {
                  _enabled = value;
                });
              },
            ),
          ]),
          const SizedBox(height: 12),
          _card('加價內容', <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStart,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('開始：${_dateText(_startDate)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEnd,
                    icon: const Icon(Icons.event_outlined),
                    label: Text('結束：${_dateText(_endDate)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _amountLabel,
                hintText: '例如：300',
                suffixText: '元',
                border: const OutlineInputBorder(),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _card('適用服務與條件', <Widget>[
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: const Text('住宿'),
              value: 'stay',
              groupValue: _serviceGroup,
              onChanged: (_) {
                setState(() {
                  _applicableServices = List<String>.from(
                    PolicyApplicableService.accommodationOnly,
                  );
                });
              },
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: const Text('安親'),
              value: 'daycare',
              groupValue: _serviceGroup,
              onChanged: (_) {
                setState(() {
                  _applicableServices = List<String>.from(
                    PolicyApplicableService.daycareOnly,
                  );
                  _applyToAllRoomTypes = true;
                  _roomTypeIds = <String>[];
                });
              },
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: const Text('住宿與安親'),
              subtitle: const Text('住宿每晚加價／安親每次加價'),
              value: 'both',
              groupValue: _serviceGroup,
              onChanged: (_) {
                setState(() {
                  _applicableServices = List<String>.from(
                    PolicyApplicableService.shared,
                  );
                });
              },
            ),
            if (_serviceGroup != 'daycare') ...<Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('全部房型適用'),
                value: _applyToAllRoomTypes,
                onChanged: (bool value) {
                  setState(() {
                    _applyToAllRoomTypes = value;
                    if (value) {
                      _roomTypeIds = <String>[];
                    }
                  });
                },
              ),
              if (!_applyToAllRoomTypes)
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
                            final String name = (doc.data()['name'] ?? '未命名房型')
                                .toString();
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
          ]),
          const SizedBox(height: 12),
          _card('使用限制', <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('允許套用其他優惠活動'),
              subtitle: const Text('關閉後，只要日期碰到這筆加價，就不套用自動優惠活動。'),
              value: _allowCampaignDiscount,
              onChanged: (bool value) {
                setState(() {
                  _allowCampaignDiscount = value;
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('允許使用優惠券'),
              subtitle: const Text('關閉後，只要日期碰到這筆加價，就不能使用優惠券。'),
              value: _allowCoupon,
              onChanged: (bool value) {
                setState(() {
                  _allowCoupon = value;
                });
              },
            ),
          ]),
          const SizedBox(height: 12),
          DiscountPromoPreviewCard(
            lines: DiscountPromoPreview.forSurcharge(
              amountPerNight: amount,
              applicableServices: _applicableServices,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '儲存中…' : '儲存'),
          ),
        ],
      ),
    );
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

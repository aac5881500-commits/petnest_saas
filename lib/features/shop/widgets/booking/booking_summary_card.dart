// 檔案名稱：lib/features/shop/widgets/booking/booking_summary_card.dart
// 功能說明：前台預約確認卡片：顯示入住日、退房日、晚數、寵物數量、房型、加值服務與總價

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';

class BookingSummaryCard extends StatelessWidget {
  const BookingSummaryCard({
    super.key,
    required this.startDateText,
    required this.endDateText,
    required this.nights,
    required this.petCount,
    required this.roomTypeName,
    required this.totalPrice,
    this.theme = HomeThemeModel.classicDefault,
    this.depositAmount = 0,
    this.originalTotal,
    this.discountAmount = 0,
    this.discountPercent = 0,
    this.discountMinNights = 0,
    this.discountBase = '',
    this.discountCampaignName = '',
    this.discountValueType = '',
    this.discountValue = 0,
    this.discountCampaignType = '',
    this.discountUsedNights = 0,
    this.remainingDiscountNights = 0,
    this.specialDateSurchargeAmount = 0,
    this.specialDateSurchargeDetails = const [],
    this.couponName = '',
    this.couponDiscountAmount = 0,
    this.petNames = const <String>[],
    required this.timeAddon,
    required this.valueServices,
    required this.customServices,
    required this.customServicePrices,
    required this.dailyTimedServices,
    required this.selectedDailyTimedServices,
    this.petNamesById = const {},
  });

  final HomeThemeModel theme;
  final String startDateText;
  final String endDateText;
  final int nights;
  final int petCount;
  final String roomTypeName;
  final int totalPrice;
  final int depositAmount;
  final int? originalTotal;
  final int discountAmount;
  final int discountPercent;
  final int discountMinNights;
  final String discountBase;
  final String discountCampaignName;
  final String discountValueType;
  final num discountValue;
  final String discountCampaignType;
  final int discountUsedNights;
  final int remainingDiscountNights;
  final int specialDateSurchargeAmount;
  final List<Map<String, dynamic>> specialDateSurchargeDetails;
  final String couponName;
  final int couponDiscountAmount;
  final List<String> petNames;
  final Map<String, dynamic>? timeAddon;
  final List<Map<String, dynamic>> valueServices;
  final Map<String, List<String>> customServices;
  final Map<String, int> customServicePrices;
  final List<Map<String, dynamic>> dailyTimedServices;
  final Map<String, Map<String, Map<String, List<String>>>>
  selectedDailyTimedServices;
  final Map<String, String> petNamesById;

  @override
  Widget build(BuildContext context) {
    final int baseOriginal =
        (originalTotal ?? totalPrice) -
        (specialDateSurchargeAmount > 0 ? specialDateSurchargeAmount : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '費用與確認',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 10),
        _section(
          title: '住宿日期',
          children: <Widget>[
            _infoRow('入住日', startDateText),
            const SizedBox(height: 6),
            _infoRow('退房日', endDateText),
            const SizedBox(height: 6),
            _infoRow('晚數', '$nights 晚'),
          ],
        ),
        _section(
          title: '入住寵物',
          children: <Widget>[
            _infoRow('數量', '$petCount 隻'),
            if (petNames.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              _infoRow('名單', petNames.join('、')),
            ],
          ],
        ),
        _section(title: '房型', children: <Widget>[_infoRow('房型', roomTypeName)]),
        _section(
          title: '加值服務',
          children: <Widget>[
            if (timeAddon == null &&
                valueServices.isEmpty &&
                customServices.isEmpty &&
                !_hasDailyTimedSelections())
              Text(
                '未加購服務',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.textColor.withValues(alpha: 0.7),
                ),
              )
            else ...<Widget>[
              if (timeAddon != null)
                _infoRow('時間加購', '+NT\$ ${timeAddon!['price'] ?? 0}'),
              if (valueServices.isNotEmpty)
                ...valueServices.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _infoRow(
                      e['name'] ?? '',
                      '+NT\$ ${e['price'] ?? 0}',
                    ),
                  ),
                ),
              if (customServices.isNotEmpty)
                ...customServices.entries.map((entry) {
                  final name = entry.key;
                  final count = entry.value.length;
                  final price = customServicePrices[name] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _infoRow(
                      '$name ($count隻)',
                      '+NT\$ ${price * count}',
                    ),
                  );
                }),
              if (_hasDailyTimedSelections())
                ..._buildDailyTimedServiceWidgets(),
            ],
          ],
        ),
        if (couponName.trim().isNotEmpty || couponDiscountAmount > 0)
          _section(
            title: '優惠券',
            children: <Widget>[
              _infoRow(
                couponName.trim().isEmpty ? '會員優惠券' : couponName.trim(),
                couponDiscountAmount > 0
                    ? '-NT\$ $couponDiscountAmount'
                    : '已選擇',
              ),
            ],
          ),
        _section(
          title: '費用明細',
          children: <Widget>[
            _infoRow(
              '原價',
              'NT\$ ${baseOriginal < 0 ? totalPrice : baseOriginal}',
            ),
            if (specialDateSurchargeAmount > 0) ...<Widget>[
              const SizedBox(height: 6),
              _infoRow('加價', '+NT\$ $specialDateSurchargeAmount'),
              if (specialDateSurchargeDetails.isNotEmpty)
                ...specialDateSurchargeDetails.map((detail) {
                  final String date = _formatSurchargeDate(
                    (detail['date'] ?? '').toString(),
                  );
                  final int amount = ((detail['amount'] ?? 0) as num).toInt();
                  final List<Map<String, dynamic>> items =
                      List<Map<String, dynamic>>.from(
                        detail['items'] ?? const <dynamic>[],
                      );
                  final String names = items
                      .map((item) => (item['name'] ?? '').toString().trim())
                      .where((name) => name.isNotEmpty)
                      .join('、');
                  return Padding(
                    padding: const EdgeInsets.only(left: 8, top: 5),
                    child: Text(
                      '$date${names.isEmpty ? '' : '　$names'}　+NT\$ $amount',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  );
                }),
            ],
            if (discountAmount > 0) ...<Widget>[
              const SizedBox(height: 6),
              _infoRow(
                '優惠活動',
                discountCampaignName.trim().isNotEmpty
                    ? discountCampaignName
                    : '長住優惠：滿 $discountMinNights 晚折扣 $discountPercent%',
              ),
              const SizedBox(height: 6),
              _infoRow('優惠內容', _discountContentText()),
              if (discountCampaignType == 'newMember' &&
                  discountUsedNights > 0) ...<Widget>[
                const SizedBox(height: 6),
                _infoRow('本次優惠晚數', '$discountUsedNights 晚'),
                const SizedBox(height: 6),
                _infoRow('使用後剩餘', '$remainingDiscountNights 晚'),
              ],
              const SizedBox(height: 6),
              _infoRow('活動折扣', '-NT\$ $discountAmount'),
            ],
            if (couponDiscountAmount > 0) ...<Widget>[
              const SizedBox(height: 6),
              _infoRow(
                couponName.trim().isEmpty ? '優惠券' : couponName.trim(),
                '-NT\$ $couponDiscountAmount',
              ),
            ],
            const SizedBox(height: 10),
            _infoRow('折後總額', 'NT\$ $totalPrice', emphasize: true),
            const SizedBox(height: 6),
            _infoRow(
              depositAmount > 0 ? '應付訂金' : '應付金額',
              'NT\$ ${depositAmount > 0 ? depositAmount : totalPrice}',
              emphasize: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return BookingThemedCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  bool _hasDailyTimedSelections() {
    return selectedDailyTimedServices.values.any((petSelections) {
      return petSelections.values.any((dateSelections) {
        return dateSelections.values.any((slotIds) => slotIds.isNotEmpty);
      });
    });
  }

  List<Widget> _buildDailyTimedServiceWidgets() {
    final widgets = <Widget>[];

    for (final entry in dailyTimedServices.asMap().entries) {
      final serviceIndex = entry.key;
      final service = entry.value;
      final serviceId = _dailyTimedServiceId(service, serviceIndex);
      final serviceSelections = selectedDailyTimedServices[serviceId];
      if (serviceSelections == null || serviceSelections.isEmpty) {
        continue;
      }

      final serviceName = service['name']?.toString().trim().isNotEmpty == true
          ? service['name'].toString().trim()
          : '每日服務';
      final servicePrice = ((service['price'] ?? 0) as num).toInt();
      final timeSlotLabels = _timeSlotLabels(service);
      int selectedCount = 0;
      for (final petSelections in serviceSelections.values) {
        for (final slotIds in petSelections.values) {
          selectedCount += slotIds.length;
        }
      }
      if (selectedCount == 0) {
        continue;
      }

      widgets.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            border: Border.all(color: theme.cardBorderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      serviceName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                  Text(
                    '+NT\$ ${servicePrice * selectedCount}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...serviceSelections.entries.map((petEntry) {
                final petId = petEntry.key;
                final petName = petNamesById[petId] ?? petId;
                final dateSelections = petEntry.value;
                final sortedDates = dateSelections.entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key));
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        petName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...sortedDates
                          .where((dateEntry) => dateEntry.value.isNotEmpty)
                          .map((dateEntry) {
                            final labels = dateEntry.value
                                .map((slotId) {
                                  return timeSlotLabels[slotId] ?? slotId;
                                })
                                .join('、');
                            return Padding(
                              padding: const EdgeInsets.only(left: 8, top: 3),
                              child: Text(
                                '${_formatDailyTimedDate(dateEntry.key)}　$labels',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textColor.withValues(alpha: 0.7),
                                ),
                              ),
                            );
                          }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  String _dailyTimedServiceId(Map<String, dynamic> service, int serviceIndex) {
    final rawServiceId = service['id']?.toString().trim() ?? '';
    final serviceName = service['name']?.toString().trim() ?? '';
    if (rawServiceId.isNotEmpty) {
      return rawServiceId;
    }
    if (serviceName.isNotEmpty) {
      return 'daily_timed_$serviceName';
    }
    return 'daily_timed_$serviceIndex';
  }

  Map<String, String> _timeSlotLabels(Map<String, dynamic> service) {
    final result = <String, String>{};
    final rawSlots = service['timeSlots'];
    if (rawSlots is! List) {
      return result;
    }
    for (final rawSlot in rawSlots) {
      if (rawSlot is! Map) {
        continue;
      }
      final slot = Map<String, dynamic>.from(rawSlot);
      final id = slot['id']?.toString().trim() ?? '';
      final label = slot['label']?.toString().trim() ?? '';
      if (id.isNotEmpty) {
        result[id] = label.isNotEmpty ? label : id;
      }
    }
    return result;
  }

  String _formatDailyTimedDate(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) {
      return dateKey;
    }
    return '${parts[0]}/${parts[1]}/${parts[2]}';
  }

  String _discountContentText() {
    String discountText;
    switch (discountValueType) {
      case 'percent':
        discountText = '折扣 ${_formatDiscountValue(discountValue)}%';
      case 'fixedAmount':
        discountText = '折 NT\$ ${_formatDiscountValue(discountValue)}';
      default:
        discountText = '已套用優惠';
    }
    return '$discountText（${_discountBaseText()}）';
  }

  String _formatDiscountValue(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _discountBaseText() {
    switch (discountBase) {
      case 'room':
        return '只折房價';
      case 'room_pet':
      case 'roomAndPet':
        return '房價與寵物費';
      case 'total':
        return '全部金額';
      default:
        return '依活動設定';
    }
  }

  String _formatSurchargeDate(String dateKey) {
    final List<String> parts = dateKey.split('-');
    if (parts.length != 3) {
      return dateKey;
    }
    return '${parts[0]}/${parts[1]}/${parts[2]}';
  }

  Widget _infoRow(String label, String value, {bool emphasize = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: TextStyle(
              fontSize: emphasize ? 16 : 14,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: theme.textColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 16 : 14,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: theme.textColor,
            ),
          ),
        ),
      ],
    );
  }
}

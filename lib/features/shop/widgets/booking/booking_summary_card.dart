// lib/features/shop/widgets/booking/booking_summary_card.dart
// 🔥 前台預約確認卡片：顯示入住日、退房日、晚數、寵物數量、房型、加值服務與總價

import 'package:flutter/material.dart';

class BookingSummaryCard extends StatelessWidget {
  const BookingSummaryCard({
    super.key,
    required this.startDateText,
    required this.endDateText,
    required this.nights,
    required this.petCount,
    required this.roomTypeName,
    required this.totalPrice,
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

    required this.timeAddon,
    required this.valueServices,
    required this.customServices,
    required this.customServicePrices,
    required this.dailyTimedServices,
    required this.selectedDailyTimedServices,
    this.petNamesById = const {},
  });

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

  /// percent / fixedAmount
  final String discountValueType;

  /// 店家設定的折扣數值，例如 10% 或 1000 元
  final num discountValue;

  /// newMember / longStay / roomType 等活動類型
  final String discountCampaignType;

  /// 本次實際使用的優惠晚數
  final int discountUsedNights;

  /// 本次優惠使用完成後剩餘晚數
  final int remainingDiscountNights;

  /// 特殊日期住宿夜固定加價總額
  final int specialDateSurchargeAmount;

  final List<Map<String, dynamic>> specialDateSurchargeDetails;

  final String couponName;
  final int couponDiscountAmount;
  final Map<String, dynamic>? timeAddon;
  final List<Map<String, dynamic>> valueServices;
  final Map<String, List<String>> customServices;
  final Map<String, int> customServicePrices;

  /// 店家設定的每日分時段服務。
  final List<Map<String, dynamic>> dailyTimedServices;

  /// serviceId → petId → yyyy-MM-dd → 時段 ID 清單
  final Map<String, Map<String, Map<String, List<String>>>>
  selectedDailyTimedServices;

  /// petId → 寵物名稱
  final Map<String, String> petNamesById;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '預約確認',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _infoRow('入住日', startDateText),
            const SizedBox(height: 6),

            _infoRow('退房日', endDateText),
            const SizedBox(height: 6),

            _infoRow('晚數', '$nights 晚'),
            const SizedBox(height: 6),

            _infoRow('寵物數量', '$petCount 隻'),
            const SizedBox(height: 6),

            _infoRow('房型', roomTypeName),
            const SizedBox(height: 6),

            if (timeAddon != null)
              _infoRow('時間加購', '+NT\$ ${timeAddon!['price'] ?? 0}'),

            if (valueServices.isNotEmpty)
              ...valueServices.map(
                (e) => _infoRow(e['name'] ?? '', '+NT\$ ${e['price'] ?? 0}'),
              ),

            if (customServices.isNotEmpty)
              ...customServices.entries.map((entry) {
                final name = entry.key;
                final count = entry.value.length;
                final price = customServicePrices[name] ?? 0;

                return _infoRow('$name ($count隻)', '+NT\$ ${price * count}');
              }),

            if (_hasDailyTimedSelections()) ...[
              const SizedBox(height: 10),
              const Text(
                '每日分時段服務',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._buildDailyTimedServiceWidgets(),
            ],
            const Divider(),

            if (specialDateSurchargeAmount > 0) ...[
              _infoRow('特殊日期加價', '+NT\$ $specialDateSurchargeAmount'),

              if (specialDateSurchargeDetails.isNotEmpty) ...[
                const SizedBox(height: 8),

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
                    padding: const EdgeInsets.only(left: 16, bottom: 5),
                    child: Text(
                      '$date${names.isEmpty ? '' : '　$names'}　+NT\$ $amount',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 6),
            ],

            if ((discountAmount > 0 || couponDiscountAmount > 0) &&
                originalTotal != null) ...[
              _infoRow('原價', 'NT\$ $originalTotal'),
              const SizedBox(height: 6),
            ],

            if (discountAmount > 0) ...[
              _infoRow(
                '優惠活動',
                discountCampaignName.trim().isNotEmpty
                    ? discountCampaignName
                    : '長住優惠：滿 $discountMinNights 晚折扣 $discountPercent%',
              ),
              const SizedBox(height: 6),
              _infoRow('優惠內容', _discountContentText()),
              const SizedBox(height: 6),

              if (discountCampaignType == 'newMember' &&
                  discountUsedNights > 0) ...[
                _infoRow('本次優惠晚數', '$discountUsedNights 晚'),
                const SizedBox(height: 6),
                _infoRow('使用後剩餘', '$remainingDiscountNights 晚'),
                const SizedBox(height: 6),
              ],

              _infoRow('活動折扣', '-NT\$ $discountAmount'),
              const SizedBox(height: 6),
            ],

            if (couponDiscountAmount > 0) ...[
              _infoRow(
                couponName.trim().isEmpty ? '會員優惠券' : couponName.trim(),
                '-NT\$ $couponDiscountAmount',
              ),
              const SizedBox(height: 6),
            ],

            _infoRow(
              (discountAmount > 0 || couponDiscountAmount > 0) ? '折後總價' : '總價',
              'NT\$ $totalPrice',
            ),
            if (depositAmount > 0) ...[
              const SizedBox(height: 6),
              _infoRow('本次應付訂金', 'NT\$ $depositAmount'),
            ],
          ],
        ),
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
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      serviceName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '+NT\$ ${servicePrice * selectedCount}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                    children: [
                      Text(
                        '🐱 $petName',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      ...sortedDates
                          .where((dateEntry) {
                            return dateEntry.value.isNotEmpty;
                          })
                          .map((dateEntry) {
                            final labels = dateEntry.value
                                .map((slotId) {
                                  return timeSlotLabels[slotId] ?? slotId;
                                })
                                .join('、');

                            return Padding(
                              padding: const EdgeInsets.only(left: 18, top: 3),
                              child: Text(
                                '├─ ${_formatDailyTimedDate(dateEntry.key)}　$labels',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
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
        break;

      case 'fixedAmount':
        discountText = '折 NT\$ ${_formatDiscountValue(discountValue)}';
        break;

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

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}

// 檔案名稱：lib/features/admin/widgets/admin_create_booking_confirm_section.dart
// 功能說明：顯示會員、寵物、日期、房型、加值服務與總金額確認
// ✅ 後台手動新增訂單：確認資料區塊

import 'package:flutter/material.dart';

class AdminCreateBookingConfirmSection extends StatelessWidget {
  const AdminCreateBookingConfirmSection({
    super.key,
    required this.member,
    required this.roomType,
    required this.startDate,
    required this.endDate,
    required this.selectedPetIds,
    required this.selectedTimeAddon,
    required this.selectedValueServices,
    required this.selectedCustomServices,
    required this.selectedDailyTimedServices,
    required this.pets,
    required this.addonData,
    required this.adminOrderSource,
    required this.applyLongStayDiscount,
    required this.onApplyLongStayDiscountChanged,
    required this.discountInfo,
    required this.noteController,

    required this.depositEnabled,
    required this.depositAmount,
    required this.payAmountType,
    required this.paymentMethod,
    required this.cashEnabled,
    required this.transferEnabled,
    required this.onPayAmountTypeChanged,
    required this.onPaymentMethodChanged,

    required this.onOrderSourceChanged,
    required this.formatDate,
  });

  final Map<String, dynamic>? member;
  final Map<String, dynamic>? roomType;
  final DateTime? startDate;
  final DateTime? endDate;

  final Set<String> selectedPetIds;

  final Map<String, dynamic>? selectedTimeAddon;

  final List<Map<String, dynamic>> selectedValueServices;

  final Map<String, List<String>> selectedCustomServices;

  final Map<String, Map<String, Map<String, List<String>>>>
  selectedDailyTimedServices;

  final List<Map<String, dynamic>> pets;

  final Map<String, dynamic>? addonData;

  final String adminOrderSource;
  final bool applyLongStayDiscount;
  final ValueChanged<bool> onApplyLongStayDiscountChanged;
  final Map<String, dynamic>? discountInfo;
  final TextEditingController noteController;

  final bool depositEnabled;

  final int depositAmount;

  final String payAmountType;

  final String? paymentMethod;

  final bool cashEnabled;

  final bool transferEnabled;

  final ValueChanged<String> onPayAmountTypeChanged;

  final ValueChanged<String?> onPaymentMethodChanged;

  final void Function(String value) onOrderSourceChanged;

  final String Function(DateTime date) formatDate;

  @override
  Widget build(BuildContext context) {
    if (member == null ||
        roomType == null ||
        startDate == null ||
        endDate == null) {
      return const SizedBox();
    }

    final nights = endDate!.difference(startDate!).inDays;

    final roomName = roomType!['name']?.toString() ?? '未選房型';

    final price = roomType!['price'] ?? 0;

    final extraPetPrice = roomType!['extraPrice'] ?? 0;

    final extraPetCount = selectedPetIds.length > 1
        ? selectedPetIds.length - 1
        : 0;

    final extraPetTotal = extraPetPrice * extraPetCount * nights;

    final valueAddonTotal = selectedValueServices.fold<int>(
      0,
      (sum, item) => sum + ((item['total'] ?? 0) as int),
    );

    final timeAddonTotal = (selectedTimeAddon?['total'] ?? 0) as int;

    final customAddonTotal = selectedCustomServices.entries.fold<int>(0, (
      sum,
      entry,
    ) {
      final service = List<Map<String, dynamic>>.from(
        addonData?['customServices'] ?? [],
      ).firstWhere((item) => item['name'] == entry.key, orElse: () => {});

      final price = service['price'] ?? 0;

      return sum + ((price as int) * entry.value.length);
    });

    final dailyTimedServices = List<Map<String, dynamic>>.from(
      addonData?['dailyTimedServices'] ?? [],
    );

    var dailyTimedAddonTotal = 0;

    for (final entry in dailyTimedServices.asMap().entries) {
      final serviceIndex = entry.key;
      final service = entry.value;

      final rawServiceId = service['id']?.toString().trim() ?? '';
      final serviceName = service['name']?.toString().trim() ?? '';

      final serviceId = rawServiceId.isNotEmpty
          ? rawServiceId
          : serviceName.isNotEmpty
          ? 'daily_timed_$serviceName'
          : 'daily_timed_$serviceIndex';

      final selections = selectedDailyTimedServices[serviceId];

      if (selections == null) {
        continue;
      }

      final servicePrice = ((service['price'] ?? 0) as num).toInt();

      var count = 0;

      for (final petSelections in selections.values) {
        for (final slotIds in petSelections.values) {
          count += slotIds.length;
        }
      }

      dailyTimedAddonTotal += servicePrice * count;
    }

    final addonTotal =
        valueAddonTotal +
        timeAddonTotal +
        customAddonTotal +
        dailyTimedAddonTotal;
    final totalPrice = (price * nights) + extraPetTotal + addonTotal;
    final finalTotal = discountInfo != null
        ? ((discountInfo!['finalTotal'] ?? totalPrice) as num).toInt()
        : totalPrice;

    final int specialDateSurchargeAmount = discountInfo == null
        ? 0
        : ((discountInfo!['specialDateSurchargeAmount'] ?? 0) as num).toInt();

    final List<Map<String, dynamic>> specialDateSurchargeDetails =
        discountInfo == null
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            discountInfo!['specialDateSurchargeDetails'] ?? const <dynamic>[],
          );

    final currentPayAmount = depositAmount.clamp(0, finalTotal).toInt();

    final remainingAmount = (finalTotal - currentPayAmount)
        .clamp(0, finalTotal)
        .toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '第六步：確認資料',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 8),

        const Text(
          '確認資料無誤後，下一步會建立訂單並鎖房。',
          style: TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: adminOrderSource,
          decoration: InputDecoration(
            labelText: '下單方式',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: const [
            DropdownMenuItem(value: '電話預約', child: Text('電話預約')),
            DropdownMenuItem(value: 'LINE 預約', child: Text('LINE 預約')),
            DropdownMenuItem(value: '現場預約', child: Text('現場預約')),
            DropdownMenuItem(value: '其他', child: Text('其他')),
          ],
          onChanged: (value) {
            onOrderSourceChanged(value ?? '電話預約');
          },
        ),

        const SizedBox(height: 12),

        TextField(
          controller: noteController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '訂單備註',
            hintText: '例如：電話預約、LINE 預約、已口頭確認、特殊照顧事項',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),

        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '付款設定',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),

              const SizedBox(height: 8),

              if (depositEnabled)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    '收訂金',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  value: 'deposit',
                  groupValue: payAmountType,
                  onChanged: (value) {
                    if (value != null) {
                      onPayAmountTypeChanged(value);
                    }
                  },
                ),

              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  '收全額',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                value: 'full',
                groupValue: payAmountType,
                onChanged: (value) {
                  if (value != null) {
                    onPayAmountTypeChanged(value);
                  }
                },
              ),

              const Divider(height: 24),

              const Text('付款方式', style: TextStyle(fontWeight: FontWeight.w800)),

              if (cashEnabled)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('現金'),
                  value: 'cash',
                  groupValue: paymentMethod,
                  onChanged: onPaymentMethodChanged,
                ),

              if (transferEnabled)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('銀行轉帳'),
                  value: 'transfer',
                  groupValue: paymentMethod,
                  onChanged: onPaymentMethodChanged,
                ),

              if (!cashEnabled && !transferEnabled)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '店家尚未啟用付款方式',
                    style: TextStyle(color: Colors.red),
                  ),
                ),

              const Divider(height: 24),

              _confirmRow('訂單總金額', 'NT\$ $finalTotal'),

              _confirmRow(
                payAmountType == 'full' ? '本次收全額' : '本次收訂金',
                'NT\$ $currentPayAmount',
              ),

              _confirmRow('剩餘尾款', 'NT\$ $remainingAmount'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmRow('會員', member!['name'] ?? '未填姓名'),

              _confirmRow('電話', member!['phone'] ?? '未填電話'),

              _confirmRow('寵物數', '${selectedPetIds.length} 隻'),

              _confirmRow(
                '日期',
                '${formatDate(startDate!)} ～ ${formatDate(endDate!)}',
              ),

              _confirmRow('晚數', '$nights 晚'),

              _confirmRow('房型', roomName),

              _confirmRow('房型單價', 'NT\$ $price'),

              if (specialDateSurchargeAmount > 0) ...[
                _confirmRow('特殊日期加價', '+NT\$ $specialDateSurchargeAmount'),

                ...specialDateSurchargeDetails.map((detail) {
                  final String date = (detail['date'] ?? '').toString();

                  final int amount = ((detail['amount'] ?? 0) as num).toInt();

                  final List<Map<String, dynamic>> items =
                      List<Map<String, dynamic>>.from(
                        detail['items'] ?? const <dynamic>[],
                      );

                  final String names = items
                      .map((item) => (item['name'] ?? '').toString().trim())
                      .where((name) => name.isNotEmpty)
                      .join('、');

                  return _confirmRow(
                    '加價明細',
                    '$date${names.isEmpty ? '' : '｜$names'}｜+NT\$ $amount',
                  );
                }),
              ],

              const SizedBox(height: 4),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '套用自動優惠',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('開啟後，符合店家優惠活動條件時會自動套用最佳優惠'),
                value: applyLongStayDiscount,
                onChanged: onApplyLongStayDiscountChanged,
              ),

              const SizedBox(height: 4),

              if (extraPetCount > 0)
                _confirmRow(
                  '寵物加價',
                  'NT\$ $extraPetPrice × '
                      '$extraPetCount 隻 × '
                      '$nights 晚 = NT\$ $extraPetTotal',
                ),

              if (selectedTimeAddon != null)
                _confirmRow(
                  '時間加購',
                  '${selectedTimeAddon!['name']} '
                      '/ NT\$ $timeAddonTotal',
                ),

              if (selectedCustomServices.isNotEmpty)
                ...selectedCustomServices.entries.map((entry) {
                  final serviceName = entry.key;
                  final count = entry.value.length;

                  if (count <= 0) {
                    return const SizedBox();
                  }

                  final service =
                      List<Map<String, dynamic>>.from(
                        addonData?['customServices'] ?? [],
                      ).firstWhere(
                        (item) => item['name'] == serviceName,
                        orElse: () => {},
                      );

                  final price = service['price'] ?? 0;

                  final total = price * count;

                  return _confirmRow(
                    '客製化服務',
                    '$serviceName '
                        '/ $count 隻 '
                        '/ NT\$ $total',
                  );
                }),

              if (selectedDailyTimedServices.isNotEmpty)
                ...dailyTimedServices.asMap().entries.expand((entry) {
                  final serviceIndex = entry.key;
                  final service = entry.value;

                  final rawServiceId = service['id']?.toString().trim() ?? '';
                  final serviceName =
                      service['name']?.toString().trim().isNotEmpty == true
                      ? service['name'].toString().trim()
                      : '每日分時段服務';

                  final serviceId = rawServiceId.isNotEmpty
                      ? rawServiceId
                      : serviceName.isNotEmpty
                      ? 'daily_timed_$serviceName'
                      : 'daily_timed_$serviceIndex';

                  final servicePrice = ((service['price'] ?? 0) as num).toInt();

                  final selections = selectedDailyTimedServices[serviceId];

                  if (selections == null || selections.isEmpty) {
                    return <Widget>[];
                  }

                  final rows = <Widget>[];

                  for (final petEntry in selections.entries) {
                    final petId = petEntry.key;

                    final pet = pets.firstWhere((item) {
                      final itemPetId =
                          item['petId']?.toString() ??
                          item['id']?.toString() ??
                          '';

                      return itemPetId == petId;
                    }, orElse: () => <String, dynamic>{});

                    final petName =
                        pet['name']?.toString().trim().isNotEmpty == true
                        ? pet['name'].toString().trim()
                        : petId;

                    final sortedDates = petEntry.value.entries.toList()
                      ..sort((a, b) => a.key.compareTo(b.key));

                    for (final dateEntry in sortedDates) {
                      final slotIds = dateEntry.value;

                      if (slotIds.isEmpty) {
                        continue;
                      }

                      final timeSlots = List<Map<String, dynamic>>.from(
                        service['timeSlots'] ?? [],
                      );

                      final slotLabels = slotIds.map((slotId) {
                        final slot = timeSlots.firstWhere((item) {
                          final itemId = item['id']?.toString() ?? '';
                          return itemId == slotId;
                        }, orElse: () => <String, dynamic>{});

                        final label = slot['label']?.toString().trim() ?? '';

                        return label.isNotEmpty ? label : slotId;
                      }).toList();

                      final total = servicePrice * slotIds.length;

                      rows.add(
                        _confirmRow(
                          '每日服務',
                          '$serviceName｜$petName\n'
                              '${dateEntry.key}｜${slotLabels.join('、')}\n'
                              '${slotIds.length} 次 × NT\$ $servicePrice = NT\$ $total',
                        ),
                      );
                    }
                  }

                  return rows;
                }),

              if (selectedValueServices.isNotEmpty)
                ...selectedValueServices.map((item) {
                  final name = item['name']?.toString() ?? '加值服務';

                  final total = item['total'] ?? item['price'] ?? 0;

                  return _confirmRow('加值服務', '$name / NT\$ $total');
                }),

              if (addonTotal > 0) _confirmRow('加值服務小計', 'NT\$ $addonTotal'),

              if (discountInfo != null &&
                  ((discountInfo!['discountAmount'] ?? 0) as int) > 0) ...[
                _confirmRow('原價', 'NT\$ ${discountInfo!['originalTotal']}'),
                _confirmRow('優惠活動', _buildDiscountDescription(discountInfo!)),
                if ((discountInfo!['discountCampaignType'] ?? '').toString() ==
                    'newMember') ...[
                  if (((discountInfo!['discountUsedNights'] ?? 0) as num)
                          .toInt() >
                      0)
                    _confirmRow(
                      '本次優惠晚數',
                      '${((discountInfo!['discountUsedNights'] ?? 0) as num).toInt()} 晚',
                    ),
                  _confirmRow(
                    '剩餘優惠晚數',
                    '${((discountInfo!['remainingDiscountNights'] ?? 0) as num).toInt()} 晚',
                  ),
                ],
                _confirmRow('折扣後金額', 'NT\$ ${discountInfo!['finalTotal']}'),
              ] else ...[
                _confirmRow('總金額', 'NT\$ $finalTotal'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _buildDiscountDescription(Map<String, dynamic> info) {
    final campaignName = info['discountCampaignName']?.toString().trim() ?? '';

    final campaignType = info['discountCampaignType']?.toString().trim() ?? '';

    final valueType = info['discountValueType']?.toString().trim() ?? '';

    final discountValue = info['discountValue'];

    final discountAmount = ((info['discountAmount'] ?? 0) as num).toInt();

    final discountPercent = ((info['discountPercent'] ?? 0) as num).toInt();

    final minimumNights = ((info['discountMinNights'] ?? 0) as num).toInt();

    final lines = <String>[];

    if (campaignName.isNotEmpty) {
      lines.add(campaignName);
    } else {
      switch (campaignType) {
        case 'newMember':
          lines.add('新會員優惠');
          break;

        case 'longStay':
          lines.add('長住優惠');
          break;

        case 'stayDate':
          lines.add('特定住宿日期優惠');
          break;

        case 'roomType':
          lines.add('指定房型優惠');
          break;

        case 'minimumAmount':
          lines.add('滿額優惠');
          break;

        case 'limitedTime':
          lines.add('限時下單優惠');
          break;

        case 'googleReview':
          lines.add('Google 評論優惠');
          break;

        default:
          lines.add('訂單優惠');
      }
    }

    if (campaignType == 'longStay' && minimumNights > 0) {
      lines.add('滿 $minimumNights 晚');
    }

    if (valueType == 'percent' && discountValue is num) {
      lines.add('${discountValue.toInt()}%');
    } else if (discountPercent > 0) {
      lines.add('$discountPercent%');
    }

    lines.add('- NT\$ $discountAmount');

    return lines.join('｜');
  }
}

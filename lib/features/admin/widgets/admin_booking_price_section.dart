// lib/features/admin/widgets/admin_booking_price_section.dart
// 💰 後台訂單詳細頁：價格與付款區塊
// 功能：顯示房費、寵物加價、加值服務、總價、訂金、付款方式、轉帳後五碼與轉帳截圖

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_date_helpers.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_text_helpers.dart';

class AdminBookingPriceSection extends StatelessWidget {
  const AdminBookingPriceSection({
    super.key,
    required this.data,
    required this.pets,
  });

  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> pets;

  @override
  Widget build(BuildContext context) {
    final basePrice = data['basePrice'] ?? 0;
    final extraPetPrice = data['extraPetPrice'] ?? 0;
    final extraPetCount = data['extraPetCount'] ?? 0;
    final extraPetTotal = data['extraPetTotal'] ?? 0;

    final nights = data['nights'] ?? 1;
    final roomPriceTotal = basePrice * nights;
    final petPriceTotal = extraPetTotal;
    final correctSubtotal = roomPriceTotal + petPriceTotal;

    final depositPaid = data['depositPaid'] == true;
    final depositAmount = data['depositAmount'] ?? 0;
    final payAmountType = (data['payAmountType'] ?? 'deposit').toString();

    final paymentTitle = payAmountType == 'full' ? '全額' : '訂金';

    final paymentAmount = payAmountType == 'full'
        ? (data['totalPrice'] ?? 0)
        : depositAmount;
    final paymentMethodText = adminBookingPaymentMethodText(
      data['paymentMethod'],
    );
    final originalTotal = (data['originalTotal'] ?? 0) as num;
    final discountAmount = (data['discountAmount'] ?? 0) as num;
    final discountPercent = (data['discountPercent'] ?? 0) as num;
    final discountMinNights = (data['discountMinNights'] ?? 0) as num;
    final discountBase = (data['discountBase'] ?? '').toString();
    final discountCampaignName = (data['discountCampaignName'] ?? '')
        .toString()
        .trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('房費'),
                  Text(
                    'NT\$ $basePrice × $nights 晚',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'NT\$ $roomPriceTotal',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('寵物加價'),
                  Text(
                    extraPetCount > 0
                        ? 'NT\$ $extraPetPrice × $extraPetCount 隻 × $nights 晚'
                        : '-',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'NT\$ $petPriceTotal',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const Divider(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '小計',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'NT\$ $correctSubtotal',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        if ((data['addons'] ?? []).isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('加值服務', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),

              ...List.generate((data['addons'] as List).length, (index) {
                final item = data['addons'][index];

                final price = item['price'] ?? 0;
                final count = item['count'] ?? 1;
                final total = item['total'] ?? (price * count);

                final List<dynamic> petIds = item['petNames'] ?? [];

                final List<String> petNames = petIds
                    .map<String>((id) {
                      final match = pets
                          .cast<Map<String, dynamic>?>()
                          .firstWhere(
                            (p) => p?['name'] == id || p?['petId'] == id,
                            orElse: () => null,
                          );

                      final name = match != null ? match['name'] : id;
                      return name?.toString() ?? '';
                    })
                    .where((name) => name.isNotEmpty)
                    .toList();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('🐾 ', style: TextStyle(fontSize: 16)),
                              Text(
                                item['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '+NT\$ $total',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      if (count > 1)
                        Text(
                          '$price x $count = $total',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),

                      if (item['type'] == 'custom' && petNames.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '👉 指定寵物：${petNames.join('、')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                      if ((item['type'] ?? '').toString() == 'daily_timed')
                        ..._buildDailyTimedSelections(item),
                    ],
                  ),
                );
              }),
            ],
          ),

        const SizedBox(height: 10),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (discountAmount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('原價', style: TextStyle(color: Colors.grey)),
                    Text(
                      'NT\$ ${originalTotal.toInt()}',
                      style: const TextStyle(
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      discountCampaignName.isNotEmpty
                          ? discountCampaignName
                          : '長住優惠（滿${discountMinNights.toInt()}晚 ${discountPercent.toInt()}%）',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '- NT\$ ${discountAmount.toInt()}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('折扣範圍', style: TextStyle(color: Colors.grey)),
                    Text(
                      discountBase == 'room'
                          ? '只折房價'
                          : discountBase == 'room_pet'
                          ? '房價＋寵物加價'
                          : '總金額（含加值服務）',
                    ),
                  ],
                ),

                const Divider(height: 20),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '總價',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  Text(
                    'NT\$ ${data['totalPrice'] ?? 0}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    paymentTitle,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'NT\$ $paymentAmount',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: depositPaid ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (paymentAmount > 0)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: depositPaid ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    depositPaid ? '✅ 已確認$paymentTitle' : '❌ 尚未確認$paymentTitle',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: depositPaid ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                if (!depositPaid && data['depositExpireAt'] != null)
                  Text(
                    adminBookingFormatDateTime(data['depositExpireAt']),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '💡 本訂單無需訂金',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),

        const SizedBox(height: 10),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.payment, color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '付款方式',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      paymentMethodText,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (data['paymentMethod'] == 'transfer') ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.yellow.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️ 客戶轉帳後五碼',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (data['transferLast5'] ?? '').toString().isEmpty
                      ? '未填寫'
                      : data['transferLast5'].toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),

        if (data['transferImageUrl'] != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '📷 客戶轉帳截圖',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ),

                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 5,
                          child: Image.network(
                            data['transferImageUrl'],
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    child: Image.network(
                      data['transferImageUrl'],
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _buildDailyTimedSelections(dynamic item) {
    final rawSelections = item['selections'];

    if (rawSelections is! List || rawSelections.isEmpty) {
      return const [];
    }

    final widgets = <Widget>[];

    for (final rawSelection in rawSelections) {
      if (rawSelection is! Map) {
        continue;
      }

      final selection = Map<String, dynamic>.from(rawSelection);

      final petName = (selection['petName'] ?? selection['petId'] ?? '寵物')
          .toString();

      final rawDates = selection['dates'];

      if (rawDates is! List || rawDates.isEmpty) {
        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            '🐾 $petName',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
        ),
      );

      for (final rawDate in rawDates) {
        if (rawDate is! Map) {
          continue;
        }

        final dateData = Map<String, dynamic>.from(rawDate);

        final date = _formatDailyTimedDate((dateData['date'] ?? '').toString());

        final slotLabels = dateData['slotLabels'] is List
            ? List<String>.from(dateData['slotLabels'])
            : <String>[];

        final slotIds = dateData['slotIds'] is List
            ? List<String>.from(dateData['slotIds'])
            : <String>[];

        final labels = slotLabels.isNotEmpty ? slotLabels : slotIds;

        if (date.isEmpty || labels.isEmpty) {
          continue;
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 4),
            child: Text(
              '├─ $date　${labels.join('、')}',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  String _formatDailyTimedDate(String value) {
    if (value.isEmpty) {
      return '';
    }

    final parts = value.split('-');

    if (parts.length != 3) {
      return value;
    }

    return '${parts[0]}/${parts[1]}/${parts[2]}';
  }
}

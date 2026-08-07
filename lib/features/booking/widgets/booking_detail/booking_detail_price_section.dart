// lib/features/booking/widgets/booking_detail/booking_detail_price_section.dart
// 💰 客戶端訂單詳細頁：價格與加值服務區塊
// 功能：顯示房費、寵物加價、加值服務、總金額與訂金

import 'package:flutter/material.dart';

class BookingDetailPriceSection extends StatelessWidget {
  const BookingDetailPriceSection({
    super.key,
    required this.data,
    required this.basePrice,
    required this.nights,
    required this.extraPetPrice,
    required this.extraPetCount,
    required this.roomPriceTotal,
    required this.petPriceTotal,
    required this.correctSubtotal,
    required this.addonTotal,
    required this.finalTotal,
  });

  final Map<String, dynamic> data;
  final dynamic basePrice;
  final dynamic nights;
  final dynamic extraPetPrice;
  final dynamic extraPetCount;
  final dynamic roomPriceTotal;
  final dynamic petPriceTotal;
  final dynamic correctSubtotal;
  final int addonTotal;
  final dynamic finalTotal;

  @override
  Widget build(BuildContext context) {
    final payAmountType = (data['payAmountType'] ?? 'deposit').toString();

    final originalTotal = (data['originalTotal'] ?? 0) as num;
    final discountAmount = (data['discountAmount'] ?? 0) as num;
    final discountPercent = (data['discountPercent'] ?? 0) as num;
    final discountMinNights = (data['discountMinNights'] ?? 0) as num;
    final discountBase = (data['discountBase'] ?? '').toString();
    final discountCampaignName = (data['discountCampaignName'] ?? '')
        .toString()
        .trim();

    final discountCampaignDescription =
        (data['discountCampaignDescription'] ?? '').toString().trim();

    final String couponId = (data['couponId'] ?? '').toString().trim();
    final String couponName = (data['couponName'] ?? '').toString().trim();
    final num couponDiscountAmount = (data['couponDiscountAmount'] ?? 0) as num;

    final bool hasCampaignDiscount = discountAmount > 0;
    final bool hasCouponDiscount =
        couponId.isNotEmpty && couponDiscountAmount > 0;
    final bool hasAnyDiscount = hasCampaignDiscount || hasCouponDiscount;

    final paymentLabel = payAmountType == 'full' ? '需支付全額' : '需支付訂金';

    final paymentAmount = payAmountType == 'full'
        ? finalTotal
        : (data['depositAmount'] ?? 0);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('房費'),
                  Text(
                    '$basePrice × $nights 晚',
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
                        ? '$extraPetPrice × $extraPetCount 隻 × $nights 晚'
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

        if ((data['addons'] ?? []).isNotEmpty)
          _sectionCard(
            title: '加值服務',
            children: [
              ...List.generate((data['addons'] as List).length, (index) {
                final item = data['addons'][index];
                final pets = (data['pets'] ?? []) as List;
                final petIds = (item['petNames'] ?? []) as List;

                final petNames = petIds
                    .map((id) {
                      final match = pets
                          .cast<Map<String, dynamic>?>()
                          .firstWhere(
                            (p) => p?['name'] == id || p?['petId'] == id,
                            orElse: () => null,
                          );
                      return match != null ? match['name'] : id;
                    })
                    .where((e) => e != null && e.toString().isNotEmpty)
                    .toList();

                final price = (item['price'] ?? 0) as num;
                final count = (item['count'] ?? 1) as num;
                final total = (item['total'] ?? (price * count)) as num;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
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
                          Text(
                            item['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '+ NT\$ ${total.toInt()}',
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      if (count > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${price.toInt()} x ${count.toInt()} = ${total.toInt()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                      if (petNames.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '👉 ${petNames.join('、')}',
                            style: const TextStyle(
                              fontSize: 12,
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

              const Divider(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '加值服務小計',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'NT\$ $addonTotal',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasAnyDiscount) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('原價', style: TextStyle(color: Colors.white70)),
                    Text(
                      'NT\$ ${originalTotal.toInt()}',
                      style: const TextStyle(
                        color: Colors.white70,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),

                if (hasCampaignDiscount) ...[
                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                discountCampaignName.isNotEmpty
                                    ? discountCampaignName
                                    : '優惠活動',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (discountCampaignDescription.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  _showDiscountDescription(
                                    context,
                                    campaignName:
                                        discountCampaignName.isNotEmpty
                                        ? discountCampaignName
                                        : '優惠活動',
                                    description: discountCampaignDescription,
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '- NT\$ ${discountAmount.toInt()}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '折扣範圍',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        discountBase == 'room'
                            ? '只折房價'
                            : discountBase == 'room_pet'
                            ? '房價＋寵物加價'
                            : '總金額（含加值服務）',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ],

                if (hasCouponDiscount) ...[
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.confirmation_number_outlined,
                              size: 18,
                              color: Colors.amberAccent,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                couponName.isNotEmpty ? couponName : '會員優惠券',
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '- NT\$ ${couponDiscountAmount.toInt()}',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],

                const Divider(color: Colors.white24, height: 24),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    hasAnyDiscount ? '折後總價' : '總金額',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    'NT\$ $finalTotal',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    paymentLabel,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    'NT\$ $paymentAmount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: (data['depositStatus'] == 'confirmed')
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showDiscountDescription(
    BuildContext context, {
    required String campaignName,
    required String description,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(bottomSheetContext).size.height * 0.65,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.card_giftcard_outlined,
                        color: Color(0xFF2E8B47),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          campaignName,
                          style: Theme.of(bottomSheetContext)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Flexible(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        description,
                        style: const TextStyle(fontSize: 15, height: 1.65),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                      },
                      child: const Text('關閉'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
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

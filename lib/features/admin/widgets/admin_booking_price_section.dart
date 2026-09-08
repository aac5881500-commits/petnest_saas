// 檔案名稱：lib/features/admin/widgets/admin_booking_price_section.dart
// 功能說明：顯示房費、寵物加價、加值服務、總價、訂金、付款方式、轉帳後五碼與轉帳截圖
// 💰 後台訂單詳細頁：價格與付款區塊

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_fee_line_item.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/services/daycare_payment_display.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';
import 'package:petnest_saas/core/widgets/booking_payment_deadline_banner.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_date_helpers.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_text_helpers.dart';

class AdminBookingPriceSection extends StatelessWidget {
  const AdminBookingPriceSection({
    super.key,
    required this.data,
    required this.pets,
    this.lineItemsOnly = false,
  });

  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> pets;
  final bool lineItemsOnly;

  @override
  Widget build(BuildContext context) {
    if (BookingKind.isDaycare(data)) {
      return _DaycareAdminPriceSection(
        data: data,
        lineItemsOnly: lineItemsOnly,
      );
    }
    return _stayPrice(context);
  }

  Widget _stayPrice(BuildContext context) {
    final basePrice = data['basePrice'] ?? 0;
    final extraPetPrice = data['extraPetPrice'] ?? 0;
    final extraPetCount = data['extraPetCount'] ?? 0;
    final extraPetTotal = data['extraPetTotal'] ?? 0;

    final nights = data['nights'] ?? 1;
    final roomPriceTotal = basePrice * nights;
    final petPriceTotal = extraPetTotal;
    final correctSubtotal = roomPriceTotal + petPriceTotal;
    final int specialDateSurchargeAmount =
        ((data['specialDateSurchargeAmount'] ?? 0) as num).toInt();

    final List<Map<String, dynamic>> specialDateSurchargeDetails =
        List<Map<String, dynamic>>.from(
          data['specialDateSurchargeDetails'] ?? const <dynamic>[],
        );
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

    final discountCampaignDescription =
        (data['discountCampaignDescription'] ?? '').toString().trim();

    final String couponId = (data['couponId'] ?? '').toString().trim();
    final String couponName = (data['couponName'] ?? '').toString().trim();

    final num couponDiscountAmount = data['couponDiscountAmount'] is num
        ? data['couponDiscountAmount'] as num
        : num.tryParse((data['couponDiscountAmount'] ?? '0').toString()) ?? 0;

    final bool hasCampaignDiscount = discountAmount > 0;

    final bool hasCouponDiscount =
        couponId.isNotEmpty && couponDiscountAmount > 0;

    final bool hasAnyDiscount = hasCampaignDiscount || hasCouponDiscount;

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
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(child: Text('房費')),
                  Expanded(
                    child: Text(
                      'NT\$ $basePrice × $nights 晚',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  Text(
                    'NT\$ $roomPriceTotal',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Expanded(child: Text('寵物加價')),
                  Expanded(
                    child: Text(
                      extraPetCount > 0
                          ? 'NT\$ $extraPetPrice × $extraPetCount 隻 × $nights 晚'
                          : '-',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
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
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: (data['addons'] as List).length <= 3,
              tilePadding: EdgeInsets.zero,
              title: Text(
                '加值服務（${(data['addons'] as List).length}項）',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              children: List.generate((data['addons'] as List).length, (index) {
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
            ),
          ),

        const SizedBox(height: 10),

        if (specialDateSurchargeAmount > 0) ...[
          Container(
            width: double.infinity,
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
                  children: [
                    const Expanded(
                      child: Text(
                        '特殊日期加價',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      '+ NT\$ $specialDateSurchargeAmount',
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),

                if (specialDateSurchargeDetails.isNotEmpty) ...[
                  const Divider(height: 22),

                  ...specialDateSurchargeDetails.map((detail) {
                    final String date = _formatDailyTimedDate(
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
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '$date${names.isEmpty ? '' : '　$names'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '+ NT\$ $amount',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),
        ],

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasAnyDiscount) ...[
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
                                    : '長住優惠（滿${discountMinNights.toInt()}晚 ${discountPercent.toInt()}%）',
                                style: const TextStyle(
                                  color: Colors.green,
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
                                    color: Colors.green,
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
                ],

                if (hasCouponDiscount) ...[
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(
                        Icons.confirmation_number_outlined,
                        size: 18,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 6),

                      Expanded(
                        child: Text(
                          couponName.isNotEmpty ? couponName : '會員優惠券',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Text(
                        '- NT\$ ${couponDiscountAmount.toInt()}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],

                const Divider(height: 20),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    hasAnyDiscount ? '折後總價' : '總價',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
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

        if (!lineItemsOnly && paymentAmount > 0)
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
        else if (!lineItemsOnly)
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

        if (!lineItemsOnly) ...<Widget>[
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
        ],
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
}

class _DaycareAdminPriceSection extends StatelessWidget {
  const _DaycareAdminPriceSection({
    required this.data,
    this.lineItemsOnly = false,
  });

  final Map<String, dynamic> data;
  final bool lineItemsOnly;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> snapshot = data['daycarePricingSnapshot'] is Map
        ? Map<String, dynamic>.from(data['daycarePricingSnapshot'] as Map)
        : <String, dynamic>{};
    final int displayTotal = DaycarePaymentDisplay.resolveTotal(data);
    final int displayPaid = DaycarePaymentDisplay.resolvePaid(data);
    final int displayRemaining = DaycarePaymentDisplay.resolveRemaining(
      total: displayTotal,
      paid: displayPaid,
    );
    final List<BookingFeeLineItem> timeLines = DaycarePricingService.instance
        .itemLinesFromBooking(data);
    final List<dynamic> addons = (data['addons'] as List?) ?? const <dynamic>[];
    int addonLinesTotal = 0;
    for (final dynamic item in addons) {
      if (item is Map) {
        addonLinesTotal += DaycarePaymentDisplay.toInt(
          item['total'] ?? item['price'],
        );
      }
    }
    final int snapshotAddonAmount = DaycarePaymentDisplay.toInt(
      snapshot['addonAmount'],
    );
    final int addonAmount = addons.isNotEmpty
        ? addonLinesTotal
        : snapshotAddonAmount;
    final int couponAmount = DaycarePaymentDisplay.toInt(
      data['couponDiscountAmount'] ?? snapshot['couponAmount'],
    );
    final int discountAmount = DaycarePaymentDisplay.toInt(
      data['discountAmount'] ?? snapshot['discountAmount'],
    );
    int subtotal = addonAmount;
    for (final BookingFeeLineItem line in timeLines) {
      subtotal += line.amount;
    }

    Widget moneyRow(
      String label,
      int amount, {
      bool negative = false,
      String subtitle = '',
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            Text(
              '${negative ? '-' : ''}NT\$ $amount',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: negative ? Colors.green : Colors.black,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              ...timeLines.map(
                (BookingFeeLineItem line) => moneyRow(
                  line.label,
                  line.amount.abs(),
                  negative: line.amount < 0,
                  subtitle: line.subtitle,
                ),
              ),
              if (addonAmount > 0 && addons.isEmpty)
                moneyRow('加值服務', addonAmount),
              if (subtotal != 0 || timeLines.isNotEmpty) ...<Widget>[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      '折扣前小計',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'NT\$ $subtotal',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (addons.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: addons.length <= 3,
              tilePadding: EdgeInsets.zero,
              title: Text(
                '加值服務（${addons.length}項）',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              children: addons.whereType<Map>().map((Map item) {
                final int total = DaycarePaymentDisplay.toInt(
                  item['total'] ?? item['price'],
                );
                if (total <= 0) {
                  return const SizedBox.shrink();
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          (item['name'] ?? '加值服務').toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '+NT\$ $total',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              if (discountAmount > 0)
                moneyRow('折扣', discountAmount, negative: true),
              if (couponAmount > 0)
                moneyRow(
                  (data['couponName'] ?? '優惠券').toString(),
                  couponAmount,
                  negative: true,
                ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    '應付金額',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'NT\$ $displayTotal',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
              const Divider(height: 24),
              if (!lineItemsOnly) ...<Widget>[
                moneyRow('已付款', displayPaid),
                moneyRow('尚需付款', displayRemaining),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text('付款狀態', style: TextStyle(color: Colors.grey)),
                    Text(
                      DaycarePaymentDisplay.statusLabel(
                        total: displayTotal,
                        paid: displayPaid,
                        remaining: displayRemaining,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text('付款方式', style: TextStyle(color: Colors.grey)),
                    Text(
                      DaycarePaymentDisplay.storedPaymentMethodLabel(
                        data['paymentMethod'],
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (!lineItemsOnly) BookingPaymentDeadlineBanner(data: data),
        if (!lineItemsOnly &&
            (data['paymentMethod'] ?? '').toString() == 'transfer') ...<Widget>[
          const SizedBox(height: 10),
          Builder(
            builder: (BuildContext context) {
              final String last5 = (data['transferLast5'] ?? '')
                  .toString()
                  .trim();
              return Text(
                last5.isEmpty ? '尚無轉帳後五碼' : '轉帳後五碼 $last5',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

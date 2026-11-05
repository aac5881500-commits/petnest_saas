import 'booking_appearance_scope.dart';
import 'booking_editorial_design.dart';
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
    this.roomAmount,
    this.addonAmount,
    this.couponSection,
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
    this.pointAmount = 0,
    this.petNames = const <String>[],
    required this.timeAddon,
    required this.valueServices,
    required this.customServices,
    required this.customServicePrices,
    required this.dailyTimedServices,
    required this.selectedDailyTimedServices,
    this.petNamesById = const {},
  });

  final int? roomAmount, addonAmount;
  final Widget? couponSection;
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
  final int pointAmount;
  final List<String> petNames;
  final Map<String, dynamic>? timeAddon;
  final List<Map<String, dynamic>> valueServices;
  final Map<String, List<String>> customServices;
  final Map<String, int> customServicePrices;
  final List<Map<String, dynamic>> dailyTimedServices;
  final Map<String, Map<String, Map<String, List<String>>>>
  selectedDailyTimedServices;
  final Map<String, String> petNamesById;

  Widget _editorial(BuildContext context) {
    final t = BookingEditorial.theme(context);
    final cream = BookingAppearanceScope.of(context).style == 'cream';
    Widget amount(
      String label,
      int value, {
      String? note,
      bool strong = false,
    }) => Container(
      margin: cream ? const EdgeInsets.only(bottom: 9) : null,
      decoration: cream
          ? BoxDecoration(
              color: strong ? BookingEditorial.tint(context) : t.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.cardBorderColor),
            )
          : null,
      padding: cream
          ? const EdgeInsets.all(14)
          : const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final caption = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: strong
                    ? BookingEditorial.title(21, context)
                    : BookingEditorial.body(16, context),
              ),
              if (note != null)
                Text(note, style: BookingEditorial.body(13, context)),
            ],
          );
          final price = Text(
            'NT\$ $value',
            style: strong
                ? BookingEditorial.title(25, context)
                : BookingEditorial.body(17, context),
          );
          if (c.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 21) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                caption,
                const SizedBox(height: 5),
                Align(alignment: Alignment.centerRight, child: price),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: caption),
              const SizedBox(width: 12),
              price,
            ],
          );
        },
      ),
    );
    Widget detail(String label, Widget content) => Container(
      margin: cream ? const EdgeInsets.only(bottom: 12) : null,
      padding: cream
          ? const EdgeInsets.all(16)
          : const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: cream ? t.cardColor : null,
        borderRadius: cream ? BorderRadius.circular(24) : null,
        border: cream
            ? Border.all(color: t.cardBorderColor)
            : Border(bottom: BorderSide(color: t.cardBorderColor)),
      ),
      child: LayoutBuilder(
        builder: (context, c) =>
            c.maxWidth < 300 || MediaQuery.textScalerOf(context).scale(14) > 22
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: BookingEditorial.title(18, context)),
                  const SizedBox(height: 8),
                  content,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      label,
                      style: BookingEditorial.title(18, context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: content),
                ],
              ),
      ),
    );
    final lines = <MapEntry<String, int>>[
      if (timeAddon != null)
        MapEntry(
          timeAddon!['label']?.toString() ?? '入退房時間',
          ((timeAddon!['price'] ?? 0) as num).toInt(),
        ),
      for (final v in valueServices)
        MapEntry(
          v['name']?.toString() ?? '加值服務',
          ((v['price'] ?? 0) as num).toInt(),
        ),
      for (final v in customServices.entries)
        if (v.value.isNotEmpty)
          MapEntry(
            '${v.key}（${v.value.length} 隻）',
            (customServicePrices[v.key] ?? 0) * v.value.length,
          ),
    ];
    for (final entry in dailyTimedServices.asMap().entries) {
      final service = entry.value;
      final name = service['name']?.toString() ?? '';
      final raw = service['id']?.toString().trim() ?? '';
      final id = raw.isNotEmpty
          ? raw
          : name.isNotEmpty
          ? 'daily_timed_$name'
          : 'daily_timed_${entry.key}';
      var count = 0;
      for (final days in (selectedDailyTimedServices[id] ?? {}).values) {
        for (final slots in days.values) {
          count += slots.length;
        }
      }
      if (count > 0) {
        lines.add(
          MapEntry(
            '$name（$count 次）',
            ((service['price'] ?? 0) as num).toInt() * count,
          ),
        );
      }
    }
    final addons = addonAmount ?? lines.fold<int>(0, (sum, e) => sum + e.value);
    final room =
        roomAmount ??
        ((originalTotal ?? totalPrice) - addons - specialDateSurchargeAmount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BookingEditorial.heading('確認住宿安排', subtitle: '請核對本次住宿內容與費用。'),
        BookingEditorial.trip(
          '${startDateText.replaceAll('-', '/')}—${endDateText.replaceAll('-', '/')} · $nights 晚 · $petCount 隻',
        ),
        const SizedBox(height: 12),
        detail(
          '住宿日期',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '入住  $startDateText',
                style: BookingEditorial.body(16, context),
              ),
              Text(
                '退房  $endDateText',
                style: BookingEditorial.body(16, context),
              ),
            ],
          ),
        ),
        detail(
          '入住貓咪',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in petNames)
                Chip(
                  avatar: Icon(
                    Icons.pets_outlined,
                    size: 17,
                    color: t.primaryColor,
                  ),
                  label: Text(name, style: BookingEditorial.body(14, context)),
                  backgroundColor: t.backgroundColor,
                  side: BorderSide(color: t.cardBorderColor),
                ),
            ],
          ),
        ),
        detail(
          '入住房型',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(roomTypeName, style: BookingEditorial.title(19, context)),
              Text('$petCount 隻入住', style: BookingEditorial.body(14, context)),
            ],
          ),
        ),
        BookingEditorial.heading('加購服務'),
        if (lines.isEmpty)
          Text('本次未加購其他服務。', style: BookingEditorial.body(14, context)),
        for (final e in lines) ...[
          amount(e.key, e.value),
          Divider(color: t.cardBorderColor, height: 1),
        ],
        if (couponSection != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: couponSection!,
          ),
        BookingEditorial.heading('費用明細'),
        amount('住宿費用', room, note: '共 $nights 晚 · $petCount 隻'),
        amount('加購服務', addons),
        if (specialDateSurchargeAmount > 0)
          amount('特殊日期加價', specialDateSurchargeAmount),
        for (final d in specialDateSurchargeDetails)
          Text(
            '${d['date'] ?? ''} · NT\$ ${d['amount'] ?? 0}',
            style: BookingEditorial.body(12, context),
          ),
        if (discountAmount > 0)
          amount(
            discountCampaignName.isEmpty ? '住宿優惠' : discountCampaignName,
            -discountAmount,
          ),
        if (couponDiscountAmount > 0)
          amount(
            couponName.isEmpty ? '優惠券折抵' : couponName,
            -couponDiscountAmount,
          ),
        if (pointAmount > 0) amount('點數折抵', -pointAmount),
        if (discountAmount == 0 &&
            couponDiscountAmount == 0 &&
            pointAmount == 0)
          amount('優惠折抵', 0),
        Divider(color: t.primaryColor, height: 18),
        amount('應付總額', totalPrice, strong: true),
        if (depositAmount > 0) amount('訂金', depositAmount),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (const [
      'editorial',
      'cream',
    ].contains(BookingAppearanceScope.of(context).style)) {
      return _editorial(context);
    }
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
            if (pointAmount > 0) ...<Widget>[
              const SizedBox(height: 6),
              _infoRow('點數折抵', '-NT\$ $pointAmount'),
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

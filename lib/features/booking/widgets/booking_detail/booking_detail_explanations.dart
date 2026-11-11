import 'package:petnest_saas/core/utils/safe_parse.dart';

String _text(Object? value) => SafeParse.parseString(value).trim();
List<String> _strings(Object? value) => SafeParse.parseList(
  value,
).map(_text).where((text) => text.isNotEmpty).toList();

String _petName(String id, List<Map<String, dynamic>> pets) {
  if (id.isEmpty) return '未記錄寵物';
  for (final pet in pets) {
    if (_text(pet['petId'] ?? pet['id']) == id) {
      final name = _text(pet['name']);
      if (name.isNotEmpty) return name;
    }
  }
  return '未記錄名稱的寵物';
}

String addonExplanation(
  Map<String, dynamic> addon,
  List<Map<String, dynamic>> pets, {
  bool schedules = false,
  bool includePetSchedule = true,
}) {
  final parts = <String>[];
  final type = _text(addon['type']);
  final count = SafeParse.parseMoney(addon['count'] ?? addon['quantity'] ?? 1);
  final price = SafeParse.parseMoney(addon['price']);
  final amount = SafeParse.parseMoney(addon['total'] ?? addon['amount']);
  if (price > 0 && count > 0 && (amount == 0 || price * count == amount)) {
    parts.add('單價 NT\$ $price × $count');
  } else if (count > 1) {
    parts.add('數量 $count');
  }
  final selections = SafeParse.parseMapList(addon['selections']);
  final names = <String>[
    ..._strings(addon['petNames']),
    if (_strings(addon['petNames']).isEmpty)
      ..._strings(
        addon['selectedPetIds'] ?? addon['petIds'],
      ).map((id) => _petName(id, pets)),
    for (final selection in selections)
      _text(selection['petName']).isNotEmpty
          ? _text(selection['petName'])
          : _petName(_text(selection['petId']), pets),
  ];
  if (names.isNotEmpty && (!schedules || selections.isEmpty)) {
    parts.add('寵物：${names.toSet().join('、')}');
  }
  if (schedules) {
    if (includePetSchedule) {
      for (final schedule in addonPetSchedules(addon, pets)) {
        parts.addAll([schedule.name, ...schedule.times]);
      }
    }
    final slots = SafeParse.parseMapList(addon['selectedTimeSlots'])
        .map((slot) {
          final label = _text(slot['label']);
          final start = _text(slot['start'] ?? slot['startTime']);
          final end = _text(slot['end'] ?? slot['endTime']);
          return label.isNotEmpty
              ? label
              : [start, end].where((s) => s.isNotEmpty).join('–');
        })
        .where((s) => s.isNotEmpty);
    if (slots.isNotEmpty) parts.add('時段：${slots.join('、')}');
    final dates = _strings(addon['dates']);
    if (dates.isNotEmpty && selections.isEmpty) {
      parts.add('日期：${dates.join('、')}');
    }
    if (type == 'daily_timed' && selections.isEmpty && slots.isEmpty) {
      parts.add('此訂單未保存時段明細');
    }
  }
  return parts.join(schedules ? '\n' : ' ・ ');
}

String campaignExplanation(Map<String, dynamic> raw) {
  final snapshot = SafeParse.parseMap(raw['discountExplanation']);
  final type = _text(snapshot['type'] ?? raw['discountCampaignType']);
  final description = _text(
    snapshot['description'] ?? raw['discountCampaignDescription'],
  );
  final threshold = SafeParse.parseMoney(snapshot['minimumAmount']);
  final minimumNights = SafeParse.parseMoney(snapshot['minimumNights']);
  final eligible = SafeParse.parseMoney(snapshot['eligibleAmount']);
  final base = SafeParse.parseMoney(
    snapshot['baseAmount'] ?? raw['discountBase'],
  );
  final value =
      num.tryParse(_text(snapshot['value'] ?? raw['discountValue'])) ?? 0;
  final valueType = _text(snapshot['valueType'] ?? raw['discountValueType']);
  final nights = SafeParse.parseMoney(raw['discountUsedNights']);
  final cap = SafeParse.parseMoney(snapshot['maximumDiscountAmount']);
  final name = _text(raw['discountCampaignName']);
  final parts = <String>[
    if (type == 'minimumAmount' || name.contains('滿額'))
      threshold > 0
          ? '本單符合滿額門檻 NT\$ $threshold${eligible > 0 ? '（符合門檻的消費 NT\$ $eligible）' : ''}'
          : '本單已套用滿額優惠；此訂單未保存門檻金額',
    if (type == 'longStay')
      minimumNights > 0 ? '符合連住 $minimumNights 晚的活動條件' : '符合連住優惠條件',
    if (type == 'roomType') '預約房型符合活動條件',
    if (type == 'stayDate') '住宿日期符合活動條件',
    if (type == 'newMember') '符合新會員優惠條件',
    if (type == 'limitedTime') '在活動有效期間內預約',
    if (type == 'googleReview') '符合評論優惠條件',
    if (description.isNotEmpty) description,
    if (base > 0) '折扣計算基準 NT\$ $base',
    if (valueType == 'percent' && value > 0) '折抵 $value%',
    if (['fixed', 'fixedAmount'].contains(valueType) && value > 0)
      '固定折抵 NT\$ $value${nights > 0 ? '／晚' : ''}',
    if (nights > 0) '適用 $nights 晚',
    if (valueType == 'percent' && cap > 0) '最高折抵 NT\$ $cap',
  ];
  return parts.isEmpty ? '此訂單未保存優惠條件，折抵金額依下單紀錄' : parts.join('；');
}

List<({String name, List<String> times})> addonPetSchedules(
  Map<String, dynamic> addon,
  List<Map<String, dynamic>> pets,
) {
  return [
    for (final selection in SafeParse.parseMapList(addon['selections']))
      (
        name: _text(selection['petName']).isNotEmpty
            ? _text(selection['petName'])
            : _petName(_text(selection['petId']), pets),
        times: [
          for (final day in SafeParse.parseMapList(selection['dates']))
            _addonDayLabel(day),
        ],
      ),
  ];
}

String _addonDayLabel(Map<String, dynamic> day) {
  final date = _text(day['date']).replaceAll('-', '/');
  final slots = _strings(day['slotLabels']);
  return '${date.isEmpty ? '未記錄日期' : date}｜${slots.isEmpty ? '未記錄時段名稱' : slots.join('、')}';
}

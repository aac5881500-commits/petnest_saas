import 'pet_service_module.dart';

Map<String, String> petServiceKinds(PetServiceModule module) => module.isDog
    ? const {'overnight': '住宿', 'daycare': '日間安親', 'assessment': '適應評估'}
    : module.isHospital
    ? const {
        'consultation': '一般門診',
        'specialty': '專科門診',
        'wellness': '健檢／預防保健',
        'followup': '回診',
      }
    : const {
        'bath': '洗澡清潔',
        'styling': '造型修剪',
        'spa': '護理／SPA',
        'addon': '加購整理',
      };
String petServiceKind(PetServiceModule module, Map<String, dynamic> service) {
  final kinds = petServiceKinds(module);
  return kinds.containsKey(service['kind'])
      ? service['kind'] as String
      : kinds.keys.first;
}

bool dogServiceNeedsPickupDate(
  PetServiceModule module,
  Map<String, dynamic> service,
) => module.isDog && petServiceKind(module, service) == 'overnight';
String petServicePriceUnit(
  PetServiceModule module,
  Map<String, dynamic> service,
) {
  if (!module.isDog) return '次';
  return switch (petServiceKind(module, service)) {
    'overnight' => '晚',
    'daycare' => '日',
    _ => '次',
  };
}

String petServiceStatus(PetServiceModule module, String status) =>
    status == 'arrived'
    ? module.isDog
          ? '已入住／安親中'
          : module.isHospital
          ? '已報到／門診中'
          : '美容服務中'
    : serviceStatusLabels[status] ?? status;
List<String> petServiceRecordFields(PetServiceModule module) => module.isDog
    ? const ['飲食與飲水', '排泄與散步', '情緒與互動', '用藥／交接提醒']
    : module.isHospital
    ? const ['主訴與到院情況', '病史與用藥轉述', '院內處理／交接事項', '回診與聯絡安排']
    : const ['美容前毛況與皮膚觀察', '實際服務與造型', '服務中反應', '接回提醒'];
String composePetServiceRecord(
  PetServiceModule module,
  List<String> values,
  String note,
) {
  final fields = petServiceRecordFields(module);
  final parts = <String>[
    for (var i = 0; i < fields.length && i < values.length; i++)
      if (values[i].trim().isNotEmpty) '${fields[i]}：${values[i].trim()}',
    if (note.trim().isNotEmpty) '補充：${note.trim()}',
  ];
  final text = parts.join('\n');
  if (text.length > 3000) throw StateError('紀錄超過 3000 字，請縮短內容');
  return text;
}

String petServiceTimestamp(Object? value) {
  if (value == null) return '儲存中';
  DateTime? date;
  if (value is DateTime) {
    date = value;
  } else {
    try {
      date = (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return value.toString();
    }
  }
  final local = date.toUtc().add(const Duration(hours: 8));
  return '${serviceDate(local)} ${serviceTime(local.hour * 60 + local.minute)}';
}

bool petRequestOnDate(
  Map<String, dynamic> row,
  String date, {
  bool includeStay = true,
}) {
  final start = '${row['date'] ?? ''}',
      end = '${row['endDate'] ?? row['date'] ?? ''}';
  if (row['module'] == 'dog_hotel' && includeStay) {
    return start.compareTo(date) <= 0 && end.compareTo(date) >= 0;
  }
  return start == date;
}

List<Map<String, dynamic>> petServiceUpcoming(
  List<Map<String, dynamic>> rows,
  String today,
) {
  final result = rows
      .where(
        (e) =>
            ['pending', 'confirmed', 'arrived'].contains(e['status']) &&
            '${e['endDate'] ?? e['date'] ?? ''}'.compareTo(today) >= 0,
      )
      .toList();
  result.sort(
    (a, b) =>
        '${a['date']} ${a['time']}'.compareTo('${b['date']} ${b['time']}'),
  );
  return result;
}

/// Operational warnings only; the acceptance workflow remains manual.
/// Excludes cancelled and pending applications from committed resource usage.
List<String> petServiceConflicts(
  PetServiceModule module,
  Map<String, dynamic> request,
  List<Map<String, dynamic>> rows,
  PetServiceConfig config,
) {
  final selected = config.services
      .where((e) => e['id'] == request['serviceId'])
      .firstOrNull;
  final others = rows.where(
    (e) =>
        e['id'] != request['id'] &&
        ['confirmed', 'arrived'].contains(e['status']),
  );
  if (module.isDog) {
    final capacity = (selected?['capacity'] as num?)?.toInt() ?? 0;
    if (capacity <= 0) return [];
    DateTime? day = DateTime.tryParse('${request['date']}'),
        end = DateTime.tryParse('${request['endDate'] ?? request['date']}');
    if (day == null || end == null) return [];
    // Include the arrival day; overnight departure does not occupy the next night.
    final last = end.isAfter(day) ? end.subtract(const Duration(days: 1)) : day;
    for (var d = day; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      final key = serviceDate(d);
      final used = others.where((e) {
        if (e['serviceId'] != request['serviceId']) return false;
        final a = '${e['date']}', b = '${e['endDate'] ?? e['date']}';
        return a.compareTo(key) <= 0 &&
            (a == b ? a == key : b.compareTo(key) > 0);
      }).length;
      if (used >= capacity) {
        return ['$key 此方案已有 $used 筆已確認／入住，達到設定接待量 $capacity；請先核對實際房間。'];
      }
    }
    return [];
  }
  final staff = '${request['staffId'] ?? ''}';
  if (staff.isEmpty) return [];
  int minute(Object? raw) {
    final p = '$raw'.split(':');
    return p.length == 2
        ? (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0)
        : 0;
  }

  int duration(Map<String, dynamic> row) {
    final item = config.services
        .where((e) => e['id'] == row['serviceId'])
        .firstOrNull;
    return (item?['duration'] as num?)?.toInt() ?? 60;
  }

  final start = minute(request['time']), end = start + duration(request);
  return [
    for (final other in others)
      if (other['staffId'] == staff &&
          other['date'] == request['date'] &&
          start < minute(other['time']) + duration(other) &&
          minute(other['time']) < end)
        '${request['staffName']} 在 ${other['time']} 已有 ${other['petName']} 的${other['serviceName']}，時段重疊。',
  ];
}

String petServiceCatalogueSummary(
  PetServiceModule module,
  Map<String, dynamic> item,
) {
  final price = (item['price'] as num?)?.toInt() ?? 0;
  final amount = price == 0
      ? '現場評估報價'
      : 'NT\$ $price／${petServicePriceUnit(module, item)} 起';
  final kind = petServiceKinds(module)[petServiceKind(module, item)];
  if (module.isDog) {
    final capacity = (item['capacity'] as num?)?.toInt() ?? 0;
    return '$amount · $kind${capacity > 0 ? ' · 接待量 $capacity' : ''}';
  }
  final animals = switch (item['animalType']) {
    'cat' => '貓咪',
    'both' => '犬貓皆可',
    _ => module.isHospital ? '犬貓皆可' : '狗狗',
  };
  return '$amount · $kind · ${item['duration']} 分鐘 · $animals';
}

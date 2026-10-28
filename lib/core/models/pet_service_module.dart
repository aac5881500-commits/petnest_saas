import 'package:flutter/material.dart';

/// The public catalogue contains no customer or clinical information.
class PetServiceModule {
  const PetServiceModule(
    this.id,
    this.title,
    this.subtitle,
    this.icon,
    this.catalogueTitle,
    this.staffTitle,
    this.recordTitle,
    this.questions,
    this.suggestions,
  );
  final String id, title, subtitle, catalogueTitle, staffTitle, recordTitle;
  final IconData icon;
  final List<String> questions, suggestions;
  bool get isDog => id == 'dog_hotel';
  bool get isHospital => id == 'hospital';
  static const all = <PetServiceModule>[
    PetServiceModule(
      'dog_hotel',
      '狗狗旅店',
      '住宿、安親與每日照護',
      Icons.pets,
      '住宿房型與安親方案',
      '照護人員與班表',
      '適應評估與照護紀錄',
      ['體型／體重', '疫苗與驅蟲狀況', '與其他狗狗相處情形', '飲食、用藥及散步需求'],
      ['小型犬住宿', '中大型犬住宿', '日間安親', '初次適應評估'],
    ),
    PetServiceModule(
      'grooming',
      '寵物美容',
      '洗澡、造型與美容預約',
      Icons.content_cut,
      '美容服務與價目表',
      '美容師與班表',
      '美容前評估與服務紀錄',
      ['品種／體型／體重', '毛況與皮膚注意事項', '期望造型', '接送及其他需求'],
      ['基礎洗澡', '洗澡與造型修剪', '局部整理', '加購護毛'],
    ),
    PetServiceModule(
      'hospital',
      '動物醫院',
      '門診預約、醫師與報到管理',
      Icons.local_hospital_outlined,
      '門診科別與項目',
      '醫師與門診班表',
      '報到與門診處理紀錄',
      ['動物種類／品種／年齡', '本次就診原因', '症狀開始時間', '既往病史、過敏及用藥'],
      ['一般門診', '預防保健', '皮膚門診', '健康檢查'],
    ),
  ];
  static PetServiceModule byId(String id) => all.firstWhere((e) => e.id == id);
}

Map<String, dynamic> serviceMap(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
List<Map<String, dynamic>> serviceEntries(Object? raw) => serviceMap(raw)
    .entries
    .map((e) => <String, dynamic>{...serviceMap(e.value), 'id': e.key})
    .toList();

class PetServiceConfig {
  PetServiceConfig(this.module, Object? raw) : data = serviceMap(raw);
  final PetServiceModule module;
  final Map<String, dynamic> data;
  List<String> get acceptedSpecies => module.isDog
      ? ['dog']
      : (data['acceptedSpecies'] is List
            ? (data['acceptedSpecies'] as List)
                  .whereType<String>()
                  .where((v) => ['cat', 'dog'].contains(v))
                  .toList()
            : ['cat', 'dog']);
  bool get enabled => data['enabled'] == true;
  String get notice => (data['notice'] ?? '').toString();
  List<Map<String, dynamic>> get services => serviceEntries(data['services']);
  List<Map<String, dynamic>> get staff => serviceEntries(data['staff']);
  List<int> get days =>
      (data['days'] is List ? data['days'] as List : [1, 2, 3, 4, 5, 6])
          .whereType<int>()
          .toList();
  int get opens => (data['opens'] as num?)?.toInt() ?? 600;
  int get closes => (data['closes'] as num?)?.toInt() ?? 1080;
  int get advanceDays => (data['advanceDays'] as num?)?.toInt() ?? 60;
  bool get ready => services.any(
    (item) =>
        item['enabled'] == true &&
        (module.isDog ||
            staff.any(
              (person) => petStaffSupportsService(person, '${item['id']}'),
            )),
  );
  Map<String, dynamic> get editable => {
    '_revision': data['updatedAt'],
    'acceptedSpecies': acceptedSpecies,
    'enabled': enabled,
    'notice': notice,
    'days': days,
    'opens': opens,
    'closes': closes,
    'advanceDays': advanceDays,
    'services': serviceMap(data['services']),
    'staff': serviceMap(data['staff']),
  };
}

String serviceTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
String serviceDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
DateTime serviceTaipeiNow([DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
const serviceStatusLabels = {
  'pending': '待確認',
  'confirmed': '已確認',
  'arrived': '已報到／服務中',
  'completed': '已完成',
  'cancelled': '已取消',
  'declined': '未受理',
};
const serviceTransitions = {
  'pending': ['confirmed', 'declined', 'cancelled'],
  'confirmed': ['arrived', 'cancelled'],
  'arrived': ['completed'],
  'completed': <String>[],
  'cancelled': <String>[],
  'declined': <String>[],
};

/// Returns requested start times; acceptance and resource allocation are manual.
List<int> petServiceTimes(
  PetServiceConfig config,
  DateTime date,
  Map<String, dynamic>? staff,
  int duration, {
  DateTime? now,
}) {
  if (!config.days.contains(date.weekday)) return [];
  var opens = config.opens, closes = config.closes;
  if (staff != null) {
    final days = (staff['days'] as List? ?? []).whereType<int>();
    if (staff['enabled'] != true || !days.contains(date.weekday)) return [];
    final start = (staff['opens'] as num?)?.toInt() ?? opens;
    final end = (staff['closes'] as num?)?.toInt() ?? closes;
    if (start > opens) opens = start;
    if (end < closes) closes = end;
  }
  final today = serviceTaipeiNow(now);
  final todayKey = serviceDate(today);
  final dateKey = serviceDate(date);
  if (dateKey.compareTo(todayKey) < 0 ||
      dateKey.compareTo(
            serviceDate(today.add(Duration(days: config.advanceDays))),
          ) >
          0) {
    return [];
  }
  return [
    for (var n = ((opens + 29) ~/ 30) * 30; n + duration <= closes; n += 30)
      if (dateKey != todayKey || n > today.hour * 60 + today.minute) n,
  ];
}

bool petStaffSupportsService(Map<String, dynamic> staff, String serviceId) {
  final ids = staff['serviceIds'];
  return staff['enabled'] == true &&
      (ids is! List || ids.isEmpty || ids.contains(serviceId));
}

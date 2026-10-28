import 'dart:async';
import 'package:petnest_saas/core/models/pet_service_module.dart';
import 'package:petnest_saas/core/services/pet_service_module_service.dart';

/// Isolated local preview repository. Never connects to Firebase.
class ServiceModulesFixture implements PetServiceModuleService {
  final configs = <String, Map<String, dynamic>>{};
  final applications = <Map<String, dynamic>>[];
  final notes = <String, List<Map<String, dynamic>>>{};
  final changes = StreamController<void>.broadcast();
  int serial = 0;
  @override
  Stream<List<Map<String, dynamic>>> watchMyPets() => Stream.value([
    {'petId': 'dog1', 'name': '雪球', 'species': 'dog', 'vaccineTypes': '依手冊紀錄'},
    {'petId': 'cat1', 'name': '麻糬', 'species': 'cat', 'vaccineTypes': '依手冊紀錄'},
  ]);
  @override
  String? get currentUserId => 'preview-user';
  ServiceModulesFixture() {
    for (final module in PetServiceModule.all) {
      configs[module.id] = {
        'enabled': true,
        'notice': module.isHospital
            ? '請於預約時間前 10 分鐘報到，攜帶過往就醫與用藥資料。'
            : '初次服務請提前聯絡，讓我們了解毛孩習慣。',
        'days': [1, 2, 3, 4, 5, 6, 7],
        'opens': 600,
        'closes': 1140,
        'advanceDays': 60,
        'services': {
          for (var i = 0; i < module.suggestions.length; i++)
            'service$i': {
              'name': module.suggestions[i],
              'description': module.isDog
                  ? '依體型與個性評估，安排獨立休息與活動時間。'
                  : module.isHospital
                  ? '由院方評估就診需求，實際費用依檢查與處置說明。'
                  : '包含基礎清潔與服務前毛況評估，費用依體型與毛量確認。',
              'enabled': true,
              'price': module.isHospital ? 0 : [800, 1200, 500, 300][i],
              'duration': module.isHospital ? 30 : 60,
              'maxWeight': 0,
            },
        },
        'staff': {
          for (var i = 0; i < 2; i++)
            'staff$i': {
              'name': module.isHospital
                  ? '示範醫師 ${i + 1}'
                  : module.isDog
                  ? '示範照護員 ${i + 1}'
                  : '示範美容師 ${i + 1}',
              'description': '示範人員・請由店家更換為實際資料',
              'enabled': true,
              'days': [1, 2, 3, 4, 5, 6, 7],
              'opens': 600,
              'closes': 1140,
            },
        },
      };
      final today = serviceDate(serviceTaipeiNow());
      for (var i = 0; i < 3; i++) {
        applications.add({
          'id': 'demo_${module.id}_$i',
          'module': module.id,
          'serviceId': 'service$i',
          'serviceName': module.suggestions[i],
          'petName': ['麻糬', '布丁', '豆豆'][i],
          'contactName': '示範飼主 ${i + 1}',
          'phone': '0900-000-000',
          'date': today,
          'endDate': today,
          'time': ['10:00', '13:00', '15:30'][i],
          'staffId': 'staff0',
          'staffName': module.isHospital
              ? '示範醫師 1'
              : module.isDog
              ? '由店家安排'
              : '示範美容師 1',
          'status': ['pending', 'confirmed', 'arrived'][i],
          'weight': 6.5,
          'details': module.isHospital
              ? '本次希望安排健康檢查，帶有既往資料。'
              : '第一次到店，個性慢熟，請先讓牠熟悉環境。',
        });
      }
    }
  }
  @override
  Stream<PetServiceConfig> watchConfig(
    String shop,
    PetServiceModule module,
  ) async* {
    yield PetServiceConfig(module, configs[module.id]);
    yield* changes.stream.map(
      (_) => PetServiceConfig(module, configs[module.id]),
    );
  }

  @override
  Stream<List<Map<String, dynamic>>> watchRequests(
    String shop,
    String module, {
    bool mine = false,
  }) async* {
    List<Map<String, dynamic>> current() => applications
        .where((e) => e['module'] == module)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    yield current();
    yield* changes.stream.map((_) => current());
  }

  @override
  Future<void> saveConfig(
    String shop,
    PetServiceModule module,
    Map<String, dynamic> data,
  ) async {
    final config = PetServiceConfig(module, data);
    if (config.days.isEmpty ||
        config.opens >= config.closes ||
        (config.enabled && !config.ready)) {
      throw StateError('請完成有效設定');
    }
    configs[module.id] = config.editable;
    changes.add(null);
  }

  @override
  String newRequestId(String shop) => 'preview_${serial++}';
  @override
  Future<void> submit(String shop, String id, Map<String, dynamic> data) async {
    if (!applications.any((e) => e['id'] == id)) {
      applications.add({...data, 'id': id, 'status': 'pending'});
    }
    changes.add(null);
  }

  @override
  Future<void> transition(
    String shop,
    String id,
    String from,
    String to,
  ) async {
    final entry = applications.firstWhere((e) => e['id'] == id);
    if (entry['status'] != from ||
        !(serviceTransitions[from] ?? []).contains(to)) {
      throw StateError('狀態已變更');
    }
    entry['status'] = to;
    changes.add(null);
  }

  @override
  Stream<List<Map<String, dynamic>>> records(String shop, String id) async* {
    yield notes[id] ?? [];
    yield* changes.stream.map((_) => notes[id] ?? []);
  }

  @override
  Future<void> addRecord(String shop, String id, String note) async {
    (notes[id] ??= []).insert(0, {
      'note': note,
      'createdAt': serviceDate(serviceTaipeiNow()),
    });
    changes.add(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

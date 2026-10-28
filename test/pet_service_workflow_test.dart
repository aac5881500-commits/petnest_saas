import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/pet_service_module.dart';
import 'package:petnest_saas/core/models/pet_service_workflow.dart';
import 'package:petnest_saas/features/shop/pages/services/shop_pet_service_booking_page.dart';
import 'package:petnest_saas/features/shop/pages/services/shop_service_module_hub.dart';
import '../tool/service_modules_fixture.dart';

void main() {
  final dog = PetServiceModule.byId('dog_hotel'),
      groom = PetServiceModule.byId('grooming'),
      hospital = PetServiceModule.byId('hospital');
  PetServiceConfig config(PetServiceModule module) => PetServiceConfig(module, {
    'services': {
      'a': {'id': 'a', 'enabled': true, 'duration': 60, 'capacity': 2},
      'b': {'enabled': true, 'duration': 30},
    },
    'staff': {
      's': {
        'enabled': true,
        'serviceIds': ['a'],
      },
    },
  });
  test(
    'dog lodging and same-day services use different pickup and price units',
    () {
      expect(dogServiceNeedsPickupDate(dog, {}), isTrue);
      expect(dogServiceNeedsPickupDate(dog, {'kind': 'daycare'}), isFalse);
      expect(dogServiceNeedsPickupDate(dog, {'kind': 'assessment'}), isFalse);
      expect(petServicePriceUnit(dog, {'kind': 'overnight'}), '晚');
      expect(petServicePriceUnit(dog, {'kind': 'daycare'}), '日');
      expect(petServicePriceUnit(groom, {}), '次');
      expect(
        petServiceCatalogueSummary(hospital, {'price': 0, 'duration': 30}),
        contains('犬貓皆可'),
      );
    },
  );
  test(
    'personnel service assignment gates availability and module readiness',
    () {
      expect(
        petStaffSupportsService({
          'enabled': true,
          'serviceIds': ['a'],
        }, 'a'),
        isTrue,
      );
      expect(
        petStaffSupportsService({
          'enabled': true,
          'serviceIds': ['a'],
        }, 'b'),
        isFalse,
      );
      expect(petStaffSupportsService({'enabled': false}, 'a'), isFalse);
      expect(
        PetServiceConfig(groom, {
          'services': {
            'a': {'enabled': true},
          },
          'staff': {
            's': {
              'enabled': true,
              'serviceIds': ['b'],
            },
          },
        }).ready,
        isFalse,
      );
      expect(config(groom).ready, isTrue);
    },
  );
  test(
    'grooming conflicts span distinct services and ignore adjacency and cancelled jobs',
    () {
      final request = {
        'id': 'new',
        'serviceId': 'b',
        'date': '2026-10-28',
        'time': '10:30',
        'staffId': 's',
        'staffName': '小林',
      };
      final row = {
        'id': 'old',
        'serviceId': 'a',
        'date': '2026-10-28',
        'time': '10:00',
        'staffId': 's',
        'petName': '麻糬',
        'serviceName': '洗澡',
        'status': 'confirmed',
      };
      expect(
        petServiceConflicts(groom, request, [row], config(groom)),
        hasLength(1),
      );
      expect(
        petServiceConflicts(
          groom,
          {...request, 'time': '11:00'},
          [row],
          config(groom),
        ),
        isEmpty,
      );
      expect(
        petServiceConflicts(groom, request, [
          {...row, 'status': 'cancelled'},
        ], config(groom)),
        isEmpty,
      );
      expect(
        petServiceConflicts(groom, request, [
          {...row, 'staffId': 'other'},
        ], config(groom)),
        isEmpty,
      );
    },
  );
  test(
    'dog capacity warns per occupied night but releases a departing room',
    () {
      final request = {
        'id': 'new',
        'serviceId': 'a',
        'date': '2026-10-28',
        'endDate': '2026-10-30',
      };
      final rows = [
        for (var i = 0; i < 2; i++)
          {
            'id': 'old$i',
            'serviceId': 'a',
            'date': '2026-10-27',
            'endDate': '2026-10-29',
            'status': 'confirmed',
          },
      ];
      expect(
        petServiceConflicts(dog, request, rows, config(dog)),
        hasLength(1),
      );
      expect(
        petServiceConflicts(
          dog,
          {...request, 'date': '2026-10-29'},
          rows,
          config(dog),
        ),
        isEmpty,
      );
      expect(
        petServiceConflicts(dog, request, [rows.first], config(dog)),
        isEmpty,
      );
    },
  );
  test(
    'private record text uses each module-specific labels and a safe length limit',
    () {
      final value = composePetServiceRecord(dog, [
        '正常飲食',
        '',
        '情緒穩定',
        '',
      ], '晚間交接');
      expect(value, contains('飲食與飲水：正常飲食'));
      expect(value, contains('情緒與互動：情緒穩定'));
      expect(petServiceRecordFields(groom), contains('接回提醒'));
      expect(petServiceRecordFields(hospital), contains('回診與聯絡安排'));
      expect(composePetServiceRecord(hospital, [], '  '), isEmpty);
      expect(
        () => composePetServiceRecord(dog, [], List.filled(3001, '字').join()),
        throwsStateError,
      );
    },
  );
  test(
    'upcoming list is chronological, includes current stays and excludes terminal requests',
    () {
      final rows = <Map<String, dynamic>>[
        {
          'id': 'later',
          'date': '2026-10-29',
          'time': '10:00',
          'status': 'pending',
        },
        {
          'id': 'stay',
          'date': '2026-10-26',
          'endDate': '2026-10-30',
          'time': '10:00',
          'status': 'arrived',
        },
        {'id': 'cancelled', 'date': '2026-10-28', 'status': 'cancelled'},
        {'id': 'past', 'date': '2026-10-25', 'status': 'confirmed'},
      ];
      expect(petServiceUpcoming(rows, '2026-10-28').map((e) => e['id']), [
        'stay',
        'later',
      ]);
      expect(
        petRequestOnDate({
          'module': 'dog_hotel',
          'date': '2026-10-26',
          'endDate': '2026-10-30',
        }, '2026-10-28'),
        isTrue,
      );
    },
  );
  testWidgets(
    'same-day dog booking does not ask for an overnight pickup date',
    (tester) async {
      final repo = ServiceModulesFixture();
      addTearDown(repo.changes.close);
      (repo.configs['dog_hotel']!['services'] as Map)['service2']['kind'] =
          'daycare';
      await tester.pumpWidget(
        MaterialApp(
          home: ShopPetServiceBookingPage(
            shopId: 'fixture',
            module: dog,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('日間安親').last);
      await tester.pumpAndSettle();
      expect(find.text('選擇接回日期'), findsNothing);
      expect(find.text('4. 服務前資料'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'recommended service opens an editable draft and cancellation does not write it',
    (tester) async {
      final repo = ServiceModulesFixture();
      addTearDown(repo.changes.close);
      repo.configs['grooming']!['enabled'] = false;
      repo.configs['grooming']!['services'] = {};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopServiceModuleHub(
              shopId: 'fixture',
              module: groom,
              canConfigure: true,
              canManage: true,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('建立服務項目'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, '基礎洗澡'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '基礎洗澡',
      );
      expect(find.text('服務分類'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(repo.configs['grooming']!['services'], isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('dog daycare submits a same-day request with structured intake', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = ServiceModulesFixture();
    addTearDown(repo.changes.close);
    (repo.configs['dog_hotel']!['services'] as Map)['service2']['kind'] =
        'daycare';
    await tester.pumpWidget(
      MaterialApp(
        home: ShopPetServiceBookingPage(
          shopId: 'fixture',
          module: dog,
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('日間安親').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('選擇日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final tomorrow = serviceTaipeiNow().add(const Duration(days: 1));
    await tester.enterText(
      find.byType(TextField).last,
      '${tomorrow.month}/${tomorrow.day}/${tomorrow.year}',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final time = find.byType(DropdownButtonFormField<int>);
    await tester.ensureVisible(time);
    await tester.pumpAndSettle();
    await tester.tap(time);
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:00').last);
    await tester.pumpAndSettle();
    for (final entry in [
      (0, '王先生'),
      (1, '0912345678'),
      (2, '8'),
      (3, '小型犬，8 公斤'),
    ]) {
      await tester.enterText(find.byType(TextFormField).at(entry.$1), entry.$2);
    }
    final petChoice = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField<String> &&
          w.decoration.labelText == '選擇我的寵物',
    );
    await tester.ensureVisible(petChoice);
    await tester.tap(petChoice);
    await tester.pumpAndSettle();
    expect(find.text('麻糬 · 貓咪'), findsNothing);
    await tester.tap(find.text('雪球 · 狗狗').last);
    await tester.pumpAndSettle();
    final accepted = find.text('我已閱讀服務須知，了解這是待店家確認的預約申請。');
    await tester.ensureVisible(accepted);
    await tester.pumpAndSettle();
    await tester.tap(accepted);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('送出預約申請'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('送出預約申請'));
    await tester.pumpAndSettle();
    expect(find.text('預約申請已送出'), findsOneWidget);
    final sent = repo.applications.last;
    expect(sent['petId'], 'dog1');
    expect(sent['date'], serviceDate(tomorrow));
    expect(sent['endDate'], sent['date']);
    expect(sent['details'], contains('體型／體重：小型犬，8 公斤'));
    expect(sent['status'], 'pending');
    expect(tester.takeException(), isNull);
  });
}

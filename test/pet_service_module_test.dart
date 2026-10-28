import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/pet_service_module.dart';
import 'package:petnest_saas/features/shop/pages/services/shop_service_module_hub.dart';
import '../tool/service_modules_fixture.dart';
import 'package:petnest_saas/features/shop/pages/services/shop_pet_service_booking_page.dart';

void main() {
  final module = PetServiceModule.byId('grooming');
  final now = DateTime.utc(2026, 10, 26, 0);
  PetServiceConfig config() => PetServiceConfig(module, {
    'enabled': true,
    'days': [1, 2, 3, 4, 5, 6],
    'opens': 600,
    'closes': 1080,
    'advanceDays': 30,
    'services': {
      'bath': {'enabled': true},
    },
    'staff': {
      'a': {'enabled': true},
    },
  });
  test('unconfigured modules remain closed and cannot be ready', () {
    for (final m in PetServiceModule.all) {
      final c = PetServiceConfig(m, null);
      expect(c.enabled, false);
      expect(c.ready, false);
    }
  });
  test(
    'appointments require enabled staff; dog requests can be assigned manually',
    () {
      expect(
        PetServiceConfig(module, {
          'services': {
            'a': {'enabled': true},
          },
        }).ready,
        false,
      );
      expect(
        PetServiceConfig(PetServiceModule.byId('dog_hotel'), {
          'services': {
            'a': {'enabled': true},
          },
        }).ready,
        true,
      );
    },
  );
  test(
    'slots respect staff hours, duration, closed weekdays and past days',
    () {
      final staff = {
        'enabled': true,
        'days': [1],
        'opens': 660,
        'closes': 840,
      };
      expect(
        petServiceTimes(config(), DateTime(2026, 10, 26), staff, 90, now: now),
        [660, 690, 720, 750],
      );
      expect(
        petServiceTimes(config(), DateTime(2026, 10, 27), staff, 90, now: now),
        isEmpty,
      );
      expect(
        petServiceTimes(config(), DateTime(2026, 10, 25), null, 30, now: now),
        isEmpty,
      );
      expect(
        petServiceTimes(config(), DateTime(2026, 11, 27), null, 30, now: now),
        isEmpty,
      );
    },
  );
  test('Taipei today excludes elapsed and exact current times', () {
    expect(
      petServiceTimes(
        config(),
        DateTime(2026, 10, 26),
        null,
        60,
        now: DateTime.utc(2026, 10, 26, 3),
      ),
      isNot(contains(660)),
    );
    expect(
      serviceDate(serviceTaipeiNow(DateTime.utc(2026, 10, 25, 18))),
      '2026-10-26',
    );
  });
  test(
    'terminal requests cannot be reopened or changed to another terminal state',
    () {
      for (final state in ['completed', 'cancelled', 'declined']) {
        expect(serviceTransitions[state], isEmpty);
      }
      expect(serviceTransitions['pending'], isNot(contains('completed')));
    },
  );
  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    for (final m in PetServiceModule.all) {
      testWidgets('${m.id} overview and catalogue at ${size.width}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = ServiceModulesFixture();
        addTearDown(repo.changes.close);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShopServiceModuleHub(
                shopId: 'preview',
                module: m,
                canConfigure: true,
                canManage: true,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('今日營運'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final item = find.byKey(const ValueKey('service-menu-catalogue'));
        await tester.ensureVisible(item);
        await tester.pumpAndSettle();
        await tester.tap(item);
        await tester.pumpAndSettle();
        expect(find.text('新增項目'), findsOneWidget);
        expect(
          find.widgetWithText(ListTile, '${m.suggestions.first} '),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('新增項目'));
        await tester.pumpAndSettle();
        expect(find.text('服務項目'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
      });
    }
  }
  testWidgets(
    'staff editor can save a new person without disposing active fields',
    (tester) async {
      final repo = ServiceModulesFixture();
      addTearDown(repo.changes.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopServiceModuleHub(
              shopId: 'preview',
              module: module,
              canConfigure: true,
              canManage: true,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('service-menu-staff')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('service-menu-staff')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增人員'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '測試美容師');
      await tester.enterText(find.byType(TextFormField).at(1), '一般美容');
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('測試美容師 '), findsOneWidget);
    },
  );

  for (final m in PetServiceModule.all) {
    testWidgets('${m.id} booking form and my requests fit on a phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ServiceModulesFixture();
      addTearDown(repo.changes.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ShopPetServiceBookingPage(
            shopId: 'preview',
            module: m,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1. 選擇服務'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('我的申請'));
      await tester.pumpAndSettle();
      expect(find.text('我的預約申請'), findsOneWidget);
      expect(find.textContaining('麻糬'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'request management appends private records and confirms a pending request',
    (tester) async {
      final repo = ServiceModulesFixture();
      addTearDown(repo.changes.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopServiceModuleHub(
              shopId: 'preview',
              module: module,
              canConfigure: true,
              canManage: true,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('預約管理'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('麻糬').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '已核對皮膚與毛況');
      await tester.ensureVisible(find.text('新增紀錄'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增紀錄'));
      await tester.pumpAndSettle();
      expect(find.textContaining('已核對皮膚與毛況'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '已確認'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認變更'));
      await tester.pumpAndSettle();
      expect(
        repo.applications.firstWhere(
          (e) => e['id'] == 'demo_grooming_0',
        )['status'],
        'confirmed',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

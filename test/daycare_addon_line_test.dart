import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/daycare_addon_catalog.dart';
import 'package:petnest_saas/core/services/daycare_addon_line.dart';

void main() {
  test('legacy add-on without applicableServices stays out of daycare', () {
    final Map<String, dynamic> item = <String, dynamic>{
      'id': 'old_custom',
      'name': '梳毛',
      'price': 100,
      'groupKey': 'customServices',
    };
    expect(DaycareAddonCatalog.appliesToDaycare(item), isFalse);
    expect(
      PolicyApplicableService.parse(item['applicableServices']),
      PolicyApplicableService.accommodationOnly,
    );
  });

  test('custom addon charges unit price times selected pets', () {
    final DaycareAddonLineResult result = DaycareAddonLine.resolve(
      live: <String, dynamic>{
        'id': 'custom_1',
        'name': '梳毛',
        'price': 80,
        'groupKey': 'customServices',
        'applicableServices': <String>['daycare'],
      },
      requested: <String, dynamic>{
        'id': 'custom_1',
        'selectedPetIds': <String>['p1', 'p2'],
      },
      orderPetIds: <String>['p1', 'p2', 'p3'],
      allowedAddonIds: <String>['custom_1'],
      scheduledStartAt: DateTime.utc(2026, 9, 8, 1),
      scheduledEndAt: DateTime.utc(2026, 9, 8, 8),
    );
    expect(result.ok, isTrue);
    expect(result.amount, 160);
    expect(result.line['count'], 2);
  });

  test('daily timed addon charges pets times slots', () {
    final DaycareAddonLineResult result = DaycareAddonLine.resolve(
      live: <String, dynamic>{
        'id': 'timed_1',
        'name': '餵食',
        'price': 50,
        'groupKey': 'dailyTimedServices',
        'applicableServices': <String>['daycare'],
        'timeSlots': <Map<String, dynamic>>[
          <String, dynamic>{'id': 's12', 'label': '12:00'},
          <String, dynamic>{'id': 's14', 'label': '14:10'},
          <String, dynamic>{'id': 's16', 'label': '16:20'},
        ],
      },
      requested: <String, dynamic>{
        'id': 'timed_1',
        'selectedPetIds': <String>['p1', 'p2'],
        'selectedTimeSlots': <String>['s12', 's14'],
      },
      orderPetIds: <String>['p1', 'p2'],
      allowedAddonIds: <String>['timed_1'],
      scheduledStartAt: DateTime.utc(2026, 9, 8, 1),
      scheduledEndAt: DateTime.utc(2026, 9, 8, 8),
    );
    expect(result.ok, isTrue);
    expect(result.amount, 200);
    expect(result.line['count'], 4);
  });

  test('slot outside drop-off to pick-up is rejected', () {
    expect(
      DaycareAddonLine.slotFullyInside(
        label: '16:20',
        scheduledStartAt: DateTime.utc(2026, 9, 8, 1),
        scheduledEndAt: DateTime.utc(2026, 9, 8, 8),
      ),
      isFalse,
    );
    expect(
      DaycareAddonLine.slotFullyInside(
        label: '12:00',
        scheduledStartAt: DateTime.utc(2026, 9, 8, 1),
        scheduledEndAt: DateTime.utc(2026, 9, 8, 8),
      ),
      isTrue,
    );
    final DaycareAddonLineResult result = DaycareAddonLine.resolve(
      live: <String, dynamic>{
        'id': 'timed_1',
        'name': '餵食',
        'price': 50,
        'groupKey': 'dailyTimedServices',
        'applicableServices': <String>['daycare'],
        'timeSlots': <Map<String, dynamic>>[
          <String, dynamic>{'id': 's16', 'label': '16:20'},
        ],
      },
      requested: <String, dynamic>{
        'id': 'timed_1',
        'selectedPetIds': <String>['p1'],
        'selectedTimeSlots': <String>['s16'],
      },
      orderPetIds: <String>['p1'],
      allowedAddonIds: <String>['timed_1'],
      scheduledStartAt: DateTime.utc(2026, 9, 8, 1),
      scheduledEndAt: DateTime.utc(2026, 9, 8, 8),
    );
    expect(result.ok, isFalse);
  });

  test(
    'unopened daycare addon, foreign pet and duplicate slots cannot bypass',
    () {
      final DaycareAddonLineResult closed = DaycareAddonLine.resolve(
        live: <String, dynamic>{
          'id': 'stay_only',
          'name': '住宿專用',
          'price': 10,
          'groupKey': 'customServices',
        },
        requested: <String, dynamic>{
          'id': 'stay_only',
          'selectedPetIds': <String>['p1'],
        },
        orderPetIds: <String>['p1'],
        allowedAddonIds: <String>['stay_only'],
        scheduledStartAt: DateTime.utc(2026, 9, 8, 1),
        scheduledEndAt: DateTime.utc(2026, 9, 8, 8),
      );
      expect(closed.ok, isFalse);

      final DaycareAddonLineResult foreignPet = DaycareAddonLine.resolve(
        live: <String, dynamic>{
          'id': 'custom_1',
          'name': '梳毛',
          'price': 80,
          'groupKey': 'customServices',
          'applicableServices': <String>['daycare'],
        },
        requested: <String, dynamic>{
          'id': 'custom_1',
          'selectedPetIds': <String>['other'],
        },
        orderPetIds: <String>['p1'],
        allowedAddonIds: <String>['custom_1'],
        scheduledStartAt: DateTime.utc(2026, 9, 8, 1),
        scheduledEndAt: DateTime.utc(2026, 9, 8, 8),
      );
      expect(foreignPet.ok, isFalse);

      final DaycareAddonLineResult dupSlots = DaycareAddonLine.resolve(
        live: <String, dynamic>{
          'id': 'timed_1',
          'name': '餵食',
          'price': 50,
          'groupKey': 'dailyTimedServices',
          'applicableServices': <String>['daycare'],
          'timeSlots': <Map<String, dynamic>>[
            <String, dynamic>{'id': 's12', 'label': '12:00'},
          ],
        },
        requested: <String, dynamic>{
          'id': 'timed_1',
          'selectedPetIds': <String>['p1'],
          'selectedTimeSlots': <String>['s12', 's12', '12:00'],
        },
        orderPetIds: <String>['p1'],
        allowedAddonIds: <String>['timed_1'],
        scheduledStartAt: DateTime.utc(2026, 9, 8, 1),
        scheduledEndAt: DateTime.utc(2026, 9, 8, 8),
      );
      expect(dupSlots.ok, isTrue);
      expect(dupSlots.line['count'], 1);
    },
  );

  test('inventory quantity follows custom and timed counts', () {
    expect(
      DaycareAddonLine.resolve(
        live: <String, dynamic>{
          'id': 'custom_1',
          'price': 10,
          'groupKey': 'customServices',
          'applicableServices': <String>['daycare'],
        },
        requested: <String, dynamic>{
          'id': 'custom_1',
          'selectedPetIds': <String>['a', 'b'],
        },
        orderPetIds: <String>['a', 'b'],
        allowedAddonIds: <String>['custom_1'],
        scheduledStartAt: DateTime.utc(2026, 9, 8, 1),
        scheduledEndAt: DateTime.utc(2026, 9, 8, 8),
      ).line['quantity'],
      2,
    );
  });
}

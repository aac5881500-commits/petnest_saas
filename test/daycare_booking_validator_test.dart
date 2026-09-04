// test/daycare_booking_validator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_booking_validator.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';

void main() {
  test('安親開關相容 bool／0／1，且任一來源為開即開放', () {
    expect(
      DaycareSettingsService.instance.isEnabledForShop(
        shop: <String, dynamic>{'daycareEnabled': true},
        settings: const DaycareSettingsModel(),
      ),
      isTrue,
    );
    expect(
      DaycareSettingsService.instance.isEnabledForShop(
        shop: <String, dynamic>{'daycareEnabled': 1},
        settings: const DaycareSettingsModel(),
      ),
      isTrue,
    );
    expect(
      DaycareSettingsService.instance.isEnabledForShop(
        shop: <String, dynamic>{'daycareEnabled': 'true'},
        settings: const DaycareSettingsModel(),
      ),
      isTrue,
    );
    expect(
      DaycareSettingsService.instance.isEnabledForShop(
        shop: <String, dynamic>{'daycareEnabled': false},
        settings: const DaycareSettingsModel(enabled: true),
      ),
      isTrue,
    );
    expect(
      DaycareSettingsService.instance.isEnabledForShop(
        shop: <String, dynamic>{},
        settings: const DaycareSettingsModel(enabled: true),
      ),
      isTrue,
    );
    expect(
      DaycareSettingsService.instance.isEnabledForShop(
        shop: <String, dynamic>{'daycareEnabled': 0},
        settings: const DaycareSettingsModel(),
      ),
      isFalse,
    );
    expect(
      DaycareSettingsService.instance.isEnabledForShop(
        shop: <String, dynamic>{},
        settings: const DaycareSettingsModel(),
      ),
      isFalse,
    );
  });

  test('客戶建立臨托訂單不需先選房型', () {
    expect(
      DaycareBookingValidator.validatePlan(
        plan: const DaycarePlanModel(id: 'p1', name: '臨托', enabled: true),
        startAt: DateTime(2026, 9, 2, 10),
      ).isOk,
      isTrue,
    );
  });

  test('加購必須在臨托允許清單中，不讀 applicableTo', () {
    const settings = DaycareSettingsModel(allowedAddonIds: <String>['a1']);
    expect(
      DaycareBookingValidator.validateAllowedAddons(
        settings: settings,
        addonIds: <String>['a1'],
      ).isOk,
      isTrue,
    );
    expect(
      DaycareBookingValidator.validateAllowedAddons(
        settings: settings,
        addonIds: <String>['a2'],
      ).isOk,
      isFalse,
    );
    expect(ServiceScope.applies('both', 'daycare'), isTrue);
  });

  test('黑名單一律擋前台，不再看臨托專用開關', () {
    const settings = DaycareSettingsModel(blockBlacklisted: false);
    expect(
      DaycareBookingValidator.validatePets(
        settings: settings,
        petCount: 1,
        petTypes: <String>['cat'],
        anyUnneutered: true,
        missingVaccine: true,
        blacklisted: true,
      ).isOk,
      isFalse,
    );
  });

  test('長時間安親不再被最長安親時間阻擋', () {
    final DaycareValidationResult result =
        DaycareBookingValidator.validateSchedule(
          settings: const DaycareSettingsModel(
            maxDurationMinutes: 480,
            minDurationMinutes: 30,
            forbidOvernight: true,
            blockOutsideHours: false,
            allowSameDay: true,
          ),
          startAt: DateTime(2026, 9, 1, 8),
          endAt: DateTime(2026, 9, 1, 20),
          isAdmin: true,
        );
    expect(result.isOk, isTrue);
    expect(result.error, isNot(contains('最長安親')));
  });

  test('接回時間早於或等於送達時間顯示錯誤', () {
    expect(
      DaycareBookingValidator.validateSchedule(
        settings: const DaycareSettingsModel(),
        startAt: DateTime(2026, 9, 1, 12),
        endAt: DateTime(2026, 9, 1, 12),
        isAdmin: true,
      ).error,
      '送達時間不得晚於接回時間',
    );
    expect(
      DaycareBookingValidator.validateSchedule(
        settings: const DaycareSettingsModel(),
        startAt: DateTime(2026, 9, 1, 12),
        endAt: DateTime(2026, 9, 1, 10),
        isAdmin: true,
      ).isOk,
      isFalse,
    );
  });
}

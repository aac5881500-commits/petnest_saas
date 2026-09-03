import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_addon_catalog.dart';
import 'package:petnest_saas/core/services/daycare_booking_validator.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';

void main() {
  group('BookingKind', () {
    test('舊訂單沒有 bookingKind 視為住宿', () {
      expect(
        BookingKind.resolve(<String, dynamic>{}),
        BookingKind.accommodation,
      );
      expect(
        BookingKind.resolve(<String, dynamic>{'serviceType': 'cat_hotel'}),
        BookingKind.accommodation,
      );
    });

    test('bookingKind daycare 優先於舊 serviceType', () {
      expect(
        BookingKind.resolve(<String, dynamic>{
          'bookingKind': 'daycare',
          'serviceType': 'cat_hotel',
        }),
        BookingKind.daycare,
      );
    });
  });

  group('DaycarePricingService', () {
    final DaycarePricingService pricing = DaycarePricingService.instance;
    final DaycareSettingsModel settings = const DaycareSettingsModel(
      depositType: DaycareDepositTypes.percent,
      depositValue: 50,
    );

    test('每小時計費四捨五入為整數', () {
      final DaycarePlanModel plan = const DaycarePlanModel(
        id: 'h',
        name: '每小時',
        type: DaycarePlanTypes.hourly,
        basePrice: 200,
      );
      final DaycareQuote quote = pricing.quote(
        settings: settings,
        plan: plan,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 10, 30),
        petCount: 1,
      );
      expect(quote.durationMinutes, 90);
      expect(quote.baseAmount, 400);
      expect(quote.depositAmount, 200);
    });

    test('每 30 分鐘與第二隻加價', () {
      final DaycarePlanModel plan = const DaycarePlanModel(
        id: 'hh',
        name: '半小時',
        type: DaycarePlanTypes.halfHourly,
        basePrice: 100,
        extraPetSurcharge: 50,
      );
      final DaycareQuote quote = pricing.quote(
        settings: const DaycareSettingsModel(),
        plan: plan,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 10),
        petCount: 3,
      );
      expect(quote.baseAmount, 200);
      expect(quote.extraPetAmount, 100);
      expect(quote.totalAmount, 300);
    });

    test('每小時計費一小時無其他加價合計為 200', () {
      final DaycarePlanModel plan = const DaycarePlanModel(
        id: 'h',
        name: '每小時',
        type: DaycarePlanTypes.hourly,
        basePrice: 200,
      );
      final DaycareQuote quote = pricing.quote(
        settings: const DaycareSettingsModel(),
        plan: plan,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 10),
        petCount: 1,
      );
      expect(quote.baseAmount, 200);
      expect(quote.extraPetAmount, 0);
      expect(quote.roomTypeExtra, 0);
      expect(quote.addonAmount, 0);
      expect(quote.totalAmount, 200);
    });

    test('新報價不加入房型加價', () {
      final DaycarePlanModel plan = const DaycarePlanModel(
        id: 'h',
        name: '每小時',
        type: DaycarePlanTypes.hourly,
        basePrice: 200,
      );
      final DaycareQuote quote = pricing.quote(
        settings: const DaycareSettingsModel(),
        plan: plan,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 10),
        petCount: 1,
      );
      expect(quote.totalAmount, 200);
    });

    test('舊訂單快照仍可帶入房型加價', () {
      final DaycarePlanModel plan = const DaycarePlanModel(
        id: 'h',
        name: '每小時',
        type: DaycarePlanTypes.hourly,
        basePrice: 200,
      );
      final DaycareQuote quote = pricing.quote(
        settings: const DaycareSettingsModel(),
        plan: plan,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 10),
        petCount: 1,
        roomTypeExtra: 200,
      );
      expect(quote.totalAmount, 400);
      expect(quote.roomTypeExtra, 200);
    });

    test('總額不可為負', () {
      final DaycarePlanModel plan = const DaycarePlanModel(
        id: 'h',
        name: '每小時',
        basePrice: 100,
      );
      final DaycareQuote quote = pricing.quote(
        settings: const DaycareSettingsModel(),
        plan: plan,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 10),
        petCount: 1,
        couponAmount: 999,
      );
      expect(quote.totalAmount, 0);
    });
  });

  group('時間衝突與狀態', () {
    test('重疊時段', () {
      expect(
        DaycareTimeHelper.overlaps(
          DateTime(2026, 9, 1, 9),
          DateTime(2026, 9, 1, 12),
          DateTime(2026, 9, 1, 11),
          DateTime(2026, 9, 1, 13),
        ),
        isTrue,
      );
      expect(
        DaycareTimeHelper.overlaps(
          DateTime(2026, 9, 1, 9),
          DateTime(2026, 9, 1, 11),
          DateTime(2026, 9, 1, 11),
          DateTime(2026, 9, 1, 13),
        ),
        isFalse,
      );
    });

    test('開始不得晚於結束', () {
      final DaycareValidationResult result =
          DaycareBookingValidator.validateSchedule(
            settings: const DaycareSettingsModel(),
            startAt: DateTime(2026, 9, 1, 12),
            endAt: DateTime(2026, 9, 1, 10),
            isAdmin: true,
          );
      expect(result.isOk, isFalse);
    });

    test('狀態不可任意跳轉', () {
      expect(DaycareStatusMachine.canTransit('pending', 'confirmed'), isTrue);
      expect(DaycareStatusMachine.canTransit('pending', 'completed'), isFalse);
      expect(
        DaycareStatusMachine.canTransit('checked_in', 'completed'),
        isTrue,
      );
      expect(DaycareStatusMachine.canTransit('completed', 'pending'), isFalse);
      expect(DaycareStatusMachine.canAssignRoom('pending'), isFalse);
      expect(DaycareStatusMachine.canAssignRoom('confirmed'), isTrue);
      expect(
        DaycareStatusMachine.canCheckIn(status: 'pending', roomId: 'r1'),
        isFalse,
      );
      expect(
        DaycareStatusMachine.canCheckIn(status: 'confirmed', roomId: ''),
        isFalse,
      );
      expect(
        DaycareStatusMachine.canCheckIn(status: 'confirmed', roomId: 'r1'),
        isTrue,
      );
    });
  });

  group('轉住宿折抵', () {
    test('全部折抵與自訂折抵', () {
      expect(
        DaycareConversionHelper.credit(
          policy: DaycareConversionHelper.creditAll,
          daycareTotal: 1000,
        ),
        1000,
      );
      expect(
        DaycareConversionHelper.credit(
          policy: DaycareConversionHelper.custom,
          daycareTotal: 1000,
          customAmount: 300,
        ),
        300,
      );
      expect(
        DaycareConversionHelper.credit(
          policy: DaycareConversionHelper.keepDaycare,
          daycareTotal: 1000,
        ),
        0,
      );
    });
  });

  group('房間時段名額', () {
    test('未分房臨托會佔用房型名額，清潔中房間不可用', () {
      final DateTime start = DateTime(2026, 9, 1, 9);
      final DateTime end = DateTime(2026, 9, 1, 10);
      final int remaining = DaycareOccupancyService.remainingRoomsFromData(
        rooms: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'r1',
            'roomTypeId': 'vip',
            'enabled': true,
            'status': 'available',
          },
          <String, dynamic>{
            'id': 'r2',
            'roomTypeId': 'vip',
            'enabled': true,
            'status': 'cleaning',
          },
        ],
        bookings: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'b1',
            'bookingKind': 'daycare',
            'status': 'pending',
            'roomTypeId': 'vip',
            'roomId': '',
            'scheduledStartAt': start,
            'scheduledEndAt': end,
          },
        ],
        roomTypeId: 'vip',
        startAt: start,
        endAt: end,
      );
      expect(remaining, 0);
    });

    test('時間不重疊的臨托可共用同一房型', () {
      final int remaining = DaycareOccupancyService.remainingRoomsFromData(
        rooms: <Map<String, dynamic>>[
          <String, dynamic>{'id': 'r1', 'roomTypeId': 'vip', 'enabled': true},
        ],
        bookings: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'b1',
            'bookingKind': 'daycare',
            'status': 'confirmed',
            'roomTypeId': 'vip',
            'roomId': 'r1',
            'scheduledStartAt': DateTime(2026, 9, 1, 9),
            'scheduledEndAt': DateTime(2026, 9, 1, 11),
          },
        ],
        roomTypeId: 'vip',
        startAt: DateTime(2026, 9, 1, 13),
        endAt: DateTime(2026, 9, 1, 15),
      );
      expect(remaining, 1);
    });
  });

  group('加購允許清單', () {
    test('只回傳 allowedAddonIds 內且仍存在的服務', () {
      final List<Map<String, dynamic>> allowed =
          DaycareAddonCatalog.allowedForDaycare(
            doc: <String, dynamic>{
              'enabled': true,
              'valueServices': <Map<String, dynamic>>[
                <String, dynamic>{'id': 'a1', 'name': '梳毛', 'price': 100},
                <String, dynamic>{'id': 'a2', 'name': '剪指甲', 'price': 80},
              ],
            },
            allowedAddonIds: <String>['a1'],
          );
      expect(allowed.length, 1);
      expect(allowed.first['id'], 'a1');
    });

    test('停用的加購模組前台不顯示，後台 flatten 仍可列出', () {
      final Map<String, dynamic> doc = <String, dynamic>{
        'enabled': false,
        'valueServices': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'a1', 'name': '梳毛'},
        ],
      };
      expect(DaycareAddonCatalog.flatten(doc), isNotEmpty);
      expect(
        DaycareAddonCatalog.allowedForDaycare(
          doc: doc,
          allowedAddonIds: <String>['a1'],
        ),
        isEmpty,
      );
    });
  });

  group('Daycare room-based pricing', () {
    test('舊資料沒有 pricingMode 視為 time_based', () {
      final DaycareSettingsModel settings = DaycareSettingsModel.fromMap(
        const <String, dynamic>{},
      );
      expect(settings.pricingMode, DaycarePricingModes.timeBased);
      expect(settings.isRoomBased, isFalse);
    });

    test('固定日價不因停留時長改變，多寵加價正確', () {
      const DaycareRoomTypeSetting room = DaycareRoomTypeSetting(
        roomTypeId: 'std',
        enabled: true,
        maxPets: 5,
        basePrice: 500,
        extraPetPrice: 100,
        extraTimePrice: 150,
        overtimeEnabled: true,
        overtimeGraceMinutes: 15,
        extraTimeUnitMinutes: 30,
      );
      final DaycarePricingService pricing = DaycarePricingService.instance;
      final DaycareRoomQuote fourHours = pricing.quoteRoom(
        roomSetting: room,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 13),
        petCount: 1,
      );
      final DaycareRoomQuote fiveHours = pricing.quoteRoom(
        roomSetting: room,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 14),
        petCount: 1,
      );
      expect(fourHours.cappedRoomAmount, 500);
      expect(fiveHours.cappedRoomAmount, 500);
      expect(fiveHours.extraTimeAmount, 0);
      final DaycareRoomQuote twoPets = pricing.quoteRoom(
        roomSetting: room,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 13),
        petCount: 2,
      );
      expect(twoPets.extraPetAmount, 100);
      expect(twoPets.cappedRoomAmount, 600);
      final DaycareRoomQuote threePets = pricing.quoteRoom(
        roomSetting: room,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 13),
        petCount: 3,
      );
      expect(threePets.extraPetAmount, 200);
      expect(threePets.cappedRoomAmount, 700);
      const settings = DaycareSettingsModel(latestPickUp: '18:00');
      expect(
        pricing.estimatedLatePickupFee(
          settings: settings,
          roomSetting: room,
          endAt: DateTime(2026, 9, 1, 18, 45),
        ),
        150,
      );
    });

    test('多貓加價與國定假日 overnight 原價較高', () {
      const DaycareRoomTypeSetting room = DaycareRoomTypeSetting(
        roomTypeId: 'sun',
        enabled: true,
        baseMinutes: 240,
        basePrice: 1000,
        extraPetPrice: 100,
        extraTimePrice: 200,
      );
      final DaycarePricingService pricing = DaycarePricingService.instance;
      expect(
        pricing.overnightStayOriginal(
          roomNightPrice: 1800,
          extraPetNightPrice: 300,
          petCount: 2,
          specialDateSurcharge: 500,
        ),
        2600,
      );
      final DaycareRoomQuote quote = pricing.quoteRoom(
        roomSetting: room,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 18),
        petCount: 2,
        overnightCapAmount: 2600,
      );
      expect(quote.extraPetAmount, 100);
      expect(quote.cappedRoomAmount <= 2600, isTrue);
    });
  });
}

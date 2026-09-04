import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_fee_line_item.dart';
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

    test('新版 toMap 不寫入營業開始／結束，fromMap 仍讀舊欄位', () {
      final Map<String, dynamic> saved = const DaycareSettingsModel(
        openTime: '08:00',
        closeTime: '21:00',
        earliestDropOff: '09:30',
      ).toMap();
      expect(saved.containsKey('openTime'), isFalse);
      expect(saved.containsKey('closeTime'), isFalse);
      expect(saved['earliestDropOff'], '09:30');
      expect(saved['maxDurationMinutes'], 1440);
      expect(
        DaycareSettingsModel.fromMap(<String, dynamic>{
          'openTime': '07:15',
          'closeTime': '22:00',
        }).openTime,
        '07:15',
      );
    });

    test('訂金依總額百分比計算', () {
      final DaycarePlanModel plan = const DaycarePlanModel(
        id: 'p',
        name: '4 小時安親方案',
        includedMinutes: 240,
        basePrice: 880,
      );
      final DaycareQuote quote = pricing.quote(
        settings: settings,
        plan: plan,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 12),
        petCount: 1,
      );
      expect(quote.totalAmount, 880);
      expect(quote.depositAmount, 440);
    });

    test('4 小時 NT\$880，使用 3 小時只收起步價格', () {
      final DaycareTimeCharge charge = pricing.quoteTimeCharge(
        includedMinutes: 240,
        basePrice: 880,
        extraBillingMinutes: 60,
        extraBillingPrice: 200,
        extraPetPrice: 0,
        maxBaseCharge: 0,
        durationMinutes: 180,
        petCount: 1,
      );
      expect(charge.timeCharge, 880);
      expect(charge.extraUnits, 0);
      expect(charge.extraPetCharge, 0);
    });

    test('4 小時 NT\$880，超過後每小時 NT\$200，使用 6 小時為 1280', () {
      final DaycareTimeCharge charge = pricing.quoteTimeCharge(
        includedMinutes: 240,
        basePrice: 880,
        extraBillingMinutes: 60,
        extraBillingPrice: 200,
        extraPetPrice: 0,
        maxBaseCharge: 0,
        durationMinutes: 360,
        petCount: 1,
      );
      expect(charge.timeCharge, 1280);
      expect(charge.extraUnits, 2);
    });

    test('2 隻寵物每多 1 隻 NT\$100 加在時間費用之外', () {
      final DaycareTimeCharge charge = pricing.quoteTimeCharge(
        includedMinutes: 240,
        basePrice: 880,
        extraBillingMinutes: 60,
        extraBillingPrice: 200,
        extraPetPrice: 100,
        maxBaseCharge: 0,
        durationMinutes: 360,
        petCount: 2,
      );
      expect(charge.timeCharge, 1280);
      expect(charge.extraPetCharge, 100);
      expect(charge.subtotal, 1380);
    });

    test('最高時間費用只限制時間費，不限制多寵加收', () {
      final DaycareTimeCharge charge = pricing.quoteTimeCharge(
        includedMinutes: 240,
        basePrice: 880,
        extraBillingMinutes: 60,
        extraBillingPrice: 200,
        extraPetPrice: 100,
        maxBaseCharge: 1100,
        durationMinutes: 360,
        petCount: 2,
      );
      expect(charge.timeCharge, 1100);
      expect(charge.extraPetCharge, 100);
      expect(charge.subtotal, 1200);
    });

    test('最高時間費用 0 不限制', () {
      final DaycareTimeCharge charge = pricing.quoteTimeCharge(
        includedMinutes: 240,
        basePrice: 880,
        extraBillingMinutes: 60,
        extraBillingPrice: 200,
        extraPetPrice: 0,
        maxBaseCharge: 0,
        durationMinutes: 360,
        petCount: 1,
      );
      expect(charge.timeCharge, 1280);
    });

    test('每多 1 隻加收 0 不增加費用', () {
      final DaycareTimeCharge charge = pricing.quoteTimeCharge(
        includedMinutes: 240,
        basePrice: 880,
        extraBillingMinutes: 60,
        extraBillingPrice: 200,
        extraPetPrice: 0,
        maxBaseCharge: 0,
        durationMinutes: 240,
        petCount: 4,
      );
      expect(charge.extraPetCharge, 0);
      expect(charge.subtotal, 880);
    });

    test('超過 10 分鐘、每 30 分鐘加收計算 1 個單位', () {
      final DaycareTimeCharge charge = pricing.quoteTimeCharge(
        includedMinutes: 240,
        basePrice: 880,
        extraBillingMinutes: 30,
        extraBillingPrice: 200,
        extraPetPrice: 0,
        maxBaseCharge: 0,
        durationMinutes: 250,
        petCount: 1,
      );
      expect(charge.extraMinutes, 10);
      expect(charge.extraUnits, 1);
      expect(charge.timeCharge, 1080);
    });

    test('方案 quote 與 quoteTimeCharge 使用同一結果', () {
      final DaycarePlanModel plan = const DaycarePlanModel(
        id: 'p',
        name: '4 小時安親方案',
        includedMinutes: 240,
        basePrice: 880,
        extraBillingMinutes: 60,
        extraBillingPrice: 200,
        extraPetPrice: 100,
      );
      final DaycareQuote quote = pricing.quote(
        settings: const DaycareSettingsModel(),
        plan: plan,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 15),
        petCount: 2,
      );
      expect(quote.timeCharge, 1280);
      expect(quote.extraPetAmount, 100);
      expect(quote.totalAmount, 1380);
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
    test('舊資料沒有 pricingMode 視為 independentPlan', () {
      final DaycareSettingsModel settings = DaycareSettingsModel.fromMap(
        const <String, dynamic>{},
      );
      expect(settings.pricingMode, DaycarePricingModes.independentPlan);
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
      const settings = DaycareSettingsModel(
        latestPickUp: '18:00',
        latePickupEnabled: true,
        overtimeGraceMinutes: 15,
        latePickupUnitMinutes: 30,
        latePickupPrice: 150,
      );
      expect(
        pricing.shopLatePickupFee(
          settings: settings,
          scheduledEndAt: DateTime(2026, 9, 1, 18),
          actualEndAt: DateTime(2026, 9, 1, 18, 45),
        ),
        150,
      );
      expect(
        pricing.estimatedLatePickupFee(
          settings: settings,
          roomSetting: room,
          endAt: DateTime(2026, 9, 1, 18, 45),
        ),
        0,
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

    test('費用明細顯示多寵費與時間費上限折抵，且總額與 quote 相同', () {
      final DaycarePricingService pricing = DaycarePricingService.instance;
      const DaycarePlanModel plan = DaycarePlanModel(
        id: 'cap',
        name: '安親方案',
        includedMinutes: 240,
        basePrice: 880,
        extraBillingMinutes: 60,
        extraBillingPrice: 200,
        extraPetPrice: 100,
        maxBaseCharge: 1100,
      );
      final DaycareQuote quote = pricing.quote(
        settings: const DaycareSettingsModel(
          depositType: DaycareDepositTypes.percent,
          depositValue: 50,
        ),
        plan: plan,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 15),
        petCount: 2,
      );
      expect(quote.timeCharge, 1100);
      expect(quote.extraPetAmount, 100);
      expect(quote.totalAmount, 1200);
      expect(quote.toPriceSnapshot()['totalAmount'], quote.totalAmount);
      final List<BookingFeeLineItem> lines = pricing.customerFeeLines(
        quote: quote,
        primaryLabel: plan.name,
        depositType: DaycareDepositTypes.percent,
      );
      expect(
        lines.any((BookingFeeLineItem e) => e.label.contains('多寵費')),
        isTrue,
      );
      expect(lines.any((BookingFeeLineItem e) => e.label == '時間費上限折抵'), isTrue);
      expect(
        lines
            .firstWhere(
              (BookingFeeLineItem e) => e.kind == BookingFeeLineKind.total,
            )
            .amount,
        quote.totalAmount,
      );
      expect(
        lines
            .firstWhere(
              (BookingFeeLineItem e) => e.kind == BookingFeeLineKind.payable,
            )
            .label,
        '預計訂金',
      );
    });

    test('上限為 0 不限制時間費；多寵費為 0 不加價', () {
      final DaycarePricingService pricing = DaycarePricingService.instance;
      final DaycareTimeCharge uncapped = pricing.quoteTimeCharge(
        includedMinutes: 240,
        basePrice: 880,
        extraBillingMinutes: 60,
        extraBillingPrice: 200,
        extraPetPrice: 0,
        maxBaseCharge: 0,
        durationMinutes: 360,
        petCount: 3,
      );
      expect(uncapped.timeCharge, 1280);
      expect(uncapped.extraPetCharge, 0);
    });

    test('超過 10 分鐘且每 30 分鐘計費收 1 單位', () {
      final DaycarePricingService pricing = DaycarePricingService.instance;
      final DaycareTimeCharge charge = pricing.quoteTimeCharge(
        includedMinutes: 240,
        basePrice: 880,
        extraBillingMinutes: 30,
        extraBillingPrice: 100,
        extraPetPrice: 0,
        maxBaseCharge: 0,
        durationMinutes: 250,
        petCount: 1,
      );
      expect(charge.extraMinutes, 10);
      expect(charge.extraUnits, 1);
      expect(charge.timeCharge, 980);
    });
  });
}

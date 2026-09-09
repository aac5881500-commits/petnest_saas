// 檔案名稱：test/daycare_pricing_service_test.dart
// 功能說明：安親計價服務的單元測試（舊訂單沒有 bookingKind 視為住宿）

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

    test('5 小時起步方案使用 3 小時仍收起步價、不加超時費', () {
      final DaycareTimeCharge charge = pricing.quoteTimeCharge(
        includedMinutes: 300,
        basePrice: 1000,
        extraBillingMinutes: 60,
        extraBillingPrice: 200,
        extraPetPrice: 0,
        maxBaseCharge: 0,
        durationMinutes: 180,
        petCount: 1,
      );
      expect(charge.timeCharge, 1000);
      expect(charge.extraMinutes, 0);
      expect(charge.extraUnits, 0);
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

    test('roomType 設定只提供安親房型、不列出獨立方案', () {
      const DaycareSettingsModel settings = DaycareSettingsModel(
        pricingMode: DaycarePricingModes.roomType,
        plans: <DaycarePlanModel>[
          DaycarePlanModel(id: 'hourly', name: '每小時計費', enabled: true),
        ],
      );
      expect(settings.isRoomBased, isTrue);
      expect(settings.customerPlans, isEmpty);
      expect(
        DaycarePricingModes.persist('room_based'),
        DaycarePricingModes.roomType,
      );
      expect(
        DaycarePricingModes.persist('time_based'),
        DaycarePricingModes.independentPlan,
      );
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

    test('費用明細顯示多寵費與計費上限折抵，且總額與 quote 相同', () {
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
      expect(
        lines.any(
          (BookingFeeLineItem e) => e.label.startsWith('已套用當次最高費用 NT\$1100'),
        ),
        isTrue,
      );
      final List<BookingFeeLineItem> roomLines = pricing.customerFeeLines(
        quote: quote,
        primaryLabel: 'VIP尊爵房',
        depositType: DaycareDepositTypes.percent,
        isRoomBased: true,
      );
      expect(
        roomLines.any(
          (BookingFeeLineItem e) => e.label.startsWith('已套用當次最高費用 NT\$1100'),
        ),
        isTrue,
      );
      expect(
        DaycarePlanModel.offerDetailLines(
          includedMinutes: 300,
          basePrice: 880,
          extraBillingMinutes: 60,
          extraBillingPrice: 200,
          maxBaseCharge: 1500,
          extraPetPrice: 100,
          maxPets: 3,
          enabled: true,
          roomBased: true,
        ).contains('當日房型收費最高上限 NT\$1500'),
        isTrue,
      );
      expect(
        DaycarePlanModel.offerDetailLines(
          includedMinutes: 120,
          basePrice: 200,
          extraBillingMinutes: 30,
          extraBillingPrice: 100,
          maxBaseCharge: 1000,
          extraPetPrice: 100,
          maxPets: 3,
          enabled: true,
        ).contains('當次最高計費　NT\$1000'),
        isTrue,
      );
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
        '本次應付訂金',
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

    test('10 小時、起步 2 小時 NT\$200、超過每小時 NT\$100：起步 200＋超時 800＝時間費 1000', () {
      final DaycarePricingService pricing = DaycarePricingService.instance;
      const DaycarePlanModel plan = DaycarePlanModel(
        id: 'hourly',
        name: '每小時計費',
        includedMinutes: 120,
        basePrice: 200,
        extraBillingMinutes: 60,
        extraBillingPrice: 100,
      );
      final DaycareQuote quote = pricing.quote(
        settings: const DaycareSettingsModel(),
        plan: plan,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 19),
        petCount: 1,
        addonAmount: 500,
      );
      expect(quote.durationMinutes, 600);
      expect(quote.baseAmount, 200);
      expect(quote.extraMinutes, 480);
      expect(quote.extraUnits, 8);
      expect(quote.extraTimeAmount, 800);
      expect(quote.timeCharge, 1000);
      expect(quote.totalAmount, 1500);
      final List<BookingFeeLineItem> lines = pricing.customerFeeLines(
        quote: quote,
        primaryLabel: plan.name,
        includePayable: false,
        addonLines: const <BookingFeeLineItem>[
          BookingFeeLineItem(label: '加值 A', amount: 300),
          BookingFeeLineItem(label: '加值 B', amount: 200),
        ],
      );
      expect(
        lines.any((BookingFeeLineItem e) => e.label.contains('每小時計費')),
        isFalse,
      );
      expect(
        lines
            .firstWhere((BookingFeeLineItem e) => e.label.startsWith('起步費'))
            .amount,
        200,
      );
      expect(
        lines
            .firstWhere((BookingFeeLineItem e) => e.label.startsWith('超過起步'))
            .amount,
        800,
      );
      expect(
        lines.any((BookingFeeLineItem e) => e.label.contains('超時加收')),
        isFalse,
      );
      int itemSum = 0;
      for (final BookingFeeLineItem line in lines) {
        if (line.kind == BookingFeeLineKind.total ||
            line.kind == BookingFeeLineKind.payable) {
          continue;
        }
        itemSum += line.amount;
      }
      expect(itemSum, 1500);
      expect(
        lines
            .firstWhere(
              (BookingFeeLineItem e) => e.kind == BookingFeeLineKind.total,
            )
            .amount,
        1500,
      );
      expect(
        pricing.hourlyRuleTextFromQuote(
          quote,
          extraBillingPrice: plan.extraBillingPrice,
        ),
        '起步 2 小時 NT\$200，超過後每小時 NT\$100；不足 1 小時以 1 小時計。',
      );
    });

    test('超過 10 分鐘、每 30 分鐘 NT\$50：顯示 1 個 30 分鐘 × NT\$50', () {
      final DaycarePricingService pricing = DaycarePricingService.instance;
      const DaycarePlanModel plan = DaycarePlanModel(
        id: 'half',
        name: '每 30 分鐘',
        includedMinutes: 120,
        basePrice: 200,
        extraBillingMinutes: 30,
        extraBillingPrice: 50,
      );
      final DaycareQuote quote = pricing.quote(
        settings: const DaycareSettingsModel(),
        plan: plan,
        startAt: DateTime(2026, 9, 1, 9, 0),
        endAt: DateTime(2026, 9, 1, 11, 10),
        petCount: 1,
      );
      expect(quote.extraMinutes, 10);
      expect(quote.extraUnits, 1);
      expect(quote.extraTimeAmount, 50);
      final List<BookingFeeLineItem> lines = pricing.customerFeeLines(
        quote: quote,
        primaryLabel: '方案',
        includePayable: false,
      );
      final BookingFeeLineItem extra = lines.firstWhere(
        (BookingFeeLineItem e) => e.label.startsWith('超過起步'),
      );
      expect(extra.amount, 50);
      expect(extra.label, contains('1 個 30 分鐘 × NT\$50'));
      expect(extra.subtitle, '每 30 分鐘 NT\$50');
      expect(
        pricing.hourlyRuleTextFromQuote(
          quote,
          extraBillingPrice: plan.extraBillingPrice,
        ),
        '起步 2 小時 NT\$200，超過後每 30 分鐘 NT\$50；不足 30 分鐘以 30 分鐘計。',
      );
    });

    test('加值服務與多寵費加入後，明細加總等於預估總額', () {
      final DaycarePricingService pricing = DaycarePricingService.instance;
      const DaycarePlanModel plan = DaycarePlanModel(
        id: 'p',
        name: '方案',
        includedMinutes: 120,
        basePrice: 200,
        extraBillingMinutes: 60,
        extraBillingPrice: 100,
        extraPetPrice: 80,
      );
      final DaycareQuote quote = pricing.quote(
        settings: const DaycareSettingsModel(),
        plan: plan,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 19),
        petCount: 2,
        addonAmount: 500,
      );
      expect(quote.extraPetAmount, 80);
      expect(quote.timeCharge, 1000);
      expect(quote.totalAmount, 1580);
      final List<BookingFeeLineItem> lines = pricing.customerFeeLines(
        quote: quote,
        primaryLabel: '方案',
        includePayable: false,
        addonLines: const <BookingFeeLineItem>[
          BookingFeeLineItem(label: '加值 A', amount: 300),
          BookingFeeLineItem(label: '加值 B', amount: 200),
        ],
      );
      expect(
        lines.any(
          (BookingFeeLineItem e) =>
              e.label == '多寵費（增加 1 隻 × NT\$80）' && e.amount == 80,
        ),
        isTrue,
      );
      expect(lines.any((BookingFeeLineItem e) => e.label == '加值服務小計'), isFalse);
      int itemSum = 0;
      for (final BookingFeeLineItem line in lines) {
        if (line.kind == BookingFeeLineKind.total) {
          continue;
        }
        itemSum += line.amount;
      }
      expect(itemSum, quote.totalAmount);
    });

    test('有最高上限時明細和總額一致', () {
      final DaycarePricingService pricing = DaycarePricingService.instance;
      const DaycarePlanModel plan = DaycarePlanModel(
        id: 'cap',
        name: '上限方案',
        includedMinutes: 120,
        basePrice: 200,
        extraBillingMinutes: 60,
        extraBillingPrice: 100,
        maxBaseCharge: 600,
      );
      final DaycareQuote quote = pricing.quote(
        settings: const DaycareSettingsModel(),
        plan: plan,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 19),
        petCount: 1,
        addonAmount: 300,
      );
      expect(quote.uncappedTimeCharge, 1000);
      expect(quote.timeCharge, 600);
      expect(quote.totalAmount, 900);
      final List<BookingFeeLineItem> lines = pricing.customerFeeLines(
        quote: quote,
        primaryLabel: '方案',
        includePayable: false,
        addonLines: const <BookingFeeLineItem>[
          BookingFeeLineItem(label: '加值', amount: 300),
        ],
      );
      expect(quote.timeChargeCapDiscount, 400);
      int itemSum = 0;
      for (final BookingFeeLineItem line in lines) {
        if (line.kind == BookingFeeLineKind.total) {
          continue;
        }
        itemSum += line.amount;
      }
      expect(itemSum, 900);
      expect(
        lines.any(
          (BookingFeeLineItem e) =>
              e.label == '已套用當次最高費用 NT\$600' && e.amount == -400,
        ),
        isTrue,
      );
    });

    test('客戶端與店主端顯示同一套計費說明，舊單缺欄位不崩潰', () {
      final DaycarePricingService pricing = DaycarePricingService.instance;
      const DaycarePlanModel plan = DaycarePlanModel(
        id: 'hourly',
        name: '每小時計費',
        includedMinutes: 120,
        basePrice: 200,
        extraBillingMinutes: 60,
        extraBillingPrice: 100,
      );
      final DaycareQuote quote = pricing.quote(
        settings: const DaycareSettingsModel(),
        plan: plan,
        startAt: DateTime(2026, 9, 1, 9),
        endAt: DateTime(2026, 9, 1, 19),
        petCount: 1,
      );
      final List<BookingFeeLineItem> quoteLines = pricing
          .customerFeeLines(
            quote: quote,
            primaryLabel: plan.name,
            includePayable: false,
          )
          .where((BookingFeeLineItem e) => e.kind == BookingFeeLineKind.normal)
          .toList();
      final Map<String, dynamic> booking = <String, dynamic>{
        'pricingMode': DaycarePricingModes.independentPlan,
        'daycarePricingSnapshot': quote.toPriceSnapshot(),
        'timeChargeSnapshot': pricing.timeChargeSnapshot(
          pricing.quoteTimeCharge(
            includedMinutes: plan.includedMinutes,
            basePrice: plan.basePrice,
            extraBillingMinutes: plan.extraBillingMinutes,
            extraBillingPrice: plan.extraBillingPrice,
            extraPetPrice: 0,
            maxBaseCharge: 0,
            durationMinutes: 600,
            petCount: 1,
          ),
        ),
        'daycarePlanSnapshot': plan.toMap(),
        'totalPrice': quote.totalAmount,
      };
      final List<BookingFeeLineItem> bookingLines = pricing
          .itemLinesFromBooking(booking);
      expect(
        bookingLines.map((BookingFeeLineItem e) => e.label).toList(),
        quoteLines.map((BookingFeeLineItem e) => e.label).toList(),
      );
      expect(
        bookingLines.map((BookingFeeLineItem e) => e.amount).toList(),
        quoteLines.map((BookingFeeLineItem e) => e.amount).toList(),
      );
      expect(
        pricing.hourlyRuleTextFromBooking(booking),
        pricing.hourlyRuleTextFromQuote(
          quote,
          extraBillingPrice: plan.extraBillingPrice,
        ),
      );
      expect(
        () => pricing.itemLinesFromBooking(<String, dynamic>{
          'bookingKind': 'daycare',
          'totalPrice': 880,
          'daycarePricingSnapshot': <String, dynamic>{'baseAmount': 880},
        }),
        returnsNormally,
      );
      final List<BookingFeeLineItem> legacy = pricing.itemLinesFromBooking(
        <String, dynamic>{
          'daycarePricingSnapshot': <String, dynamic>{
            'timeCharge': 1000,
            'extraTimeAmount': 800,
          },
        },
      );
      expect(legacy.where((BookingFeeLineItem e) => e.amount == 1000), isEmpty);
      expect(
        legacy.any(
          (BookingFeeLineItem e) =>
              e.label.startsWith('超過起步') && e.amount == 800,
        ),
        isTrue,
      );
    });
  });
}

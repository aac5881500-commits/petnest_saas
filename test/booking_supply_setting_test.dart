// 檔案名稱：test/booking_supply_setting_test.dart
// 功能說明：舊住宿耗材相容，以及住宿／安親各自的扣除量。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/booking_supply_setting_model.dart';

void main() {
  Map<String, dynamic> booking({int nights = 2, int pets = 2}) {
    return <String, dynamic>{
      'nights': nights,
      'petIds': List<String>.generate(pets, (int index) => 'pet$index'),
    };
  }

  BookingSupplySettingModel legacy() {
    return BookingSupplySettingModel.fromMap(
      id: 'legacy',
      data: <String, dynamic>{
        'name': '豆腐砂',
        'useInventory': true,
        'inventoryItemId': 'item-sand',
        'quantityPerUnit': 0.5,
        'deductionMode': 'perRoomPerNight',
        'enabled': true,
        'unit': '包',
      },
    );
  }

  test('舊文件只套用住宿，安親不會扣除', () {
    final BookingSupplySettingModel setting = legacy();
    expect(setting.appliesToStay, isTrue);
    expect(setting.appliesToDaycare, isFalse);
    expect(setting.stayQuantity, 0.5);
    expect(setting.stayMode, BookingSupplyDeductionMode.perRoomPerNight);
    expect(setting.shouldDeductForStay, isTrue);
    expect(setting.shouldDeductForDaycare, isFalse);

    final List<BookingSupplyDeductLine> stay = BookingSupplyDeduction.stayLines(
      booking: booking(),
      settings: <BookingSupplySettingModel>[setting],
    );
    expect(stay, hasLength(1));
    expect(stay.single.quantity, 1);
    expect(stay.single.reason, '住宿耗材「豆腐砂」');
    expect(
      BookingSupplyDeduction.daycareLines(
        booking: booking(),
        settings: <BookingSupplySettingModel>[setting],
      ),
      isEmpty,
    );
  });

  test('只套住宿時，安親開始不產生扣除', () {
    final BookingSupplySettingModel setting = BookingSupplySettingModel.fromMap(
      id: 'stay-only',
      data: <String, dynamic>{
        'name': '濕紙巾',
        'useInventory': true,
        'inventoryItemId': 'item-tissue',
        'enabled': true,
        'appliesToStay': true,
        'appliesToDaycare': false,
        'stayQuantityPerUnit': 1,
        'stayDeductionMode': 'perRoomPerStay',
        'daycareQuantityPerUnit': 3,
        'daycareDeductionMode': 'perPetPerVisit',
        'quantityPerUnit': 1,
        'deductionMode': 'perRoomPerStay',
      },
    );
    expect(
      BookingSupplyDeduction.daycareLines(
        booking: booking(),
        settings: <BookingSupplySettingModel>[setting],
      ),
      isEmpty,
    );
    expect(
      BookingSupplyDeduction.stayLines(
        booking: booking(),
        settings: <BookingSupplySettingModel>[setting],
      ).single.quantity,
      1,
    );
  });

  test('只套安親時，住宿入住不扣，安親依寵物數扣一次', () {
    final BookingSupplySettingModel setting = BookingSupplySettingModel.fromMap(
      id: 'daycare-only',
      data: <String, dynamic>{
        'name': '餐盒',
        'useInventory': true,
        'inventoryItemId': 'item-meal',
        'enabled': true,
        'appliesToStay': false,
        'appliesToDaycare': true,
        'stayQuantityPerUnit': 9,
        'stayDeductionMode': 'perPetPerNight',
        'daycareQuantityPerUnit': 1,
        'daycareDeductionMode': 'perPetPerVisit',
        'quantityPerUnit': 9,
        'deductionMode': 'perPetPerNight',
      },
    );
    expect(setting.shouldDeductForStay, isFalse);
    expect(setting.shouldDeductForDaycare, isTrue);
    expect(
      BookingSupplyDeduction.stayLines(
        booking: booking(),
        settings: <BookingSupplySettingModel>[setting],
      ),
      isEmpty,
    );
    final List<BookingSupplyDeductLine> daycare =
        BookingSupplyDeduction.daycareLines(
          booking: booking(pets: 3),
          settings: <BookingSupplySettingModel>[setting],
        );
    expect(daycare.single.quantity, 3);
    expect(daycare.single.reason, '安親耗材「餐盒」');
    expect(
      BookingSupplyDeduction.daycareLines(
        booking: booking(pets: 3),
        settings: <BookingSupplySettingModel>[setting],
      ).single.quantity,
      daycare.single.quantity,
    );
  });

  test('同時套用時住宿與安親各自使用自己的規則', () {
    final BookingSupplySettingModel setting = BookingSupplySettingModel.fromMap(
      id: 'both',
      data: <String, dynamic>{
        'name': '清潔液',
        'useInventory': true,
        'inventoryItemId': 'item-clean',
        'enabled': true,
        'appliesToStay': true,
        'appliesToDaycare': true,
        'quantityPerUnit': 0.5,
        'deductionMode': 'perRoomPerNight',
        'stayQuantityPerUnit': 0.5,
        'stayDeductionMode': 'perRoomPerNight',
        'daycareQuantityPerUnit': 1,
        'daycareDeductionMode': 'perRoomPerVisit',
      },
    );
    final BookingSupplyDeductLine stay = BookingSupplyDeduction.stayLines(
      booking: booking(nights: 2, pets: 4),
      settings: <BookingSupplySettingModel>[setting],
    ).single;
    final BookingSupplyDeductLine daycare = BookingSupplyDeduction.daycareLines(
      booking: booking(nights: 2, pets: 4),
      settings: <BookingSupplySettingModel>[setting],
    ).single;
    expect(stay.quantity, 1);
    expect(stay.reason, '住宿耗材「清潔液」');
    expect(daycare.quantity, 1);
    expect(daycare.reason, '安親耗材「清潔液」');
  });

  test('沒有寵物資料時安親仍至少扣 1 次', () {
    final BookingSupplySettingModel setting = BookingSupplySettingModel.fromMap(
      id: 'fallback',
      data: <String, dynamic>{
        'name': '毛巾',
        'useInventory': true,
        'inventoryItemId': 'item-towel',
        'enabled': true,
        'appliesToDaycare': true,
        'appliesToStay': false,
        'daycareQuantityPerUnit': 0.5,
        'daycareDeductionMode': 'perPetPerVisit',
      },
    );
    final BookingSupplyDeductLine line = BookingSupplyDeduction.daycareLines(
      booking: <String, dynamic>{'petIds': <String>[], 'pets': <Object>[]},
      settings: <BookingSupplySettingModel>[setting],
    ).single;
    expect(line.quantity, 0.5);
  });

  test('新文件仍把住宿規則寫進舊欄位', () {
    final DateTime now = DateTime(2026, 9, 28);
    final BookingSupplySettingModel setting = BookingSupplySettingModel(
      id: 'new',
      shopId: 'shop',
      name: '砂',
      quantityPerUnit: 2,
      deductionMode: BookingSupplyDeductionMode.perPetPerStay,
      enabled: true,
      createdAt: now,
      updatedAt: now,
      useInventory: true,
      inventoryItemId: 'item',
      appliesToStay: true,
      appliesToDaycare: true,
      stayQuantityPerUnit: 2,
      stayDeductionMode: BookingSupplyDeductionMode.perPetPerStay,
      daycareQuantityPerUnit: 1,
      daycareDeductionMode: DaycareSupplyDeductionMode.perRoomPerVisit,
    );
    final Map<String, dynamic> data = setting.toMap();
    expect(data['quantityPerUnit'], 2);
    expect(data['deductionMode'], 'perPetPerStay');
    expect(data['appliesToStay'], isTrue);
    expect(data['appliesToDaycare'], isTrue);
    expect(
      InventoryConstants.daycareSupplyDeductId('booking-1'),
      'ds_booking-1_deduct',
    );
    expect(
      InventoryConstants.daycareSupplyDeductId('booking-1'),
      isNot(InventoryConstants.bookingSupplyDeductId('booking-1')),
    );
  });
}

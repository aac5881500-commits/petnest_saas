// 檔案名稱：test/booking_addon_section_bool_test.dart
// 功能說明：預約加值服務區塊布林的單元測試（int 0 搭配 ?? true 會 TypeError（舊 allowMultiplePetsPerSlot 寫法））

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_addon_section.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_addons_helper.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_summary_helper.dart';

/// 重現舊寫法：Firestore 把開關存成 0 時，`?? true` 會把 int 指派給 bool。
bool unsafeAssignBool(dynamic value, {required bool fallback}) {
  return value ?? fallback;
}

void main() {
  test('int 0 搭配 ?? true 會 TypeError（舊 allowMultiplePetsPerSlot 寫法）', () {
    expect(
      () => unsafeAssignBool(0, fallback: true),
      throwsA(isA<TypeError>()),
    );
  });

  test('int 0 搭配 as bool 會 TypeError（舊 allowCouponTogether 寫法）', () {
    dynamic value = 0;
    expect(() => (value ?? false) as bool, throwsA(isA<TypeError>()));
  });

  testWidgets(
    '加值服務區塊：enabled / allowMultiplePetsPerSlot / useInventory 為 0 或 1 不紅屏',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingAddonSection(
                showAddons: true,
                addonLoading: false,
                addonData: <String, dynamic>{
                  'enabled': 0,
                  'timeOptions': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'label': '提早入住',
                      'price': 200,
                      'desc': '營業時間外',
                    },
                  ],
                  'valueServices': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'v1',
                      'name': '接送',
                      'price': 100,
                      'desc': '來回',
                      'useInventory': 0,
                    },
                  ],
                  'customServices': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'c1',
                      'name': '剪指甲',
                      'price': 50,
                      'desc': '',
                      'useInventory': 1,
                    },
                  ],
                  'dailyTimedServices': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'feed',
                      'name': '餵食',
                      'price': 30,
                      'desc': '依時段',
                      'allowMultiplePetsPerSlot': 0,
                      'useInventory': 0,
                      'timeSlots': <Map<String, dynamic>>[
                        <String, dynamic>{'id': 'am', 'label': '上午'},
                      ],
                    },
                  ],
                },
                selectedPetIds: const <String>['p1'],
                pets: const <Map<String, dynamic>>[
                  <String, dynamic>{'petId': 'p1', 'name': 'Kiki'},
                ],
                selectedTimeAddon: null,
                selectedValueServices: const <Map<String, dynamic>>[],
                selectedCustomServices: const <String, List<String>>{},
                startDate: DateTime(2026, 9, 1),
                endDate: DateTime(2026, 9, 3),
                onToggleShowAddons: () {},
                onSelectTimeAddon: (_) {},
                onToggleValueService: (_) {},
                onToggleCustomService: (_) {},
                onToggleCustomPet: _noopCustomPet,
                onDailyTimedServicesChanged: () {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      await _expandCategory(tester, '入退房時間');
      expect(find.text('目前未開放營業時間外入住'), findsOneWidget);
      await _expandCategory(tester, '加值服務');
      expect(find.text('接送'), findsOneWidget);
      await _expandCategory(tester, '客製服務');
      expect(find.text('剪指甲'), findsOneWidget);
      await _expandCategory(tester, '每日分時段服務');
      expect(find.text('餵食'), findsOneWidget);
      expect(find.text('同一時段僅能選擇一隻寵物'), findsOneWidget);
    },
  );

  testWidgets('加值服務區塊：true/false 與欄位不存在', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookingAddonSection(
              showAddons: true,
              addonLoading: false,
              addonData: <String, dynamic>{
                'enabled': true,
                'timeOptions': <Map<String, dynamic>>[
                  <String, dynamic>{'label': '正常入住', 'price': 0, 'desc': ''},
                ],
                'valueServices': <Map<String, dynamic>>[
                  <String, dynamic>{'name': '加床', 'price': 200, 'desc': ''},
                ],
                'customServices': <Map<String, dynamic>>[],
                'dailyTimedServices': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'name': '夜間巡房',
                    'price': 80,
                    'desc': '',
                    'timeSlots': <Map<String, dynamic>>[
                      <String, dynamic>{'id': 'night', 'label': '晚上'},
                    ],
                  },
                ],
              },
              selectedPetIds: const <String>['p1'],
              pets: const <Map<String, dynamic>>[
                <String, dynamic>{'petId': 'p1', 'name': 'Momo'},
              ],
              selectedTimeAddon: null,
              selectedValueServices: const <Map<String, dynamic>>[],
              selectedCustomServices: const <String, List<String>>{},
              startDate: DateTime(2026, 9, 1),
              endDate: DateTime(2026, 9, 2),
              onToggleShowAddons: () {},
              onSelectTimeAddon: (_) {},
              onToggleValueService: (_) {},
              onToggleCustomService: (_) {},
              onToggleCustomPet: _noopCustomPet,
              onDailyTimedServicesChanged: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await _expandCategory(tester, '入退房時間');
    expect(find.text('目前未開放營業時間外入住'), findsNothing);
    expect(find.text('正常入住'), findsOneWidget);
    await _expandCategory(tester, '加值服務');
    expect(find.text('加床'), findsOneWidget);
    await _expandCategory(tester, '每日分時段服務');
    expect(find.text('夜間巡房'), findsOneWidget);
    expect(find.text('同一時段僅能選擇一隻寵物'), findsNothing);
  });

  testWidgets('沒有任何加值服務時不紅屏', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingAddonSection(
            showAddons: true,
            addonLoading: false,
            addonData: null,
            selectedPetIds: const <String>[],
            pets: const <Map<String, dynamic>>[],
            selectedTimeAddon: null,
            selectedValueServices: const <Map<String, dynamic>>[],
            selectedCustomServices: const <String, List<String>>{},
            onToggleShowAddons: _noop,
            onSelectTimeAddon: _noopMap,
            onToggleValueService: _noopMap,
            onToggleCustomService: _noopMap,
            onToggleCustomPet: _noopCustomPet,
            onDailyTimedServicesChanged: _noop,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('目前尚未設定加值服務'), findsOneWidget);
    expect(find.textContaining('已選 0 項加值服務'), findsOneWidget);
    expect(find.textContaining('NT\$ 0'), findsOneWidget);
  });

  test('未選加值時 addonTotal 為 0，46000 應是房價千分位而不是加值重複累加', () {
    final Map<String, int> parts = BookingSummaryHelper.calculatePriceParts(
      selectedRoomType: const <String, dynamic>{
        'price': 23000,
        'extraPrice': 0,
      },
      nights: 2,
      selectedPetIds: const <String>['p1'],
      selectedTimeAddon: null,
      selectedValueServices: const <Map<String, dynamic>>[],
      selectedCustomServices: const <String, List<String>>{},
      selectedDailyTimedServices:
          const <String, Map<String, Map<String, List<String>>>>{},
      addonData: const <String, dynamic>{},
    );

    expect(parts['addonTotal'], 0);
    expect(parts['roomTotal'], 46000);
    expect(ShopReportFormat.money(46000), 'NT\$ 46,000');
  });

  test('buildAddonsData 將 useInventory 0/1 轉成 bool', () {
    final List<Map<String, dynamic>> addons =
        BookingAddonsHelper.buildAddonsData(
          selectedTimeAddon: const <String, dynamic>{
            'label': '提早入住',
            'price': 200,
          },
          selectedValueServices: const <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'v1',
              'name': '接送',
              'price': 100,
              'useInventory': 0,
            },
          ],
          selectedCustomServices: const <String, List<String>>{
            '剪指甲': <String>['p1'],
          },
          selectedDailyTimedServices:
              const <String, Map<String, Map<String, List<String>>>>{
                'feed': <String, Map<String, List<String>>>{
                  'p1': <String, List<String>>{
                    '2026-09-02': <String>['am'],
                  },
                },
              },
          addonData: <String, dynamic>{
            'customServices': <dynamic>[
              <String, dynamic>{
                'id': 'c1',
                'name': '剪指甲',
                'price': 50,
                'useInventory': 1,
              },
            ],
            'dailyTimedServices': <dynamic>[
              <String, dynamic>{
                'id': 'feed',
                'name': '餵食',
                'price': 30,
                'useInventory': 0,
              },
            ],
          },
          selectedPetIds: const <String>['p1'],
          pets: const <Map<String, dynamic>>[
            <String, dynamic>{'petId': 'p1', 'name': 'Kiki'},
          ],
        );

    expect(addons[0]['type'], 'time');
    expect(addons[1]['useInventory'], isFalse);
    expect(addons[2]['useInventory'], isTrue);
    expect(addons[3]['useInventory'], isFalse);
  });
}

void _noop() {}

void _noopMap(Map<String, dynamic> value) {}

void _noopCustomPet(String name, String petId, bool selected) {}

Future<void> _expandCategory(WidgetTester tester, String title) async {
  await tester.tap(find.widgetWithText(ExpansionTile, title));
  await tester.pumpAndSettle();
}

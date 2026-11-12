import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/features/medication/medication_widgets.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_addon_section.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_scope.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';

final setting = <String, dynamic>{
  'enabled': true,
  'mode': 'visit',
  'price': 50,
  'types': ['oral', 'eye'],
  'mixFree': true,
  'successOnly': true,
  'windows': [
    {'start': '09:00', 'end': '21:00'},
  ],
};
final medicine = <String, dynamic>{
  'id': 'm0',
  'petId': 'p',
  'name': '藥品 A',
  'type': 'oral',
  'dose': '1 顆',
  'instruction': '依藥袋指示使用',
  'schedule': 'fixed',
  'times': ['09:00', '21:00'],
};
Map<String, dynamic> booking(String state) => {
  'shopId': 's',
  'status': 'checked_in',
  'customerName': '陳小姐',
  'startDate': Timestamp.fromDate(DateTime(2026, 11, 10)),
  'endDate': Timestamp.fromDate(DateTime(2026, 11, 12)),
  'pets': [
    {'petId': 'p', 'name': '麻糬'},
  ],
  'medication': {
    'state': state,
    'revision': 1,
    'setting': setting,
    'request': {
      'careStart': '2026-11-10T15:00:00+08:00',
      'careEnd': '2026-11-12T12:00:00+08:00',
      'medicines': [medicine],
    },
    'estimate': {'plannedCount': 4, 'amount': 200},
    'tasks': [
      {
        'id': 't0',
        'petId': 'p',
        'scheduledAt': '2026-11-11T09:00:00+08:00',
        'medicineIds': ['m0'],
        'result': 'pending',
      },
    ],
    'history': [],
  },
};

class _EmbeddedMedicationRoute extends StatefulWidget {
  const _EmbeddedMedicationRoute();

  @override
  State<_EmbeddedMedicationRoute> createState() =>
      _EmbeddedMedicationRouteState();
}

class _EmbeddedMedicationRouteState extends State<_EmbeddedMedicationRoute>
    with ShopDashboardLeaveAware<_EmbeddedMedicationRoute> {
  final medication = GlobalKey<MedicationSettingsPageState>();

  @override
  bool get dashboardHasUnsavedChanges =>
      medication.currentState?.hasUnsavedChanges ?? false;

  @override
  bool get dashboardIsBusy => medication.currentState?.isSaving ?? false;

  @override
  Widget build(BuildContext context) => dashboardGuard(
    Scaffold(
      appBar: AppBar(title: const Text('加購服務設定')),
      body: MedicationSettingsPage(
        key: medication,
        shopId: 's',
        embedded: true,
        loadSetting: () async => setting,
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    final icons = File(
      'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (await icons.exists()) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(
        Future.value(ByteData.sublistView(await icons.readAsBytes())),
      );
      await loader.load();
    }
    final font = File('C:/Windows/Fonts/msjh.ttc');
    if (await font.exists()) {
      final loader = FontLoader('MedicationTest');
      loader.addFont(
        Future.value(ByteData.sublistView(await font.readAsBytes())),
      );
      await loader.load();
    }
  });
  test(
    'discounted accommodation baseline and medication extras charged once',
    () {
      final data = <String, dynamic>{
        'originalTotal': 2000,
        'totalPrice': 1800,
        'quotedTotalPrice': 1800,
        'paidAmount': 1800,
        'extraCharges': [
          {'id': 'medication', 'amount': 150},
        ],
      };
      expect(BookingSettlementMath.expectedTotal(data: data), 1950);
      expect(BookingSettlementMath.remainingDue(data: data), 150);
    },
  );
  testWidgets('per-pet needs start off and enabling requires a medicine', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    Map<String, dynamic> draft = {};
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'MedicationTest'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: form,
              child: MedicationRequestEditor(
                shopId: 's',
                pets: const [
                  {'petId': 'p', 'name': '麻糬'},
                  {'petId': 'q', 'name': '布丁'},
                ],
                setting: setting,
                startDate: DateTime(2026, 11, 10),
                endDate: DateTime(2026, 11, 12),
                onChanged: (v) => draft = v,
              ),
            ),
          ),
        ),
      ),
    );
    expect(form.currentState!.validate(), isTrue);
    await tester.tap(find.text('麻糬需要用藥協助'));
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('請新增至少一筆藥品，或關閉此需求'), findsOneWidget);
    expect(draft['requiredPetIds'], ['p']);
    await tester.tap(find.text('麻糬需要用藥協助'));
    await tester.pumpAndSettle();
    expect(draft['medicines'], isEmpty);
  });
  testWidgets(
    'medicine form requires dose, instruction and time before saving',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'MedicationTest'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => MedicationMedicineDialog(
                    shopId: 's',
                    setting: setting,
                    petId: 'p',
                    start: DateTime(2026, 11, 10, 15),
                    end: DateTime(2026, 11, 12, 12),
                    allowPhotoUpload: false,
                  ),
                ),
                child: const Text('新增'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('儲存藥品'));
      await tester.pumpAndSettle();
      expect(find.text('請填寫名稱'), findsOneWidget);
      expect(find.byType(MedicationMedicineDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'customer sees confirmation actions but no staff execution controls',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'MedicationTest'),
          home: Scaffold(
            body: ListView(
              children: [
                BookingMedicationPanel(
                  bookingId: 'b',
                  booking: booking('pending_customer'),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('同意安排與費用'), findsOneWidget);
      expect(find.text('請店家調整'), findsOneWidget);
      expect(find.text('確認安排／提出報價'), findsNothing);
      expect(find.text('確認用藥費並帶入退房結算'), findsNothing);
    },
  );
  testWidgets(
    'staff narrow layout and execution controls render without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'MedicationTest'),
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: ListView(
                children: [
                  BookingMedicationPanel(
                    bookingId: 'b',
                    booking: booking('confirmed'),
                    staff: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('記錄結果'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (Platform.environment['MEDICATION_CAPTURE_DIR']
          case final String capture) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(capture).create(recursive: true);
          await File(
            '$capture/order-staff-390.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );
  testWidgets(
    'owner setting saves selected pricing and refuses negative prices',
    (tester) async {
      Map<String, dynamic>? saved;
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'MedicationTest'),
          home: RepaintBoundary(
            key: boundary,
            child: MedicationSettingsPage(
              shopId: 's',
              loadSetting: () async => setting,
              saveSetting: (value) async => saved = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final price = find.widgetWithText(TextFormField, '每隻貓／每次費用（元）');
      await tester.enterText(price, '-1');
      await tester.ensureVisible(find.text('儲存設定'));
      await tester.tap(find.text('儲存設定'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('請輸入 0～100000 的整數金額'), findsOneWidget);
      await tester.ensureVisible(price);
      await tester.enterText(price, '80');
      await tester.ensureVisible(find.text('儲存設定'));
      await tester.tap(find.text('儲存設定'));
      await tester.pumpAndSettle();
      expect(saved?['price'], 80);
      expect(saved?['mode'], 'visit');
      expect(saved?['types'], ['oral', 'eye']);
      expect(tester.takeException(), isNull);
      if (Platform.environment['MEDICATION_CAPTURE_DIR']
          case final String capture) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$capture/settings-390.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );
  testWidgets('read-only staff see records without mutation controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              BookingMedicationPanel(
                bookingId: 'b',
                booking: booking('confirmed'),
                staff: true,
                canManage: false,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('記錄結果'), findsNothing);
    expect(find.text('確認用藥費並帶入退房結算'), findsNothing);
    expect(find.text('確認安排／提出報價'), findsNothing);
  });
  testWidgets('pricing cards reveal only relevant price fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MedicationSettingsPage(
          shopId: 's',
          loadSetting: () async => setting,
          saveSetting: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final quote = find.text('評估後報價');
    await tester.ensureVisible(quote);
    await tester.tap(quote);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '每隻貓／每次費用（元）'), findsNothing);
    expect(find.text('客人先填寫用藥需求，店家再提出總報價，客人同意後生效。'), findsOneWidget);
    await tester.ensureVisible(find.text('按次收費'));
    await tester.tap(find.text('按次收費'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '每隻貓／每次費用（元）'), findsOneWidget);
    expect(find.text('儲存設定'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'daily replaces nightly and saves selected-date pricing and payment timing',
    (tester) async {
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: MedicationSettingsPage(
            shopId: 's',
            loadSetting: () async => {...setting, 'mode': 'night'},
            saveSetting: (v) async => saved = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('按晚收費'), findsNothing);
      expect(find.text('按日收費'), findsOneWidget);
      expect(find.text('每日計費範圍'), findsNothing);
      expect(find.widgetWithText(TextFormField, '每隻貓／每日費用（元）'), findsOneWidget);
      final timing = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(timing);
      await tester.tap(timing);
      await tester.pumpAndSettle();
      await tester.tap(find.text('預約先收預估費用').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('儲存設定'));
      await tester.pumpAndSettle();
      expect(saved?['mode'], 'day');
      expect(saved?['dayRule'], 'service_dates');
      expect(saved?['paymentTiming'], 'advance');
      expect(tester.takeException(), isNull);
    },
  );
  test('internal errors have a user-facing message instead of a raw code', () {
    final text = medicationErrorMessage(
      FirebaseFunctionsException(code: 'internal', message: 'internal'),
    );
    expect(text, contains('這次操作未完成'));
    expect(text, isNot('internal'));
  });
  testWidgets(
    'embedded settings use one back prompt and preserve draft on cancel',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const _EmbeddedMedicationRoute(),
                  ),
                ),
                child: const Text('上一頁'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('上一頁'));
      await tester.pumpAndSettle();
      final back = find.byType(BackButton);
      final price = find.widgetWithText(TextFormField, '每隻貓／每次費用（元）');
      await tester.enterText(price, '80');
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog, skipOffstage: false), findsOneWidget);
      await tester.tap(find.text('繼續編輯'));
      await tester.pumpAndSettle();
      expect(find.text('80'), findsOneWidget);

      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog, skipOffstage: false), findsOneWidget);
      await tester.tap(find.text('放棄變更並離開'));
      await tester.pumpAndSettle();
      expect(find.text('上一頁'), findsOneWidget);
      expect(find.text('加購服務設定'), findsNothing);

      await tester.tap(find.text('上一頁'));
      await tester.pumpAndSettle();
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('上一頁'), findsOneWidget);
    },
  );

  testWidgets(
    'customer add-ons show medication without other services and restore its draft',
    (tester) async {
      final formKey = GlobalKey<FormState>();
      Map<String, dynamic> draft = {};
      final pets = [
        <String, dynamic>{'petId': 'p', 'name': '麻糬'},
      ];

      Future<void> openAddons(
        String style, {
        bool enabled = true,
        String mode = 'visit',
        Map<String, String> boundaries = const {},
      }) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingAppearanceScope(
                appearance: BookingPageAppearance(serviceStyle: style),
                child: BookingAddonSection(
                  showAddons: true,
                  addonLoading: false,
                  addonData: null,
                  selectedPetIds: const ['p'],
                  pets: pets,
                  selectedTimeAddon: null,
                  selectedValueServices: const [],
                  selectedCustomServices: const {},
                  medication: enabled
                      ? Form(
                          key: formKey,
                          child: BookingMedicationRequestSection(
                            theme: HomeThemeModel.classicDefault,
                            pets: pets,
                            setting: {
                              ...setting,
                              'mode': mode,
                              'price': 50,
                              'mixFree': true,
                              'successOnly': true,
                              'paymentTiming': 'advance',
                              ...boundaries,
                            },
                            startDate: DateTime(2026, 11, 9),
                            endDate: DateTime(2026, 11, 11),
                            initial: draft,
                            onChanged: (value) => draft = value,
                          ),
                        )
                      : null,
                  onToggleShowAddons: () {},
                  onSelectTimeAddon: (_) {},
                  onToggleValueService: (_) {},
                  onToggleCustomService: (_) {},
                  onToggleCustomPet: (_, _, _) {},
                  onDailyTimedServicesChanged: () {},
                ),
              ),
            ),
          ),
        ),
      );

      final dialog = find.byType(AlertDialog);
      final menu = find.byType(DropdownButton<String>);
      Finder inDialog(String label) =>
          find.descendant(of: dialog, matching: find.text(label));

      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> pickTime(String time) async {
        await tapVisible(menu);
        await tapVisible(find.text(time).last);
      }

      await openAddons('editorial');
      expect(find.text('用藥協助'), findsOneWidget);
      expect(find.text('目前尚未設定加購服務'), findsNothing);
      expect(menu, findsNothing);
      await tapVisible(find.text('新增安排'));
      expect(inDialog('時間'), findsOneWidget);
      expect(inDialog('用藥'), findsOneWidget);
      expect(inDialog('日期'), findsOneWidget);
      expect(menu, findsNothing);
      await tapVisible(inDialog('儲存安排'));
      expect(inDialog('請先選擇用藥時間'), findsOneWidget);
      expect(draft, isEmpty);

      await tapVisible(inDialog('時間'));
      final times = tester.widget<DropdownButton<String>>(menu).items!;
      expect(times.first.value, '09:00');
      expect(times[1].value, '09:30');
      expect(times.last.value, '21:00');
      await pickTime('09:30');
      await pickTime('10:00');
      await tapVisible(inDialog('用藥'));
      expect(menu, findsNothing);
      await tapVisible(inDialog('口服藥'));
      await tapVisible(inDialog('點眼藥'));
      await tapVisible(inDialog('日期'));
      expect(inDialog('口服藥'), findsNothing);
      await tapVisible(inDialog('11/10'));
      await tapVisible(inDialog('儲存安排'));
      expect(dialog, findsNothing);
      expect(formKey.currentState!.validate(), isTrue);
      expect(draft['preferences'], [
        {
          'petId': 'p',
          'dates': [
            {
              'date': '2026-11-10',
              'times': ['09:30', '10:00'],
            },
          ],
          'types': ['oral'],
        },
        {
          'petId': 'p',
          'dates': [
            {
              'date': '2026-11-10',
              'times': ['09:30', '10:00'],
            },
          ],
          'types': ['eye'],
        },
      ]);
      expect(find.text('用藥預估小計 NT\$ 100'), findsOneWidget);
      for (final label in ['可拌食者免費', '未成功不收費']) {
        final badge = tester.widget<Chip>(find.widgetWithText(Chip, label));
        expect((badge.avatar as Icon).icon, Icons.check);
      }
      await tapVisible(find.text('查看計費說明'));
      expect(find.textContaining('未成功的用藥費於退房時扣除'), findsOneWidget);
      expect(find.textContaining('已多付的部分由店家辦理退費'), findsOneWidget);
      await tapVisible(find.text('查看計費說明'));
      expect(find.byType(TextFormField), findsNothing);

      final previous = draft;
      await tapVisible(find.text('口服藥、點眼藥'));
      await tapVisible(inDialog('時間'));
      await pickTime('10:30');
      await tapVisible(find.byTooltip('關閉'));
      expect(draft, same(previous));

      await openAddons('original', enabled: false);
      await openAddons('original', mode: 'day');
      expect(find.text('口服藥、點眼藥'), findsOneWidget);
      expect(find.text('用藥預估小計 NT\$ 50'), findsOneWidget);
      expect(formKey.currentState!.validate(), isTrue);

      await openAddons('original', enabled: false);
      draft = {};
      const boundaries = {'checkInFrom': '15:30', 'checkOutUntil': '11:30'};
      await openAddons('original', boundaries: boundaries);
      await tapVisible(find.text('新增安排'));
      await tapVisible(inDialog('時間'));
      await pickTime('09:30');
      await tapVisible(inDialog('用藥'));
      await tapVisible(inDialog('口服藥'));
      await tapVisible(inDialog('日期'));
      expect(find.textContaining('請確認用藥時間在辦理入住後'), findsNothing);
      await tapVisible(inDialog('全選住宿日'));
      expect(find.textContaining('請確認用藥時間在辦理入住後'), findsOneWidget);
      final checkoutDay = find.widgetWithText(FilterChip, '11/11（退房日）');
      expect(tester.widget<FilterChip>(checkoutDay).selected, isFalse);
      expect(find.textContaining('請確認用藥時間在接回貓咪前'), findsNothing);
      await tapVisible(checkoutDay);
      expect(find.textContaining('請確認用藥時間在接回貓咪前'), findsOneWidget);
      await tapVisible(inDialog('調整個別日期'));
      expect(
        tester.widget<DropdownButton<String>>(menu).items!.first.value,
        '09:00',
      );
      await tapVisible(find.widgetWithText(ChoiceChip, '11/11'));
      expect(
        tester.widget<DropdownButton<String>>(menu).items!.last.value,
        '21:00',
      );
      await tapVisible(inDialog('儲存安排'));
      expect((draft['preferences'] as List).single['dates'], [
        {
          'date': '2026-11-09',
          'times': ['09:30'],
        },
        {
          'date': '2026-11-10',
          'times': ['09:30'],
        },
        {
          'date': '2026-11-11',
          'times': ['09:30'],
        },
      ]);

      await tapVisible(find.text('新增安排'));
      await tapVisible(inDialog('時間'));
      await pickTime('09:30');
      await tapVisible(inDialog('用藥'));
      await tapVisible(inDialog('口服藥'));
      await tapVisible(inDialog('點眼藥'));
      await tapVisible(inDialog('日期'));
      await tapVisible(inDialog('11/10'));
      await tapVisible(inDialog('藥品資料（選填）'));
      final name = find.byKey(const PageStorageKey<String>('eye-藥名'));
      await tester.ensureVisible(name);
      await tester.enterText(name, '眼藥 A');
      await tester.pumpAndSettle();
      await tapVisible(inDialog('儲存安排'));
      final preferences = medList(draft['preferences']);
      expect(preferences.length, 3);
      expect(preferences.last['name'], '眼藥 A');
      expect(find.text('用藥預估小計 NT\$ 150'), findsOneWidget);
      expect(
        medicationPreferenceAmount(
          {...setting, 'splitTypes': true},
          preferences,
          2,
        ),
        200,
      );

      await openAddons('original', enabled: false);
      await openAddons('original', boundaries: boundaries);
      await tapVisible(find.text('口服藥、點眼藥（眼藥 A）'));
      await tapVisible(inDialog('移除安排'));
      expect((draft['preferences'] as List).length, 1);
      expect(formKey.currentState!.validate(), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'medication fee details keep their own state after scroll restoration',
    (tester) async {
      final bucket = PageStorageBucket();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageStorage(
              bucket: bucket,
              child: Builder(
                key: const PageStorageKey<String>('shop_booking_scroll_2'),
                builder: (context) {
                  bucket.writeState(context, 1700.0);
                  return BookingMedicationRequestSection(
                    theme: HomeThemeModel.classicDefault,
                    pets: const [
                      {'petId': 'p', 'name': '麻糬'},
                    ],
                    startDate: DateTime(2026, 11, 9),
                    endDate: DateTime(2026, 11, 11),
                    setting: setting,
                    initial: const {},
                    onChanged: (_) {},
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('查看計費說明'));
      await tester.pumpAndSettle();
      expect(
        find.text(medRule(setting, includeFeeWaivers: false)),
        findsOneWidget,
      );
      final scrollContext = tester.element(
        find.byKey(const PageStorageKey<String>('shop_booking_scroll_2')),
      );
      expect(bucket.readState(scrollContext), 1700.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy medication requests show on customer detail and shop overview',
    (tester) async {
      final oldBooking = booking('pending_shop')
        ..remove('medication')
        ..['medicationRequest'] = {
          'preferences': [
            {
              'petId': 'p',
              'types': ['oral'],
              'times': ['09:00', '13:00'],
            },
          ],
        };

      for (final staff in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BookingMedicationPanel(
                bookingId: 'old-booking',
                booking: oldBooking,
                staff: staff,
                summaryOnly: staff,
              ),
            ),
          ),
        );
        expect(find.text('麻糬・口服藥・每日 09:00、13:00'), findsOneWidget);
        expect(find.text('待店家確認'), findsOneWidget);
        expect(find.text('用藥費待店家確認'), findsOneWidget);
        expect(find.text('確認安排／提出報價'), findsNothing);
      }
    },
  );

  testWidgets('customer fee separates checkout, advance and historical rates', (
    tester,
  ) async {
    Future<void> show(
      Map<String, dynamic> data, {
      Map<String, dynamic>? reference,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingMedicationPanel(
                bookingId: 'price-check',
                booking: data,
                customerDetails: true,
                referencePricing: reference ?? {...setting, 'price': 80},
              ),
            ),
          ),
        ),
      );
    }

    final deferred = booking('pending_shop');
    await show(deferred);
    expect(find.text('下單時的店家預設費率：每隻貓每次 NT\$ 50'), findsOneWidget);
    expect(find.text('用藥預估 NT\$ 200'), findsOneWidget);
    expect(find.text('用藥費尚未收款，退房時依實際用藥結果結算。'), findsOneWidget);
    expect(find.textContaining('目前參考費率'), findsNothing);

    final advance = booking('pending_shop');
    (advance['medication'] as Map)['advanceAmount'] = 200;
    await show(advance);
    expect(find.textContaining('已列入預約應付'), findsOneWidget);
    expect(find.textContaining('尚未收款'), findsNothing);

    final historical = booking('pending_shop')
      ..remove('medication')
      ..['medicationRequest'] = {
        'preferences': [
          for (final (petId, type, times) in [
            ('p', 'oral', ['09:00', '11:00']),
            ('p2', 'eye', ['10:00', '14:30']),
          ])
            {
              'petId': petId,
              'types': [type],
              'dates': [
                {'date': '2026-11-10', 'times': times},
                {'date': '2026-11-11', 'times': times},
              ],
            },
        ],
      };
    await show(historical, reference: setting);
    expect(find.text('依現行費率預估 NT\$ 400'), findsOneWidget);
    expect(find.text('NT\$ 50 × 8 次'), findsOneWidget);
    expect(find.text('店家目前參考費率：每隻貓每次 NT\$ 50'), findsOneWidget);
    expect(find.textContaining('未保存下單時的費率'), findsOneWidget);
    expect(find.textContaining('退房時結算'), findsOneWidget);

    await show(historical, reference: {...setting, 'includedTimes': 1});
    expect(find.text('本單用藥費待確認'), findsOneWidget);
    expect(find.textContaining('依現行費率預估 NT'), findsNothing);

    final finalized = booking('confirmed');
    finalized['medication'] = {
      ...medMap(finalized['medication']),
      'finalized': true,
      'finalAmount': 150,
    };
    await show(finalized);
    expect(find.text('用藥結算 NT\$ 150'), findsOneWidget);
    expect(find.textContaining('尚未收款'), findsNothing);
  });

  testWidgets('failed saving preserves changes and never shows success', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MedicationSettingsPage(
          shopId: 's',
          loadSetting: () async => setting,
          saveSetting: (_) async => throw FirebaseFunctionsException(
            code: 'internal',
            message: 'internal',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final price = find.widgetWithText(TextFormField, '每隻貓／每次費用（元）');
    await tester.ensureVisible(price);
    await tester.enterText(price, '80');
    await tester.tap(find.text('儲存設定'));
    await tester.pumpAndSettle();
    expect(find.text('用藥協助設定已儲存'), findsNothing);
    expect(find.textContaining('這次操作未完成'), findsOneWidget);
    expect(find.text('有尚未儲存的變更'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
  });
}

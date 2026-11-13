import 'package:petnest_saas/features/medication/medication_widgets.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_action_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_customer_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_payment_aside.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_form_focus.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_header_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_order_workspace.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_experience.dart';
import 'package:petnest_saas/features/admin/widgets/booking_order_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_strip.dart';

const Key previewKey = ValueKey<String>('workspace-preview');
Map<String, dynamic> fixtureData() => <String, dynamic>{
  'bookingCode': 'SHOP0017-B000001',
  'bookingKind': 'accommodation',
  'status': 'pending',
  'customerName': '林小安',
  'customerPhone': '0912345678',
  'address': '新竹縣測試路 100 號',
  'roomTypeName': '陽光標準房',
  'startDate': Timestamp.fromDate(DateTime(2026, 11, 6)),
  'endDate': Timestamp.fromDate(DateTime(2026, 11, 8)),
  'nights': 2,
  'totalPrice': 1800,
  'totalAmount': 1800,
  'depositAmount': 1800,
  'payAmountType': 'full',
  'paymentMethod': 'cash',
  'assignStatus': 'unassigned',
};

Widget fixture({
  double textScale = 1,
  String status = 'pending',
  String preferenceScope = '',
}) {
  final Map<String, dynamic> data = fixtureData()..['status'] = status;
  final Map<String, dynamic> emergency = <String, dynamic>{
    'name': '林小晴',
    'phone': '0987654321',
    'relation': '家人',
  };
  Future<void> noop() async {}
  Widget actions(AdminBookingActionChrome chrome) => AdminBookingActionSection(
    data: data,
    status: status,
    depositAmount: 1800,
    depositPaid: false,
    chrome: chrome,
    compact: true,
    onAssignRoom: noop,
    onChangeRoom: noop,
    onConfirmBooking: noop,
    onConfirmDeposit: noop,
    onCancelBooking: noop,
    onCheckIn: noop,
    onCheckOut: noop,
  );
  return ShopFrontendThemeInherited(
    theme: ShopFrontendTheme.fallback,
    child: MaterialApp(
      theme: ThemeData(
        fontFamily: 'NotoSansTC',
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFF58A24),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: previewKey,
        child: AdminBookingDetailScaffold(
          title: '訂單詳細',
          operationsShopId: 'fixture-shop',
          bookingCode: 'SHOP0017-B000001',
          overview: AdminBookingHeaderCard(
            data: data,
            bookingId: 'fixture-1',
            dense: true,
          ),
          splitPhoneActions: true,
          actions: AdminBookingDetailCard(
            child: actions(AdminBookingActionChrome.full),
          ),
          phoneInlineActions: actions(AdminBookingActionChrome.phoneInline),
          phoneStickyActions: actions(AdminBookingActionChrome.phoneSticky),
          left: const <Widget>[],
          right: <Widget>[
            AdminBookingDetailPaymentAside(data: data, bookingId: 'fixture-1'),
          ],
          workspace: AdminBookingWorkspaceContent(
            preferenceScope: preferenceScope,
            balance: AdminBookingWorkspaceBalance(data: data),
            pets: const AdminBookingPetStrip(
              pets: <Map<String, dynamic>>[
                <String, dynamic>{
                  'name': '布丁',
                  'species': 'cat',
                  'gender': 'female',
                  'age': '3歲',
                  'medicalStatus': '慢性病',
                },
                <String, dynamic>{
                  'name': '麻糬',
                  'species': 'cat',
                  'gender': 'male',
                  'age': '2歲',
                },
              ],
            ),
            contacts: AdminBookingCustomerSection(
              data: data,
              emergency: emergency,
              compact: true,
            ),
            carePreview: BookingMedicationPanel(
              bookingId: 'fixture-1',
              staff: true,
              summaryOnly: true,
              booking: {
                ...data,
                'medication': {
                  'state': 'requested',
                  'request': {
                    'preferences': [
                      {
                        'petId': 'pet-1',
                        'type': 'oral',
                        'times': ['09:30', '12:00'],
                      },
                    ],
                  },
                },
              },
            ),
            summary: <Widget>[
              if (Platform.environment['PETNEST_PREVIEW_ONLY'] != '1')
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () => AdminBookingFormFocusScope.maybeOf(
                      context,
                    )!.requestFocus(AdminBookingFormAnchor.customerSubmit),
                    child: const Text('測試表單定位'),
                  ),
                ),
            ],
            care: const <Widget>[
              AdminBookingDetailSection(
                title: '每日照護摘要',
                child: AdminBookingDetailCard(child: Text('查看每日回報與待處理照護')),
              ),
              TextField(
                key: ValueKey<String>('care-draft'),
                decoration: InputDecoration(labelText: '照護草稿'),
              ),
            ],
            charges: const <Widget>[Text('服務費用明細測試內容')],
            details: <Widget>[
              AdminBookingCustomerSection(data: data, emergency: emergency),
            ],
            activity: const <Widget>[Text('操作紀錄測試內容')],
          ),
          forms: <Widget>[
            Builder(
              builder: (context) => Container(
                key: AdminBookingFormFocusScope.maybeOf(
                  context,
                )!.anchorKeys[AdminBookingFormAnchor.customerSubmit],
                child: const TextField(
                  key: ValueKey<String>('form-draft'),
                  decoration: InputDecoration(labelText: '表單草稿'),
                ),
              ),
            ),
          ],
          progress: const Text('完整訂單時間軸測試內容'),
          handover: const Text('店內交接測試內容'),
          communication: const <Widget>[Text('客戶留言測試內容')],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('住宿工作單依階段展開，收合後保留內容', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminBookingDetailExperience(
            scope: '',
            workflow: true,
            worksheetHeader: const Text('A03 · 栗子與麻糬'),
            worksheetPrimarySection: 1,
            sectionBuilder: (index, _, _) => index == 1
                ? const TextField(key: ValueKey('worksheet-draft'))
                : Text('section-$index'),
          ),
        ),
      ),
    );
    expect(find.text('A03 · 栗子與麻糬'), findsOneWidget);
    final draft = find.byKey(const ValueKey('worksheet-draft'));
    expect(draft, findsOneWidget);
    await tester.enterText(draft, '麻糬照護紀錄');
    await tester.tap(find.byKey(const ValueKey('booking-tab-1')));
    await tester.pumpAndSettle();
    expect(draft, findsNothing);
    await tester.tap(find.byKey(const ValueKey('booking-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('麻糬照護紀錄'), findsOneWidget);
  });

  testWidgets('窄版工作台一按開單，直接進照護且切頁保留輸入', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 650);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: BookingOrderCard(
              bookingId: 'fixture-1',
              data: fixtureData(),
              compact: true,
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: AdminBookingDetailExperience(
                      scope: '',
                      workflow: true,
                      initialSection: 1,
                      sectionBuilder: (index, _, _) => index == 1
                          ? const TextField(key: ValueKey('care-draft'))
                          : Text('section-$index'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('林小安'));
    await tester.pumpAndSettle();
    final draft = find.byKey(const ValueKey('care-draft'));
    expect(draft, findsOneWidget);
    await tester.enterText(draft, '照護草稿');
    await tester.tap(find.text('結帳'));
    await tester.pumpAndSettle();
    expect(find.text('section-2'), findsOneWidget);
    await tester.tap(find.text('照護'));
    await tester.pumpAndSettle();
    expect(find.text('照護草稿'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  setUpAll(() async {
    final FontLoader font = FontLoader('NotoSansTC');
    font.addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'));
    await font.load();
    final FontLoader icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('工作區在320到2560寬度無溢出，分類可直接切換', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final double width in <double>[
      320,
      390,
      600,
      768,
      1024,
      1440,
      1920,
      2560,
    ]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(fixture());
      await tester.pumpAndSettle();
      for (final int tab in <int>[0, 1, 2, 3, 4]) {
        await tester.tap(find.byKey(ValueKey<String>('booking-tab-$tab')));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'width=$width, tab=$tab',
        );
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey<String>('booking-tab-0')))
              .dy,
          lessThan(240),
        );
      }
      expect(find.text('完整訂單時間軸測試內容'), findsOneWidget);
      expect(find.text('店內交接測試內容'), findsOneWidget);
      expect(find.text('客戶留言測試內容'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('booking-tab-0')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('桌面總覽一屏可見聯絡資料，手機取消入口與主要操作分離', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(fixture());
    await tester.pumpAndSettle();
    expect(find.text('2 晚'), findsOneWidget);
    expect(find.text('2 晚晚'), findsNothing);
    expect(
      tester.getBottomRight(find.byType(AdminBookingCustomerSection)).dy,
      lessThan(900),
    );
    expect(find.text('疾病提醒'), findsOneWidget);
    expect(find.text('完整訂單時間軸測試內容', skipOffstage: false), findsNothing);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(OutlinedButton, '取消訂單').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('確認全額入帳'), findsOneWidget);
    expect(find.byTooltip('更多訂單操作'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首次只載入總覽，切頁保留草稿且表單定位會開啟資料', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(fixture());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('form-draft'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('care-draft'), skipOffstage: false),
      findsNothing,
    );
    expect(find.text('服務費用明細測試內容', skipOffstage: false), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('booking-tab-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('care-draft')),
      '保留照護草稿',
    );
    await tester.tap(find.byKey(const ValueKey<String>('booking-tab-0')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('測試表單定位'));
    await tester.tap(find.text('測試表單定位'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('form-draft')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('form-draft')),
      '保留表單草稿',
    );
    await tester.tap(find.byKey(const ValueKey<String>('booking-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('保留照護草稿'), findsOneWidget);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.text('保留照護草稿'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('booking-tab-3')));
    await tester.pumpAndSettle();
    expect(find.text('保留表單草稿'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手機寵物依內容高度排列，均可開啟完整資料', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(fixture());
    await tester.pumpAndSettle();
    final Finder cards = find.byType(AdminBookingPetCard);
    expect(cards, findsNWidgets(2));
    for (final Element element in cards.evaluate()) {
      expect(
        tester.getSize(find.byWidget(element.widget)).height,
        lessThan(150),
      );
    }
    await tester.ensureVisible(find.text('麻糬'));
    await tester.tap(find.text('麻糬'));
    await tester.pumpAndSettle();
    expect(find.text('寵物基本資料'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('大字體與低視窗仍能切頁及找到主要操作', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(fixture(textScale: 1.5));
    await tester.pumpAndSettle();
    for (final int tab in <int>[0, 1, 2, 3, 4]) {
      await tester.tap(find.byKey(ValueKey<String>('booking-tab-$tab')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'textScale=1.5 tab=$tab');
      expect(find.text('確認全額入帳'), findsOneWidget);
    }
  });

  testWidgets('輸出工作區視覺預覽（指定目錄時）', (tester) async {
    final String? directory = Platform.environment['PETNEST_PREVIEW_DIR'];
    if (directory == null) return;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final Size size in <Size>[Size(1440, 900), Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(fixture());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('booking-tab-0')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final RenderRepaintBoundary boundary = tester.renderObject(
          find.byKey(previewKey),
        );
        final ui.Image image = await boundary.toImage(pixelRatio: 1);
        final ByteData bytes = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!;
        final File file = File(
          '$directory/workspace-${size.width.toInt()}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}

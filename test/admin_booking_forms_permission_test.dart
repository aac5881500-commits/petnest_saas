// 檔案名稱：test/admin_booking_forms_permission_test.dart
// 功能說明：店家後台表單／客戶備註編輯權限、完整表單階層與寵物卡不再放照護入口。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_form_answers_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_form_summary_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_note_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_strip.dart';
import 'package:petnest_saas/features/custom_form/widgets/order_form_answers_view.dart';

Map<String, dynamic> _answer({required String label, required String value}) {
  return <String, dynamic>{
    'formId': 'f1',
    'formTitle': '表單',
    'answers': <Map<String, dynamic>>[
      <String, dynamic>{
        'questionId': 'q1',
        'questionLabel': label,
        'displayValue': value,
        'value': value,
      },
    ],
  };
}

Widget _wrap(Widget child, {Size size = const Size(1440, 1100)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: ShopFrontendThemeInherited(
      theme: ShopFrontendTheme.fallback,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  testWidgets('客戶送單表單與客戶備註沒有編輯按鈕', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        ListView(
          children: <Widget>[
            AdminBookingFormAnswersSection(
              shopId: 'shop-a',
              bookingId: 'b1',
              data: <String, dynamic>{
                'source': 'app',
                'customFormAnswers': _answer(label: '飲食', value: '早午餐'),
              },
            ),
            const AdminBookingNoteSection(
              data: <String, dynamic>{'note': '怕生'},
              shopId: 'shop-a',
              bookingId: 'b1',
            ),
          ],
        ),
        size: const Size(390, 800),
      ),
    );
    await tester.pump();
    expect(find.text('客戶送單表單'), findsOneWidget);
    expect(find.text('飲食'), findsWidgets);
    expect(find.text('編輯'), findsNothing);
    expect(find.text('怕生'), findsOneWidget);
  });

  testWidgets('手動訂單表單只有手動訂單顯示且可編輯', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        AdminBookingFormAnswersSection(
          shopId: 'shop-a',
          bookingId: 'b1',
          data: <String, dynamic>{
            'source': 'admin',
            'adminCustomFormAnswers': _answer(label: '交接', value: '已清點'),
            'customFormAnswers': _answer(label: '客戶題', value: '不該出現'),
          },
        ),
        size: const Size(390, 800),
      ),
    );
    await tester.pump();
    expect(find.text('手動訂單表單'), findsOneWidget);
    expect(find.text('編輯'), findsOneWidget);
    expect(find.text('客戶送單表單'), findsNothing);
    expect(find.text('不該出現'), findsNothing);
  });

  testWidgets('完整表單依訂單資訊與每隻寵物分層顯示', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        OrderFormAnswersView(
          orderRaw: _answer(label: '接送', value: '需要'),
          petAnswersByPetId: <String, dynamic>{
            'p1': <String, dynamic>{
              'petId': 'p1',
              'petName': '毛毛',
              'answers':
                  (_answer(label: '藥物', value: '早一顆')['answers'] as List),
            },
            'p2': <String, dynamic>{
              'petId': 'p2',
              'petName': '喵喵',
              'answers':
                  (_answer(label: '飲食', value: '濕食')['answers'] as List),
            },
          },
          pets: const <Map<String, dynamic>>[
            <String, dynamic>{'petId': 'p1', 'name': '毛毛'},
            <String, dynamic>{'petId': 'p2', 'name': '喵喵'},
          ],
          theme: HomeThemeModel.classicDefault,
        ),
        size: const Size(390, 800),
      ),
    );
    await tester.pump();
    expect(find.textContaining('訂單資訊'), findsWidgets);
    expect(find.textContaining('毛毛的照護資訊'), findsOneWidget);
    expect(find.textContaining('喵喵的照護資訊'), findsOneWidget);
    expect(find.text('寵物照護資料提醒'), findsNothing);
  });

  testWidgets('desktop 3/1 主副欄，mobile 維持三分頁；摘要可展開表單', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Map<String, dynamic> data = <String, dynamic>{
      'source': 'app',
      'customFormAnswers': _answer(label: '飲食', value: '早午餐'),
    };

    await tester.pumpWidget(
      ShopFrontendThemeInherited(
        theme: ShopFrontendTheme.fallback,
        child: MaterialApp(
          home: AdminBookingDetailScaffold(
            title: '訂單詳細',
            bookingCode: 'B1',
            overview: const Text('摘要'),
            actions: const AdminBookingDetailCard(child: Text('確認訂金')),
            left: const <Widget>[Text('顧客資訊')],
            progress: const AdminBookingDetailSection(
              title: '訂單進度',
              child: Text('完整時間軸'),
            ),
            right: const <Widget>[
              AdminBookingDetailCard(child: Text('付款摘要')),
              AdminBookingDetailCard(child: Text('條款')),
              AdminBookingDetailSection(
                title: '操作紀錄',
                child: Text('紀錄內容'),
              ),
            ],
            forms: <Widget>[
              AdminBookingFormAnswersSection(
                shopId: 'shop-a',
                bookingId: 'b1',
                data: data,
              ),
            ],
            formSummary: AdminBookingFormSummaryCard(
              shopId: 'shop-a',
              bookingId: 'b1',
              data: data,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('admin-booking-desktop-split')),
      findsOneWidget,
    );
    expect(find.byType(Scrollbar), findsNWidgets(2));
    expect(find.text('訂單資料'), findsNothing);
    expect(find.text('訂單進度'), findsOneWidget);
    expect(find.text('完整時間軸'), findsOneWidget);
    expect(find.text('顧客資訊'), findsOneWidget);
    expect(find.text('飲食'), findsWidgets);
    await tester.tap(find.text('客戶送單表單').first);
    await tester.pumpAndSettle();
    expect(find.text('客戶送單表單'), findsWidgets);
    expect(find.text('飲食'), findsWidgets);

    tester.view.physicalSize = const Size(390, 800);
    await tester.pumpWidget(
      ShopFrontendThemeInherited(
        theme: ShopFrontendTheme.fallback,
        child: MaterialApp(
          home: AdminBookingDetailScaffold(
            title: '訂單詳細',
            bookingCode: 'B1',
            overview: const Text('摘要'),
            left: const <Widget>[Text('顧客資訊')],
            right: const <Widget>[Text('付款')],
            forms: const <Widget>[Text('表單內容')],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('訂單資料'), findsOneWidget);
    expect(find.text('表單資料'), findsOneWidget);
    expect(find.text('交接與溝通'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('admin-booking-desktop-split')),
      findsNothing,
    );
  });

  testWidgets('手機表單資料分頁顯示訂單表單，不再出現寵物照護卡', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Map<String, dynamic> data = <String, dynamic>{
      'source': 'app',
      'pets': <Map<String, dynamic>>[
        <String, dynamic>{'petId': 'p1', 'name': '咪'},
      ],
      'customFormAnswers': _answer(label: '飲食', value: '早午餐'),
      'petFormAnswersByPetId': <String, dynamic>{
        'p1': <String, dynamic>{
          'petId': 'p1',
          'petName': '咪',
          'answers': (_answer(label: '藥物', value: '早一顆')['answers'] as List),
        },
      },
    };

    await tester.pumpWidget(
      ShopFrontendThemeInherited(
        theme: ShopFrontendTheme.fallback,
        child: MaterialApp(
          home: AdminBookingDetailScaffold(
            title: '訂單詳細',
            bookingCode: 'B1',
            overview: const Text('摘要'),
            left: const <Widget>[Text('顧客資訊')],
            right: const <Widget>[Text('付款')],
            forms: <Widget>[
              AdminBookingFormAnswersSection(
                shopId: 'shop-a',
                bookingId: 'b1',
                data: data,
              ),
            ],
            formSummary: AdminBookingFormSummaryCard(
              shopId: 'shop-a',
              bookingId: 'b1',
              data: data,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('表單資料'));
    await tester.pumpAndSettle();
    expect(find.text('寵物照護資料'), findsNothing);
    expect(find.textContaining('訂單資訊'), findsWidgets);
    expect(find.textContaining('咪的照護資訊'), findsOneWidget);
    expect(find.text('客戶送單表單'), findsOneWidget);
    expect(find.text('飲食'), findsWidgets);
  });

  testWidgets('表單資料摘要不含無法展開的寵物照護資料列', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        const AdminBookingFormSummaryCard(
          shopId: 'shop-a',
          bookingId: 'b1',
          data: <String, dynamic>{
            'source': 'app',
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('表單資料摘要'), findsOneWidget);
    expect(find.text('查看完整表單'), findsOneWidget);
    expect(find.text('寵物照護資料'), findsNothing);
    expect(find.text('客戶送單表單'), findsOneWidget);
    expect(find.text('手動訂單表單'), findsOneWidget);
  });

  testWidgets('寵物資訊下方不再顯示照護提醒與查看入口', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        AdminBookingPetStrip(
          pets: const <Map<String, dynamic>>[
            <String, dynamic>{'petId': 'p1', 'name': '測試'},
            <String, dynamic>{'petId': 'p2', 'name': '喵喵'},
            <String, dynamic>{'petId': 'p3', 'name': '無表單'},
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('⚠ 寵物照護資料提醒'), findsNothing);
    expect(find.textContaining('查看照護表單'), findsNothing);
    expect(find.textContaining('點擊查看'), findsNothing);
    expect(find.text('測試'), findsWidgets);
    expect(find.text('喵喵'), findsWidgets);
  });
}

// 檔案名稱：test/admin_booking_forms_permission_test.dart
// 功能說明：店家後台表單／客戶備註編輯權限、寵物照護卡與桌機摘要展開。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/booking_pet_care_form_loader.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_form_answers_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_form_summary_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_note_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_care_forms.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_care_scope.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_strip.dart';

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

  testWidgets('訂單詳細頁依每隻寵物顯示已填照護表單卡', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        AdminBookingPetCareForms(
          shopId: 'shop-a',
          userId: '',
          pets: <Map<String, dynamic>>[
            <String, dynamic>{
              'petId': 'p1',
              'name': '咪',
              'customFormAnswersByShop': <String, dynamic>{
                'shop-a': _answer(label: '個性', value: '黏人'),
              },
            },
            <String, dynamic>{
              'petId': 'p2',
              'name': '球',
              'customFormAnswersByShop': <String, dynamic>{
                'shop-a': _answer(label: '飲食', value: '濕食'),
              },
            },
            <String, dynamic>{
              'petId': 'p3',
              'name': '空空',
            },
          ],
        ),
        size: const Size(390, 800),
      ),
    );
    await tester.pump();
    expect(find.text('寵物照護資料'), findsOneWidget);
    expect(find.text('咪'), findsWidgets);
    expect(find.text('球'), findsWidgets);
    expect(find.text('空空'), findsNothing);
    expect(find.text('已填 1 題'), findsNWidgets(2));
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
    expect(find.byKey(const ValueKey<String>('admin-booking-desktop-split')), findsOneWidget);
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
    expect(find.byKey(const ValueKey<String>('admin-booking-desktop-split')), findsNothing);
  });

  testWidgets('手機表單資料分頁顯示寵物照護卡，摘要用同一批資料計數', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final List<BookingPetCareFormItem> items = <BookingPetCareFormItem>[
      BookingPetCareFormItem(
        petId: 'p1',
        name: '咪',
        photoUrl: '',
        raw: _answer(label: '個性', value: '黏人'),
        filledCount: 1,
      ),
    ];
    final Map<String, dynamic> data = <String, dynamic>{
      'source': 'app',
      'pets': <Map<String, dynamic>>[
        <String, dynamic>{'petId': 'p1', 'name': '咪'},
      ],
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
            left: const <Widget>[Text('顧客資訊')],
            right: const <Widget>[Text('付款')],
            petCareFuture: Future<List<BookingPetCareFormItem>>.value(items),
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
    expect(find.text('寵物照護資料'), findsOneWidget);
    expect(find.text('已填 1 題'), findsWidgets);
    expect(find.text('客戶送單表單'), findsOneWidget);
    expect(find.text('飲食'), findsWidgets);
  });

  testWidgets('表單摘要在已載入時顯示幾隻已填，不把讀取中當成無', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        AdminBookingPetCareScope(
          items: <BookingPetCareFormItem>[
            BookingPetCareFormItem(
              petId: 'p1',
              name: '咪',
              photoUrl: '',
              raw: _answer(label: '個性', value: '黏人'),
              filledCount: 1,
            ),
          ],
          loading: false,
          child: const AdminBookingPetCareFormsSummary(
            shopId: 'shop-a',
            userId: 'u1',
            pets: <Map<String, dynamic>>[
              <String, dynamic>{'petId': 'p1', 'name': '咪'},
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('1 隻已填'), findsOneWidget);
    expect(find.text('無'), findsNothing);
  });

  testWidgets('寵物資訊下方顯示照護提醒卡與查看入口', (WidgetTester tester) async {
    final List<BookingPetCareFormItem> items = <BookingPetCareFormItem>[
      BookingPetCareFormItem(
        petId: 'p1',
        name: '測試',
        photoUrl: '',
        raw: _answer(label: '飲食', value: '早午餐'),
        filledCount: 9,
      ),
      BookingPetCareFormItem(
        petId: 'p2',
        name: '喵喵',
        photoUrl: '',
        raw: _answer(label: '個性', value: '黏人'),
        filledCount: 6,
      ),
    ];
    await tester.pumpWidget(
      _wrap(
        AdminBookingPetCareScope(
          items: items,
          loading: false,
          child: AdminBookingPetStrip(
            pets: const <Map<String, dynamic>>[
              <String, dynamic>{'petId': 'p1', 'name': '測試'},
              <String, dynamic>{'petId': 'p2', 'name': '喵喵'},
              <String, dynamic>{'petId': 'p3', 'name': '無表單'},
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('⚠ 寵物照護資料提醒'), findsOneWidget);
    expect(find.text('本訂單有 2 隻寵物已填寫照護資料，請於照護前查看。'), findsOneWidget);
    expect(find.text('測試：已填 9 題'), findsOneWidget);
    expect(find.text('喵喵：已填 6 題'), findsOneWidget);
    expect(find.text('查看照護表單（已填 9 題） ›'), findsOneWidget);
    expect(find.text('查看照護表單（已填 6 題） ›'), findsOneWidget);
    expect(find.textContaining('查看照護表單（已填'), findsNWidgets(2));
  });

  testWidgets('桌機寵物資訊也顯示照護提醒卡', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        AdminBookingDetailScope(
          mode: AdminBookingDetailMode.desktop,
          width: 1440,
          child: AdminBookingPetCareScope(
            items: <BookingPetCareFormItem>[
              BookingPetCareFormItem(
                petId: 'p1',
                name: '測試',
                photoUrl: '',
                raw: _answer(label: '飲食', value: '早午餐'),
                filledCount: 9,
              ),
            ],
            loading: false,
            child: const AdminBookingPetStrip(
              pets: <Map<String, dynamic>>[
                <String, dynamic>{'petId': 'p1', 'name': '測試'},
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('⚠ 寵物照護資料提醒'), findsOneWidget);
    expect(find.text('查看照護表單（已填 9 題） ›'), findsOneWidget);
  });

  testWidgets('沒有照護表單時不顯示提醒卡', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        const AdminBookingPetCareScope(
          items: <BookingPetCareFormItem>[],
          loading: false,
          child: AdminBookingPetStrip(
            pets: <Map<String, dynamic>>[
              <String, dynamic>{'petId': 'p1', 'name': '測試'},
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('⚠ 寵物照護資料提醒'), findsNothing);
    expect(find.textContaining('查看照護表單'), findsNothing);
  });
}

// 檔案名稱：test/custom_form_front_flow_test.dart
// 功能說明：新增寵物／送出訂單自訂表單前台顯示、必填驗證、答案快照與舊資料相容測試

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/pet_shop_form_answers.dart';
import 'package:petnest_saas/features/booking/models/booking_form_submit_data.dart';
import 'package:petnest_saas/features/booking/pages/booking_form_page.dart';
import 'package:petnest_saas/features/custom_form/widgets/custom_form_answer_view.dart';
import 'package:petnest_saas/features/pet/pages/add_pet_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';

CustomFormModel _form({
  required CustomFormType type,
  bool enabled = true,
  List<CustomFormQuestion>? questions,
}) {
  return CustomFormModel(
    id: type.storageId,
    shopId: 'shop-a',
    formType: type,
    title: type.defaultTitle,
    enabled: enabled,
    version: 4,
    sections: <CustomFormSection>[
      CustomFormSection(
        id: 'sec-care',
        title: '照護',
        sortOrder: 0,
        questions:
            questions ??
            <CustomFormQuestion>[
              const CustomFormQuestion(
                id: 'q_food',
                label: '飲食習慣',
                required: true,
                type: CustomFormQuestionType.shortText,
              ),
              CustomFormQuestion(
                id: 'q_trait',
                label: '個性',
                required: true,
                type: CustomFormQuestionType.multipleChoice,
                options: const <CustomFormOption>[
                  CustomFormOption(id: 'kind', label: '親人'),
                  CustomFormOption(id: 'shy', label: '怕生'),
                ],
              ),
              const CustomFormQuestion(
                id: 'q_med',
                label: '是否吃藥',
                required: true,
                type: CustomFormQuestionType.yesNo,
              ),
            ],
      ),
    ],
  );
}

Future<void> _pumpBooking(
  WidgetTester tester, {
  CustomFormModel? seed,
  required Future<void> Function(BookingFormSubmitData data) onSubmit,
  String submitLabel = '送出預約',
  String service = '住宿',
}) async {
  tester.view.physicalSize = const Size(390, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final TextEditingController name = TextEditingController(text: '王小明');
  final TextEditingController phone = TextEditingController(text: '0911111111');
  final TextEditingController note = TextEditingController();
  addTearDown(name.dispose);
  addTearDown(phone.dispose);
  addTearDown(note.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: BookingFormPage(
        shopId: 'shop-a',
        skipRemoteLoads: true,
        seedCustomForm: seed,
        paymentTestState: BookingFormPaymentTestState.ready,
        seedMemberData: const <String, dynamic>{
          'name': '王小明',
          'phone': '0911111111',
          'address': '台北市大安區仁愛路一段1號',
          'emergencyContact': <String, dynamic>{
            'name': '王媽媽',
            'phone': '0987654321',
            'relation': '父母',
            'address': '台北市大安區仁愛路一段1號',
          },
        },
        onSubmitWithData: onSubmit,
        addons: const <Map<String, dynamic>>[],
        formKey: GlobalKey<FormState>(),
        customerNameController: name,
        customerPhoneController: phone,
        noteController: note,
        serviceTypes: <String>[service],
        selectedServiceType: service,
        onServiceChanged: (_) {},
        onSubmit: () {},
        isSubmitting: false,
        canSubmit: true,
        isBlacklisted: false,
        totalPrice: 1000,
        roomPrice: 1000,
        submitLabel: submitLabel,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('表單關閉時不收集答案', () {
    final CustomFormModel form = _form(
      type: CustomFormType.petProfile,
      enabled: false,
    );
    expect(form.shouldCollectAnswers, isFalse);
  });

  test('必填未填不能通過驗證', () {
    final CustomFormModel form = _form(type: CustomFormType.petProfile);
    final CustomFormValidationResult result = CustomFormAnswerSnapshot.validate(
      form: form,
      answersByQuestionId: const <String, dynamic>{},
    );
    expect(result.isValid, isFalse);
  });

  test('填完可產生答案快照，多選為 List、yesNo 為 bool，並保存題目文字', () {
    final CustomFormModel form = _form(type: CustomFormType.petProfile);
    final CustomFormAnswerSnapshot snapshot = CustomFormAnswerSnapshot.build(
      form: form,
      answersByQuestionId: <String, dynamic>{
        'q_food': '早午晚',
        'q_trait': <String>['kind', 'shy'],
        'q_med': true,
      },
    );
    expect(snapshot.formVersion, 4);
    expect(snapshot.formTitle, '新增寵物表單');
    expect(snapshot.answers.first.questionLabel, '飲食習慣');
    expect(snapshot.answers[1].value, isA<List<String>>());
    expect(snapshot.answers[2].value, isTrue);
    expect(snapshot.answers[1].displayValue, contains('親人'));
  });

  test('不同 shopId 的寵物答案路徑互相獨立', () {
    expect(
      PetShopFormAnswers.path(userId: 'u1', petId: 'p1', shopId: 'shop-a') ==
          PetShopFormAnswers.path(userId: 'u1', petId: 'p1', shopId: 'shop-b'),
      isFalse,
    );
    final Map<String, dynamic>? onlyA = PetShopFormAnswers.resolve(
      shopId: 'shop-a',
      petData: <String, dynamic>{
        'customFormAnswersByShop': <String, dynamic>{
          'shop-a': <String, dynamic>{'formId': 'a'},
          'shop-b': <String, dynamic>{'formId': 'b'},
        },
      },
    );
    expect(onlyA?['formId'], 'a');
  });

  testWidgets('表單關閉時新增寵物不顯示自訂欄位', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AddPetPage(shopId: 'shop-a', skipRemoteLoads: true),
      ),
    );
    await tester.pump();
    expect(find.text('飲食習慣'), findsNothing);
    expect(find.text('新增寵物'), findsWidgets);
  });

  testWidgets('表單開啟時新增寵物顯示題目', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AddPetPage(
          shopId: 'shop-a',
          skipRemoteLoads: true,
          seedCustomForm: _form(type: CustomFormType.petProfile),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('飲食習慣'), findsOneWidget);
  });

  testWidgets('必填題未填不能新增寵物', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AddPetPage(
          shopId: 'shop-a',
          skipRemoteLoads: true,
          seedCustomForm: _form(type: CustomFormType.petProfile),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '新增寵物'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('請完成必填'), findsWidgets);
  });

  testWidgets('送出訂單表單關閉時維持原送單流程', (WidgetTester tester) async {
    BookingFormSubmitData? captured;
    await _pumpBooking(
      tester,
      onSubmit: (BookingFormSubmitData data) async {
        captured = data;
      },
    );
    expect(find.text('飲食習慣'), findsNothing);
    await tester.ensureVisible(find.text('銀行轉帳'));
    await tester.tap(find.text('銀行轉帳'));
    await tester.pump();
    await tester.ensureVisible(find.text('送出預約').last);
    await tester.tap(find.text('送出預約').last);
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.customFormAnswers, isNull);
  });

  testWidgets('表單開啟時住宿顯示題目', (WidgetTester tester) async {
    await _pumpBooking(
      tester,
      seed: _form(type: CustomFormType.bookingSubmit),
      onSubmit: (_) async {},
    );
    expect(find.text('送出訂單表單'), findsOneWidget);
    expect(find.text('飲食習慣 *'), findsOneWidget);
  });

  testWidgets('表單開啟時安親顯示題目', (WidgetTester tester) async {
    await _pumpBooking(
      tester,
      seed: _form(type: CustomFormType.bookingSubmit),
      submitLabel: '確認訂單',
      service: 'daycare',
      onSubmit: (_) async {},
    );
    expect(find.text('飲食習慣 *'), findsOneWidget);
  });

  testWidgets('必填未填時 onSubmitWithData 不可被呼叫', (WidgetTester tester) async {
    bool called = false;
    await _pumpBooking(
      tester,
      seed: _form(type: CustomFormType.bookingSubmit),
      onSubmit: (_) async {
        called = true;
      },
    );
    await tester.ensureVisible(find.text('銀行轉帳'));
    await tester.tap(find.text('銀行轉帳'));
    await tester.pump();
    await tester.ensureVisible(find.text('送出預約').last);
    await tester.tap(find.text('送出預約').last);
    await tester.pump();
    expect(called, isFalse);
    expect(find.text('請完成送出訂單表單'), findsWidgets);
  });

  testWidgets('BookingFormPage 仍只有最下面一顆送出按鈕', (WidgetTester tester) async {
    await _pumpBooking(
      tester,
      seed: _form(type: CustomFormType.bookingSubmit),
      onSubmit: (_) async {},
    );
    expect(find.byType(BookingPrimaryButton), findsOneWidget);
  });

  testWidgets('重複按送出只呼叫一次 onSubmitWithData', (WidgetTester tester) async {
    int calls = 0;
    await _pumpBooking(
      tester,
      onSubmit: (BookingFormSubmitData data) async {
        calls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
    );
    await tester.ensureVisible(find.text('銀行轉帳'));
    await tester.tap(find.text('銀行轉帳'));
    await tester.pump();
    await tester.ensureVisible(find.text('送出預約').last);
    await tester.tap(find.text('送出預約').last);
    await tester.tap(find.text('送出預約').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(calls, 1);
  });

  testWidgets('手機窄畫面不 overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AddPetPage(
          shopId: 'shop-a',
          skipRemoteLoads: true,
          seedCustomForm: _form(type: CustomFormType.petProfile),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('舊訂單沒有 customFormAnswers 仍正常顯示', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomFormAnswerView(
            raw: null,
            title: '本次照護交代',
            theme: HomeThemeModel.classicDefault,
          ),
        ),
      ),
    );
    expect(find.text('本次照護交代'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('舊格式 bookingFormAnswers／formAnswers 仍可讀取', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomFormAnswerView(
            raw: <String, dynamic>{
              'formTitle': '舊表單',
              'answers': <Map<String, dynamic>>[
                <String, dynamic>{
                  'sectionTitle': '照護',
                  'questionLabel': '飲食',
                  'displayValue': '早午晚',
                  'questionType': 'shortText',
                },
              ],
            },
            title: '本次照護交代',
            theme: HomeThemeModel.classicDefault,
          ),
        ),
      ),
    );
    expect(find.textContaining('本次照護交代'), findsOneWidget);
    expect(find.text('飲食'), findsOneWidget);
    expect(find.text('早午晚'), findsOneWidget);
  });
}

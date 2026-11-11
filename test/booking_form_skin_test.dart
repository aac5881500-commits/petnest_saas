import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/booking/pages/booking_form_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';

Map<String, dynamic> get seed => {
  'name': '王小明',
  'phone': '0912345678',
  'address': '台北市大安區仁愛路一段1號',
  'emergencyContact': {
    'name': '王媽媽',
    'phone': '0987654321',
    'relation': '父母',
    'address': '台北市大安區仁愛路一段1號',
    'phone2': '',
  },
};
Widget form(
  WidgetTester tester,
  String style, {
  double scale = 1,
  BookingFormPaymentTestState payment = BookingFormPaymentTestState.ready,
  bool frontend = false,
  GlobalKey? boundary,
}) {
  final name = TextEditingController(),
      phone = TextEditingController(),
      note = TextEditingController();
  addTearDown(name.dispose);
  addTearDown(phone.dispose);
  addTearDown(note.dispose);
  final child = BookingFormPage(
    shopId: 'test',
    shopName: '喵屋貓咪旅館',
    appearance: BookingPageAppearance(
      style: style,
      serviceStyle: style,
      suiteColorMode: frontend ? 'frontend' : 'template',
      looks: frontend
          ? {style: const BookingPageLook(font: 'NotoSansTC', fontWeight: 700)}
          : const {},
    ),
    frontendTheme: HomeThemeModel.modernDefault.copyWith(
      primaryColorValue: 0xFF6554A5,
      textColorValue: 0xFF493853,
    ),
    skipRemoteLoads: true,
    seedMemberData: seed,
    paymentTestState: payment,
    onSubmitWithData: (_) async {},
    addons: const [],
    formKey: GlobalKey<FormState>(),
    customerNameController: name,
    customerPhoneController: phone,
    noteController: note,
    serviceTypes: const ['住宿'],
    selectedServiceType: '住宿',
    onServiceChanged: (_) {},
    onSubmit: () {},
    isSubmitting: false,
    canSubmit: true,
    isBlacklisted: false,
    totalPrice: 1300,
    roomPrice: 1200,
  );
  return MaterialApp(
    key: UniqueKey(),
    home: MediaQuery(
      data: MediaQueryData(
        size: scale == 2 ? const Size(320, 740) : const Size(390, 844),
        textScaler: TextScaler.linear(scale),
      ),
      child: boundary == null
          ? child
          : RepaintBoundary(key: boundary, child: child),
    ),
  );
}

void main() {
  for (final style in ['cream', 'editorial']) {
    testWidgets(
      '$style keeps form data and payment guards while using the suite',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(form(tester, style));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('booking-form-intro')),
          findsOneWidget,
        );
        expect(find.text('喵屋貓咪旅館'), findsOneWidget);
        expect(find.text('王小明'), findsOneWidget);
        await tester.tap(find.text('送出預約'));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsOneWidget);
        final cash = find.text('到店付款');
        await tester.ensureVisible(cash);
        await tester.tap(cash);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BookingPrimaryButton>(find.byType(BookingPrimaryButton))
              .enabled,
          isTrue,
        );
        expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('$style follows frontend colors and typography', (
      tester,
    ) async {
      await tester.pumpWidget(form(tester, style, frontend: true));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(
        (field.decoration!.focusedBorder as OutlineInputBorder)
            .borderSide
            .color,
        const Color(0xFF6554A5),
      );
      expect(
        Theme.of(
          tester.element(find.byType(TextFormField).first),
        ).textTheme.bodyLarge!.fontFamily,
        'NotoSansTC',
      );
      expect(
        Theme.of(
          tester.element(find.byType(TextFormField).first),
        ).textTheme.bodyLarge!.fontWeight,
        FontWeight.w700,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      '$style remains usable at 320px and 200 percent text when payments fail',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          form(
            tester,
            style,
            scale: 2,
            payment: BookingFormPaymentTestState.error,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('付款方式載入失敗'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('booking-form-section-緊急聯絡人')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('render both styled booking forms', (tester) async {
    final output = Platform.environment['BOOKING_FORM_SKIN_OUTPUT'];
    if (output == null) return;
    await tester.runAsync(() async {
      for (final e in {
        'jfOpenHuninn': 'assets/fonts/jf-openhuninn-2.1.ttf',
        'NotoSerifTC': 'assets/fonts/NotoSerifTC-VariableFont_wght.ttf',
        'NotoSansTC': 'assets/fonts/NotoSansTC-VariableFont_wght.ttf',
        'MaterialIcons':
            'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final loader = FontLoader(e.key)
          ..addFont(
            Future.value(
              ByteData.sublistView(await File(e.value).readAsBytes()),
            ),
          );
        await loader.load();
      }
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final style in ['cream', 'editorial']) {
      final key = GlobalKey();
      await tester.pumpWidget(form(tester, style, boundary: key));
      await tester.pumpAndSettle();
      for (final lower in [false, true]) {
        if (lower) {
          final scroll = tester
              .widget<SingleChildScrollView>(
                find.byType(SingleChildScrollView).first,
              )
              .controller!;
          scroll.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final img =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$output/$style-${lower ? 'lower' : 'top'}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          img.dispose();
        });
      }
    }
  });
}

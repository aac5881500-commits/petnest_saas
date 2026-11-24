import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/widgets/booking_care_activity.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_summary_card.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_customer_pet_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';
import 'booking_care_flow_test.dart' as fixture;

void main() {
  for (final width in [320.0, 430.0, 1200.0]) {
    testWidgets('milk tea customer cards preserve information at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await (FontLoader(
        'MilkPreview',
      )..addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('NotoSansTC')..addFont(
            rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
          ))
          .load();
      await (FontLoader('NotoSerifTC')..addFont(
            rootBundle.load('assets/fonts/NotoSerifTC-VariableFont_wght.ttf'),
          ))
          .load();
      final data = fixture.booking()
        ..addAll({
          'endDate': '2026-11-14',
          'customerName': '測試飼主',
          'customerPhone': '0900000000',
          'emergencyContact': {'name': '緊急聯絡人測試', 'phone': '0911111111'},
        });
      final view = BookingDetailViewData.fromBooking(data: data, docId: 'b');
      final palette = BookingDetailUi.milkTea(ShopFrontendTheme.fallback);
      for (final page in ['summary', 'guests', 'care']) {
        final content = switch (page) {
          'summary' => BookingDetailSummaryCard(
            view: view,
            onCancel: () {},
            onContactShop: () {},
            onOpenCare: () {},
          ),
          'guests' => BookingDetailCustomerPetSection(
            data: data,
            view: view,
            showFullDetails: true,
          ),
          _ => BookingCareActivity(bookingId: 'b', booking: data),
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              fontFamily: 'MilkPreview',
              colorScheme: ColorScheme.fromSeed(
                seedColor: palette.primary,
                surface: palette.card,
                onSurface: palette.text,
              ),
            ),
            home: BookingDetailMilkTeaScope(
              child: Scaffold(
                backgroundColor: palette.background,
                body: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 1400),
                    textScaler: TextScaler.linear(1.2),
                  ),
                  child: SingleChildScrollView(
                    child: RepaintBoundary(
                      key: ValueKey('preview-$page'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$page at $width');
        if (page == 'guests') {
          expect(find.text('小布'), findsOneWidget);
          expect(find.text('奶茶'), findsOneWidget);
          expect(find.text('飼主資料'), findsOneWidget);
          expect(find.text('緊急聯絡人'), findsWidgets);
        }
        if (page == 'care') {
          expect(find.text('口服藥'), findsOneWidget);
          expect(find.text('小布 · 口服藥'), findsNothing);
          expect(find.text('專屬陪玩'), findsNWidgets(2));
        }
        if (const bool.fromEnvironment('MILK_PREVIEW') && width == 430) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(ValueKey('preview-$page')),
            );
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('build/milk-tea-$page.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}

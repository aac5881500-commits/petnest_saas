import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/admin/widgets/booking_status_filter.dart';
import 'package:petnest_saas/features/admin/widgets/booking_order_card.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Preview')
      ..addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('分組篩選與訂單入口在窄螢幕及放大文字仍可操作', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    const previewKey = ValueKey('list-preview');
    for (final width in [320.0, 390.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1200);
      String selected = 'active';
      bool opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'Preview',
            colorSchemeSeed: const Color(0xFF526197),
            scaffoldBackgroundColor: const Color(0xFFF5F6FA),
          ),
          builder: (context, child) =>
              RepaintBoundary(key: previewKey, child: child!),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1200),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    BookingStatusFilter(
                      grouped: true,
                      selectedType: selected,
                      counts: const {
                        'pending': 1,
                        'active': 1,
                        'todayCheckIn': 1,
                        'settled': 2,
                        'cancelled': 1,
                      },
                      items: BookingStatusFilter.stayItems,
                      onChanged: (value) => selected = value,
                    ),
                    BookingOrderCard(
                      bookingId: 'test-123',
                      data: {
                        'customerName': '測試顧客',
                        'roomTypeName': '陽光標準房',
                        'bookingCode': 'SHOP0017-B000004',
                        'customerPhone': '0912345678',
                        'startDate': DateTime(2026, 11, 8),
                        'endDate': DateTime(2026, 11, 12),
                        'nights': 4,
                        'assignStatus': 'unassigned',
                        'pets': [
                          {'name': '布丁'},
                          {'name': '麻糬'},
                        ],
                      },
                      onTap: () => opened = true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final output = Platform.environment['PETNEST_LIST_PREVIEW'];
      if (output != null) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(previewKey),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File(
            '$output/list-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('今日入住'));
      expect(selected, 'todayCheckIn');
      await tester.ensureVisible(find.text('開啟訂單'));
      await tester.tap(find.text('開啟訂單'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    }
  });
}

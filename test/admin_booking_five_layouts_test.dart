import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_experience.dart';
import 'admin_booking_order_workspace_test.dart' as fixture;

Future<void> choose(WidgetTester tester, BookingDetailExperience mode) async {
  await tester.tap(find.byKey(const ValueKey('booking-layout-settings')));
  await tester.pumpAndSettle();
  final target = find.byKey(ValueKey('choose-experience-${mode.name}'));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

AdminBookingDetailExperienceState shell(WidgetTester tester) =>
    tester.state(find.byType(AdminBookingDetailExperience));
Future<void> open(WidgetTester tester, int section) async {
  shell(tester).select(section);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final font = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('五套完整介面保留每個分類資料且支援各尺寸', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(
        fixture.fixture(textScale: width == 320 ? 1.3 : 1),
      );
      await tester.pumpAndSettle();
      for (final mode in BookingDetailExperience.values) {
        await choose(tester, mode);
        expect(shell(tester).experience, mode);
        for (var i = 0; i < 5; i++) {
          await open(tester, i);
          expect(
            find.byKey(ValueKey('detail-section-$i')),
            findsOneWidget,
            reason: '$width $mode section$i',
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$width $mode section$i',
          );
        }
        await open(tester, 0);
        expect(find.text('疾病提醒'), findsOneWidget);
        expect(find.text('0912345678'), findsWidgets);
        await open(tester, 2);
        expect(find.text('服務費用明細測試內容'), findsOneWidget);
        await open(tester, 3);
        expect(find.byKey(const ValueKey('form-draft')), findsOneWidget);
        await open(tester, 4);
        expect(find.text('完整訂單時間軸測試內容'), findsOneWidget);
        expect(find.text('店內交接測試內容'), findsOneWidget);
        expect(find.text('客戶留言測試內容'), findsOneWidget);
      }
    }
  });
  testWidgets('分頁數、主從返回與階段展開確實不同', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(fixture.fixture());
    await tester.pumpAndSettle();
    await choose(tester, BookingDetailExperience.single);
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('detail-section-$i')), findsOneWidget);
    }
    await choose(tester, BookingDetailExperience.dual);
    expect(find.byKey(const ValueKey('detail-group-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-group-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-section-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-section-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('detail-group-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-section-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-section-4')), findsOneWidget);
    await choose(tester, BookingDetailExperience.master);
    expect(find.byKey(const ValueKey('master-item-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-section-2')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('master-item-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-section-2')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('master-back')));
    await tester.tap(find.byKey(const ValueKey('master-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('master-item-2')), findsOneWidget);
    await choose(tester, BookingDetailExperience.stages);
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('stage-$i')), findsOneWidget);
    }
    await open(tester, 1);
    await tester.ensureVisible(find.byKey(const ValueKey('stage-1')));
    await tester.tap(find.byKey(const ValueKey('stage-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-section-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('stage-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-section-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('整套切換及跨尺寸保留全部編輯草稿與帳號偏好', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(fixture.fixture(preferenceScope: 'shopA:userA'));
    await tester.pumpAndSettle();
    await open(tester, 1);
    await tester.enterText(find.byKey(const ValueKey('care-draft')), '照護草稿保留');
    await open(tester, 3);
    await tester.enterText(find.byKey(const ValueKey('form-draft')), '表單草稿保留');
    for (final mode in BookingDetailExperience.values) {
      await choose(tester, mode);
      for (final width in [1440.0, 390.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpAndSettle();
        await open(tester, 1);
        expect(find.text('照護草稿保留'), findsOneWidget);
        await open(tester, 3);
        expect(find.text('表單草稿保留'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('booking.detail.experience.v2.shopA:userA'),
      'stages',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(fixture.fixture(preferenceScope: 'shopA:userA'));
    await tester.pumpAndSettle();
    expect(shell(tester).experience, BookingDetailExperience.stages);
    await prefs.setString(
      'booking.detail.experience.v2.shopA:userB',
      'dossier',
    );
    await tester.pumpWidget(fixture.fixture(preferenceScope: 'shopA:userB'));
    await tester.pumpAndSettle();
    expect(shell(tester).experience, BookingDetailExperience.tabs);
    await tester.tap(find.byKey(const ValueKey('booking-layout-settings')));
    await tester.pumpAndSettle();
    expect(find.text('預設 · 總覽、照護、帳務、資料、紀錄'), findsOneWidget);
    expect(find.text('新增版型'), findsNothing);
    expect(find.byKey(const ValueKey('choose-experience-board')), findsNothing);
    expect(find.byKey(const ValueKey('choose-experience-desk')), findsNothing);
    expect(
      find.byKey(const ValueKey('choose-experience-dossier')),
      findsNothing,
    );
  });
  testWidgets('輸出整套介面預覽', (tester) async {
    final output = Platform.environment['PETNEST_EXPERIENCE_PREVIEW'];
    if (output == null) return;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [1440.0, 390.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(fixture.fixture());
      await tester.pumpAndSettle();
      for (final mode in BookingDetailExperience.values) {
        await open(tester, 0);
        await choose(tester, mode);
        for (final section in [0, 2]) {
          if (section != 0) await open(tester, section);
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(fixture.previewKey),
            );
            final image = await boundary.toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await Directory(output).create(recursive: true);
            await File(
              '$output/${mode.name}-$section-${width.toInt()}.png',
            ).writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    }
  });
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_task_item.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_panel.dart';
import 'package:petnest_saas/core/widgets/daily_care_medication_summary.dart';
import 'package:petnest_saas/features/medication/medication_widgets.dart';

void main() {
  final booking = <String, dynamic>{
    'status': 'checked_in',
    'pets': [
      {'petId': 'p1', 'name': '小布'},
    ],
    'medication': {
      'state': 'confirmed',
      'revision': 1,
      'request': {
        'medicines': [
          {
            'id': 'm0',
            'type': 'topical',
            'name': '示例藥品',
            'dose': '依指示',
            'instruction': '核對照護單',
          },
        ],
      },
      'tasks': [
        {
          'id': 't0',
          'petId': 'p1',
          'scheduledAt': '2026-11-11T01:30:00Z',
          'medicineIds': ['m0'],
          'result': 'pending',
        },
        {
          'id': 't1',
          'petId': 'p1',
          'scheduledAt': '2026-11-11T01:00:00Z',
          'medicineIds': ['m0'],
          'result': 'done',
          'finished': true,
          'actualAt': '2026-11-11T01:01:00Z',
        },
      ],
    },
  };

  testWidgets('用藥單筆入口直接開結果表單且不能跳過選擇', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingMedicationPanel(
            bookingId: 'demo',
            booking: booking,
            staff: true,
            taskId: 't0',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('小布 · 擦藥'), findsOneWidget);
    expect(find.text('原訂 11/11 09:30'), findsOneWidget);
    await tester.tap(find.text('儲存結果'));
    await tester.pumpAndSettle();
    expect(find.text('請確認每項用藥的執行結果'), findsOneWidget);
  });

  testWidgets('飼主照護回報僅顯示選定日期已記錄的用藥', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyCareMedicationSummary(
            booking: booking,
            dateKey: '2026-11-11',
          ),
        ),
      ),
    );
    expect(find.text('照護時程與結果'), findsOneWidget);
    expect(find.text('小布 · 擦藥'), findsOneWidget);
    expect(find.text('成功'), findsOneWidget);
    expect(find.text('實際 2026-11-11 09:01'), findsOneWidget);
    expect(find.text('09:30'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('今日待辦可在窄版與寬版依分類查看並保留原操作入口', (tester) async {
    final font = FontLoader('TaskPreview')
      ..addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const previewKey = ValueKey('task-center-preview');
    const snapshot = ShopTaskCenterSnapshot(
      bookingEnabled: true,
      careEnabled: true,
      cameraEnabled: true,
      items: [
        ShopTaskItem(
          id: 'care',
          type: ShopTaskType.dailyCare,
          shopId: 'demo',
          title: 'A03 房 · 小布',
          subtitle: '上午照護回報',
          statusLabel: '待填',
          targetType: 'care',
          targetId: '1',
        ),
        ShopTaskItem(
          id: 'booking',
          type: ShopTaskType.booking,
          shopId: 'demo',
          title: '新預約',
          subtitle: '示例訂單 · 奶茶',
          statusLabel: '待確認',
          targetType: 'booking',
          targetId: '2',
        ),
      ],
    );
    for (final width in [390.0, 840.0]) {
      tester.view.physicalSize = Size(width, 760);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorSchemeSeed: const Color(0xFF4C548B),
            fontFamily: 'TaskPreview',
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: previewKey,
              child: SingleChildScrollView(
                child: ShopTaskCenterContent(
                  snapshot: snapshot,
                  showViewAll: true,
                  closeBeforeOpen: false,
                  onViewAll: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('立即填寫'), findsOneWidget);
      expect(find.text('查看訂單'), findsOneWidget);
      final output = Platform.environment['PETNEST_TASK_PREVIEW'];
      if (output != null) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(previewKey),
          );
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await Directory(output).create(recursive: true);
          await File(
            '$output/task-center-${width.toInt()}.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.widgetWithText(ChoiceChip, '訂單確認 1'));
      await tester.pumpAndSettle();
      expect(find.text('立即填寫'), findsNothing);
      expect(find.text('查看訂單'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '攝影機 0'));
      await tester.pumpAndSettle();
      expect(find.text('這個分類目前沒有待辦'), findsOneWidget);
      expect(find.text('查看訂單'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}

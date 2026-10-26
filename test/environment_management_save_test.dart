import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_manage_page.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';

Map<String, dynamic> _shop() => {
  'environmentIntro': {
    'heroTitle': '原有環境標題',
    'heroSubtitle': '原有環境副標題',
    'bannerTitle': '原有中段標題',
    'bottomNote': '原有提醒',
    'heroImageUrl': '',
    'bannerImageUrl': '',
    'galleryImages': <Map<String, dynamic>>[],
    'features': <Map<String, dynamic>>[],
    'facilityKeys': <String>[],
    'environmentPresentation': {
      'customServices': <Map<String, dynamic>>[],
      'legacyExtension': {'keep': true},
    },
  },
};

Future<void> _openEditor(
  WidgetTester tester, {
  required Future<void> Function(Map<String, dynamic>) save,
}) async {
  const size = Size(1400, 1000);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: size),
        child: child!,
      ),
      home: ShopEnvironmentManagePage(
        shopId: 'fixture',
        loadShop: () async => _shop(),
        saveIntro: save,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('封面與文案'));
  await tester.pumpAndSettle();
}

Finder get _title => find.widgetWithText(TextField, '主標題');
Finder get _save => find.widgetWithText(FilledButton, '儲存').first;
ShopDashboardLeaveAware _state(WidgetTester tester) =>
    tester.state(find.byType(ShopEnvironmentManagePage))
        as ShopDashboardLeaveAware;

void main() {
  testWidgets('成功讀取環境資料後才儲存，保留其餘內容與擴充設定', (tester) async {
    final writes = <Map<String, dynamic>>[];
    await _openEditor(tester, save: (payload) async => writes.add(payload));
    expect(tester.widget<TextField>(_title).controller!.text, '原有環境標題');
    expect(_state(tester).dashboardHasUnsavedChanges, isFalse);
    await tester.enterText(_title, '更新環境標題');
    await tester.pump();
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(writes, hasLength(1));
    expect(writes.single['heroTitle'], '更新環境標題');
    expect(writes.single['heroSubtitle'], '原有環境副標題');
    expect(writes.single['bottomNote'], '原有提醒');
    expect(writes.single['environmentPresentation']['legacyExtension'], {
      'keep': true,
    });
    expect(_state(tester).dashboardHasUnsavedChanges, isFalse);
    expect(find.text('環境介紹已儲存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('環境儲存失敗保留草稿與離開保護，可再次儲存', (tester) async {
    var attempts = 0;
    await _openEditor(
      tester,
      save: (_) async {
        if (++attempts == 1) throw StateError('fixture offline');
      },
    );
    await tester.enterText(_title, '失敗後仍保留的環境標題');
    await tester.pump();
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(find.text('儲存失敗，草稿已保留，請稍後重試'), findsOneWidget);
    expect(tester.widget<TextField>(_title).controller!.text, '失敗後仍保留的環境標題');
    expect(_state(tester).dashboardHasUnsavedChanges, isTrue);
    expect(_state(tester).dashboardIsBusy, isFalse);
    ScaffoldMessenger.of(
      tester.element(find.byType(ShopEnvironmentManagePage)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(_state(tester).dashboardHasUnsavedChanges, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('環境儲存等待期間後續鍵盤輸入仍為未儲存變更', (tester) async {
    final pending = Completer<void>();
    final writes = <Map<String, dynamic>>[];
    await _openEditor(
      tester,
      save: (payload) async {
        writes.add(payload);
        if (writes.length == 1) await pending.future;
      },
    );
    await tester.enterText(_title, '本次送出的環境標題');
    await tester.pump();
    await tester.tap(_save);
    await tester.pump();
    expect(writes.single['heroTitle'], '本次送出的環境標題');
    tester.testTextInput.enterText('等待期間繼續輸入的環境標題');
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();
    expect(writes.single['heroTitle'], '本次送出的環境標題');
    expect(tester.widget<TextField>(_title).controller!.text, '等待期間繼續輸入的環境標題');
    expect(_state(tester).dashboardHasUnsavedChanges, isTrue);
    expect(find.text('這次變更已儲存，另有未儲存內容'), findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(ShopEnvironmentManagePage)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(writes, hasLength(2));
    expect(writes.last['heroTitle'], '等待期間繼續輸入的環境標題');
    expect(_state(tester).dashboardHasUnsavedChanges, isFalse);
    expect(tester.takeException(), isNull);
  });
}

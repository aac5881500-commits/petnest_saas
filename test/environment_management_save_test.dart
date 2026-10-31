import 'package:petnest_saas/features/shop/widgets/environment/environment_feature_manager.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_gallery_manager.dart';
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
  Map<String, dynamic>? shop,
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
        loadShop: () async => shop ?? _shop(),
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
  testWidgets('特色新增只留草稿，整頁儲存失敗可重試', (tester) async {
    final writes = <Map<String, dynamic>>[];
    var fail = true;
    await _openEditor(
      tester,
      save: (payload) async {
        writes.add(payload);
        if (fail) throw StateError('offline');
      },
    );
    await tester.tap(find.text('環境特色').first);
    await tester.pumpAndSettle();
    tester
        .widget<EnvironmentFeatureManager>(
          find.byType(EnvironmentFeatureManager),
        )
        .onAdd();
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(_state(tester).dashboardHasUnsavedChanges, isTrue);
    expect(
      tester
          .widget<EnvironmentFeatureManager>(
            find.byType(EnvironmentFeatureManager),
          )
          .features,
      hasLength(1),
    );
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(writes.single['features'], hasLength(1));
    expect(_state(tester).dashboardHasUnsavedChanges, isTrue);
    fail = false;
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(_state(tester).dashboardHasUnsavedChanges, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('相簿排序與回收統一儲存，儲存後可復原舊照片', (tester) async {
    final shop = _shop();
    shop['environmentIntro']['galleryImages'] = [
      {'imageUrl': 'https://example.test/a.jpg', 'imageStoragePath': ''},
      {'imageUrl': 'https://example.test/b.jpg', 'imageStoragePath': ''},
    ];
    final writes = <Map<String, dynamic>>[];
    await _openEditor(
      tester,
      shop: shop,
      save: (payload) async => writes.add(payload),
    );
    await tester.tap(find.text('相簿與提醒'));
    await tester.pumpAndSettle();
    EnvironmentGalleryManager manager() =>
        tester.widget(find.byType(EnvironmentGalleryManager));
    manager().onMove!(1, -1);
    await tester.pump();
    await manager().onDelete(0);
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(manager().images, ['https://example.test/a.jpg']);
    expect(manager().trashImages, ['https://example.test/b.jpg']);
    expect(_state(tester).dashboardHasUnsavedChanges, isTrue);
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(writes.single['galleryTrash'], hasLength(1));
    expect(_state(tester).dashboardHasUnsavedChanges, isFalse);
    manager().onRestore!(0);
    await tester.pumpAndSettle();
    expect(manager().images, [
      'https://example.test/a.jpg',
      'https://example.test/b.jpg',
    ]);
    expect(manager().trashImages, isEmpty);
    expect(_state(tester).dashboardHasUnsavedChanges, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('相簿封面與說明保留到回收區，重進後可復原', (tester) async {
    final shop = _shop();
    shop['environmentIntro']['galleryImages'] = [
      {
        'imageUrl': 'https://example.test/a.jpg',
        'imageStoragePath': '',
        'caption': '日照休憩區',
        'customMetadata': 7,
      },
    ];
    final writes = <Map<String, dynamic>>[];
    await _openEditor(
      tester,
      shop: shop,
      save: (payload) async => writes.add(payload),
    );
    await tester.tap(find.text('相簿與提醒'));
    await tester.pumpAndSettle();
    EnvironmentGalleryManager manager() =>
        tester.widget(find.byType(EnvironmentGalleryManager));
    manager().onSetCover!(0);
    await tester.pump();
    await manager().onDelete(0);
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(writes.single['heroImageUrl'], 'https://example.test/a.jpg');
    expect(writes.single['galleryTrash'].single['caption'], '日照休憩區');
    expect(writes.single['galleryTrash'].single['customMetadata'], 7);
    final saved = writes.single;
    await tester.pumpWidget(const SizedBox());
    await _openEditor(
      tester,
      shop: {'environmentIntro': saved},
      save: (payload) async => writes.add(payload),
    );
    await tester.tap(find.text('相簿與提醒'));
    await tester.pumpAndSettle();
    expect(manager().trashImages, hasLength(1));
    manager().onRestore!(0);
    await tester.pumpAndSettle();
    expect(manager().captions, ['日照休憩區']);
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(writes.last['galleryImages'].single['customMetadata'], 7);
    expect(_state(tester).dashboardHasUnsavedChanges, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('特色草稿繼續編輯及放棄都不會局部發布', (tester) async {
    final writes = <Map<String, dynamic>>[];
    await _openEditor(tester, save: (payload) async => writes.add(payload));
    await tester.tap(find.text('環境特色').first);
    await tester.pumpAndSettle();
    tester
        .widget<EnvironmentFeatureManager>(
          find.byType(EnvironmentFeatureManager),
        )
        .onAdd();
    await tester.pumpAndSettle();
    final cancel = _state(tester).dashboardConfirmLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    expect(await cancel, isFalse);
    expect(_state(tester).dashboardHasUnsavedChanges, isTrue);
    final discard = _state(tester).dashboardConfirmLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('放棄變更'));
    await tester.pumpAndSettle();
    expect(await discard, isTrue);
    expect(writes, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('刪除特色草稿不刪除仍被相簿引用的圖片', (tester) async {
    final shop = _shop();
    final shared = {
      'imageUrl': 'https://example.test/shared.jpg',
      'imageStoragePath': 'shops/fixture/environment/feature_shared.jpg',
    };
    shop['environmentIntro']['features'] = [
      {...shared, 'title': '共享圖片特色', 'description': '', 'icon': 'home'},
    ];
    shop['environmentIntro']['galleryImages'] = [shared];
    final writes = <Map<String, dynamic>>[];
    await _openEditor(
      tester,
      shop: shop,
      save: (payload) async => writes.add(payload),
    );
    await tester.tap(find.text('環境特色').first);
    await tester.pumpAndSettle();
    final deletion = tester
        .widget<EnvironmentFeatureManager>(
          find.byType(EnvironmentFeatureManager),
        )
        .onDelete(0);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '刪除特色'));
    await tester.pumpAndSettle();
    await deletion;
    expect(writes, isEmpty);
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(writes.single['features'], isEmpty);
    expect(
      writes.single['galleryImages'].single['imageUrl'],
      shared['imageUrl'],
    );
    // No Firebase app is initialized in this fixture: any attempted Storage deletion
    // would fail the save instead of reaching the saved state.
    expect(_state(tester).dashboardHasUnsavedChanges, isFalse);

    expect(tester.takeException(), isNull);
  });
}

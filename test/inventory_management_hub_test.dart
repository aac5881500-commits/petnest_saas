import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_management_hub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async => Firebase.initializeApp());
  InventoryItemModel item(
    String id,
    num stock, {
    bool enabled = true,
    DateTime? expiry,
  }) => InventoryItemModel(
    id: id,
    shopId: 'shop',
    name: id,
    currentStock: stock,
    safetyStock: 3,
    allowDecimal: false,
    enabled: enabled,
    nearestExpiryDate: expiry,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  Future<void> show(
    WidgetTester tester,
    Stream<List<InventoryItemModel>> stream, {
    double width = 390,
    Map<String, dynamic>? member = const {'role': 'owner'},
    bool complete = true,
  }) async {

    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InventoryManagementHub(
            shopId: 'shop',
            isProfileComplete: complete,
            memberData: member,
            itemsStream: stream,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 1100.0]) {
    testWidgets('stock alerts and layout at $width', (tester) async {
      await show(
        tester,
        Stream.value([
          item('缺貨貓砂', 0),
          item('低庫存飼料', 2),
          item('正常清潔劑', 8),
          item('停用品項', 0, enabled: false),
          item('即期用品', 7, expiry: DateTime.now().add(const Duration(days: 1))),
        ]),
        width: width,
      );
      expect(find.text('優先處理'), findsOneWidget);
      expect(find.text('缺貨貓砂'), findsOneWidget);
      expect(find.text('低庫存飼料'), findsOneWidget);
      expect(find.text('停用品項'), findsNothing);
      expect(find.text('正常清潔劑'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('empty inventory provides create action for owner', (
    tester,
  ) async {
    await show(tester, Stream.value([]));
    expect(find.text('新增庫存品項'), findsOneWidget);
    expect(find.text('從第一個庫存品項開始'), findsOneWidget);
  });
  testWidgets('load failure is not an empty inventory', (tester) async {
    await show(tester, Stream.error(StateError('offline')));
    expect(find.text('暫時無法讀取庫存摘要'), findsOneWidget);
    expect(find.text('重新載入'), findsOneWidget);
    expect(find.text('從第一個庫存品項開始'), findsNothing);
  });
  testWidgets('no permission never subscribes', (tester) async {
    var listened = false;
    final controller = StreamController<List<InventoryItemModel>>(
      onListen: () => listened = true,
    );
    await show(tester, controller.stream, member: null);
    expect(listened, isFalse);
    expect(find.text('目前沒有庫存檢視權限，請聯絡店家管理員調整。'), findsOneWidget);
    controller.close();
  });
  testWidgets('incomplete profile never subscribes', (tester) async {
    var listened = false;
    final controller = StreamController<List<InventoryItemModel>>(
      onListen: () => listened = true,
    );
    await show(tester, controller.stream, complete: false);
    expect(listened, isFalse);
    expect(find.text('請先完成店家基本資料，再開始管理庫存與耗材。'), findsOneWidget);
    controller.close();
  });
}



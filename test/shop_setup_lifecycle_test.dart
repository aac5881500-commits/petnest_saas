import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
// Use Firebase's existing bundled test mocks without adding a package.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_settings_page.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_rooms_hub.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_editor.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_live_preview.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_setup_center_page.dart';
import 'package:petnest_saas/core/services/stay_booking_readiness.dart';

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async {
    await Firebase.initializeApp();
  });
  void captureErrors() {
    final original = FlutterError.onError;
    var captured = false;
    FlutterError.onError = (details) {
      if (!captured) {
        captured = true;
        debugPrint('FIRST-EXCEPTION: ${details.exceptionAsString()}');
        debugPrint(details.stack.toString(), wrapWidth: 200);
      }
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  testWidgets('最小驗證：建房聚焦手機與桌機', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [390.0, 1280.0]) {
      final shop = 'guide-${width.toInt()}';
      await tester.binding.setSurfaceSize(Size(width, 900));
      final types = StreamController<List<Map<String, dynamic>>>();
      final type = {
        'id': 'new',
        'name': '新房型',
        'price': 1200,
        'capacity': 2,
        'totalRooms': 10,
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopRoomTypeRoomsHub(
              shopId: shop,
              guideUserId: 'u',
              embeddedInSetupCenter: true,
              roomTypesStream: types.stream,
              roomsStream: Stream.value([]),
              saveDraft: (_) async {
                types.add([type]);
                return 'new';
              },
            ),
          ),
        ),
      );
      types.add([]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增第一個房型'));
      await tester.pumpAndSettle();
      for (final field in {
        '房型名稱': '新房型',
        '每晚價格': '1200',
        '最多入住數': '2',
        '房間數量／上限': '10',
      }.entries) {
        await tester.enterText(
          find.widgetWithText(TextField, field.key),
          field.value,
        );
      }
      await tester.tap(find.text('建立房型'));
      await tester.pumpAndSettle();
      expect(find.text('房型建立成功！下一步請點這裡，建立實際房間。'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      expect(tester.getBottomRight(find.text('展開／收合房間')).dy, lessThan(900));
      await tester.tap(find.text('展開／收合房間'));
      await tester.pumpAndSettle();
      expect(find.text('房型建立成功！下一步請點這裡，建立實際房間。'), findsNothing);
      expect(find.text('新增房間'), findsOneWidget);
      expect(tester.getBottomRight(find.text('新增房間')).dy, lessThan(900));
      await tester.tap(find.text('展開／收合房間'));
      await tester.pumpAndSettle();
      expect(find.text('尚未建立實際房間'), findsOneWidget);
      expect(find.text('建立房間'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'roomCreationGuide:u:$shop:new',
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(types.close());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopRoomTypeRoomsHub(
              shopId: shop,
              guideUserId: 'u',
              embeddedInSetupCenter: true,
              roomTypesStream: Stream.value([type]),
              roomsStream: Stream.value([
                {'id': 'r', 'roomTypeId': 'new', 'enabled': true},
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('最小驗證：預約缺省、載入、有效狀態與舊店保留', (tester) async {
    final ready = StayBookingReadiness(
      [
        {'id': 't'},
      ],
      [
        {'id': 'r', 'roomTypeId': 't', 'enabled': true},
      ],
    );
    expect(StayBookingReadiness.requested({}), isFalse);
    final configs = StreamController<Map<String, dynamic>?>();
    final readiness = StreamController<StayBookingReadiness>();
    await tester.pumpWidget(
      MaterialApp(
        home: ShopBookingSettingsPage(
          shopId: 'fixture',
          embeddedInSetupCenter: true,
          loadMember: () async => {'role': 'owner'},
          shopStream: configs.stream,
          readinessStream: readiness.stream,
          actionLogsStream: Stream.value([]),
        ),
      ),
    );
    configs.add({'bookingEnabled': true, 'daycareEnabled': false});
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch).first).onChanged, isNull);
    readiness.add(StayBookingReadiness([], []));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    expect(find.text('目前可預約'), findsNothing);
    expect(find.text('建立第一個房型'), findsOneWidget);
    // Fixture for the existing explicit room-creation operation's persisted result.
    configs.add({'bookingEnabled': false, 'daycareEnabled': false});
    readiness.add(ready);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    configs.add({'bookingEnabled': true, 'daycareEnabled': false});
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    expect(find.text('目前可預約'), findsOneWidget);
    configs.add({'daycareEnabled': false});
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(configs.close());
    unawaited(readiness.close());
  });

  testWidgets('同一個 hub 新增草稿在窄寬窄切換保留', (tester) async {
    final types = Stream<List<Map<String, dynamic>>>.value([]);
    final rooms = Stream<List<Map<String, dynamic>>>.value([]);
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShopRoomTypeRoomsHub(
            shopId: 'test',
            embeddedInSetupCenter: true,
            roomTypesStream: types,
            roomsStream: rooms,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增第一個房型'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '房型名稱'), '跨斷點草稿');
    await tester.pump();
    for (final width in [1280.0, 390.0, 1440.0, 320.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '房型名稱'))
            .controller!
            .text,
        '跨斷點草稿',
      );
    }
  });

  testWidgets('完整整合頁：同頁修正、分頁、草稿離開與返回', (tester) async {
    captureErrors();
    final routes = _Routes();
    final types = Stream<List<Map<String, dynamic>>>.value([]);
    final rooms = Stream<List<Map<String, dynamic>>>.value([]);
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [routes],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopBookingSetupCenterPage(
                    shopId: 'test',
                    appBarActions: const [],
                    loadMember: () async => {'role': 'owner'},
                    roomTypesStream: types,
                    roomsStream: rooms,
                    shopStream: Stream.value({
                      'bookingEnabled': false,
                      'daycareEnabled': false,
                      'maxAdvanceBookingDays': 30,
                    }),
                    readinessStream: Stream.value(StayBookingReadiness([], [])),
                    actionLogsStream: Stream.value([]),
                    saveRoomType: (_) async => 'created',
                  ),
                ),
              ),
              child: const Text('開店設定'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開店設定'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('預約設定').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('建立第一個房型'));
      await tester.pumpAndSettle();
      expect(routes.pushes, 2);
      expect(find.byType(ShopBookingSetupCenterPage), findsOneWidget);
    }
    await tester.tap(find.text('新增第一個房型'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '房型名稱'), '整合頁草稿');
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.tap(find.byIcon(Icons.arrow_back).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('預約設定').first);
    await tester.pumpAndSettle();
    expect(find.text('尚未儲存'), findsOneWidget);
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '房型名稱'))
          .controller!
          .text,
      '整合頁草稿',
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('離開'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('預約設定').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '20');
    await tester.tap(find.text('房型與房間'));
    await tester.pumpAndSettle();
    expect(find.text('尚有未儲存的變更'), findsOneWidget);
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      '20',
    );
    await tester.tap(find.text('房型與房間'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放棄變更'));
    await tester.pumpAndSettle();
    for (final width in [320.0, 390.0, 430.0, 768.0, 1280.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    expect(find.text('開店設定'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('照片、文字在編輯預覽與斷點後保留；送出失敗保留內容', (tester) async {
    final image = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a55kAAAAASUVORK5CYII=',
    );
    ShopRoomTypeDraft? draft;
    var saves = 0;
    final pendingSave = Completer<String>();
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ShopRoomTypeEditorPage(
          shopId: 'test',
          existing: const {
            'id': 't',
            'name': '房型',
            'price': 1200,
            'capacity': 2,
            'totalRooms': 3,
          },
          onDraftChanged: (value) => draft = value,
          pickCroppedPhoto: () async => image,
          saveDraft: (_) async {
            saves++;
            return pendingSave.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('選擇並裁切照片'));
    await tester.tap(find.text('選擇並裁切照片'));
    await tester.pumpAndSettle();
    expect(draft!.pendingImageBytes.length, 1);
    for (final width in [1280.0, 320.0, 768.0, 1440.0, 390.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpAndSettle();
      expect(draft!.pendingImageBytes.length, 1);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('預覽'));
    await tester.pumpAndSettle();
    expect(find.byType(ShopRoomTypeLivePreview), findsOneWidget);
    await tester.tap(find.text('編輯'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存變更'));
    await tester.pump();
    final submit = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.tap(submit, warnIfMissed: false);
    expect(saves, 1);
    pendingSave.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(draft!.pendingImageBytes.length, 1);
    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.byType(ShopRoomTypeEditorPage), findsOneWidget);
  });

  testWidgets('編輯房型儲存成功才退出，固定列位於鍵盤上方', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ShopRoomTypeDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShopRoomTypeRoomsHub(
            shopId: 'test',
            embeddedInSetupCenter: true,
            roomTypesStream: Stream.value([
              {
                'id': 't',
                'name': '原房型',
                'price': 1200,
                'capacity': 2,
                'totalRooms': 3,
              },
            ]),
            roomsStream: Stream.value([]),
            saveDraft: (draft) async {
              saved = draft;
              return 't';
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('編輯房型'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '房型名稱'), '更新後房型');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.widgetWithText(FilledButton, '儲存變更')).dy,
      lessThanOrEqualTo(620),
    );
    await tester.tap(find.text('儲存變更'));
    await tester.pumpAndSettle();
    expect(saved!.name, '更新後房型');
    expect(find.byType(ShopRoomTypeEditorPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('非同步權限與照片載入中離開，不在 dispose 後回呼', (tester) async {
    final role = Completer<Map<String, dynamic>?>();
    await tester.pumpWidget(
      MaterialApp(
        home: ShopBookingSetupCenterPage(
          shopId: 'test',
          appBarActions: const [],
          loadMember: () => role.future,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    role.complete({'role': 'owner'});
    await tester.pumpAndSettle();
    final photo = Completer<Uint8List?>();
    await tester.pumpWidget(
      MaterialApp(
        home: ShopRoomTypeEditorPage(
          shopId: 'test',
          pickCroppedPhoto: () => photo.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('選擇並裁切照片'));
    await tester.tap(find.text('選擇並裁切照片'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    photo.complete(Uint8List.fromList([1]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

// 檔案名稱：test/customer_camera_entry_test.dart
// 功能說明：顧客攝影機入口的房間訊號、按鈕、過期回應與頁面狀態不被重設。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/camera_entry_watch.dart';
import 'package:petnest_saas/core/services/camera_access_service.dart';
import 'package:petnest_saas/features/booking/widgets/camera_brand_launch.dart';
import 'package:petnest_saas/features/booking/widgets/customer_camera_entry.dart';

void main() {
  test('房間訊號、按鈕名稱與讀取失敗可以分開判斷', () {
    expect(cameraRoomRevisionOf(null), 0);
    expect(cameraRoomRevisionOf(<String, dynamic>{}), 0);
    expect(cameraRoomRevisionOf(<String, dynamic>{'cameraRevision': 4}), 4);
    expect(shopCameraSectionOn(null), isTrue);
    expect(
      shopCameraSectionOn(<String, dynamic>{'showCameraSection': false}),
      isFalse,
    );
    final CameraEntryWatch roomA = _watch();
    expect(cameraEntryShouldReload(null, roomA), isTrue);
    expect(cameraEntryShouldReload(roomA, _watch()), isFalse);
    expect(cameraEntryShouldReload(roomA, _watch(roomId: 'room-b')), isTrue);
    expect(cameraEntryShouldReload(roomA, _watch(roomRevision: 2)), isTrue);
    expect(cameraEntryShouldReload(roomA, _watch(shopCameraOn: false)), isTrue);
    expect(cameraEntryShouldReload(roomA, _watch(serviceOpen: false)), isTrue);
    expect(
      cameraSignalRoomIds(null, <String, dynamic>{
        'type': 'camera',
        'roomId': 'room-a',
        'url': 'https://cam.example/secret',
      }),
      <String>['room-a'],
    );
    expect(
      cameraSignalRoomIds(
        <String, dynamic>{'type': 'camera', 'roomId': 'room-a'},
        <String, dynamic>{'type': 'camera', 'roomId': 'room-b'},
      ),
      <String>['room-a', 'room-b'],
    );
    expect(
      cameraSignalRoomIds(<String, dynamic>{
        'type': 'camera',
        'roomId': 'room-a',
      }, null),
      <String>['room-a'],
    );
    expect(
      cameraSignalRoomIds(
        <String, dynamic>{'type': 'feeder', 'roomId': 'room-a'},
        <String, dynamic>{'type': 'feeder', 'roomId': 'room-b'},
      ),
      isEmpty,
    );
    expect(
      customerCameraEntryTitle(viewMode: 'web_url', provider: ''),
      '觀看攝影機',
    );
    expect(
      customerCameraEntryTitle(viewMode: 'external_app', provider: 'xiaomi'),
      '米家攝影機',
    );
    expect(
      customerCameraEntryTitle(viewMode: 'external_app', provider: 'tapo'),
      '品牌尚未開放',
    );
    expect(
      customerCameraEntrySubtitle(
        viewMode: 'external_app',
        provider: 'tapo',
        appName: '',
      ),
      contains('不能改用其他品牌'),
    );
    expect(customerCameraFailureMessage(code: 'unavailable'), '網路不穩定，請再試一次');
    expect(customerCameraFailureMessage(code: 'unauthenticated'), '請重新登入後再試');
    expect(
      customerCameraFailureMessage(code: 'not-found', message: 'NOT FOUND'),
      '攝影機暫時無法讀取，請再試一次',
    );
    expect(
      customerCameraFailureMessage(code: 'not-found', message: '找不到這筆訂單'),
      '找不到這筆訂單',
    );
    expect(
      cameraCallableDiagnostic(
        name: 'getCustomerRoomCamera',
        region: 'asia-east1',
        code: 'internal',
        message: 'fail https://cam.example/a user@mail.com',
      ),
      'callable getCustomerRoomCamera region=asia-east1 code=internal message=fail [url] [account]',
    );
    expect(
      cameraGateResultIsCurrent(
        requestTicket: 2,
        currentTicket: 2,
        requestBookingId: 'booking-1',
        currentBookingId: 'booking-1',
        requestRoomId: 'room-a',
        currentRoomId: 'room-b',
      ),
      isFalse,
    );
    expect(
      customerCameraEntryPresentation(
        const CustomerRoomCameraResult.hidden(),
      ).showsCamera,
      isFalse,
    );
    expect(
      customerCameraEntryPresentation(
        const CustomerRoomCameraResult.error('網路不穩定，請再試一次'),
      ).kind,
      CustomerCameraEntryKind.retry,
    );
    expect(
      customerCameraEntryPresentation(
        const CustomerRoomCameraResult.unsupported('此品牌尚未開放'),
      ).kind,
      CustomerCameraEntryKind.unsupported,
    );
    expect(
      customerCameraEntryPresentation(
        CustomerRoomCameraResult.ready(
          _camera(viewMode: 'external_app', provider: 'xiaomi', url: ''),
        ),
      ).label,
      '米家攝影機',
    );
  });

  testWidgets('頁面開著時關閉再啟用，按鈕跟著最新模式', (WidgetTester tester) async {
    final _Harness harness = _Harness();
    await harness.mount(tester);
    harness.next = CustomerRoomCameraResult.ready(_camera());
    await harness.emit(tester, _watch());
    expect(find.text('觀看攝影機'), findsOneWidget);

    harness.next = const CustomerRoomCameraResult.hidden();
    await harness.emit(tester, _watch(roomRevision: 1));
    expect(find.text('觀看攝影機'), findsNothing);

    harness.next = CustomerRoomCameraResult.ready(
      _camera(viewMode: 'external_app', provider: 'xiaomi', url: ''),
    );
    await harness.emit(tester, _watch(roomRevision: 2));
    expect(find.text('米家攝影機'), findsOneWidget);

    harness.next = CustomerRoomCameraResult.ready(
      _camera(url: 'https://cam.example/two'),
    );
    await harness.emit(tester, _watch(roomRevision: 3));
    expect(find.text('觀看攝影機'), findsOneWidget);
    expect(find.text('米家攝影機'), findsNothing);
  });

  testWidgets('同一訂單換房、店家開關、退房與平台鎖定都會更新入口', (WidgetTester tester) async {
    final _Harness harness = _Harness();
    await harness.mount(tester);
    harness.next = CustomerRoomCameraResult.ready(_camera(roomId: 'room-a'));
    await harness.emit(tester, _watch(roomId: 'room-a'));
    expect(find.text('觀看攝影機'), findsOneWidget);

    harness.next = CustomerRoomCameraResult.ready(_camera(roomId: 'room-b'));
    await harness.emit(tester, _watch(roomId: 'room-b', roomRevision: 1));
    expect(find.text('觀看攝影機'), findsOneWidget);
    expect(harness.loads, 2);

    harness.next = const CustomerRoomCameraResult.hidden();
    await harness.emit(tester, _watch(shopCameraOn: false, roomRevision: 1));
    expect(find.text('觀看攝影機'), findsNothing);

    harness.next = CustomerRoomCameraResult.ready(_camera());
    await harness.emit(tester, _watch(roomRevision: 4));
    expect(find.text('觀看攝影機'), findsOneWidget);

    harness.next = const CustomerRoomCameraResult.hidden();
    await harness.emit(tester, _watch(serviceOpen: false, roomRevision: 4));
    expect(find.text('觀看攝影機'), findsNothing);
    expect(find.text('查看全部照護照片'), findsOneWidget);
    expect(_photoInRow(tester), isFalse);
  });

  testWidgets('舊房結果晚回來不能覆蓋新房，失敗重試後恢復', (WidgetTester tester) async {
    final List<Completer<CustomerRoomCameraResult>> pending =
        <Completer<CustomerRoomCameraResult>>[];
    final StreamController<CameraEntryWatch> signals =
        StreamController<CameraEntryWatch>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerCameraGate(
            bookingId: 'booking-1',
            reloadDelay: _tick,
            watchEntry: (_) => signals.stream,
            loadCamera: (_) {
              final Completer<CustomerRoomCameraResult> completer =
                  Completer<CustomerRoomCameraResult>();
              pending.add(completer);
              return completer.future;
            },
            builder: (BuildContext context, CustomerCameraGateState state) {
              final String room =
                  state.result?.camera?.roomId ??
                  state.result?.visibility ??
                  'empty';
              return Text(room);
            },
          ),
        ),
      ),
    );
    signals.add(_watch(roomId: 'room-a'));
    await tester.pump(_tick);
    signals.add(_watch(roomId: 'room-b'));
    await tester.pump(_tick);
    expect(pending, hasLength(2));
    pending[0].complete(
      CustomerRoomCameraResult.ready(_camera(roomId: 'room-a')),
    );
    await tester.pump();
    expect(find.text('room-a'), findsNothing);
    pending[1].complete(
      CustomerRoomCameraResult.ready(_camera(roomId: 'room-b')),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('room-b'), findsOneWidget);

    signals.add(_watch(roomId: 'room-b', roomRevision: 2));
    await tester.pump(_tick);
    pending.last.complete(const CustomerRoomCameraResult.error('網路不穩定，請再試一次'));
    await tester.pump();
    await tester.pump();
    expect(find.text('room-b'), findsNothing);
    expect(find.text('error'), findsOneWidget);

    final CustomerCameraGateState state = tester.state(
      find.byType(CustomerCameraGate),
    );
    final Future<void> retried = state.retry();
    await tester.pump();
    pending.last.complete(
      CustomerRoomCameraResult.ready(_camera(roomId: 'room-b')),
    );
    await retried;
    await tester.pump();
    expect(find.text('room-b'), findsOneWidget);
  });

  testWidgets('讀取失敗會解除監聽，重試成功後重新監聽', (WidgetTester tester) async {
    final List<StreamController<CameraEntryWatch>> opened =
        <StreamController<CameraEntryWatch>>[];
    CustomerRoomCameraResult next = const CustomerRoomCameraResult.error(
      '攝影機暫時無法讀取，請再試一次',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerCameraGate(
            bookingId: 'booking-1',
            reloadDelay: _tick,
            watchEntry: (_) {
              final StreamController<CameraEntryWatch> controller =
                  StreamController<CameraEntryWatch>();
              opened.add(controller);
              return controller.stream;
            },
            loadCamera: (_) async => next,
            builder: (BuildContext context, CustomerCameraGateState state) {
              if (state.result?.isError == true) {
                return TextButton(
                  onPressed: state.retry,
                  child: Text(state.result!.message),
                );
              }
              return Text(state.result?.visibility ?? 'empty');
            },
          ),
        ),
      ),
    );
    opened.single.addError(const CameraAccessException('請重新登入後再試'));
    await tester.pump();
    expect(find.text('請重新登入後再試'), findsOneWidget);
    expect(opened.single.hasListener, isFalse);

    next = CustomerRoomCameraResult.ready(_camera());
    await tester.tap(find.text('請重新登入後再試'));
    await tester.pump();
    await tester.pump();
    expect(find.text('ready'), findsOneWidget);
    expect(opened, hasLength(2));
    expect(opened.first.hasListener, isFalse);
    expect(opened.last.hasListener, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(opened.last.hasListener, isFalse);
  });

  testWidgets('沒有房間訊號的舊資料仍會載入，短時間重複訊號只查一次', (WidgetTester tester) async {
    var loads = 0;
    final StreamController<CameraEntryWatch> signals =
        StreamController<CameraEntryWatch>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerCameraGate(
            bookingId: 'booking-1',
            reloadDelay: const Duration(milliseconds: 80),
            watchEntry: (_) => signals.stream,
            loadCamera: (_) async {
              loads += 1;
              return CustomerRoomCameraResult.ready(_camera());
            },
            builder: (BuildContext context, CustomerCameraGateState state) {
              return Text(state.result?.visibility ?? 'empty');
            },
          ),
        ),
      ),
    );
    signals.add(_watch(roomRevision: 0));
    await tester.pump(const Duration(milliseconds: 30));
    signals.add(_watch(roomRevision: 0));
    signals.add(_watch(roomRevision: 1));
    signals.add(_watch(roomRevision: 2));
    await tester.pump(const Duration(milliseconds: 30));
    expect(loads, 0);
    await tester.pump(const Duration(milliseconds: 80));
    expect(loads, 1);
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('換訂單會解除舊監聽，恢復時失敗不保留舊攝影機', (WidgetTester tester) async {
    final StreamController<CameraEntryWatch> first =
        StreamController<CameraEntryWatch>();
    final StreamController<CameraEntryWatch> second =
        StreamController<CameraEntryWatch>();
    var loads = 0;
    CustomerRoomCameraResult next = CustomerRoomCameraResult.ready(
      _camera(roomId: 'room-a'),
    );
    late StateSetter update;
    String bookingId = 'booking-a';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              update = setState;
              return CustomerCameraGate(
                bookingId: bookingId,
                reloadDelay: _tick,
                watchEntry: (String id) =>
                    id == 'booking-a' ? first.stream : second.stream,
                loadCamera: (_) async {
                  loads += 1;
                  return next;
                },
                builder: (BuildContext context, CustomerCameraGateState state) {
                  return Text(state.result?.camera?.roomId ?? 'empty');
                },
              );
            },
          ),
        ),
      ),
    );
    first.add(_watch(bookingId: 'booking-a', roomId: 'room-a'));
    await tester.pump(_tick);
    expect(find.text('room-a'), findsOneWidget);
    expect(first.hasListener, isTrue);

    update(() => bookingId = 'booking-b');
    await tester.pump();
    expect(first.hasListener, isFalse);
    expect(second.hasListener, isTrue);
    expect(find.text('room-a'), findsNothing);

    next = CustomerRoomCameraResult.ready(_camera(roomId: 'room-b'));
    second.add(_watch(bookingId: 'booking-b', roomId: 'room-b'));
    await tester.pump(_tick);
    expect(find.text('room-b'), findsOneWidget);

    next = const CustomerRoomCameraResult.error('網路不穩定，請再試一次');
    final CustomerCameraGateState state = tester.state(
      find.byType(CustomerCameraGate),
    );
    state.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.text('room-b'), findsNothing);
    expect(find.text('empty'), findsOneWidget);
    expect(loads, greaterThan(2));
  });

  testWidgets('分享視窗開著時房間變更會關閉視窗', (WidgetTester tester) async {
    final StreamController<CameraEntryWatch> signals =
        StreamController<CameraEntryWatch>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerCameraServiceButtons(
            bookingId: 'booking-1',
            previewMode: false,
            photoButton: const Text('查看全部照護照片'),
            reloadDelay: _tick,
            watchEntry: (_) => signals.stream,
            loadCamera: (_) async => CustomerRoomCameraResult.ready(
              _camera(viewMode: 'external_app', provider: 'xiaomi', url: ''),
            ),
            presentExternal: (BuildContext context, CustomerRoomCamera camera) {
              expect(camera.provider, 'xiaomi');
              return showDialog<void>(
                context: context,
                builder: (BuildContext dialogContext) {
                  return const AlertDialog(title: Text('分享視窗'));
                },
              );
            },
          ),
        ),
      ),
    );
    signals.add(_watch());
    await tester.pump(_tick);
    await tester.pump();
    await tester.tap(find.text('米家攝影機'));
    await tester.pump();
    await tester.pump();
    expect(find.text('分享視窗'), findsOneWidget);

    signals.add(_watch(roomId: 'room-b', roomRevision: 3));
    await tester.pump();
    expect(find.text('分享視窗'), findsNothing);
    expect(find.text('房間或攝影機已變更，請重新開啟'), findsOneWidget);
  });

  testWidgets('未支援品牌不會進米家，照片在攝影機隱藏時填滿', (WidgetTester tester) async {
    final _Harness harness = _Harness();
    await harness.mount(tester);
    harness.next = const CustomerRoomCameraResult.unsupported('此品牌尚未開放');
    await harness.emit(tester, _watch());
    expect(find.text('品牌尚未開放'), findsOneWidget);
    expect(find.text('米家攝影機'), findsNothing);
    expect(find.text('重新讀取攝影機'), findsNothing);
    await tester.tap(find.text('品牌尚未開放'));
    await tester.pump();
    await tester.pump();
    expect(find.text('此品牌尚未開放'), findsWidgets);
    expect(find.text('米家'), findsNothing);
    await tester.tap(find.text('知道了'));
    await tester.pump();
    await tester.pump();

    harness.next = const CustomerRoomCameraResult.hidden();
    await harness.emit(tester, _watch(roomRevision: 1));
    expect(find.text('品牌尚未開放'), findsNothing);
    expect(find.text('查看全部照護照片'), findsOneWidget);
    expect(_photoInRow(tester), isFalse);
  });

  testWidgets('預覽與攝影機更新不影響日期、場次、照片與捲動', (WidgetTester tester) async {
    final ScrollController scroll = ScrollController();
    final StreamController<CameraEntryWatch> signals =
        StreamController<CameraEntryWatch>();
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              const Text('日期 10/02'),
              const Text('場次 2'),
              const Text('照片 4'),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: <Widget>[
                    CustomerCameraServiceButtons(
                      bookingId: 'booking-1',
                      previewMode: false,
                      photoButton: const Text('查看全部照護照片', key: Key('photo')),
                      reloadDelay: _tick,
                      watchEntry: (_) => signals.stream,
                      loadCamera: (_) async {
                        loads += 1;
                        return CustomerRoomCameraResult.ready(_camera());
                      },
                    ),
                    const SizedBox(height: 1600),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    signals.add(_watch());
    await tester.pump(_tick);
    await tester.pump();
    scroll.jumpTo(80);
    signals.add(_watch(roomRevision: 1));
    await tester.pump(_tick);
    await tester.pump();
    expect(find.text('日期 10/02'), findsOneWidget);
    expect(find.text('場次 2'), findsOneWidget);
    expect(find.text('照片 4'), findsOneWidget);
    expect(scroll.offset, 80);
    expect(loads, 2);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomerCameraServiceButtons(
            bookingId: 'booking-1',
            previewMode: true,
            photoButton: Text('查看全部照護照片'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('查看全部照護照片'), findsOneWidget);
    expect(find.text('觀看攝影機'), findsNothing);
    expect(loads, 2);
    scroll.dispose();
  });

  testWidgets('手機與桌面都用中央卡片，鍵盤開啟後仍看得到輸入', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return TextButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => const CustomerCameraRequestDialog(
                    child: CustomScrollView(
                      shrinkWrap: true,
                      slivers: <Widget>[
                        SliverToBoxAdapter(child: Text('A01')),
                        SliverToBoxAdapter(child: Text('房間攝影機')),
                        SliverToBoxAdapter(
                          child: TextField(
                            decoration: InputDecoration(labelText: '分享帳號'),
                          ),
                        ),
                        SliverToBoxAdapter(child: Text('送出申請')),
                      ],
                    ),
                  ),
                );
              },
              child: const Text('開啟'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    final Rect phone = tester.getRect(
      find.byKey(const Key('camera-request-card')),
    );
    expect(phone.width, lessThanOrEqualTo(480));
    expect(phone.left, greaterThanOrEqualTo(16));
    expect(phone.right, lessThanOrEqualTo(374));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('送出申請'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNothing);

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('送出申請'), findsOneWidget);
    expect(tester.getRect(find.byType(TextField)).bottom, lessThan(500));

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    final Rect desktop = tester.getRect(
      find.byKey(const Key('camera-request-card')),
    );
    expect(desktop.width, lessThanOrEqualTo(480));
    expect(desktop.left, greaterThan(300));
  });
}

CameraEntryWatch _watch({
  String bookingId = 'booking-1',
  String roomId = 'room-a',
  bool serviceOpen = true,
  bool shopCameraOn = true,
  int roomRevision = 0,
}) {
  return CameraEntryWatch(
    bookingId: bookingId,
    shopId: 'shop-1',
    roomId: roomId,
    serviceOpen: serviceOpen,
    shopCameraOn: shopCameraOn,
    roomRevision: roomRevision,
  );
}

CustomerRoomCamera _camera({
  String roomId = 'room-a',
  String viewMode = 'web_url',
  String provider = '',
  String url = 'https://cam.example/one',
  String deviceId = 'device-1',
}) {
  return CustomerRoomCamera(
    viewMode: viewMode,
    name: '房間攝影機',
    provider: provider,
    providerLabel: provider,
    appName: provider == 'xiaomi' ? '米家' : '',
    customerShareNote: '',
    deviceId: deviceId,
    shopId: 'shop-1',
    roomId: roomId,
    roomName: roomId,
    bookingKind: 'accommodation',
    bookingKindLabel: '住宿',
    servicePeriodLabel: '',
    customerName: '客人',
    url: url,
  );
}

class _Harness {
  final StreamController<CameraEntryWatch> signals =
      StreamController<CameraEntryWatch>();
  CustomerRoomCameraResult next = const CustomerRoomCameraResult.hidden();
  int loads = 0;

  Future<void> mount(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerCameraServiceButtons(
            bookingId: 'booking-1',
            previewMode: false,
            photoButton: const Text('查看全部照護照片', key: Key('photo')),
            reloadDelay: _tick,
            watchEntry: (_) => signals.stream,
            loadCamera: (_) async {
              loads += 1;
              return next;
            },
          ),
        ),
      ),
    );
  }

  Future<void> emit(WidgetTester tester, CameraEntryWatch watch) async {
    signals.add(watch);
    await tester.pump(_tick);
    await tester.pump();
  }
}

const Duration _tick = Duration(milliseconds: 1);

bool _photoInRow(WidgetTester tester) {
  final Element element = tester.element(find.byKey(const Key('photo')));
  return element.findAncestorWidgetOfExactType<Row>() != null;
}

import 'package:firebase_core/firebase_core.dart';
// Use the Firebase platform interfaces bundled with the existing plugins.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/room_intro_appearance.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_appearance_scope.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_editor.dart';

class _Store extends FirebaseFirestorePlatform {
  final documents = <String, Map<String, dynamic>>{};
  int nextId = 0;
  int roomListReads = 0;
  bool failNextLog = false;

  @override
  FirebaseFirestorePlatform delegateFor({
    required FirebaseApp app,
    required String databaseId,
  }) => this;

  @override
  CollectionReferencePlatform collection(String path) =>
      _Collection(this, path);

  @override
  DocumentReferencePlatform doc(String path) => _Document(this, path);

  DocumentSnapshotPlatform snapshot(String path) => DocumentSnapshotPlatform(
    this,
    path,
    documents[path],
    InternalSnapshotMetadata(hasPendingWrites: false, isFromCache: false),
  );
}

class _Collection extends CollectionReferencePlatform {
  _Collection(_Store super.firestore, super.path);
  _Store get store => firestore as _Store;

  @override
  DocumentReferencePlatform doc([String? path]) =>
      store.doc('${this.path}/${path ?? 'generated-${++store.nextId}'}');

  @override
  Future<QuerySnapshotPlatform> get([
    GetOptions options = const GetOptions(),
  ]) async {
    if (path.endsWith('/room_types')) store.roomListReads++;
    return QuerySnapshotPlatform(
      store.documents.keys
          .where(
            (key) =>
                key.startsWith('$path/') &&
                key.split('/').length == path.split('/').length + 1,
          )
          .map(store.snapshot)
          .toList(),
      [],
      SnapshotMetadataPlatform(false, false),
    );
  }
}

class _Document extends DocumentReferencePlatform {
  _Document(_Store super.firestore, super.path);
  _Store get store => firestore as _Store;

  @override
  Future<DocumentSnapshotPlatform> get([
    GetOptions options = const GetOptions(),
  ]) async => store.snapshot(path);

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (path.startsWith('action_logs/') && store.failNextLog) {
      store.failNextLog = false;
      throw StateError('fixture log unavailable');
    }
    store.documents[path] = Map.of(data);
  }

  @override
  Future<void> update(Map<FieldPath, dynamic> data) async {
    final current = store.documents[path];
    if (current == null) throw StateError('Missing document: $path');
    for (final entry in data.entries) {
      current[entry.key.components.join('.')] = entry.value;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final store = _Store();
  setUpAll(() async {
    await Firebase.initializeApp();
    FirebaseFirestorePlatform.instance = store;
  });
  setUp(() {
    store.documents.clear();
    store.nextId = store.roomListReads = 0;
    store.failNextLog = false;
  });

  test('同名房型各自回傳實際建立的文件 ID', () async {
    Future<String> create() => ShopRoomService.instance.createRoomType(
      shopId: 'fixture',
      name: '同名房型',
      capacity: 2,
      price: 1200,
      totalRooms: 3,
      description: '',
      extraPrice: 0,
      width: 0,
      depth: 0,
      height: 0,
    );
    final first = await create();
    final second = await create();
    expect(first, isNot(second));
    expect(store.documents['shops/fixture/room_types/$first']?['name'], '同名房型');
    expect(
      store.documents['shops/fixture/room_types/$second']?['name'],
      '同名房型',
    );
    expect(store.roomListReads, 0);
  });

  testWidgets('建立後紀錄失敗，重試保留原文件並交接正確 ID', (tester) async {
    store.documents['shops/fixture'] = {};
    store.documents['shops/fixture/room_types/existing'] = {
      'name': '同名房型',
      'price': 800,
      'capacity': 1,
      'totalRooms': 1,
      'images': [],
    };
    store.failNextLog = true;
    String? savedId;
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => RoomIntroAppearanceScope(
          appearance: const RoomIntroAppearance(),
          theme: HomeThemeModel.classicDefault,
          child: child!,
        ),
        home: Scaffold(
          body: ShopRoomTypeEditorPage(
            shopId: 'fixture',
            embedded: true,
            onSaved: (id) => savedId = id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final entry in {
      '房型名稱': '同名房型',
      '每晚價格': '1200',
      '最多入住數': '2',
      '房間數量／上限': '3',
    }.entries) {
      await tester.enterText(
        find.widgetWithText(TextField, entry.key),
        entry.value,
      );
    }
    await tester.tap(find.text('建立房型'));
    await tester.pumpAndSettle();
    expect(savedId, isNull);
    expect(find.textContaining('fixture log unavailable'), findsOneWidget);
    final createdPath = store.documents.keys.singleWhere(
      (path) =>
          path.startsWith('shops/fixture/room_types/') &&
          !path.endsWith('/existing'),
    );
    // Dismiss the failure feedback before retrying the button underneath it.
    ScaffoldMessenger.of(
      tester.element(find.byType(ShopRoomTypeEditorPage)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('建立房型'));
    await tester.pumpAndSettle();
    expect(savedId, createdPath.split('/').last);
    expect(
      store.documents.keys.where(
        (path) => path.startsWith('shops/fixture/room_types/'),
      ),
      hasLength(2),
    );
    expect(store.documents['shops/fixture/room_types/existing']?['price'], 800);
    expect(store.documents[createdPath]?['price'], 1200);
    expect(store.roomListReads, 1);
    expect(tester.takeException(), isNull);
  });
}

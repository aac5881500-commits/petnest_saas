import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/shop_deletion_service.dart';
import 'package:petnest_saas/features/platform/widgets/platform_shop_deletion_dialog.dart';

void main() {
  testWidgets('桌機顯示四階段、店家統計、Storage 與安全限制', (WidgetTester tester) async {
    final _FakeDeletionService service = _FakeDeletionService();
    await _surface(tester, const Size(1200, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformShopDeletionDialog(
          shopId: 'SHOP9001',
          shopName: '隔離測試店',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A. 完整資料掃描'), findsOneWidget);
    expect(find.text('B. 刪除範圍'), findsOneWidget);
    expect(find.text('C. 安全確認'), findsOneWidget);
    expect(find.text('D. 進度與結果'), findsOneWidget);
    expect(find.text('隔離測試店'), findsOneWidget);
    expect(
      find.textContaining('owner@example.test\nowner-uid'),
      findsOneWidget,
    );
    expect(find.text('17'), findsOneWidget);
    expect(find.text('4'), findsWidgets);

    await tester.tap(find.text('B. 刪除範圍'));
    await tester.pumpAndSettle();
    expect(find.text('bookings'), findsOneWidget);
    expect(find.text('shop_subscription_payments'), findsOneWidget);
    expect(find.text('shops/SHOP9001/'), findsOneWidget);
    expect(find.textContaining('保留'), findsWidgets);

    await tester.tap(find.text('C. 安全確認'));
    await tester.pumpAndSettle();
    expect(find.text('A. 測試重置'), findsOneWidget);
    expect(find.text('B. 正式永久刪除'), findsOneWidget);
    expect(find.textContaining('第一階段仍只允許預覽'), findsOneWidget);
    final Finder startFinder = find.byWidgetPredicate(
      (Widget widget) => widget is FilledButton,
      skipOffstage: false,
    );
    expect(startFinder, findsOneWidget);
    final FilledButton startButton = tester.widget<FilledButton>(startFinder);
    expect(startButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手機採全畫面單欄，既有工作只可唯讀重新載入', (WidgetTester tester) async {
    final _FakeDeletionService service = _FakeDeletionService(
      existingJob: <String, dynamic>{
        'jobId': 'job-1',
        'shopId': 'SHOP9001',
        'shopCode': 'SHOP9001',
        'shopName': '隔離測試店',
        'mode': 'test_reset',
        'status': 'failed',
        'phase': 'storage_direct',
        'deletedFirestore': 3,
        'deletedStorage': 2,
        'failedCount': 1,
        'lastError': '模擬 Storage 失敗',
      },
    );
    await _surface(tester, const Size(390, 820));
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformShopDeletionDialog(
          shopId: 'SHOP9001',
          shopName: '隔離測試店',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final TabController controller = DefaultTabController.of(
      tester.element(find.byType(TabBar)),
    );
    controller.animateTo(3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.index, 3);

    expect(find.text('刪除工作尚未完成'), findsOneWidget);
    expect(find.text('模擬 Storage 失敗'), findsOneWidget);
    expect(find.text('執行與重試已鎖定'), findsOneWidget);
    expect(find.text('重試失敗階段'), findsNothing);
    await tester.ensureVisible(find.text('重新載入進度'));
    await tester.pump();
    await tester.tap(find.text('重新載入進度'));
    await tester.pump();
    expect(service.getJobCount, greaterThanOrEqualTo(2));
    expect(service.runCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Storage 掃描失敗不會顯示假 0 且安全操作保持鎖定', (WidgetTester tester) async {
    final _FakeDeletionService service = _FakeDeletionService(
      storageFailed: true,
    );
    await _surface(tester, const Size(1200, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformShopDeletionDialog(
          shopId: 'SHOP9001',
          shopName: '隔離測試店',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('掃描狀態：部分完成'), findsOneWidget);
    expect(find.text('掃描失敗'), findsWidgets);
    expect(find.text('Storage 檔案'), findsOneWidget);
    expect(find.text('第一階段預覽模式：不會建立或執行刪除工作'), findsOneWidget);
    await tester.tap(find.text('重新掃描'));
    await tester.pumpAndSettle();
    expect(service.previewCount, 2);
  });
}

class _FakeDeletionService implements ShopDeletionGateway {
  _FakeDeletionService({
    Map<String, dynamic>? existingJob,
    this.storageFailed = false,
  }) : currentJob = existingJob;

  Map<String, dynamic>? currentJob;
  final bool storageFailed;
  int runCount = 0;
  int getJobCount = 0;
  int previewCount = 0;

  @override
  Future<Map<String, dynamic>> preview(String shopId) async {
    previewCount += 1;
    return <String, dynamic>{
      'scan': <String, dynamic>{
        'scanId': 'scan-1',
        'status': storageFailed ? 'partial' : 'success',
        'complete': !storageFailed,
        'completedAtMillis': 2,
        'projectId': 'petnest-saas',
        'region': 'asia-east1',
        'failures': storageFailed
            ? <Map<String, dynamic>>[
                <String, dynamic>{
                  'source': 'shops/$shopId/',
                  'errorCode': 'unavailable',
                },
              ]
            : <Map<String, dynamic>>[],
      },
      'shop': <String, dynamic>{
        'shopId': shopId,
        'shopCode': shopId,
        'name': '隔離測試店',
        'ownerUid': 'owner-uid',
        'ownerEmail': 'owner@example.test',
        'ownerResolutionSource': 'shops.ownerUid、shop_members owner',
        'status': 'active',
        'createdAtMillis': 1,
        'updatedAtMillis': 2,
        'updatedAtSource': 'shops.updatedAt',
        'lastActivityAtMillis': 2,
        'lastActivityBasis': 'bookings/b1 的 updatedAt',
      },
      'firestore': <String, dynamic>{
        'status': 'success',
        'complete': true,
        'shopTreeCount': 17,
        'shopTreeStatus': 'success',
        'estimatedDeleteCount': 21,
        'memberCounts': <Map<String, dynamic>>[
          <String, dynamic>{'label': '店家會員', 'count': 4, 'status': 'success'},
        ],
        'collections': <Map<String, dynamic>>[
          <String, dynamic>{
            'collection': 'bookings',
            'classification': 'delete',
            'count': 4,
            'status': 'success',
            'relation': 'shopId == 指定店號',
          },
          <String, dynamic>{
            'collection': 'shop_subscription_payments',
            'classification': 'retain',
            'count': 0,
            'status': 'success',
            'relation': 'shopId == 指定店號',
          },
        ],
      },
      'storage': <String, dynamic>{
        'status': storageFailed ? 'failed' : 'success',
        'complete': !storageFailed,
        'fileCount': storageFailed ? null : 4,
        'totalBytes': storageFailed ? null : 2048,
        'prefixes': <Map<String, dynamic>>[
          <String, dynamic>{
            'prefix': 'shops/$shopId/',
            'count': storageFailed ? null : 4,
            'truncated': false,
            'status': storageFailed ? 'failed' : 'success',
            'ownership': 'confirmed',
            'reason': storageFailed ? '掃描失敗' : '',
          },
        ],
      },
      'transactions': <String, dynamic>{
        'bookingCount': 4,
        'stayBookingCount': 3,
        'daycareBookingCount': 1,
        'paymentCount': 0,
        'sections': <Map<String, dynamic>>[
          <String, dynamic>{'source': 'bookings', 'status': 'success'},
          <String, dynamic>{'source': 'payments', 'status': 'success'},
        ],
      },
      'blockers': <String>[],
    };
  }

  @override
  Future<Map<String, dynamic>> getJob({String? shopId, String? jobId}) async {
    getJobCount += 1;
    return <String, dynamic>{
      'job': currentJob,
      'failures': currentJob == null
          ? <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'failure-1',
                'phase': 'storage_direct',
                'message': '模擬 Storage 失敗',
                'storageObject': 'shops/SHOP9001/logo.jpg',
              },
            ],
    };
  }

  @override
  Future<Map<String, dynamic>> runBatch(String jobId) async {
    runCount += 1;
    currentJob = <String, dynamic>{
      ...?currentJob,
      'jobId': jobId,
      'status': 'completed',
      'phase': 'completed',
      'lastError': '',
    };
    return currentJob!;
  }

  @override
  Future<Map<String, dynamic>> verify(String jobId) async {
    return <String, dynamic>{'complete': true, 'residual': <String>[]};
  }

  @override
  Future<Map<String, dynamic>> createJob({
    required String shopId,
    required String mode,
    required String reason,
    required String typedShopCode,
    required bool irreversibleAcknowledged,
    required bool testDataConfirmed,
  }) {
    throw UnimplementedError();
  }
}

Future<void> _surface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

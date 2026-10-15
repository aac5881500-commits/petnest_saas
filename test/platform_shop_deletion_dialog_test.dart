import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/shop_deletion_service.dart';
import 'package:petnest_saas/features/platform/widgets/platform_shop_deletion_dialog.dart';

void main() {
  testWidgets('桌機顯示簡潔刪除確認，不可刪除時按鈕鎖定', (WidgetTester tester) async {
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

    expect(find.text('完整刪除店家'), findsOneWidget);
    expect(find.text('隔離測試店'), findsOneWidget);
    expect(find.text('SHOP9001'), findsWidgets);
    expect(find.text('安全檢查'), findsOneWidget);
    expect(find.textContaining('不可刪除，原因：仍有待人工確認項目'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    expect(find.text('我確認永久刪除此店家及其專屬資料'), findsOneWidget);
    expect(find.text('寄送驗證碼'), findsOneWidget);
    expect(find.text('重新驗證'), findsNothing);
    expect(find.text('確認永久刪除'), findsOneWidget);
    expect(find.text('查看技術掃描報告'), findsOneWidget);
    expect(find.text('A. 可安全刪除'), findsNothing);
    expect(find.text('申請 Email 驗證碼'), findsNothing);
    final Finder startFinder = find.byWidgetPredicate(
      (Widget widget) => widget is FilledButton,
      skipOffstage: false,
    );
    expect(startFinder, findsOneWidget);
    final FilledButton startButton = tester.widget<FilledButton>(startFinder);
    expect(startButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手機採全畫面單欄，失敗工作可安全重試', (WidgetTester tester) async {
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

    expect(find.text('刪除工作尚未完成'), findsOneWidget);
    expect(find.text('模擬 Storage 失敗'), findsWidgets);
    expect(find.text('安全重試此批次'), findsOneWidget);
    await tester.ensureVisible(find.text('重新載入進度'));
    await tester.pump();
    await tester.tap(find.text('重新載入進度'));
    await tester.pump();
    expect(service.getJobCount, greaterThanOrEqualTo(2));
    await tester.ensureVisible(find.text('安全重試此批次'));
    await tester.tap(find.text('安全重試此批次'));
    await tester.pumpAndSettle();
    expect(service.runCount, 1);
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
    expect(find.text('Storage 實際已掃描檔案'), findsOneWidget);
    expect(find.textContaining('掃描未完成，不能刪除'), findsOneWidget);
    expect(find.textContaining('正式營運店家退場仍鎖定'), findsNothing);
    await tester.tap(find.text('重新掃描'));
    await tester.pumpAndSettle();
    expect(service.previewCount, 2);
  });

  testWidgets('舊版預覽契約不會把 A／B／C 空白誤認為完成', (WidgetTester tester) async {
    final _FakeDeletionService service = _FakeDeletionService(
      legacyContract: true,
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
    expect(find.textContaining('後端預覽契約版本過舊'), findsWidgets);
    expect(find.textContaining('空白冒充完成'), findsOneWidget);
    expect(find.text('版本不符'), findsWidgets);
    expect(find.text('0'), findsNothing);
  });
}

class _FakeDeletionService implements ShopDeletionGateway {
  _FakeDeletionService({
    Map<String, dynamic>? existingJob,
    this.storageFailed = false,
    this.legacyContract = false,
  }) : currentJob = existingJob;

  Map<String, dynamic>? currentJob;
  final bool storageFailed;
  final bool legacyContract;
  int runCount = 0;
  int getJobCount = 0;
  int previewCount = 0;

  @override
  Future<Map<String, dynamic>> preview(String shopId) async {
    previewCount += 1;
    return <String, dynamic>{
      if (!legacyContract) 'contractVersion': 4,
      'scan': <String, dynamic>{
        'scanId': 'scan-1',
        'status': storageFailed ? 'partial' : 'success',
        'complete': !storageFailed,
        'completedAtMillis': 2,
        'expiresAtMillis': DateTime.now()
            .add(const Duration(minutes: 15))
            .millisecondsSinceEpoch,
        'projectId': 'petnest-saas',
        'region': 'asia-east1',
        'sources': <Map<String, dynamic>>[
          <String, dynamic>{
            'source': 'shops/$shopId/**',
            'relation': '主文件 ID 與遞迴子集合',
            'status': 'success',
            'foundCount': 16,
            'classificationSuccessCount': 16,
            'classificationFailedCount': 0,
            'pageComplete': true,
          },
        ],
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
            'classification': 'retain',
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
        'paidPaymentCount': 0,
        'unpaidPaymentCount': 0,
        'refundingPaymentCount': 0,
        'disputeCount': 0,
        'sections': <Map<String, dynamic>>[
          <String, dynamic>{'source': 'bookings', 'status': 'success'},
          <String, dynamic>{'source': 'payments', 'status': 'success'},
        ],
      },
      'ownership': <String, dynamic>{
        'safeDelete': <String, dynamic>{
          'firestoreCount': 21,
          'storageCount': storageFailed ? 0 : 4,
          'storageBytes': storageFailed ? 0 : 2048,
          'complete': !storageFailed,
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'source': 'shops/$shopId/**',
              'dataType': 'firestore',
              'count': 17,
              'status': 'success',
              'reason': '店家專屬子集合',
            },
          ],
        },
        'mustRetain': <String, dynamic>{
          'firestoreCount': 4,
          'storageCount': 1,
          'storageBytes': 512,
          'complete': true,
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'source': 'bookings',
              'dataType': 'firestore',
              'count': 4,
              'status': 'success',
              'reason': '訂單與交易保存政策尚未確認',
            },
            <String, dynamic>{
              'source': 'booking_images/B1/',
              'dataType': 'storage',
              'count': 1,
              'bytes': 512,
              'status': 'success',
              'reason': '付款證明必須保留',
            },
          ],
        },
        'shared': <String, dynamic>{
          'firestoreCount': 4,
          'storageCount': 1,
          'storageBytes': 1024,
          'complete': true,
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'source': 'user_profiles.shopIds',
              'dataType': 'firestore',
              'count': 4,
              'status': 'success',
              'reason': '會員共用主檔',
            },
            <String, dynamic>{
              'source': 'pets/{uid}/（顧客原始照片引用）',
              'dataType': 'storage',
              'count': 1,
              'bytes': 1024,
              'status': 'success',
              'reason': '顧客原始寵物照片必須保留',
              'samplePaths': <String>['pets/customer-1/pet-1.jpg'],
            },
          ],
        },
        'manual': <String, dynamic>{
          'firestoreCount': 1,
          'storageCount': storageFailed ? 0 : 1,
          'storageBytes': storageFailed ? 0 : 256,
          'complete': !storageFailed,
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'source': storageFailed ? 'shops/$shopId/' : 'review_images/B1/',
              'dataType': 'storage',
              'count': storageFailed ? null : 1,
              'bytes': storageFailed ? null : 256,
              'status': storageFailed ? 'failed' : 'success',
              'reason': storageFailed ? '掃描失敗' : '顧客產生內容待確認',
            },
          ],
        },
      },
      'consistency': <String, dynamic>{
        'status': 'success',
        'complete': true,
        'firestore': <String, dynamic>{
          'scannedCount': 30,
          'classifiedCount': 30,
          'unclassifiedCount': 0,
          'rootLinkedCount': 13,
        },
        'storage': <String, dynamic>{
          'scannedFileCount': storageFailed ? 0 : 7,
          'classifiedFileCount': storageFailed ? 0 : 7,
          'unclassifiedFileCount': 0,
          'unresolvedOwnershipCount': storageFailed ? 0 : 1,
          'duplicateReferenceCount': 2,
        },
      },
      'blockerGroups': <String, dynamic>{
        'technical': <Map<String, dynamic>>[
          if (storageFailed)
            <String, dynamic>{
              'title': 'Storage 查詢失敗',
              'count': null,
              'source': 'shops/$shopId/',
              'reason': '掃描失敗',
              'requiresManualAction': true,
              'blocksTestReset': true,
              'blocksPermanentDeletion': true,
            },
        ],
        'retention': <Map<String, dynamic>>[
          <String, dynamic>{
            'title': '付款紀錄',
            'count': 0,
            'source': 'payments',
            'reason': '交易資料保留',
            'requiresManualAction': false,
            'blocksTestReset': false,
            'blocksPermanentDeletion': true,
          },
        ],
        'business': <Map<String, dynamic>>[],
        'safety': <Map<String, dynamic>>[
          <String, dynamic>{
            'title': '永久刪除安全鎖已關閉',
            'count': 1,
            'source': 'PHASE_ONE_PREVIEW_ONLY',
            'reason': '只允許預覽',
            'requiresManualAction': false,
            'blocksTestReset': true,
            'blocksPermanentDeletion': true,
          },
        ],
      },
      'execution': <String, dynamic>{
        'enabled': true,
        'cleanupAllowed': false,
        'cleanupCategory': 'blocked',
        'cleanupLabel': '',
        'cleanupBlockers': <String>['仍有待人工確認項目'],
        'testResetAllowed': false,
        'inactiveCleanupAllowed': false,
        'testResetBlockers': <String>['仍有待人工確認項目'],
        'inactiveCleanupBlockers': <String>['仍有訂單或最後活動時間不足'],
        'permanentDeletionAllowed': false,
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
  Future<Map<String, dynamic>> requestEmailCode({
    required String shopId,
    required String mode,
    required String previewScanId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> createJob({
    required String shopId,
    required String mode,
    required String reason,
    required String typedShopCode,
    required bool irreversibleAcknowledged,
    required bool scopeConfirmed,
    required bool testDataConfirmed,
    required String previewScanId,
    required String emailChallengeId,
    required String emailCode,
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

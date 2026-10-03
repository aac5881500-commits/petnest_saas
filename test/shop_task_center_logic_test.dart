// 檔案名稱：test/shop_task_center_logic_test.dart
// 功能說明：待辦分類隔離、照護缺紀錄與攝影機待辦計算。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/camera_access_policy.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/shop_task_item.dart';
import 'package:petnest_saas/core/services/daily_care_record_service.dart';
import 'package:petnest_saas/core/services/shop_task_center_service.dart';

void main() {
  test('缺少的照護紀錄不算完成，草稿也不算完成', () {
    final DateTime day = DateTime(2026, 10, 3);
    final String doneId = DailyCareRecordService.recordId(
      bookingId: 'b1',
      recordDate: day,
      sessionIndex: 0,
    );
    final String missingId = DailyCareRecordService.recordId(
      bookingId: 'b1',
      recordDate: day,
      sessionIndex: 1,
    );
    final Set<String> done = completedCareRecordIds(<DailyCareRecordModel>[
      _record(id: doneId, status: 'completed', note: '已吃'),
      _record(id: 'draft', status: 'draft', note: '還沒確認'),
    ]);

    expect(done.contains(doneId), isTrue);
    expect(done.contains(missingId), isFalse);
    expect(done.contains('draft'), isFalse);
    expect(careRecordQueryDay(day), DateTime(2026, 10, 3));
  });

  test('照護讀取中不先當成待填，單一分類失敗仍保留其他分類', () {
    const ShopTaskItem booking = ShopTaskItem(
      id: 'booking_1',
      type: ShopTaskType.booking,
      shopId: 'shop',
      title: '新預約',
      subtitle: '客人',
      statusLabel: '待確認',
      targetType: 'booking',
      targetId: '1',
    );
    const ShopTaskCenterSnapshot loadingCare = ShopTaskCenterSnapshot(
      items: <ShopTaskItem>[booking],
      bookingEnabled: true,
      careEnabled: true,
      careLoading: true,
      cameraEnabled: true,
      cameraErrorCode: 'permission-denied',
      cameraErrorSource: 'camera_access_requests.active',
    );

    expect(loadingCare.ofType(ShopTaskType.dailyCare), isEmpty);
    expect(loadingCare.bookingCount, 1);
    expect(loadingCare.isAllClear, isFalse);
    expect(loadingCare.hasLaneError, isTrue);
    expect(
      shopTaskLaneErrorMessage(laneLabel: '攝影機分享', code: 'permission-denied'),
      contains('沒有讀取權限'),
    );
    expect(
      shopTaskLaneErrorMessage(laneLabel: '每日照護', code: 'failed-precondition'),
      contains('索引'),
    );
    expect(
      shopTaskLaneErrorMessage(laneLabel: '訂單', code: 'unavailable'),
      contains('網路'),
    );
  });

  test('只有待邀請和待取消列入店主待辦，分享帳號不進待辦', () {
    final List<ShopTaskItem> items = cameraOwnerTasks(
      shopId: 'shop',
      requests: <Map<String, dynamic>>[
        <String, dynamic>{
          'requestId': 'req-pending',
          'status': cameraRequestPending,
          'roomName': 'A01',
          'customerName': '小明',
          'provider': 'xiaomi',
          'createdAt': DateTime(2026, 10, 3, 9, 5),
          'externalAccount': 'secret@xiaomi.com',
        },
        <String, dynamic>{
          'requestId': 'req-revoke',
          'status': cameraRequestRevocationPending,
          'roomName': 'B02',
          'customerName': '小華',
          'provider': 'xiaomi',
        },
        <String, dynamic>{
          'requestId': 'req-info',
          'status': cameraRequestNeedsInfo,
          'externalAccount': 'secret@xiaomi.com',
        },
        <String, dynamic>{
          'requestId': 'req-invited',
          'status': cameraRequestInvited,
        },
        <String, dynamic>{
          'requestId': 'req-confirmed',
          'status': cameraRequestConfirmed,
        },
        <String, dynamic>{
          'requestId': 'req-closed',
          'status': cameraRequestClosed,
        },
      ],
    );

    expect(items.map((ShopTaskItem item) => item.targetId), <String>[
      'req-pending',
      'req-revoke',
    ]);
    expect(items.first.title, 'A01');
    expect(items.first.statusLabel, '待邀請');
    expect(items.first.subtitle, contains('小明'));
    expect(items.first.subtitle, contains('待邀請'));
    expect(items.last.statusLabel, '待取消分享');
    for (final ShopTaskItem item in items) {
      expect(item.metadata.containsKey('externalAccount'), isFalse);
      expect(item.subtitle.contains('secret@xiaomi.com'), isFalse);
      expect(item.title.contains('secret@xiaomi.com'), isFalse);
    }
  });

  test('分享申請錯誤依代碼分開，不一律說權限不足', () {
    expect(
      cameraAccessQueryErrorMessage(
        code: 'permission-denied',
        source: '進行中的分享申請',
      ),
      contains('管理攝影機權限'),
    );
    expect(
      cameraAccessQueryErrorMessage(
        code: 'failed-precondition',
        source: '已結束的分享申請',
      ),
      contains('索引'),
    );
    expect(
      cameraAccessQueryErrorMessage(code: 'unavailable', source: '進行中的分享申請'),
      contains('網路'),
    );
    expect(
      cameraAccessQueryErrorMessage(code: 'unknown', source: '進行中的分享申請'),
      isNot(contains('管理攝影機權限')),
    );
  });

  test('空店家的待辦綁定不會留下監聽', () async {
    final ShopTaskCenterBinding binding = ShopTaskCenterBinding(
      shopId: ' ',
      canViewBookings: true,
      canFillDailyCare: true,
      canManageDevices: true,
    );
    final ShopTaskCenterSnapshot snapshot = await binding.snapshots.first;
    expect(snapshot.items, isEmpty);
    binding.close();
    binding.close();
  });
}

DailyCareRecordModel _record({
  required String id,
  required String status,
  required String note,
}) {
  return DailyCareRecordModel(
    id: id,
    shopId: 'shop',
    bookingId: 'b1',
    roomId: 'room',
    roomName: 'A01',
    recordDate: DateTime(2026, 10, 3),
    sessionIndex: 0,
    sessionName: '第一場',
    values: <String, dynamic>{'note': note},
    petNotes: const <String, String>{},
    photoCount: 0,
    createdAt: DateTime(2026, 10, 3),
    updatedAt: DateTime(2026, 10, 3),
    reportStatus: status,
  );
}

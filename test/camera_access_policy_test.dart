// 檔案名稱：test/camera_access_policy_test.dart
// 功能說明：攝影機模式、服務期間與米家申請狀態。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/camera_access_policy.dart';
import 'package:petnest_saas/core/models/camera_brand.dart';
import 'package:petnest_saas/features/booking/widgets/camera_brand_launch.dart';

void main() {
  test('舊網址設備沒有新欄位仍可使用', () {
    final Map<String, dynamic> device = <String, dynamic>{
      'type': 'camera',
      'url': 'https://cam.example/live',
    };
    expect(cameraViewModeOf(device), cameraViewWebUrl);
    expect(cameraSetupComplete(device), isTrue);
  });

  test('米家設備沒有網址仍可啟用', () {
    final Map<String, dynamic> device = <String, dynamic>{
      'type': 'camera',
      'viewMode': cameraViewExternalApp,
      'provider': cameraProviderXiaomi,
      'url': '',
      'note': '店內備註',
    };
    expect(cameraSetupComplete(device), isTrue);
    expect(cameraIsDirectHttps(''), isFalse);
  });

  test('服務中才可看，退房與安親實際結束後關閉', () {
    expect(
      cameraServiceOpen(<String, dynamic>{
        'status': 'checked_in',
        'roomId': 'r1',
      }),
      isTrue,
    );
    expect(
      cameraServiceOpen(<String, dynamic>{
        'status': 'checked_in',
        'roomId': 'r1',
        'checkOutAt': '2026-10-02',
      }),
      isFalse,
    );
    expect(
      cameraServiceOpen(<String, dynamic>{
        'status': 'checked_in',
        'roomId': 'r1',
        'bookingKind': 'daycare',
        'scheduledEndAt': '2026-10-02',
      }),
      isTrue,
    );
    expect(
      cameraServiceOpen(<String, dynamic>{
        'status': 'checked_in',
        'roomId': 'r1',
        'bookingKind': 'daycare',
        'actualEndAt': '2026-10-02T10:00:00Z',
      }),
      isFalse,
    );
  });

  test('重複提交不新增，邀請後換帳號與換房保留取消待辦', () {
    final Map<String, dynamic> pending = <String, dynamic>{
      'status': cameraRequestPending,
      'deviceId': 'd1',
      'externalAccount': '0912000111',
    };
    expect(
      planCameraCustomerSubmit(
        current: pending,
        account: '0912000111',
        deviceId: 'd1',
      ).type,
      'noop',
    );
    expect(
      planCameraCustomerSubmit(
        current: pending,
        account: '0912000222',
        deviceId: 'd1',
      ).type,
      'update',
    );
    final Map<String, dynamic> invited = <String, dynamic>{
      'status': cameraRequestInvited,
      'deviceId': 'd1',
      'roomId': 'old',
      'externalAccount': 'old@example.com',
      'invitedAt': 't',
    };
    expect(
      planCameraCustomerSubmit(
        current: invited,
        account: 'new@example.com',
        deviceId: 'd1',
      ).type,
      'replace',
    );
    expect(
      cameraStopSharingPatch(invited, 'room_changed', 'now')?['status'],
      cameraRequestRevocationPending,
    );
    final Map<String, dynamic>? again = cameraStopSharingPatch(
      <String, dynamic>{...invited, 'status': cameraRequestRevocationPending},
      'room_changed',
      'later',
    );
    expect(again, isNull);
    final Map<String, dynamic> fresh = <String, dynamic>{
      'status': cameraRequestPending,
      'roomId': 'old',
    };
    expect(
      cameraStopSharingPatch(fresh, 'stay_ended', 'now')?['status'],
      cameraRequestClosed,
    );
    expect(
      cameraStopSharingPatch(
        fresh,
        'stay_ended',
        'now',
      )?.containsKey('revocationRequestedAt'),
      isFalse,
    );
  });

  test('顧客不能偽造店家狀態，停用與鎖定後不能再當可觀看設備', () {
    expect(cameraCustomerActionForbidden('mark_invited'), isTrue);
    expect(cameraCustomerActionForbidden('mark_revoked'), isTrue);
    expect(
      planCameraShopAction(
        <String, dynamic>{'status': cameraRequestPending},
        'mark_revoked',
        '',
      ).ok,
      isFalse,
    );
    expect(
      planCameraShopAction(
        <String, dynamic>{'status': cameraRequestInvited, 'invitedAt': 't'},
        'mark_revoked',
        '',
      ).status,
      cameraRequestClosed,
    );
    expect(plausibleMiHomeAccount('0912345678'), isTrue);
    expect(plausibleMiHomeAccount('user@example.com'), isTrue);
    expect(plausibleMiHomeAccount('a'), isFalse);
    final Map<String, dynamic> locked = <String, dynamic>{
      'type': 'camera',
      'viewMode': cameraViewExternalApp,
      'provider': cameraProviderXiaomi,
      'enabled': false,
      'platformLocked': true,
    };
    expect(cameraSetupComplete(locked), isTrue);
    expect(locked['platformLocked'], isTrue);
  });

  test('需補資料同帳號重送回待處理，待處理同帳號仍去重', () {
    expect(
      planCameraCustomerSubmit(
        current: <String, dynamic>{
          'status': cameraRequestNeedsInfo,
          'deviceId': 'd1',
          'externalAccount': '0912000111',
        },
        account: '0912000111',
        deviceId: 'd1',
      ).type,
      'update',
    );
    expect(
      planCameraCustomerSubmit(
        current: <String, dynamic>{
          'status': cameraRequestPending,
          'deviceId': 'd1',
          'externalAccount': '0912000111',
        },
        account: '0912000111',
        deviceId: 'd1',
      ).type,
      'noop',
    );
  });

  test('未知品牌不當成小米，需補資料篩選只看到該狀態', () {
    expect(
      cameraSetupComplete(<String, dynamic>{
        'type': 'camera',
        'viewMode': cameraViewExternalApp,
        'provider': 'tapo',
        'enabled': true,
      }),
      isFalse,
    );
    expect(cameraBrandLabel('tapo'), isEmpty);
    expect(cameraBrandLabel('xiaomi'), '小米／米家');
    expect(
      cameraRequestMatchesFilter(
        cameraRequestNeedsInfo,
        cameraRequestNeedsInfo,
      ),
      isTrue,
    );
    expect(
      cameraRequestMatchesFilter(cameraRequestPending, cameraRequestNeedsInfo),
      isFalse,
    );
  });

  test('已取消分享不會被同步改回，換房後舊網址結果不可沿用', () {
    expect(
      commitCameraSyncWrite(
        <String, dynamic>{'status': cameraRequestClosed, 'closedAt': 'kept'},
        'stay_ended',
        'later',
      ),
      isNull,
    );
    final Map<String, dynamic> invited = <String, dynamic>{
      'status': cameraRequestInvited,
      'roomId': 'old',
      'invitedAt': 't',
    };
    final String reason = cameraRequestSyncReason(
      invited,
      booking: <String, dynamic>{
        'status': 'checked_out',
        'roomId': 'old',
        'checkOutAt': 't',
      },
    );
    expect(
      commitCameraSyncWrite(invited, reason, 'now')?['status'],
      cameraRequestRevocationPending,
    );
    expect(
      cameraGateResultIsCurrent(
        requestTicket: 1,
        currentTicket: 2,
        requestBookingId: 'old-room-booking',
        currentBookingId: 'old-room-booking',
      ),
      isFalse,
    );
    expect(
      cameraGateResultIsCurrent(
        requestTicket: 3,
        currentTicket: 3,
        requestBookingId: 'a',
        currentBookingId: 'b',
      ),
      isFalse,
    );
  });

  testWidgets('確認失敗訊息在非編輯狀態仍可見', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CameraRequestFailureBanner(message: '不能確認可觀看')),
      ),
    );
    expect(find.byKey(const Key('camera-request-failure')), findsOneWidget);
    expect(find.text('不能確認可觀看'), findsOneWidget);
  });
}

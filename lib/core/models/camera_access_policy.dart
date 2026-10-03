// 檔案名稱：lib/core/models/camera_access_policy.dart
// 功能說明：攝影機觀看模式與米家分享申請狀態。舊設備沒有模式時視為網址觀看。

import 'package:petnest_saas/core/models/camera_brand.dart';

const String cameraViewWebUrl = 'web_url';
const String cameraViewExternalApp = 'external_app';
const String cameraProviderXiaomi = 'xiaomi';

const String cameraRequestPending = 'pending';
const String cameraRequestNeedsInfo = 'needs_info';
const String cameraRequestInvited = 'invited';
const String cameraRequestConfirmed = 'customer_confirmed';
const String cameraRequestRevocationPending = 'revocation_pending';
const String cameraRequestClosed = 'closed';

String cameraViewModeOf(Map<String, dynamic>? device) {
  final String mode = (device?['viewMode'] ?? '').toString().trim();
  if (mode == cameraViewExternalApp) {
    return cameraViewExternalApp;
  }
  return cameraViewWebUrl;
}

bool cameraIsDirectHttps(String raw) {
  final Uri? uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.isScheme('https')) {
    return false;
  }
  return uri.host.trim().isNotEmpty;
}

bool cameraSetupComplete(Map<String, dynamic>? device) {
  if (device == null) {
    return false;
  }
  final String type = (device['type'] ?? 'camera').toString();
  if (type != 'camera') {
    return false;
  }
  if (cameraViewModeOf(device) == cameraViewExternalApp) {
    return cameraBrandSupportsAccountShare(
      (device['provider'] ?? '').toString(),
    );
  }
  return cameraIsDirectHttps((device['url'] ?? '').toString());
}

bool cameraIsDaycareBooking(Map<String, dynamic>? booking) {
  final String kind = (booking?['bookingKind'] ?? '').toString().trim();
  final String service = (booking?['serviceType'] ?? '').toString().trim();
  return kind == 'daycare' || service == 'daycare';
}

bool _hasValue(Object? value) {
  return value != null && value.toString().trim().isNotEmpty;
}

bool cameraServiceOpen(Map<String, dynamic>? booking) {
  if (booking == null) {
    return false;
  }
  final String status = (booking['status'] ?? '').toString().trim();
  final String roomId = (booking['roomId'] ?? '').toString().trim();
  if (roomId.isEmpty || status == 'cancelled') {
    return false;
  }
  if (cameraIsDaycareBooking(booking)) {
    if (_hasValue(booking['actualEndAt'])) {
      return false;
    }
    if (status == 'completed' || status == 'checked_out') {
      return false;
    }
    return status == 'checked_in';
  }
  if (status != 'checked_in') {
    return false;
  }
  if (_hasValue(booking['checkOutAt']) || _hasValue(booking['checkedOutAt'])) {
    return false;
  }
  if (booking['stayRoomReleased'] == true) {
    return false;
  }
  return true;
}

bool cameraInvitationWasSent(Map<String, dynamic>? request) {
  if (request == null) {
    return false;
  }
  if (_hasValue(request['invitedAt'])) {
    return true;
  }
  final String status = (request['status'] ?? '').toString();
  return status == cameraRequestInvited ||
      status == cameraRequestConfirmed ||
      status == cameraRequestRevocationPending;
}

Map<String, dynamic>? cameraStopSharingPatch(
  Map<String, dynamic> request,
  String reason,
  String now,
) {
  final String status = (request['status'] ?? '').toString();
  if (status == cameraRequestClosed ||
      status == cameraRequestRevocationPending) {
    return null;
  }
  if (cameraInvitationWasSent(request)) {
    return <String, dynamic>{
      'status': cameraRequestRevocationPending,
      'revocationReason': reason,
      'revocationRequestedAt': request['revocationRequestedAt'] ?? now,
      'updatedAt': now,
    };
  }
  return <String, dynamic>{
    'status': cameraRequestClosed,
    'closeReason': reason,
    'closedAt': request['closedAt'] ?? now,
    'updatedAt': now,
  };
}

class CameraSubmitPlan {
  const CameraSubmitPlan(this.type, [this.reason = '']);

  final String type;
  final String reason;
}

CameraSubmitPlan planCameraCustomerSubmit({
  Map<String, dynamic>? current,
  required String account,
  required String deviceId,
}) {
  if (current == null) {
    return const CameraSubmitPlan('create');
  }
  final String status = (current['status'] ?? '').toString();
  if (status == cameraRequestClosed ||
      status == cameraRequestRevocationPending) {
    return const CameraSubmitPlan('create');
  }
  final String currentDevice = (current['deviceId'] ?? '').toString().trim();
  if (currentDevice.isNotEmpty &&
      deviceId.isNotEmpty &&
      currentDevice != deviceId) {
    if (cameraInvitationWasSent(current)) {
      return const CameraSubmitPlan('replace', 'device_changed');
    }
    return const CameraSubmitPlan('retarget');
  }
  final bool same =
      (current['externalAccount'] ?? '').toString().trim() == account;
  if (status == cameraRequestPending) {
    return CameraSubmitPlan(same ? 'noop' : 'update');
  }
  if (status == cameraRequestNeedsInfo) {
    return const CameraSubmitPlan('update');
  }
  if (status == cameraRequestInvited || status == cameraRequestConfirmed) {
    return CameraSubmitPlan(
      same ? 'noop' : 'replace',
      same ? '' : 'account_changed',
    );
  }
  return const CameraSubmitPlan('create');
}

bool cameraCustomerActionForbidden(String action) {
  return action == 'mark_invited' ||
      action == 'needs_info' ||
      action == 'mark_revoked';
}

class CameraShopActionPlan {
  const CameraShopActionPlan({
    required this.ok,
    this.message = '',
    this.status = '',
    this.closeReason = '',
  });

  final bool ok;
  final String message;
  final String status;
  final String closeReason;
}

CameraShopActionPlan planCameraShopAction(
  Map<String, dynamic> request,
  String action,
  String reason,
) {
  final String status = (request['status'] ?? '').toString();
  final String note = reason.trim();
  if (action == 'mark_invited') {
    if (status != cameraRequestPending && status != cameraRequestNeedsInfo) {
      return const CameraShopActionPlan(ok: false, message: '此申請目前不能標記為已發送邀請');
    }
    return const CameraShopActionPlan(ok: true, status: cameraRequestInvited);
  }
  if (action == 'needs_info') {
    if (note.isEmpty) {
      return const CameraShopActionPlan(ok: false, message: '請填寫需要顧客補充的說明');
    }
    if (status != cameraRequestPending && status != cameraRequestNeedsInfo) {
      return const CameraShopActionPlan(ok: false, message: '此申請目前不能要求補充資料');
    }
    return const CameraShopActionPlan(ok: true, status: cameraRequestNeedsInfo);
  }
  if (action == 'mark_revoked') {
    if (status == cameraRequestClosed) {
      return const CameraShopActionPlan(ok: false, message: '此申請已結束');
    }
    if (!cameraInvitationWasSent(request)) {
      return const CameraShopActionPlan(ok: false, message: '尚未發送邀請，不需要取消分享');
    }
    if (status != cameraRequestInvited &&
        status != cameraRequestConfirmed &&
        status != cameraRequestRevocationPending) {
      return const CameraShopActionPlan(ok: false, message: '此申請目前不能確認取消分享');
    }
    return const CameraShopActionPlan(
      ok: true,
      status: cameraRequestClosed,
      closeReason: 'share_removed',
    );
  }
  return const CameraShopActionPlan(ok: false, message: '不支援的操作');
}

bool plausibleMiHomeAccount(String raw) {
  return plausibleCameraBrandAccount(cameraProviderXiaomi, raw);
}

String cameraRequestSyncReason(
  Map<String, dynamic> request, {
  Map<String, dynamic>? booking,
  Map<String, dynamic>? device,
  bool shopCameraOn = true,
}) {
  if (booking != null) {
    if ((booking['status'] ?? '').toString().trim() == 'cancelled') {
      return 'cancelled';
    }
    final String afterRoom = (booking['roomId'] ?? '').toString().trim();
    final String requestRoom = (request['roomId'] ?? '').toString().trim();
    if (requestRoom.isNotEmpty &&
        afterRoom.isNotEmpty &&
        requestRoom != afterRoom) {
      return 'room_changed';
    }
    if (!cameraServiceOpen(booking)) {
      return cameraIsDaycareBooking(booking) ? 'daycare_ended' : 'stay_ended';
    }
  }
  if (device != null) {
    final String deviceRoom = (device['roomId'] ?? '').toString().trim();
    final String requestRoom = (request['roomId'] ?? '').toString().trim();
    if (deviceRoom.isNotEmpty &&
        requestRoom.isNotEmpty &&
        deviceRoom != requestRoom) {
      return 'device_moved';
    }
    final bool shareable =
        shopCameraOn &&
        cameraViewModeOf(device) == cameraViewExternalApp &&
        cameraBrandSupportsAccountShare(
          (device['provider'] ?? '').toString(),
        ) &&
        device['enabled'] == true &&
        device['platformLocked'] != true &&
        cameraSetupComplete(device);
    if (!shareable) {
      if (!shopCameraOn) {
        return 'shop_camera_off';
      }
      if (device['platformLocked'] == true) {
        return 'platform_locked';
      }
      if (device['enabled'] != true) {
        return 'device_disabled';
      }
      if (cameraViewModeOf(device) != cameraViewExternalApp) {
        return 'view_mode_changed';
      }
      return 'unsupported_brand';
    }
  }
  if (!shopCameraOn) {
    return 'shop_camera_off';
  }
  return '';
}

Map<String, dynamic>? commitCameraSyncWrite(
  Map<String, dynamic> latest,
  String reason,
  String now,
) {
  if (reason.isEmpty ||
      (latest['status'] ?? '').toString() == cameraRequestClosed) {
    return null;
  }
  final Map<String, dynamic>? patch = cameraStopSharingPatch(
    latest,
    reason,
    now,
  );
  if (patch == null) {
    return null;
  }
  final Map<String, dynamic> write = <String, dynamic>{
    'status': patch['status'],
    'updatedAt': now,
  };
  if (patch['status'] == cameraRequestRevocationPending) {
    if ((latest['revocationReason'] ?? '').toString().trim().isEmpty) {
      write['revocationReason'] = reason;
    }
    if (latest['revocationRequestedAt'] == null) {
      write['revocationRequestedAt'] = now;
    }
  }
  if (patch['status'] == cameraRequestClosed) {
    if ((latest['closeReason'] ?? '').toString().trim().isEmpty) {
      write['closeReason'] = patch['closeReason'] ?? reason;
    }
    if (latest['closedAt'] == null) {
      write['closedAt'] = now;
    }
  }
  return write;
}

/// 店家讀取分享申請失敗時，依 Firebase code 分開說明。
/// 不把索引或網路問題寫成權限不足。
String cameraAccessQueryErrorMessage({
  required String code,
  required String source,
}) {
  switch (code) {
    case 'permission-denied':
      return '沒有管理攝影機權限，無法讀取$source。';
    case 'failed-precondition':
      return '$source查詢尚未就緒，請先部署對應索引後再試。';
    case 'unavailable':
    case 'deadline-exceeded':
    case 'network-request-failed':
      return '網路不穩，$source讀取失敗，請再試一次。';
    default:
      return '$source讀取失敗（$code），請再試一次。';
  }
}

String cameraRequestStatusLabel(String status) {
  switch (status) {
    case cameraRequestPending:
      return '待處理';
    case cameraRequestNeedsInfo:
      return '需要補充資料';
    case cameraRequestInvited:
      return '已發送邀請';
    case cameraRequestConfirmed:
      return '已確認可觀看';
    case cameraRequestRevocationPending:
      return '待取消分享';
    case cameraRequestClosed:
      return '已結束';
    default:
      return '待處理';
  }
}

const String cameraRequestFilterAll = 'all';

bool cameraRequestMatchesFilter(String status, String filter) {
  if (filter == cameraRequestFilterAll) {
    return true;
  }
  return status == filter;
}

String cameraViewModeLabel(String mode) {
  if (mode == cameraViewExternalApp) {
    return '外部 App';
  }
  return '網址觀看';
}

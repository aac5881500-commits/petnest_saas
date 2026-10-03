// 檔案名稱：lib/core/models/camera_entry_watch.dart
// 功能說明：顧客攝影機入口的房間訊號、按鈕名稱與讀取失敗訊息。訊號不含網址或帳號。

import 'package:petnest_saas/core/models/camera_brand.dart';

const Duration cameraEntryReloadDelay = Duration(milliseconds: 350);

class CameraEntryWatch {
  const CameraEntryWatch({
    required this.bookingId,
    required this.shopId,
    required this.roomId,
    required this.serviceOpen,
    required this.shopCameraOn,
    required this.roomRevision,
  });

  final String bookingId;
  final String shopId;
  final String roomId;
  final bool serviceOpen;
  final bool shopCameraOn;
  final int roomRevision;

  String get key =>
      '$bookingId|$shopId|$roomId|$serviceOpen|$shopCameraOn|$roomRevision';
}

bool cameraEntryShouldReload(
  CameraEntryWatch? previous,
  CameraEntryWatch next,
) {
  if (previous == null) {
    return true;
  }
  return previous.key != next.key;
}

int cameraRoomRevisionOf(Map<String, dynamic>? room) {
  final Object? value = room?['cameraRevision'];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

bool shopCameraSectionOn(Map<String, dynamic>? shop) {
  if (shop == null) {
    return true;
  }
  return shop['showCameraSection'] != false;
}

List<String> cameraSignalRoomIds(
  Map<String, dynamic>? before,
  Map<String, dynamic>? after,
) {
  final List<String> ids = <String>[];
  for (final Map<String, dynamic>? data in <Map<String, dynamic>?>[
    before,
    after,
  ]) {
    if (data == null || (data['type'] ?? '').toString() != 'camera') {
      continue;
    }
    final String roomId = (data['roomId'] ?? '').toString().trim();
    if (roomId.isNotEmpty && !ids.contains(roomId)) {
      ids.add(roomId);
    }
  }
  return ids;
}

String customerCameraEntryTitle({
  required String viewMode,
  required String provider,
}) {
  if (viewMode != 'external_app') {
    return '觀看攝影機';
  }
  final CameraBrand? brand = cameraBrandById(provider);
  if (brand == null) {
    return '品牌尚未開放';
  }
  if (brand.id == cameraBrandXiaomi.id) {
    return '米家攝影機';
  }
  return '${brand.appName}攝影機';
}

String customerCameraEntrySubtitle({
  required String viewMode,
  required String provider,
  required String appName,
}) {
  if (viewMode != 'external_app') {
    return '開啟店家提供的攝影機畫面。已開啟的網址無法由 PetNest 自動撤銷。';
  }
  final CameraBrand? brand = cameraBrandById(provider);
  if (brand == null) {
    return '此品牌尚未開放，不能改用其他品牌觀看。';
  }
  final String name = appName.trim().isEmpty ? brand.appName : appName.trim();
  return '透過$name觀看。PetNest 不會自動移除原廠 App 的分享權限。';
}

String customerCameraIdentity({
  required String roomId,
  required String deviceId,
  required String viewMode,
  required String provider,
}) {
  return '$roomId|$deviceId|$viewMode|$provider';
}

String customerCameraFailureMessage({
  required String code,
  String message = '',
}) {
  switch (code) {
    case 'unauthenticated':
      return '請重新登入後再試';
    case 'unavailable':
    case 'deadline-exceeded':
    case 'resource-exhausted':
    case 'network-request-failed':
      return '網路不穩定，請再試一次';
    case 'permission-denied':
      return '目前無法查看攝影機';
    case 'not-found':
      final String lower = message.toLowerCase();
      if (lower.contains('not found') ||
          lower.contains('not_found') ||
          message.trim().isEmpty) {
        return '攝影機暫時無法讀取，請再試一次';
      }
      return '找不到這筆訂單';
    default:
      return '攝影機暫時無法讀取，請再試一次';
  }
}

String cameraCallableDiagnostic({
  required String name,
  required String region,
  required String code,
  String message = '',
}) {
  final String safe = message
      .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '[url]')
      .replaceAll(RegExp(r'\S+@\S+'), '[account]');
  return 'callable $name region=$region code=$code message=$safe';
}

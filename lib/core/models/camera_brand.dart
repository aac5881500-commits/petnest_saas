// 檔案名稱：lib/core/models/camera_brand.dart
// 功能說明：外部攝影機品牌目錄。第一版只開放小米／米家，未知品牌不當成小米。

class CameraBrand {
  const CameraBrand({
    required this.id,
    required this.label,
    required this.appName,
    required this.accountShare,
    required this.accountLabel,
    required this.accountHint,
    required this.searchName,
    required this.androidStoreUrl,
    required this.iosStoreUrl,
    required this.launchSupported,
    required this.guide,
  });

  final String id;
  final String label;
  final String appName;
  final bool accountShare;
  final String accountLabel;
  final String accountHint;
  final String searchName;
  final String androidStoreUrl;
  final String iosStoreUrl;
  final bool launchSupported;
  final List<String> guide;
}

const CameraBrand cameraBrandXiaomi = CameraBrand(
  id: 'xiaomi',
  label: '小米／米家',
  appName: '米家',
  accountShare: true,
  accountLabel: '米家帳號',
  accountHint: '可填手機號碼、Email 或小米帳號。實際格式以米家分享畫面為準，不代表所有型號相同。',
  searchName: '米家',
  androidStoreUrl:
      'https://play.google.com/store/apps/details?id=com.xiaomi.smarthome',
  iosStoreUrl: '',
  launchSupported: false,
  guide: <String>[
    '安裝並登入要接受分享的米家帳號。',
    '在 PetNest 填寫該帳號，不要填密碼。',
    '店家到米家手動分享設備。',
    '顧客在米家接受邀請。PetNest 只記錄處理狀態。',
  ],
);

const List<CameraBrand> cameraReleasedBrands = <CameraBrand>[cameraBrandXiaomi];

CameraBrand? cameraBrandById(String? providerId) {
  final String id = (providerId ?? '').trim();
  for (final CameraBrand brand in cameraReleasedBrands) {
    if (brand.id == id) {
      return brand;
    }
  }
  return null;
}

bool cameraBrandSupportsAccountShare(String? providerId) {
  final CameraBrand? brand = cameraBrandById(providerId);
  return brand != null && brand.accountShare;
}

bool plausibleCameraBrandAccount(String? providerId, String raw) {
  final CameraBrand? brand = cameraBrandById(providerId);
  if (brand == null || !brand.accountShare) {
    return false;
  }
  if (brand.id == cameraBrandXiaomi.id) {
    return _plausibleXiaomiAccount(raw);
  }
  return false;
}

bool _plausibleXiaomiAccount(String raw) {
  final String value = raw.trim();
  if (value.length < 3 || value.length > 80) {
    return false;
  }
  if (RegExp(r'\s').hasMatch(value)) {
    return false;
  }
  return RegExp(r'^[0-9A-Za-z@.+_-]+$').hasMatch(value);
}

String cameraBrandLabel(String? providerId) {
  return cameraBrandById(providerId)?.label ?? '';
}

String cameraExternalWatchReminder(String? providerId) {
  final CameraBrand? brand = cameraBrandById(providerId);
  final String appName = brand?.appName ?? '原廠 App';
  return '此攝影機需透過 $appName 觀看。PetNest 負責分享申請與處理紀錄，店家需在原廠 App 發送邀請。';
}

String cameraSyncReasonLabel(String reason) {
  switch (reason) {
    case 'cancelled':
      return '訂單取消';
    case 'room_changed':
      return '換房';
    case 'stay_ended':
      return '退房';
    case 'daycare_ended':
      return '安親結束';
    case 'device_moved':
      return '設備換房';
    case 'device_changed':
      return '更換設備';
    case 'device_disabled':
      return '設備停用';
    case 'platform_locked':
      return '平台鎖定';
    case 'shop_camera_off':
      return '店家關閉攝影機';
    case 'view_mode_changed':
      return '觀看方式變更';
    case 'account_changed':
      return '更換帳號';
    case 'unsupported_brand':
      return '品牌未開放';
    case 'share_removed':
      return '店家已在原廠 App 移除';
    default:
      return reason.trim().isEmpty ? '' : reason;
  }
}

// lib/core/constants/shop_permission_keys.dart
// 🔐 店家後台權限 Key 定義
//
// 用途：
// - 控制店家員工可使用哪些功能
// - owner 預設全權限
// - manager / staff 可依權限開關控制
//
// 注意：
// - 新增功能時，記得同步加入 all
// - Firestore 權限資料會依照這些 key 儲存

class ShopPermissionKeys {
  /// 👥 會員管理
  static const manageMembers = 'manage_members';

  /// 🏪 修改店家基本資料
  static const editBasicInfo = 'edit_basic_info';

  /// ⏰ 修改營業資訊
  static const editBusinessInfo = 'edit_business_info';

  /// 🖼️ 修改 Logo / 封面
  static const editMedia = 'edit_media';

  /// 🌿 管理環境介紹
  static const manageEnvironment = 'manage_environment';

  /// ❤️ 管理關於我們
  static const manageAbout = 'manage_about';

  /// 🧩 管理模組設定
  static const manageModules = 'manage_modules';

  /// 📅 管理預約功能
  static const manageBookings = 'manage_bookings';

  static const manageRoomDashboard = 'manage_room_dashboard';
static const manageRoomTypes = 'manage_room_types';
static const manageRooms = 'manage_rooms';
static const managePaymentSettings = 'manage_payment_settings';
static const managePolicy = 'manage_policy';

  /// 📊 查看報表統計
  static const viewReports = 'view_reports';

  /// 📝 查看操作紀錄
  static const viewActionLogs = 'view_action_logs';

  /// 🔥 全部權限列表
  static const all = [
    manageMembers,
    editBasicInfo,
    editBusinessInfo,
    editMedia,
    manageEnvironment,
    manageAbout,
    manageModules,
    manageBookings,
    manageRoomDashboard,
manageRoomTypes,
manageRooms,
managePaymentSettings,
managePolicy,
    viewReports,
    viewActionLogs,
  ];
}
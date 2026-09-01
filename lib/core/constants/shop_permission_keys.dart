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

  /// 🧾 管理前台內容：環境介紹 / 關於我們 / 公告 / FAQ
  static const manageFrontendContent = 'manage_frontend_content';

  /// ⭐ 管理評價
  static const manageReviews = 'manage_reviews';

  /// 📡 管理設備 / 攝影機
  static const manageDevices = 'manage_devices';

  /// ➕ 管理住宿加購 / 附加服務
  static const manageAddons = 'manage_addons';

  /// 🧩 管理模組設定
  static const manageModules = 'manage_modules';

  /// 📅 管理預約功能
  static const manageBookings = 'manage_bookings';

  /// 💬 查看與回覆店家聊天
  static const manageChat = 'manage_chat';

  /// 📅 管理預約設定
  static const manageBookingSettings = 'manage_booking_settings';

  static const manageRoomDashboard = 'manage_room_dashboard';
  static const manageRoomTypes = 'manage_room_types';
  static const manageRooms = 'manage_rooms';
  static const managePaymentSettings = 'manage_payment_settings';

  /// 📦 管理實體商品領取、核銷、取消與退點
  static const managePointRedemptions = 'manage_point_redemptions';

  /// 📦 查看中央庫存數量與流水
  static const viewInventory = 'view_inventory';

  /// 📦 管理庫存品項與住宿耗材設定
  static const manageInventory = 'manage_inventory';

  /// 📦 執行進貨
  static const receiveInventory = 'receive_inventory';

  /// 📦 執行手動出庫與盤點調整
  static const adjustInventory = 'adjust_inventory';

  /// 📦 查看進貨成本與估計庫存成本
  static const viewInventoryCost = 'view_inventory_cost';

  static const managePolicy = 'manage_policy';

  /// 🛒 查看商城訂單
  static const viewStoreOrders = 'view_store_orders';

  /// 🛒 管理商城商品與分類
  static const manageStoreProducts = 'manage_store_products';

  /// 🛒 管理商城訂單狀態
  static const manageStoreOrders = 'manage_store_orders';

  /// 🛒 管理賣場設定
  static const manageStoreSettings = 'manage_store_settings';

  /// 📊 查看報表統計
  static const viewReports = 'view_reports';

  /// 查看操作紀錄
  static const viewActionLogs = 'view_action_logs';

  /// 🐾 查看臨托訂單
  static const viewDaycareBookings = 'view_daycare_bookings';

  /// 🐾 管理臨托訂單
  static const manageDaycareBookings = 'manage_daycare_bookings';

  /// 🐾 管理臨托設定
  static const manageDaycareSettings = 'manage_daycare_settings';

  /// 🐾 管理臨托方案價格
  static const manageDaycarePricing = 'manage_daycare_pricing';

  /// 🐾 臨托轉住宿
  static const convertDaycareToAccommodation =
      'convert_daycare_to_accommodation';

  /// 🐾 調整臨托價格
  static const adjustDaycarePrice = 'adjust_daycare_price';

  /// 🔥 全部權限列表
  static const all = [
    manageMembers,
    editBasicInfo,
    editBusinessInfo,
    editMedia,
    manageEnvironment,
    manageAbout,
    manageFrontendContent,
    manageReviews,
    manageModules,
    manageBookings,
    manageChat,
    manageBookingSettings,
    manageRoomDashboard,
    manageRoomTypes,
    manageRooms,
    manageDevices,
    managePaymentSettings,
    managePointRedemptions,
    manageAddons,
    viewInventory,
    manageInventory,
    receiveInventory,
    adjustInventory,
    viewInventoryCost,
    viewStoreOrders,
    manageStoreProducts,
    manageStoreOrders,
    manageStoreSettings,
    managePolicy,
    viewDaycareBookings,
    manageDaycareBookings,
    manageDaycareSettings,
    manageDaycarePricing,
    convertDaycareToAccommodation,
    adjustDaycarePrice,
  ];
}

// 檔案名稱：lib/core/models/home_shortcut_gate.dart
// 功能說明：判斷右上角快捷鍵與懸浮按鈕能不能使用同一個功能，不改後端權限。

import 'package:petnest_saas/core/models/home_quick_action_setting.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';

class HomeShortcutGate {
  const HomeShortcutGate({
    required this.storeEnabled,
    required this.chatProvisioned,
    required this.phoneReady,
    required this.lineReady,
    required this.facebookReady,
    required this.instagramReady,
    required this.announcementsEnabled,
    required this.faqEnabled,
    required this.memberCenterEnabled,
    required this.showShopMenus,
    required this.paidPlan,
    required this.floatingEnabled,
    required this.floatingType,
    this.otherSlot = '',
  });

  final bool storeEnabled;
  final bool chatProvisioned;
  final bool phoneReady;
  final bool lineReady;
  final bool facebookReady;
  final bool instagramReady;
  final bool announcementsEnabled;
  final bool faqEnabled;
  final bool memberCenterEnabled;
  final bool showShopMenus;
  final bool paidPlan;
  final bool floatingEnabled;
  final String floatingType;
  final String otherSlot;

  factory HomeShortcutGate.fromShop(
    Map<String, dynamic> shop, {
    required bool memberCenterEnabled,
    required bool showShopMenus,
    bool? floatingEnabled,
    String? floatingType,
    bool? chatProvisioned,
    String otherSlot = '',
  }) {
    final FrontendNavShopState state = FrontendNavShopState.fromShop(
      shop,
      showMemberCenter: memberCenterEnabled,
      showShopMenus: showShopMenus,
      loggedIn: true,
    );
    final String savedType = ShopChatService.savedFloatingType(shop);
    return HomeShortcutGate(
      storeEnabled: state.storeEnabled,
      chatProvisioned:
          chatProvisioned ??
          (shop['storeChatEnabled'] == true ||
              savedType == ShopChatService.floatingTypePetnestChat),
      phoneReady: _text(shop['phone']).isNotEmpty,
      lineReady: _text(shop['lineUrl']).isNotEmpty,
      facebookReady: _text(shop['fbUrl']).isNotEmpty,
      instagramReady: _text(shop['igUrl']).isNotEmpty,
      announcementsEnabled: state.announcementsEnabled,
      faqEnabled: state.faqEnabled,
      memberCenterEnabled: memberCenterEnabled,
      showShopMenus: showShopMenus,
      paidPlan: state.paidPlan,
      floatingEnabled:
          floatingEnabled ?? ShopChatService.isFloatingEnabled(shop),
      floatingType: floatingType ?? savedType,
      otherSlot: otherSlot,
    );
  }

  HomeShortcutGate copyWith({String? otherSlot}) {
    return HomeShortcutGate(
      storeEnabled: storeEnabled,
      chatProvisioned: chatProvisioned,
      phoneReady: phoneReady,
      lineReady: lineReady,
      facebookReady: facebookReady,
      instagramReady: instagramReady,
      announcementsEnabled: announcementsEnabled,
      faqEnabled: faqEnabled,
      memberCenterEnabled: memberCenterEnabled,
      showShopMenus: showShopMenus,
      paidPlan: paidPlan,
      floatingEnabled: floatingEnabled,
      floatingType: floatingType,
      otherSlot: otherSlot ?? this.otherSlot,
    );
  }

  /// 正式前台要畫出來的按鈕。無效或互斥的選擇會留在設定裡，但這裡不顯示。
  List<String> visibleIds(HomeQuickActionSetting setting) {
    final List<String> ids = <String>[HomeQuickActionIds.notifications];
    for (final String slot in <String>[setting.slotOne, setting.slotTwo]) {
      if (slot.isEmpty || ids.contains(slot)) {
        continue;
      }
      if (blockReason(slot) != null) {
        continue;
      }
      ids.add(slot);
    }
    return ids;
  }

  /// 下拉選單用。另一個位置已選到的功能也不能再選。
  String? selectionReason(String id, {required String otherSlot}) {
    if (id.isEmpty) {
      return null;
    }
    if (otherSlot.isNotEmpty && otherSlot == id) {
      return '已用於另一個快捷鍵';
    }
    return blockReason(id);
  }

  String? blockReason(String id) {
    if (id.isEmpty) {
      return null;
    }
    if (floatingEnabled && floatingType == id) {
      return '已由懸浮按鈕使用';
    }
    switch (id) {
      case HomeQuickActionIds.cart:
        return storeEnabled ? null : '請先啟用商城';
      case HomeQuickActionIds.chat:
        return chatProvisioned ? null : '店家聊天尚未開通';
      case HomeQuickActionIds.phone:
        return phoneReady ? null : '請先填寫電話';
      case HomeQuickActionIds.line:
        return lineReady ? null : '請先填寫 LINE';
      case HomeQuickActionIds.facebook:
        return facebookReady ? null : '請先填寫 Facebook';
      case HomeQuickActionIds.instagram:
        return instagramReady ? null : '請先填寫 Instagram';
      case HomeQuickActionIds.bookings:
      case HomeQuickActionIds.member:
        return memberCenterEnabled ? null : '請先開啟會員中心';
      case HomeQuickActionIds.promotions:
        return _sectionReason(
          shopMenus: true,
          enabled: announcementsEnabled,
          closed: '請先開啟最新公告',
        );
      case HomeQuickActionIds.faq:
        return _sectionReason(
          shopMenus: true,
          enabled: faqEnabled,
          closed: '請先開啟常見問題',
        );
      default:
        return '此功能目前無法使用';
    }
  }

  String? _sectionReason({
    required bool shopMenus,
    required bool enabled,
    required String closed,
  }) {
    if (shopMenus && !showShopMenus) {
      return '請先開啟店家選單';
    }
    if (!enabled) {
      return closed;
    }
    if (!paidPlan) {
      return '目前方案未開放此功能';
    }
    return null;
  }

  static String _text(dynamic value) => (value ?? '').toString().trim();
}

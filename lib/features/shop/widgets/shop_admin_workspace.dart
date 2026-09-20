// 檔案名稱：lib/features/shop/widgets/shop_admin_workspace.dart
// 功能說明：店家後台共用狀態：聊天面板、草稿、預覽尺寸。不新增 Firestore 欄位。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/features/shop/controllers/shop_chat_multi_dock_controller.dart';
import 'package:petnest_saas/features/shop/widgets/shop_frontend_phone_preview.dart';

class ShopAdminWorkspaceController extends ChangeNotifier {
  ShopAdminWorkspaceController({this.canUseChat = false});

  bool canUseChat;
  String inboxFilter = 'inbox';
  String inboxQuery = '';
  ShopFrontendPhoneSize previewSize = ShopFrontendPhoneSize.live;
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  final ShopChatMultiDockController chat = ShopChatMultiDockController();
  StreamSubscription<int>? _unreadSub;

  bool get inboxOpen => chat.inboxOpen;
  bool get chatPanelOpen => chat.inboxOpen || chat.showDockWindows;

  void bindUnread(String shopId) {
    _unreadSub?.cancel();
    if (shopId.isEmpty || !canUseChat) {
      unreadCount.value = 0;
      return;
    }
    _unreadSub = ShopChatService.instance.watchShopUnreadTotal(shopId).listen((
      int value,
    ) {
      unreadCount.value = value;
    });
  }

  void bindChat({required String shopId, required String uid}) {
    bindUnread(shopId);
    if (!canUseChat) {
      return;
    }
    chat.attach(shopId: shopId, uid: uid);
  }

  TextEditingController draftOf(String threadId) {
    return chat.inputOf(threadId);
  }

  void setPreviewSize(ShopFrontendPhoneSize size) {
    if (previewSize.id == size.id) {
      return;
    }
    previewSize = size;
    notifyListeners();
  }

  void toggleInbox() {
    if (!canUseChat) {
      return;
    }
    chat.toggleInbox();
    notifyListeners();
  }

  void openInbox() {
    if (!canUseChat) {
      return;
    }
    chat.openInbox();
    notifyListeners();
  }

  void closeInbox() {
    chat.closeInbox();
    notifyListeners();
  }

  void toggleChatPanel() {
    toggleInbox();
  }

  void openChatPanel() {
    openInbox();
  }

  void closeChatPanel() {
    chat.closeInbox();
    notifyListeners();
  }

  void minimizeChatPanel() {
    chat.minimizeDock();
    notifyListeners();
  }

  ShopChatOpenResult openThreadFromInbox(ShopChatThreadModel thread) {
    final ShopChatOpenResult result = chat.openFromInbox(thread);
    notifyListeners();
    return result;
  }

  void setInboxFilter(String filter) {
    inboxFilter = filter;
    notifyListeners();
  }

  void setInboxQuery(String query) {
    inboxQuery = query;
    notifyListeners();
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    unreadCount.dispose();
    chat.dispose();
    super.dispose();
  }
}

class ShopAdminWorkspaceScope
    extends InheritedNotifier<ShopAdminWorkspaceController> {
  const ShopAdminWorkspaceScope({
    super.key,
    required ShopAdminWorkspaceController controller,
    required super.child,
  }) : super(notifier: controller);

  static ShopAdminWorkspaceController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ShopAdminWorkspaceScope>()
        ?.notifier;
  }

  static ShopAdminWorkspaceController of(BuildContext context) {
    final ShopAdminWorkspaceController? controller = maybeOf(context);
    assert(controller != null, 'ShopAdminWorkspaceScope 未找到');
    return controller!;
  }
}

class ShopAdminBreakpoints {
  ShopAdminBreakpoints._();

  static const double compact = 900;
  static const double overlayChat = 1100;
  static const double wide = 1600;
}

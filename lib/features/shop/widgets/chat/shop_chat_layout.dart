// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_layout.dart
// 功能說明：店家聊天依寬度切全頁或桌機三格 Dock；>=1280 才開窄 Dock。

enum ShopChatSurface { fullScreenInbox, desktopDock }

class ShopChatLayout {
  ShopChatLayout._();

  static const double phoneMax = 600;
  static const double desktopMin = 1024;
  static const double multiSlotMinWidth = 1100;
  static const double inboxColumnWidth = 160;
  static const double dockMinWidth = 360;
  static const double dockMaxWidth = 420;
  static const double preferredDockWidth = 380;
  static const int desktopSlotMax = 3;
  static const String slotFullMessage = '目前已開啟 3 個對話，請先關閉其中一個。';

  static double dockWidthFor(double pageWidth) {
    return preferredDockWidth;
  }

  static double get dockWidth => preferredDockWidth;

  static bool useFullScreenChat(double width) {
    return width < multiSlotMinWidth;
  }

  static bool useDesktopDock(double width) {
    return !useFullScreenChat(width);
  }

  static ShopChatSurface surfaceForWidth(double width) {
    return useFullScreenChat(width)
        ? ShopChatSurface.fullScreenInbox
        : ShopChatSurface.desktopDock;
  }

  static bool shouldShowDesktopDock({
    required double pageWidth,
    required bool inboxOpen,
  }) {
    return inboxOpen && useDesktopDock(pageWidth);
  }
}

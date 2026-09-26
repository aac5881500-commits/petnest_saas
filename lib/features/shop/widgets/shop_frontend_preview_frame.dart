// 檔案名稱：lib/features/shop/widgets/shop_frontend_preview_frame.dart
// 功能說明：後台前台預覽外框與獨立 Navigator，內容重用 ShopPublicPage。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_embedded_scope.dart';
import 'package:petnest_saas/features/shop/widgets/shop_frontend_phone_preview.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopFrontendPreviewFrame extends StatefulWidget {
  const ShopFrontendPreviewFrame({
    super.key,
    required this.shopId,
    required this.shopCode,
    required this.onClose,
    this.homeResetToken = 0,
    this.showExpand = true,
    this.expanded = false,
    this.scaleToFit = true,
    this.onToggleExpand,
    this.previewBodyOverride,
  });

  /// 固定手機 canvas。槽位夠寬時以原始寬度顯示，較窄時才等比例縮小。
  static const Size phoneLogicalSize = ShopFrontendPhoneFrame.liveLogicalSize;

  /// 前台 canvas 寬度。內嵌時優先維持這個寬度的 1 倍，不把版面重排成更窄。
  static const double canvasWidth = ShopFrontendPhoneFrame.liveLogicalWidth;

  /// 預覽框左右內距合計。canvas 必須扣掉這段才放得進槽位。
  static const double inlineCanvasInset = 16;

  /// 內嵌前台最小可操作寬度：剛好讓 500px canvas 以 1 倍顯示。
  static const double inlineMinOperableWidth = canvasWidth + inlineCanvasInset;

  /// 內嵌前台最大寬度。多餘空間留給後台，不把預覽再拉寬。
  static const double inlineMaxWidth = 540;

  /// 預覽與後台內容之間的間距，計入是否放得下的判斷。
  static const double inlineColumnGap = 8;

  /// 後台 tab 內容最小可操作寬度。低於這個寬度就不內嵌預覽。
  static const double backendMinOperableWidth = 720;

  /// 偏好槽寬（上限）。實際寬度請用 [inlineWidthFor]。
  static const double inlineSlotWidth = inlineMaxWidth;

  static const Size liveFrontendSize = phoneLogicalSize;
  static const Size dashboardFrontendPreviewSize = phoneLogicalSize;

  final String shopId;
  final String shopCode;
  final VoidCallback onClose;
  final int homeResetToken;
  final bool showExpand;
  final bool expanded;
  final bool scaleToFit;
  final VoidCallback? onToggleExpand;

  @visibleForTesting
  final Widget? previewBodyOverride;

  /// [availableWidth] 必須已扣除聊天桌機 dock，不是整個視窗寬度。
  static bool canShowInlinePreview(double availableWidth) {
    return availableWidth >=
        inlineMinOperableWidth + inlineColumnGap + backendMinOperableWidth;
  }

  /// 依剩餘寬度算出左欄槽寬。放不下最小可操作寬度時回傳 0。
  static double inlineWidthFor(double availableWidth) {
    final double room =
        availableWidth - backendMinOperableWidth - inlineColumnGap;
    if (room < inlineMinOperableWidth) {
      return 0;
    }
    if (room > inlineMaxWidth) {
      return inlineMaxWidth;
    }
    return room;
  }

  static Widget liveRoot({
    required String shopId,
    VoidCallback? onClose,
    Widget? override,
  }) {
    return override ??
        ShopPublicPage(
          shopId: shopId,
          embeddedInDashboard: true,
          onExitEmbedded: onClose,
        );
  }

  @override
  State<ShopFrontendPreviewFrame> createState() =>
      ShopFrontendPreviewFrameState();
}

class ShopFrontendPreviewFrameState extends State<ShopFrontendPreviewFrame> {
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  int _refreshGeneration = 0;

  @override
  void didUpdateWidget(covariant ShopFrontendPreviewFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeResetToken != widget.homeResetToken) {
      goHome();
    }
    if (oldWidget.shopId != widget.shopId) {
      refresh();
    }
  }

  void refresh() {
    setState(() {
      _refreshGeneration++;
      _navigatorKey = GlobalKey<NavigatorState>();
    });
  }

  void goBack() {
    _navigatorKey.currentState?.maybePop();
  }

  void goHome() {
    _navigatorKey.currentState?.popUntil((Route<dynamic> route) {
      return route.isFirst;
    });
  }

  Uri? _publicFrontendUri() {
    final String code = widget.shopCode.trim();
    if (code.isEmpty) {
      return null;
    }
    if (kIsWeb) {
      return Uri.parse('${Uri.base.origin}/s/$code');
    }
    return Uri.parse('https://petnest.tw/s/$code');
  }

  Future<void> _openPublicFrontend() async {
    final Uri? uri = _publicFrontendUri();
    if (uri == null) {
      return;
    }
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  Widget _liveRoot() {
    return ShopFrontendPreviewFrame.liveRoot(
      shopId: widget.shopId,
      onClose: widget.onClose,
      override: widget.previewBodyOverride,
    );
  }

  Route<dynamic> _routeFor(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => _liveRoot(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool hasShopCode = widget.shopCode.trim().isNotEmpty;

    return Material(
      color: const Color(0xFFF7F8FC),
      elevation: 10,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 48,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE6EAF0))),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '前台預覽',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: '此區為正式前台，操作會建立實際資料',
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    _ToolbarIcon(
                      tooltip: '回到前台首頁',
                      icon: Icons.home_outlined,
                      onPressed: goHome,
                    ),
                    _ToolbarIcon(
                      tooltip: '重新整理',
                      icon: Icons.refresh,
                      onPressed: refresh,
                    ),
                    _ToolbarIcon(
                      tooltip: '返回上一頁',
                      icon: Icons.arrow_back,
                      onPressed: goBack,
                    ),
                    if (widget.showExpand)
                      _ToolbarIcon(
                        tooltip: widget.expanded ? '縮小' : '放大',
                        icon: widget.expanded
                            ? Icons.close_fullscreen
                            : Icons.open_in_full,
                        onPressed:
                            widget.onToggleExpand ??
                            (hasShopCode ? _openPublicFrontend : null),
                      ),
                    _ToolbarIcon(
                      tooltip: '關閉',
                      icon: Icons.close,
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ShopFrontendPreviewFrame.inlineCanvasInset / 2,
                8,
                ShopFrontendPreviewFrame.inlineCanvasInset / 2,
                8,
              ),
              child: ShopFrontendPhoneFrame(
                logicalWidth: ShopFrontendPhoneFrame.liveLogicalWidth,
                scaleToFit: widget.scaleToFit,
                child: ShopDashboardEmbeddedScope(
                  onExitEmbedded: widget.onClose,
                  embeddedInShopDashboard: true,
                  child: HeroControllerScope.none(
                    child: KeyedSubtree(
                      key: ValueKey<int>(_refreshGeneration),
                      child: Navigator(
                        key: _navigatorKey,
                        onGenerateInitialRoutes:
                            (NavigatorState navigator, String initialRoute) {
                              return <Route<dynamic>>[
                                _routeFor(const RouteSettings(name: '/')),
                              ];
                            },
                        onGenerateRoute: _routeFor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );
  }
}

class ShopDashboardLiveFrontendOverlay {
  ShopDashboardLiveFrontendOverlay._();

  static const Key overlayKey = Key('shop-dashboard-live-frontend-overlay');
}

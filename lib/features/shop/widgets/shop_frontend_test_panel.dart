// 檔案名稱：lib/features/shop/widgets/shop_frontend_test_panel.dart
// 功能說明：Dashboard 左側浮層掛載正式客戶前台（ShopPublicPage），固定 430×932。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_embedded_scope.dart';
import 'package:petnest_saas/features/shop/widgets/shop_frontend_phone_preview.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopFrontendTestPanel extends StatefulWidget {
  const ShopFrontendTestPanel({
    super.key,
    required this.shopId,
    required this.shopCode,
    required this.onClose,
    this.homeResetToken = 0,
    this.previewBodyOverride,
  });

  static const Size liveFrontendSize = Size(430, 932);
  static const Size dashboardFrontendPreviewSize = liveFrontendSize;

  final String shopId;
  final String shopCode;
  final VoidCallback onClose;
  final int homeResetToken;

  @visibleForTesting
  final Widget? previewBodyOverride;

  @visibleForTesting
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
  State<ShopFrontendTestPanel> createState() => _ShopFrontendTestPanelState();
}

class _ShopFrontendTestPanelState extends State<ShopFrontendTestPanel> {
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  int _refreshGeneration = 0;

  @override
  void didUpdateWidget(covariant ShopFrontendTestPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeResetToken != widget.homeResetToken) {
      _goHome();
    }
    if (oldWidget.shopId != widget.shopId) {
      _resetNavigator();
    }
  }

  void _resetNavigator() {
    setState(() {
      _refreshGeneration++;
      _navigatorKey = GlobalKey<NavigatorState>();
    });
  }

  void _goBack() {
    _navigatorKey.currentState?.maybePop();
  }

  void _goHome() {
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
    return ShopFrontendTestPanel.liveRoot(
      shopId: widget.shopId,
      onClose: widget.onClose,
      override: widget.previewBodyOverride,
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
                        '實際前台',
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
                      onPressed: _goHome,
                    ),
                    _ToolbarIcon(
                      tooltip: '重新整理',
                      icon: Icons.refresh,
                      onPressed: _resetNavigator,
                    ),
                    _ToolbarIcon(
                      tooltip: '返回上一頁',
                      icon: Icons.arrow_back,
                      onPressed: _goBack,
                    ),
                    _ToolbarIcon(
                      tooltip: hasShopCode ? '開新視窗' : '請先設定店家代碼',
                      icon: Icons.open_in_new,
                      onPressed: hasShopCode ? _openPublicFrontend : null,
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
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: ShopFrontendPhoneFrame(
                logicalSize: ShopFrontendTestPanel.liveFrontendSize,
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
                                MaterialPageRoute<void>(
                                  settings: const RouteSettings(name: '/'),
                                  builder: (_) => _liveRoot(),
                                ),
                              ];
                            },
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
    required this.onPressed,
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

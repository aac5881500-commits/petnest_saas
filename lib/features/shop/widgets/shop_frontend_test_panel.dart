// 檔案名稱：lib/features/shop/widgets/shop_frontend_test_panel.dart
// 功能說明：店家後台左側完整前台操作區，以獨立 Navigator 載入既有 ShopPublicPage。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopFrontendTestPanel extends StatefulWidget {
  const ShopFrontendTestPanel({
    super.key,
    required this.shopId,
    required this.shopCode,
    required this.onClose,
    this.initialWidth,
    this.onWidthChanged,
    this.homeResetToken = 0,
    this.onOpenFullPage,
  });

  final String shopId;
  final String shopCode;
  final VoidCallback onClose;
  final double? initialWidth;
  final ValueChanged<double>? onWidthChanged;
  final int homeResetToken;
  final VoidCallback? onOpenFullPage;

  @override
  State<ShopFrontendTestPanel> createState() => _ShopFrontendTestPanelState();
}

class _ShopFrontendTestPanelState extends State<ShopFrontendTestPanel> {
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  int _refreshGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final double? width = widget.initialWidth;
      if (width != null) {
        widget.onWidthChanged?.call(width);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ShopFrontendTestPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeResetToken != widget.homeResetToken) {
      _navigatorKey.currentState?.popUntil((Route<dynamic> route) {
        return route.isFirst;
      });
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

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool hasShopCode = widget.shopCode.trim().isNotEmpty;

    return ColoredBox(
      color: Colors.white,
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
                        '前台',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    _ToolbarIcon(
                      tooltip: '返回上一頁',
                      icon: Icons.arrow_back,
                      onPressed: _goBack,
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
                      tooltip: '全頁查看',
                      icon: Icons.open_in_full,
                      onPressed: widget.onOpenFullPage,
                    ),
                    _ToolbarIcon(
                      tooltip: hasShopCode ? '另開完整前台' : '請先設定店家代碼',
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
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF4E8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '目前使用正式前台流程，送出預約會建立正式訂單。',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.25,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
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
                            builder: (_) =>
                                ShopPublicPage(shopId: widget.shopId),
                          ),
                        ];
                      },
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

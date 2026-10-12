// 檔案名稱：lib/features/shop/widgets/modern_home/home_quick_action_bar.dart
// 功能說明：新版首頁快捷功能列。預覽與正式前台共用這一顆。

import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_quick_action_setting.dart';
import 'package:petnest_saas/core/models/home_shortcut_gate.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/notification_service.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/core/services/shop_contact_shortcut_service.dart';
import 'package:petnest_saas/core/services/store_cart_service.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/notifications/pages/notification_center_page.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_actions.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_customer_chat_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_page.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_cart_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_shortcut_catalog.dart';

class HomeQuickActionButton {
  const HomeQuickActionButton({
    required this.id,
    required this.icon,
    required this.label,
    required this.badgeCount,
    this.onPressed,
  });

  final String id;
  final IconData icon;
  final String label;
  final int badgeCount;
  final VoidCallback? onPressed;
}

class HomeQuickActionBar extends StatelessWidget {
  const HomeQuickActionBar({
    super.key,
    required this.setting,
    required this.theme,
    required this.buttons,
  });

  final HomeQuickActionSetting setting;
  final HomeThemeModel theme;
  final List<HomeQuickActionButton> buttons;

  @override
  Widget build(BuildContext context) {
    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 280;
        return _buildFitted(maxWidth);
      },
    );
  }

  Widget _buildFitted(double maxWidth) {
    final double slot = _slotFor(maxWidth);
    final double pad =
        setting.containerStyle == HomeQuickActionSetting.containerCapsule
        ? (maxWidth < 64 ? 2 : 4)
        : 0;
    for (final double gap in <double>[6, 2, 0]) {
      if (_width(buttons.length, slot, gap, pad) <= maxWidth) {
        return _shell(
          slot: slot,
          gap: gap,
          pad: pad,
          shown: buttons,
          hidden: const <HomeQuickActionButton>[],
        );
      }
    }

    final List<HomeQuickActionButton> shown = List<HomeQuickActionButton>.of(
      buttons,
    );
    final List<HomeQuickActionButton> hidden = <HomeQuickActionButton>[];
    while (shown.length > 1 &&
        _width(shown.length + 1, slot, 0, pad) > maxWidth) {
      final int index = _lastRemovable(shown);
      if (index < 0) {
        break;
      }
      hidden.insert(0, shown.removeAt(index));
    }
    final bool overflow = hidden.isNotEmpty;
    if (_width(shown.length + (overflow ? 1 : 0), slot, 0, pad) > maxWidth) {
      final List<HomeQuickActionButton> bell = shown
          .where(
            (HomeQuickActionButton button) =>
                button.id == HomeQuickActionIds.notifications,
          )
          .toList(growable: false);
      return _shell(
        slot: math.min(slot, math.max(28, maxWidth - pad * 2)),
        gap: 0,
        pad: pad,
        shown: bell.isEmpty ? shown.take(1).toList(growable: false) : bell,
        hidden: const <HomeQuickActionButton>[],
      );
    }
    return _shell(slot: slot, gap: 0, pad: pad, shown: shown, hidden: hidden);
  }

  Widget _shell({
    required double slot,
    required double gap,
    required double pad,
    required List<HomeQuickActionButton> shown,
    required List<HomeQuickActionButton> hidden,
  }) {
    final Color iconColor = _iconColor();
    final List<Widget> children = <Widget>[];
    for (var index = 0; index < shown.length; index++) {
      if (index > 0) {
        children.add(SizedBox(width: gap));
      }
      children.add(_button(shown[index], slot, iconColor));
    }
    if (hidden.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(SizedBox(width: gap));
      }
      children.add(_overflow(hidden, slot, iconColor));
    }
    final Widget row = Row(mainAxisSize: MainAxisSize.min, children: children);
    if (setting.containerStyle == HomeQuickActionSetting.containerPlain ||
        setting.containerStyle == HomeQuickActionSetting.containerCircles) {
      return row;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _backgroundColor(),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _borderColor()),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 2),
        child: row,
      ),
    );
  }

  Widget _button(HomeQuickActionButton button, double slot, Color iconColor) {
    final String? badge = setting.showBadges
        ? homeQuickActionBadgeLabel(button.badgeCount)
        : null;
    final Widget icon = _iconFace(
      icon: button.icon,
      slot: slot,
      iconColor: iconColor,
      badge: badge,
      badgeKey: ValueKey<String>('home-quick-action-badge-${button.id}'),
    );
    return SizedBox(
      key: ValueKey<String>('home-quick-action-${button.id}'),
      width: slot,
      height: slot,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: button.label,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          minimumSize: Size(slot, slot),
          maximumSize: Size(slot, slot),
        ),
        constraints: BoxConstraints.tightFor(width: slot, height: slot),
        onPressed: button.onPressed,
        icon: icon,
      ),
    );
  }

  Widget _overflow(
    List<HomeQuickActionButton> hidden,
    double slot,
    Color iconColor,
  ) {
    return SizedBox(
      key: const ValueKey<String>('home-quick-action-overflow'),
      width: slot,
      height: slot,
      child: PopupMenuButton<int>(
        tooltip: '更多',
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          minimumSize: Size(slot, slot),
          maximumSize: Size(slot, slot),
        ),
        icon: Icon(Icons.more_horiz, size: _iconExtent, color: iconColor),
        onSelected: (int index) => hidden[index].onPressed?.call(),
        itemBuilder: (BuildContext context) {
          return <PopupMenuEntry<int>>[
            for (var index = 0; index < hidden.length; index++)
              PopupMenuItem<int>(
                value: index,
                child: Text(_menuLabel(hidden[index])),
              ),
          ];
        },
      ),
    );
  }

  Widget _iconFace({
    required IconData icon,
    required double slot,
    required Color iconColor,
    required String? badge,
    required Key badgeKey,
  }) {
    final Widget glyph = Icon(icon, size: _iconExtent, color: iconColor);
    final Widget body =
        setting.containerStyle == HomeQuickActionSetting.containerCircles
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: _backgroundColor(),
              shape: BoxShape.circle,
              border: Border.all(color: _borderColor()),
            ),
            child: Center(child: glyph),
          )
        : glyph;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: <Widget>[
        body,
        if (badge != null)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              key: badgeKey,
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: EdgeInsets.symmetric(
                horizontal: badge.length > 2 ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _menuLabel(HomeQuickActionButton button) {
    final String? badge = setting.showBadges
        ? homeQuickActionBadgeLabel(button.badgeCount)
        : null;
    if (badge == null) {
      return button.label;
    }
    return '${button.label} $badge';
  }

  double get _iconExtent {
    switch (setting.iconSize) {
      case HomeQuickActionSetting.sizeSmall:
        return 18;
      case HomeQuickActionSetting.sizeLarge:
        return 26;
      default:
        return 22;
    }
  }

  double _slotFor(double maxWidth) {
    final double preferred = _iconExtent + 14;
    if (maxWidth < preferred) {
      return math.max(28, maxWidth);
    }
    return preferred;
  }

  double _width(int count, double slot, double gap, double pad) {
    if (count <= 0) {
      return 0;
    }
    return pad * 2 + count * slot + math.max(0, count - 1) * gap;
  }

  int _lastRemovable(List<HomeQuickActionButton> shown) {
    for (var index = shown.length - 1; index >= 0; index--) {
      if (shown[index].id != HomeQuickActionIds.notifications) {
        return index;
      }
    }
    return -1;
  }

  Color _iconColor() {
    if (setting.iconColorMode == HomeQuickActionSetting.iconCustom) {
      return Color(setting.iconColorValue);
    }
    return theme.textColor;
  }

  Color _backgroundColor() {
    switch (setting.backgroundMode) {
      case HomeQuickActionSetting.backgroundTheme:
        return theme.cardColor;
      case HomeQuickActionSetting.backgroundCustom:
        return Color(setting.backgroundColorValue);
      default:
        return theme.cardColor.withValues(alpha: 0.72);
    }
  }

  Color _borderColor() {
    if (setting.backgroundMode ==
        HomeQuickActionSetting.backgroundTranslucent) {
      return theme.cardBorderColor.withValues(alpha: 0.45);
    }
    return theme.cardBorderColor.withValues(alpha: 0.7);
  }
}

/// 正式前台與外觀預覽都用這一層接上現有通知、購物車與聊天。
class HomeQuickActionHost extends StatefulWidget {
  const HomeQuickActionHost({
    super.key,
    required this.shopId,
    required this.shop,
    required this.shopName,
    required this.shopLogoUrl,
    required this.theme,
    required this.setting,
    required this.gate,
    required this.interactive,
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final String shopName;
  final String shopLogoUrl;
  final HomeThemeModel theme;
  final HomeQuickActionSetting setting;
  final HomeShortcutGate gate;
  final bool interactive;

  @override
  State<HomeQuickActionHost> createState() => _HomeQuickActionHostState();
}

class _HomeQuickActionHostState extends State<HomeQuickActionHost> {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<int>? _noteSub;
  StreamSubscription<List<StoreCartItem>>? _cartSub;
  StreamSubscription<int>? _chatSub;
  String _uid = '';
  int _notes = 0;
  int _cart = 0;
  int _chat = 0;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _authSub = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      final String next = user?.uid ?? '';
      if (next == _uid) {
        return;
      }
      _uid = next;
      _resubscribe();
    });
    _resubscribe(notify: false);
  }

  @override
  void didUpdateWidget(HomeQuickActionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId ||
        !_sameVisible(
          oldWidget.setting,
          oldWidget.gate,
          widget.setting,
          widget.gate,
        )) {
      _resubscribe();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _noteSub?.cancel();
    _cartSub?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }

  bool _sameVisible(
    HomeQuickActionSetting left,
    HomeShortcutGate leftGate,
    HomeQuickActionSetting right,
    HomeShortcutGate rightGate,
  ) {
    final List<String> a = leftGate.visibleIds(left);
    final List<String> b = rightGate.visibleIds(right);
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

  void _resubscribe({bool notify = true}) {
    _noteSub?.cancel();
    _cartSub?.cancel();
    _chatSub?.cancel();
    _noteSub = null;
    _cartSub = null;
    _chatSub = null;
    _notes = 0;
    _cart = 0;
    _chat = 0;
    final Set<String> ids = widget.gate.visibleIds(widget.setting).toSet();
    if (ids.contains(HomeQuickActionIds.notifications) && _uid.isNotEmpty) {
      _noteSub = NotificationService.instance.unreadCountStream().listen(
        (int count) {
          if (mounted) {
            setState(() => _notes = count);
          }
        },
        onError: (Object _) {
          if (mounted) {
            setState(() => _notes = 0);
          }
        },
      );
    }
    if (ids.contains(HomeQuickActionIds.cart)) {
      _cartSub = StoreCartService.instance
          .streamCart(widget.shopId)
          .listen(
            (List<StoreCartItem> items) {
              final int count = homeQuickActionCartQuantity(
                items.map((StoreCartItem item) => item.quantity),
              );
              if (mounted) {
                setState(() => _cart = count);
              }
            },
            onError: (Object _) {
              if (mounted) {
                setState(() => _cart = 0);
              }
            },
          );
    }
    if (ids.contains(HomeQuickActionIds.chat) && _uid.isNotEmpty) {
      _chatSub = ShopChatService.instance
          .watchCustomerUnread(shopId: widget.shopId, customerUid: _uid)
          .listen(
            (int count) {
              if (mounted) {
                setState(() => _chat = count);
              }
            },
            onError: (Object _) {
              if (mounted) {
                setState(() => _chat = 0);
              }
            },
          );
    }
    if (notify && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> visible = widget.gate.visibleIds(widget.setting);
    return HomeQuickActionBar(
      setting: widget.setting,
      theme: widget.theme,
      buttons: visible
          .map(_button)
          .whereType<HomeQuickActionButton>()
          .toList(growable: false),
    );
  }

  HomeQuickActionButton? _button(String id) {
    final HomeShortcutOption? option = HomeShortcutCatalog.find(id);
    switch (id) {
      case HomeQuickActionIds.notifications:
        return HomeQuickActionButton(
          id: id,
          icon: Icons.notifications_none_rounded,
          label: '通知',
          badgeCount: _notes,
          onPressed: widget.interactive ? _openNotifications : () {},
        );
      case HomeQuickActionIds.cart:
        return HomeQuickActionButton(
          id: id,
          icon: option?.icon ?? Icons.shopping_cart_outlined,
          label: option?.label ?? '購物車',
          badgeCount: _cart,
          onPressed: widget.interactive ? _openCart : () {},
        );
      case HomeQuickActionIds.chat:
        return HomeQuickActionButton(
          id: id,
          icon: option?.icon ?? Icons.chat_bubble_outline,
          label: option?.label ?? 'PetNest 店家聊天',
          badgeCount: _chat,
          onPressed: widget.interactive ? _openChat : () {},
        );
      default:
        if (option == null) {
          return null;
        }
        return HomeQuickActionButton(
          id: id,
          icon: option.icon,
          label: option.label,
          badgeCount: 0,
          onPressed: widget.interactive ? () => _openShortcut(id) : () {},
        );
    }
  }

  Future<void> _openNotifications() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await _openLogin();
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationCenterPage()),
    );
  }

  Future<void> _openCart() async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreCartPage(
          shopId: widget.shopId,
          shop: widget.shop,
          theme: widget.theme,
        ),
      ),
    );
  }

  Future<void> _openChat() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await _openLogin();
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShopCustomerChatPage(
          shopId: widget.shopId,
          shopName: widget.shopName,
          shopLogoUrl: widget.shopLogoUrl,
        ),
      ),
    );
  }

  Future<void> _openShortcut(String id) async {
    if (!mounted) {
      return;
    }
    switch (id) {
      case HomeQuickActionIds.phone:
      case HomeQuickActionIds.line:
      case HomeQuickActionIds.facebook:
      case HomeQuickActionIds.instagram:
        await ShopContactShortcutService.instance.openConfigured(
          context: context,
          shopId: widget.shopId,
          shop: widget.shop,
          type: id,
        );
        return;
      case HomeQuickActionIds.promotions:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ShopAnnouncementPage(
              shopId: widget.shopId,
              theme: widget.theme,
              initialSection: ShopAnnouncementSection.campaigns,
            ),
          ),
        );
        return;
      case HomeQuickActionIds.bookings:
        await _openNav('orders');
        return;
      case HomeQuickActionIds.member:
        await _openNav('member');
        return;
      case HomeQuickActionIds.faq:
        await _openNav('faq');
        return;
      default:
        return;
    }
  }

  Future<void> _openNav(String id) async {
    final FrontendNavigationItem? item = FrontendNavigationRegistry.find(id);
    if (item == null || !mounted) {
      return;
    }
    await FrontendNavigationLaunch(
      shopId: widget.shopId,
      shop: widget.shop,
      theme: widget.theme,
    ).open(context, item);
  }

  Future<void> _openLogin() async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(redirectShopId: widget.shopId),
      ),
    );
  }
}

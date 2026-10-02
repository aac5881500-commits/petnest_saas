import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';

enum FrontendNavAction {
  home,
  booking,
  rooms,
  store,
  announcements,
  orders,
  member,
  reviews,
  policy,
  about,
  faq,
  environment,
  chat,
  storeOrders,
  shopInfo,
  platform,
  admin,
  logout,
}

enum FrontendNavGroup { general, member, shop, system }

class FrontendNavigationItem {
  const FrontendNavigationItem({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.action,
    required this.group,
    this.ownerSelectable = true,
    this.pinned = false,
    this.requiresLogin = false,
    this.requiresPaidPlan = false,
  });

  final String id;
  final String label;
  final String shortLabel;
  final IconData icon;
  final FrontendNavAction action;
  final FrontendNavGroup group;
  final bool ownerSelectable;
  final bool pinned;
  final bool requiresLogin;
  final bool requiresPaidPlan;
}

class FrontendNavigationRegistry {
  const FrontendNavigationRegistry._();

  static const String homeId = 'home';

  static const List<FrontendNavigationItem> items = <FrontendNavigationItem>[
    FrontendNavigationItem(
      id: homeId,
      label: '首頁',
      shortLabel: '首頁',
      icon: Icons.home_rounded,
      action: FrontendNavAction.home,
      group: FrontendNavGroup.general,
      pinned: true,
    ),
    FrontendNavigationItem(
      id: 'booking',
      label: '我要預約',
      shortLabel: '預約',
      icon: Icons.calendar_month,
      action: FrontendNavAction.booking,
      group: FrontendNavGroup.shop,
      requiresPaidPlan: true,
    ),
    FrontendNavigationItem(
      id: 'rooms',
      label: '房間介紹',
      shortLabel: '房型',
      icon: Icons.bed,
      action: FrontendNavAction.rooms,
      group: FrontendNavGroup.shop,
      requiresPaidPlan: true,
    ),
    FrontendNavigationItem(
      id: 'environment',
      label: '環境介紹',
      shortLabel: '環境',
      icon: Icons.home_outlined,
      action: FrontendNavAction.environment,
      group: FrontendNavGroup.shop,
      requiresPaidPlan: true,
    ),
    FrontendNavigationItem(
      id: 'store',
      label: '寵物賣場',
      shortLabel: '商城',
      icon: Icons.storefront_outlined,
      action: FrontendNavAction.store,
      group: FrontendNavGroup.shop,
      requiresPaidPlan: true,
    ),
    FrontendNavigationItem(
      id: 'announcements',
      label: '最新公告',
      shortLabel: '公告',
      icon: Icons.campaign_outlined,
      action: FrontendNavAction.announcements,
      group: FrontendNavGroup.shop,
      requiresPaidPlan: true,
    ),
    FrontendNavigationItem(
      id: 'orders',
      label: '我的訂單',
      shortLabel: '訂單',
      icon: Icons.receipt_long,
      action: FrontendNavAction.orders,
      group: FrontendNavGroup.member,
    ),
    FrontendNavigationItem(
      id: 'member',
      label: '會員中心',
      shortLabel: '會員',
      icon: Icons.person,
      action: FrontendNavAction.member,
      group: FrontendNavGroup.member,
      requiresLogin: true,
    ),
    FrontendNavigationItem(
      id: 'reviews',
      label: '我的評價',
      shortLabel: '評價',
      icon: Icons.rate_review_outlined,
      action: FrontendNavAction.reviews,
      group: FrontendNavGroup.member,
    ),
    FrontendNavigationItem(
      id: 'policy',
      label: '入住須知',
      shortLabel: '須知',
      icon: Icons.description,
      action: FrontendNavAction.policy,
      group: FrontendNavGroup.shop,
      requiresPaidPlan: true,
    ),
    FrontendNavigationItem(
      id: 'about',
      label: '關於我們',
      shortLabel: '關於',
      icon: Icons.favorite,
      action: FrontendNavAction.about,
      group: FrontendNavGroup.shop,
      requiresPaidPlan: true,
    ),
    FrontendNavigationItem(
      id: 'faq',
      label: '常見問題',
      shortLabel: '問答',
      icon: Icons.help_outline,
      action: FrontendNavAction.faq,
      group: FrontendNavGroup.shop,
      requiresPaidPlan: true,
    ),
    FrontendNavigationItem(
      id: 'chat',
      label: '店家訊息',
      shortLabel: '訊息',
      icon: Icons.chat_bubble_outline,
      action: FrontendNavAction.chat,
      group: FrontendNavGroup.member,
      requiresLogin: true,
    ),
    FrontendNavigationItem(
      id: 'storeOrders',
      label: '我的商城訂單',
      shortLabel: '商城單',
      icon: Icons.shopping_bag_outlined,
      action: FrontendNavAction.storeOrders,
      group: FrontendNavGroup.member,
    ),
    FrontendNavigationItem(
      id: 'shopInfo',
      label: '店家資訊',
      shortLabel: '店家',
      icon: Icons.store_mall_directory_outlined,
      action: FrontendNavAction.shopInfo,
      group: FrontendNavGroup.general,
    ),
    FrontendNavigationItem(
      id: 'platform',
      label: '返回平台',
      shortLabel: '平台',
      icon: Icons.home_work_outlined,
      action: FrontendNavAction.platform,
      group: FrontendNavGroup.system,
      ownerSelectable: false,
      pinned: true,
    ),
    FrontendNavigationItem(
      id: 'admin',
      label: '回店家後台',
      shortLabel: '回後台',
      icon: Icons.dashboard_outlined,
      action: FrontendNavAction.admin,
      group: FrontendNavGroup.system,
      ownerSelectable: false,
      pinned: true,
    ),
    FrontendNavigationItem(
      id: 'logout',
      label: '登出',
      shortLabel: '登出',
      icon: Icons.logout,
      action: FrontendNavAction.logout,
      group: FrontendNavGroup.system,
      ownerSelectable: false,
      pinned: true,
      requiresLogin: true,
    ),
  ];

  static const List<String> defaultDrawerOrder = <String>[
    homeId,
    'member',
    'chat',
    'reviews',
    'orders',
    'storeOrders',
    'booking',
    'store',
    'environment',
    'rooms',
    'policy',
    'about',
    'announcements',
    'faq',
    'shopInfo',
  ];

  static List<FrontendNavigationItem> get selectableItems {
    return items
        .where((FrontendNavigationItem item) => item.ownerSelectable)
        .toList();
  }

  static FrontendNavigationItem? find(String id) {
    for (final FrontendNavigationItem item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }
}

class FrontendNavShopState {
  const FrontendNavShopState({
    required this.paidPlan,
    required this.storeEnabled,
    required this.chatEnabled,
    required this.announcementsEnabled,
    required this.faqEnabled,
    required this.showMemberCenter,
    required this.showShopMenus,
    required this.loggedIn,
  });

  final bool paidPlan;
  final bool storeEnabled;
  final bool chatEnabled;
  final bool announcementsEnabled;
  final bool faqEnabled;
  final bool showMemberCenter;
  final bool showShopMenus;
  final bool loggedIn;

  factory FrontendNavShopState.fromShop(
    Map<String, dynamic> shop, {
    required bool showMemberCenter,
    required bool showShopMenus,
    required bool loggedIn,
  }) {
    final String plan = (shop['plan'] ?? 'free').toString();
    final Object? paidUntil = shop['paidUntil'];
    bool paidActive = false;
    if (paidUntil != null) {
      final DateTime? until = _readDate(paidUntil);
      paidActive = until != null && until.isAfter(DateTime.now());
    }
    return FrontendNavShopState(
      paidPlan: plan != 'free' && paidActive,
      storeEnabled: StorefrontAccess.isModuleEnabled(shop),
      chatEnabled: ShopChatService.isEnabled(shop),
      announcementsEnabled: shop['showAnnouncementSection'] != false,
      faqEnabled: shop['showFaqSection'] != false,
      showMemberCenter: showMemberCenter,
      showShopMenus: showShopMenus,
      loggedIn: loggedIn,
    );
  }

  static DateTime? _readDate(Object value) {
    if (value is DateTime) {
      return value;
    }
    try {
      final dynamic timestamp = value;
      final DateTime? date = timestamp.toDate() as DateTime?;
      return date;
    } catch (_) {
      return null;
    }
  }

  bool isEnabled(FrontendNavigationItem item) {
    if (item.group == FrontendNavGroup.member && !showMemberCenter) {
      return false;
    }
    if (item.group == FrontendNavGroup.shop && !showShopMenus) {
      return false;
    }
    if (item.requiresPaidPlan && !paidPlan) {
      return false;
    }
    switch (item.action) {
      case FrontendNavAction.store:
      case FrontendNavAction.storeOrders:
        return storeEnabled;
      case FrontendNavAction.chat:
        return chatEnabled;
      case FrontendNavAction.announcements:
        return announcementsEnabled;
      case FrontendNavAction.faq:
        return faqEnabled;
      case FrontendNavAction.home:
      case FrontendNavAction.booking:
      case FrontendNavAction.rooms:
      case FrontendNavAction.orders:
      case FrontendNavAction.member:
      case FrontendNavAction.reviews:
      case FrontendNavAction.policy:
      case FrontendNavAction.about:
      case FrontendNavAction.environment:
      case FrontendNavAction.shopInfo:
      case FrontendNavAction.platform:
      case FrontendNavAction.admin:
      case FrontendNavAction.logout:
        return true;
    }
  }

  String? disabledReason(FrontendNavigationItem item) {
    if (isEnabled(item)) {
      return null;
    }
    return '尚未啟用';
  }
}

bool shopMemberCanOpenAdmin(String? role) {
  switch (role) {
    case ShopRoles.owner:
    case 'manager':
    case ShopRoles.staff:
      return true;
    default:
      return false;
  }
}

class FrontendNavigationConfig {
  const FrontendNavigationConfig({
    required this.style,
    required this.drawerItemOrder,
    required this.drawerHiddenItemIds,
    required this.left1,
    required this.left2,
    required this.right1,
    required this.right2,
    required this.bottomAppearance,
    required this.bottomSurface,
  });

  static const String styleDrawer = 'drawer';
  static const String styleBottom = 'bottom';
  static const String appearanceAttached = 'attached';
  static const String appearanceFloatingPill = 'floatingPill';
  static const String appearanceFloatingMinimal = 'floatingMinimal';
  static const String surfaceOpaque = 'opaque';
  static const String surfaceTranslucent = 'translucent';
  static const String surfaceTransparent = 'transparent';
  static const double phoneBreakpoint = 720;

  final String style;
  final List<String> drawerItemOrder;
  final List<String> drawerHiddenItemIds;
  final String? left1;
  final String? left2;
  final String? right1;
  final String? right2;
  final String bottomAppearance;
  final String bottomSurface;

  bool get isBottom => style == styleBottom;

  bool get isFloatingBar =>
      bottomAppearance == appearanceFloatingPill ||
      bottomAppearance == appearanceFloatingMinimal;

  bool usesBottomBar(double width) {
    return isBottom && width < phoneBreakpoint;
  }

  factory FrontendNavigationConfig.defaults() {
    return FrontendNavigationConfig(
      style: styleDrawer,
      drawerItemOrder: List<String>.from(
        FrontendNavigationRegistry.defaultDrawerOrder,
      ),
      drawerHiddenItemIds: const <String>[],
      left1: 'booking',
      left2: 'rooms',
      right1: 'orders',
      right2: 'member',
      bottomAppearance: appearanceAttached,
      bottomSurface: surfaceOpaque,
    );
  }

  factory FrontendNavigationConfig.fromMap(Map<String, dynamic>? map) {
    final FrontendNavigationConfig fallback = FrontendNavigationConfig.defaults();
    if (map == null) {
      return fallback;
    }
    final String rawStyle = (map['navigationStyle'] ?? styleDrawer).toString();
    final String style = rawStyle == styleBottom ? styleBottom : styleDrawer;
    final Map<String, dynamic> slots = map['bottomNavigationSlots'] is Map
        ? Map<String, dynamic>.from(map['bottomNavigationSlots'] as Map)
        : <String, dynamic>{};
    final Set<String> used = <String>{};
    String? take(Object? raw, String? fallbackId) {
      final String? cleaned = _cleanSlot(raw);
      final String? id = cleaned ?? fallbackId;
      if (id == null || used.contains(id)) {
        return null;
      }
      used.add(id);
      return id;
    }
    return FrontendNavigationConfig(
      style: style,
      drawerItemOrder: _cleanOrder(map['drawerItemOrder']),
      drawerHiddenItemIds: _cleanHidden(map['drawerHiddenItemIds']),
      left1: take(slots['left1'], fallback.left1),
      left2: take(slots['left2'], fallback.left2),
      right1: take(slots['right1'], fallback.right1),
      right2: take(slots['right2'], fallback.right2),
      bottomAppearance: _cleanAppearance(map['bottomNavigationAppearance']),
      bottomSurface: _cleanSurface(map['bottomNavigationSurface']),
    );
  }

  static String _cleanAppearance(Object? raw) {
    switch (raw?.toString()) {
      case appearanceFloatingPill:
      case appearanceFloatingMinimal:
        return raw.toString();
      default:
        return appearanceAttached;
    }
  }

  static String _cleanSurface(Object? raw) {
    switch (raw?.toString()) {
      case surfaceTranslucent:
      case surfaceTransparent:
        return raw.toString();
      default:
        return surfaceOpaque;
    }
  }

  static List<String> _cleanOrder(Object? raw) {
    final List<String> seen = <String>[];
    if (raw is List) {
      for (final Object? item in raw) {
        final String id = item.toString();
        final FrontendNavigationItem? known =
            FrontendNavigationRegistry.find(id);
        if (known == null || !known.ownerSelectable || seen.contains(id)) {
          continue;
        }
        seen.add(id);
      }
    }
    for (final String id in FrontendNavigationRegistry.defaultDrawerOrder) {
      if (!seen.contains(id)) {
        seen.add(id);
      }
    }
    if (!seen.contains(FrontendNavigationRegistry.homeId)) {
      seen.insert(0, FrontendNavigationRegistry.homeId);
    }
    return seen;
  }

  static List<String> _cleanHidden(Object? raw) {
    final List<String> hidden = <String>[];
    if (raw is! List) {
      return hidden;
    }
    for (final Object? item in raw) {
      final String id = item.toString();
      if (id == FrontendNavigationRegistry.homeId || hidden.contains(id)) {
        continue;
      }
      final FrontendNavigationItem? known = FrontendNavigationRegistry.find(id);
      if (known == null || !known.ownerSelectable) {
        continue;
      }
      hidden.add(id);
    }
    return hidden;
  }

  static String? _cleanSlot(Object? raw) {
    if (raw == null) {
      return null;
    }
    final String id = raw.toString().trim();
    if (id.isEmpty || id == FrontendNavigationRegistry.homeId) {
      return null;
    }
    final FrontendNavigationItem? known = FrontendNavigationRegistry.find(id);
    if (known == null || !known.ownerSelectable) {
      return null;
    }
    return id;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'navigationStyle': style,
      'drawerItemOrder': drawerItemOrder,
      'drawerHiddenItemIds': drawerHiddenItemIds,
      'bottomNavigationSlots': <String, String?>{
        'left1': left1,
        'left2': left2,
        'home': FrontendNavigationRegistry.homeId,
        'right1': right1,
        'right2': right2,
      },
      'bottomNavigationAppearance': bottomAppearance,
      'bottomNavigationSurface': bottomSurface,
    };
  }

  FrontendNavigationConfig copyWith({
    String? style,
    List<String>? drawerItemOrder,
    List<String>? drawerHiddenItemIds,
    String? left1,
    String? left2,
    String? right1,
    String? right2,
    String? bottomAppearance,
    String? bottomSurface,
    bool clearLeft1 = false,
    bool clearLeft2 = false,
    bool clearRight1 = false,
    bool clearRight2 = false,
  }) {
    return FrontendNavigationConfig(
      style: style ?? this.style,
      drawerItemOrder: drawerItemOrder ?? this.drawerItemOrder,
      drawerHiddenItemIds: drawerHiddenItemIds ?? this.drawerHiddenItemIds,
      left1: clearLeft1 ? null : (left1 ?? this.left1),
      left2: clearLeft2 ? null : (left2 ?? this.left2),
      right1: clearRight1 ? null : (right1 ?? this.right1),
      right2: clearRight2 ? null : (right2 ?? this.right2),
      bottomAppearance: bottomAppearance ?? this.bottomAppearance,
      bottomSurface: bottomSurface ?? this.bottomSurface,
    );
  }

  List<FrontendNavigationItem> visibleDrawerItems(FrontendNavShopState shop) {
    final List<FrontendNavigationItem> result = <FrontendNavigationItem>[];
    for (final String id in drawerItemOrder) {
      if (drawerHiddenItemIds.contains(id)) {
        continue;
      }
      final FrontendNavigationItem? item = FrontendNavigationRegistry.find(id);
      if (item == null || !item.ownerSelectable) {
        continue;
      }
      if (!shop.isEnabled(item)) {
        continue;
      }
      if (item.requiresLogin && !shop.loggedIn && item.action != FrontendNavAction.member) {
        continue;
      }
      result.add(item);
    }
    return result;
  }

  List<FrontendNavigationItem?> resolvedBottomSlots(FrontendNavShopState shop) {
    final List<String?> requested = <String?>[left1, left2, right1, right2];
    final List<String> used = <String>[];
    final List<String?> resolved = <String?>[];
    for (final String? id in requested) {
      final String? safe = _usableSlot(id, shop, used);
      if (safe != null) {
        used.add(safe);
      }
      resolved.add(safe);
    }
    final List<String> fallback = <String>[
      'booking',
      'rooms',
      'orders',
      'member',
      'shopInfo',
      'reviews',
      'environment',
      'about',
    ];
    for (int i = 0; i < resolved.length; i++) {
      if (resolved[i] != null) {
        continue;
      }
      for (final String id in fallback) {
        final String? safe = _usableSlot(id, shop, used);
        if (safe == null) {
          continue;
        }
        used.add(safe);
        resolved[i] = safe;
        break;
      }
    }
    return <FrontendNavigationItem?>[
      _itemOrNull(resolved[0]),
      _itemOrNull(resolved[1]),
      FrontendNavigationRegistry.find(FrontendNavigationRegistry.homeId),
      _itemOrNull(resolved[2]),
      _itemOrNull(resolved[3]),
    ];
  }

  static String? _usableSlot(
    String? id,
    FrontendNavShopState shop,
    List<String> used,
  ) {
    if (id == null || used.contains(id)) {
      return null;
    }
    final FrontendNavigationItem? item = FrontendNavigationRegistry.find(id);
    if (item == null || !item.ownerSelectable || item.id == FrontendNavigationRegistry.homeId) {
      return null;
    }
    if (!shop.isEnabled(item)) {
      return null;
    }
    return item.id;
  }

  static FrontendNavigationItem? _itemOrNull(String? id) {
    if (id == null) {
      return null;
    }
    return FrontendNavigationRegistry.find(id);
  }

  static List<String> reorder(List<String> order, int oldIndex, int newIndex) {
    final List<String> next = List<String>.from(order);
    if (oldIndex < 0 || oldIndex >= next.length) {
      return next;
    }
    int target = newIndex;
    if (target > oldIndex) {
      target -= 1;
    }
    target = target.clamp(0, next.length - 1);
    final String moved = next.removeAt(oldIndex);
    next.insert(target, moved);
    return next;
  }

  @override
  bool operator ==(Object other) {
    if (other is! FrontendNavigationConfig) {
      return false;
    }
    return style == other.style &&
        _listEquals(drawerItemOrder, other.drawerItemOrder) &&
        _listEquals(drawerHiddenItemIds, other.drawerHiddenItemIds) &&
        left1 == other.left1 &&
        left2 == other.left2 &&
        right1 == other.right1 &&
        right2 == other.right2 &&
        bottomAppearance == other.bottomAppearance &&
        bottomSurface == other.bottomSurface;
  }

  @override
  int get hashCode => Object.hash(
    style,
    Object.hashAll(drawerItemOrder),
    Object.hashAll(drawerHiddenItemIds),
    left1,
    left2,
    right1,
    right2,
    bottomAppearance,
    bottomSurface,
  );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

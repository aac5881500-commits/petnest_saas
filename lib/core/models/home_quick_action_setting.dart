// 檔案名稱：lib/core/models/home_quick_action_setting.dart
// 功能說明：新版首頁快捷功能列的外觀與開關。存在 homeAppearance.modern.homeQuickActions。

class HomeQuickActionIds {
  static const String notifications = 'notifications';
  static const String cart = 'cart';
  static const String chat = 'chat';

  static const List<String> known = <String>[notifications, cart, chat];
}

class HomeQuickActionItem {
  const HomeQuickActionItem({required this.id, required this.enabled});

  final String id;
  final bool enabled;

  HomeQuickActionItem copyWith({bool? enabled}) {
    return HomeQuickActionItem(id: id, enabled: enabled ?? this.enabled);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'enabled': id == HomeQuickActionIds.notifications || enabled,
    };
  }
}

class HomeQuickActionSetting {
  const HomeQuickActionSetting({
    this.placement = placementEnd,
    this.containerStyle = containerCapsule,
    this.backgroundMode = backgroundTranslucent,
    this.backgroundColorValue = 0xFFFFFFFF,
    this.iconSize = sizeMedium,
    this.iconColorMode = iconTheme,
    this.iconColorValue = 0xFF3A2A20,
    this.showBadges = true,
    this.items = defaultItems,
  });

  static const String mapKey = 'homeQuickActions';

  static const String placementEnd = 'end';
  static const String placementStart = 'start';
  static const String containerCapsule = 'capsule';
  static const String containerCircles = 'circles';
  static const String containerPlain = 'plain';
  static const String backgroundTheme = 'theme';
  static const String backgroundTranslucent = 'translucent';
  static const String backgroundCustom = 'custom';
  static const String sizeSmall = 'small';
  static const String sizeMedium = 'medium';
  static const String sizeLarge = 'large';
  static const String iconTheme = 'theme';
  static const String iconCustom = 'custom';

  static const List<HomeQuickActionItem> defaultItems = <HomeQuickActionItem>[
    HomeQuickActionItem(id: HomeQuickActionIds.notifications, enabled: true),
    HomeQuickActionItem(id: HomeQuickActionIds.cart, enabled: true),
    HomeQuickActionItem(id: HomeQuickActionIds.chat, enabled: true),
  ];

  final String placement;
  final String containerStyle;
  final String backgroundMode;
  final int backgroundColorValue;
  final String iconSize;
  final String iconColorMode;
  final int iconColorValue;
  final bool showBadges;
  final List<HomeQuickActionItem> items;

  bool get atStart => placement == placementStart;

  List<HomeQuickActionItem> get knownItems {
    return items
        .where((HomeQuickActionItem item) => _known(item.id))
        .toList(growable: false);
  }

  List<HomeQuickActionItem> get extraItems {
    return items
        .where((HomeQuickActionItem item) => !_known(item.id))
        .toList(growable: false);
  }

  factory HomeQuickActionSetting.fromMap(dynamic raw) {
    if (raw is! Map) {
      return const HomeQuickActionSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    return HomeQuickActionSetting(
      placement: _oneOf(map['placement'], const <String>[
        placementEnd,
        placementStart,
      ], placementEnd),
      containerStyle: _oneOf(map['containerStyle'], const <String>[
        containerCapsule,
        containerCircles,
        containerPlain,
      ], containerCapsule),
      backgroundMode: _oneOf(map['backgroundMode'], const <String>[
        backgroundTheme,
        backgroundTranslucent,
        backgroundCustom,
      ], backgroundTranslucent),
      backgroundColorValue: _color(map['backgroundColorValue'], 0xFFFFFFFF),
      iconSize: _oneOf(map['iconSize'], const <String>[
        sizeSmall,
        sizeMedium,
        sizeLarge,
      ], sizeMedium),
      iconColorMode: _oneOf(map['iconColorMode'], const <String>[
        iconTheme,
        iconCustom,
      ], iconTheme),
      iconColorValue: _color(map['iconColorValue'], 0xFF3A2A20),
      showBadges: map['showBadges'] != false,
      items: _items(map['items']),
    );
  }

  /// 前台實際畫出的按鈕。通知固定保留；購物車與聊天還要功能本身有開啟。
  List<HomeQuickActionItem> visibleItems({
    required bool storeEnabled,
    required bool chatEnabled,
  }) {
    return knownItems
        .where((HomeQuickActionItem item) {
          if (item.id == HomeQuickActionIds.notifications) {
            return true;
          }
          if (!item.enabled) {
            return false;
          }
          if (item.id == HomeQuickActionIds.cart) {
            return storeEnabled;
          }
          if (item.id == HomeQuickActionIds.chat) {
            return chatEnabled;
          }
          return false;
        })
        .toList(growable: false);
  }

  HomeQuickActionSetting toggle(String id, bool enabled) {
    if (id == HomeQuickActionIds.notifications) {
      return this;
    }
    return copyWith(
      items: items
          .map(
            (HomeQuickActionItem item) =>
                item.id == id ? item.copyWith(enabled: enabled) : item,
          )
          .toList(growable: false),
    );
  }

  HomeQuickActionSetting moveKnown(int index, int delta) {
    final List<HomeQuickActionItem> next = List<HomeQuickActionItem>.of(
      knownItems,
    );
    final int target = index + delta;
    if (index < 0 ||
        index >= next.length ||
        target < 0 ||
        target >= next.length) {
      return this;
    }
    final HomeQuickActionItem item = next.removeAt(index);
    next.insert(target, item);
    return copyWith(items: <HomeQuickActionItem>[...next, ...extraItems]);
  }

  HomeQuickActionSetting copyWith({
    String? placement,
    String? containerStyle,
    String? backgroundMode,
    int? backgroundColorValue,
    String? iconSize,
    String? iconColorMode,
    int? iconColorValue,
    bool? showBadges,
    List<HomeQuickActionItem>? items,
  }) {
    return HomeQuickActionSetting(
      placement: placement ?? this.placement,
      containerStyle: containerStyle ?? this.containerStyle,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      iconSize: iconSize ?? this.iconSize,
      iconColorMode: iconColorMode ?? this.iconColorMode,
      iconColorValue: iconColorValue ?? this.iconColorValue,
      showBadges: showBadges ?? this.showBadges,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'placement': placement,
      'containerStyle': containerStyle,
      'backgroundMode': backgroundMode,
      'backgroundColorValue': backgroundColorValue,
      'iconSize': iconSize,
      'iconColorMode': iconColorMode,
      'iconColorValue': iconColorValue,
      'showBadges': showBadges,
      'items': items
          .map((HomeQuickActionItem item) => item.toMap())
          .toList(growable: false),
    };
  }

  static bool _known(String id) => HomeQuickActionIds.known.contains(id);

  static List<HomeQuickActionItem> _items(dynamic raw) {
    final List<HomeQuickActionItem> parsed = <HomeQuickActionItem>[];
    final Set<String> seen = <String>{};
    if (raw is List) {
      for (final dynamic entry in raw) {
        if (entry is! Map) {
          continue;
        }
        final String id = (entry['id'] ?? '').toString().trim();
        if (id.isEmpty || seen.contains(id)) {
          continue;
        }
        seen.add(id);
        parsed.add(
          HomeQuickActionItem(
            id: id,
            enabled:
                id == HomeQuickActionIds.notifications ||
                entry['enabled'] != false,
          ),
        );
      }
    }
    for (final String id in HomeQuickActionIds.known) {
      if (!seen.contains(id)) {
        parsed.add(HomeQuickActionItem(id: id, enabled: true));
      }
    }
    return parsed;
  }

  static String _oneOf(dynamic raw, List<String> allowed, String fallback) {
    final String value = (raw ?? '').toString();
    return allowed.contains(value) ? value : fallback;
  }

  static int _color(dynamic raw, int fallback) {
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse((raw ?? '').toString()) ?? fallback;
  }
}

/// 0 不顯示；1–99 顯示數字；超過 99 顯示 99+。
String? homeQuickActionBadgeLabel(int count) {
  if (count <= 0) {
    return null;
  }
  if (count > 99) {
    return '99+';
  }
  return '$count';
}

/// 購物車角標用各品項數量加總，與商城頁購物車角標相同。
int homeQuickActionCartQuantity(Iterable<int> quantities) {
  var total = 0;
  for (final int quantity in quantities) {
    if (quantity > 0) {
      total += quantity;
    }
  }
  return total;
}

// 檔案名稱：lib/core/models/home_quick_action_setting.dart
// 功能說明：新版首頁快捷功能列的外觀與開關。存在 homeAppearance.modern.homeQuickActions。

class HomeQuickActionIds {
  static const String notifications = 'notifications';
  static const String cart = 'cart';
  static const String chat = 'chat';
  static const String phone = 'phone';
  static const String line = 'line';
  static const String facebook = 'facebook';
  static const String instagram = 'instagram';
  static const String bookings = 'bookings';
  static const String promotions = 'promotions';
  static const String member = 'member';
  static const String faq = 'faq';
  static const String none = '';

  /// 舊版只有這三個，缺資料時才補回，避免新功能被當成預設開啟。
  static const List<String> known = <String>[notifications, cart, chat];

  static const List<String> shortcuts = <String>[
    cart,
    chat,
    phone,
    line,
    facebook,
    instagram,
    bookings,
    promotions,
    member,
    faq,
  ];

  static bool isShortcut(String id) => shortcuts.contains(id);

  static bool isRecognized(String id) {
    return id == notifications || isShortcut(id);
  }
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
    this.slotOne = HomeQuickActionIds.cart,
    this.slotTwo = HomeQuickActionIds.chat,
    this.slotsStored = false,
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

  /// 右上角兩個可選位置。空字串表示不顯示。通知鈴鐺不佔這兩個位置。
  final String slotOne;
  final String slotTwo;

  /// 為 false 時，兩個位置是由舊版 items 推導，尚未寫入 slots。
  final bool slotsStored;

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
    final List<HomeQuickActionItem> parsedItems = _items(map['items']);
    final (String, String) slots = _slots(map, parsedItems);
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
      items: parsedItems,
      slotOne: slots.$1,
      slotTwo: slots.$2,
      slotsStored: map.containsKey('slots'),
    );
  }

  /// 改一個快捷鍵位置，保留另一個位置原本的選擇。
  HomeQuickActionSetting assignSlot(int index, String id) {
    final String next = id.trim();
    if (index == 0) {
      return next == slotOne
          ? this
          : copyWith(slotOne: next, slotsStored: true);
    }
    if (index == 1) {
      return next == slotTwo
          ? this
          : copyWith(slotTwo: next, slotsStored: true);
    }
    return this;
  }

  /// 只有已經寫入 slots 且明確選了聊天，才算店家把聊天放在右上角。
  static bool savedSlotsUseChat(Map<String, dynamic>? shop) {
    final dynamic appearance = shop?['homeAppearance'];
    if (appearance is! Map) {
      return false;
    }
    final dynamic modern = appearance['modern'];
    if (modern is! Map) {
      return false;
    }
    final dynamic raw = modern[mapKey];
    if (raw is! Map || !raw.containsKey('slots')) {
      return false;
    }
    final dynamic slots = raw['slots'];
    if (slots is! List) {
      return false;
    }
    return slots.any(
      (dynamic value) => value?.toString().trim() == HomeQuickActionIds.chat,
    );
  }

  /// 舊版測試與相容用：只依兩個位置判斷購物車與聊天。
  List<HomeQuickActionItem> visibleItems({
    required bool storeEnabled,
    required bool chatEnabled,
  }) {
    final List<String> ids = <String>[HomeQuickActionIds.notifications];
    for (final String slot in <String>[slotOne, slotTwo]) {
      if (slot.isEmpty || ids.contains(slot)) {
        continue;
      }
      final bool shown = switch (slot) {
        HomeQuickActionIds.cart => storeEnabled,
        HomeQuickActionIds.chat => chatEnabled,
        _ => false,
      };
      if (shown) {
        ids.add(slot);
      }
    }
    return ids
        .map((String id) => HomeQuickActionItem(id: id, enabled: true))
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
    String? slotOne,
    String? slotTwo,
    bool? slotsStored,
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
      slotOne: slotOne ?? this.slotOne,
      slotTwo: slotTwo ?? this.slotTwo,
      slotsStored: slotsStored ?? this.slotsStored,
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
      'slots': <String>[slotOne, slotTwo],
      'items': _savedItems()
          .map((HomeQuickActionItem item) => item.toMap())
          .toList(growable: false),
    };
  }

  List<HomeQuickActionItem> _savedItems() {
    final List<HomeQuickActionItem> saved = <HomeQuickActionItem>[];
    void add(String id, bool enabled) {
      if (id.isEmpty ||
          saved.any((HomeQuickActionItem item) => item.id == id)) {
        return;
      }
      saved.add(HomeQuickActionItem(id: id, enabled: enabled));
    }

    add(HomeQuickActionIds.notifications, true);
    add(
      HomeQuickActionIds.cart,
      slotOne == HomeQuickActionIds.cart || slotTwo == HomeQuickActionIds.cart,
    );
    add(
      HomeQuickActionIds.chat,
      slotOne == HomeQuickActionIds.chat || slotTwo == HomeQuickActionIds.chat,
    );
    if (slotOne.isNotEmpty) {
      add(slotOne, true);
    }
    if (slotTwo.isNotEmpty) {
      add(slotTwo, true);
    }
    for (final HomeQuickActionItem extra in extraItems) {
      add(extra.id, extra.enabled);
    }
    return saved;
  }

  static bool _known(String id) => HomeQuickActionIds.isRecognized(id);

  static (String, String) _slots(
    Map<String, dynamic> map,
    List<HomeQuickActionItem> parsedItems,
  ) {
    if (map.containsKey('slots')) {
      return _readSlots(map['slots']);
    }
    final List<String> derived = <String>['', ''];
    var index = 0;
    for (final HomeQuickActionItem item in parsedItems) {
      if (index >= 2) {
        break;
      }
      if (!item.enabled || !HomeQuickActionIds.isShortcut(item.id)) {
        continue;
      }
      derived[index] = item.id;
      index += 1;
    }
    return (derived[0], derived[1]);
  }

  static (String, String) _readSlots(dynamic raw) {
    final List<String> slots = <String>['', ''];
    if (raw is List) {
      var index = 0;
      for (final dynamic value in raw) {
        if (index >= 2) {
          break;
        }
        slots[index] = value?.toString().trim() ?? '';
        index += 1;
      }
    }
    return (slots[0], slots[1]);
  }

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

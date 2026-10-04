const String kHomeQuickBookingClosedMessage = '目前住宿與安親皆未開啟，正式前台不會顯示此區塊';

class HomeQuickBookingLayouts {
  static const String compactCard = 'compactCard';
  static const String singleLine = 'singleLine';
  static const String serviceSplit = 'serviceSplit';
  static const List<String> all = <String>[
    compactCard,
    singleLine,
    serviceSplit,
  ];

  static String label(String value) {
    switch (migrate(value)) {
      case compactCard:
        return '迷你入口';
      case singleLine:
        return '單行按鈕';
      default:
        return '服務選擇';
    }
  }

  static String description(String value) {
    switch (migrate(value)) {
      case compactCard:
        return '半寬小卡，可與其他小卡並排';
      case singleLine:
        return '整排預約入口，簡單不占空間';
      default:
        return '住宿與安親分開顯示';
    }
  }

  static String badge(String value) {
    return migrate(value) == compactCard ? '半格' : '整排';
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : serviceSplit;
  }
}

class HomeQuickBookingSurfaces {
  static const String solid = 'solid';
  static const String translucent = 'translucent';
  static const String transparent = 'transparent';
  static const List<String> all = <String>[solid, translucent, transparent];

  static String label(String value) {
    switch (migrate(value)) {
      case translucent:
        return '半透明';
      case transparent:
        return '透明';
      default:
        return '實色';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : solid;
  }
}

class HomeQuickBookingTextAligns {
  static const String left = 'left';
  static const String center = 'center';
  static const List<String> all = <String>[left, center];

  static String label(String value) {
    return migrate(value) == center ? '置中' : '靠左';
  }

  static String migrate(Object? raw) {
    return raw?.toString().trim() == center ? center : left;
  }
}

class HomeQuickBookingSectionSetting {
  const HomeQuickBookingSectionSetting({
    this.schemaVersion = 1,
    this.showOnHome = false,
    this.layout = HomeQuickBookingLayouts.serviceSplit,
    this.title = '快速預約',
    this.subtitle = '選擇服務，開始安排毛孩行程',
    this.buttonText = '我要預約',
    this.showAccommodation = true,
    this.showDaycare = true,
    this.showIcon = true,
    this.surfaceStyle = HomeQuickBookingSurfaces.solid,
    this.textAlign = HomeQuickBookingTextAligns.left,
  });

  final int schemaVersion;
  final bool showOnHome;
  final String layout;
  final String title;
  final String subtitle;
  final String buttonText;
  final bool showAccommodation;
  final bool showDaycare;
  final bool showIcon;
  final String surfaceStyle;
  final String textAlign;

  bool get isHalf =>
      HomeQuickBookingLayouts.migrate(layout) ==
      HomeQuickBookingLayouts.compactCard;

  String get entryTitle => _fallback(title, '快速預約', 16);

  String get entrySubtitle => _clip(subtitle, 36);

  String get entryButton => _fallback(buttonText, '我要預約', 10);

  HomeQuickBookingSectionSetting copyWith({
    int? schemaVersion,
    bool? showOnHome,
    String? layout,
    String? title,
    String? subtitle,
    String? buttonText,
    bool? showAccommodation,
    bool? showDaycare,
    bool? showIcon,
    String? surfaceStyle,
    String? textAlign,
  }) {
    return HomeQuickBookingSectionSetting(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      showOnHome: showOnHome ?? this.showOnHome,
      layout: layout ?? this.layout,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      buttonText: buttonText ?? this.buttonText,
      showAccommodation: showAccommodation ?? this.showAccommodation,
      showDaycare: showDaycare ?? this.showDaycare,
      showIcon: showIcon ?? this.showIcon,
      surfaceStyle: surfaceStyle ?? this.surfaceStyle,
      textAlign: textAlign ?? this.textAlign,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion < 1 ? 1 : schemaVersion,
      'showOnHome': showOnHome,
      'layout': HomeQuickBookingLayouts.migrate(layout),
      'title': _clip(title, 16),
      'subtitle': _clip(subtitle, 36),
      'buttonText': _clip(buttonText, 10),
      'showAccommodation': showAccommodation,
      'showDaycare': showDaycare,
      'showIcon': showIcon,
      'surfaceStyle': HomeQuickBookingSurfaces.migrate(surfaceStyle),
      'textAlign': HomeQuickBookingTextAligns.migrate(textAlign),
    };
  }

  static HomeQuickBookingSectionSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeQuickBookingSectionSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final String title = _clip(map['title'], 16);
    final String subtitle = _clip(map['subtitle'], 36);
    final String button = _clip(map['buttonText'], 10);
    return HomeQuickBookingSectionSetting(
      schemaVersion: _version(map['schemaVersion']),
      showOnHome: map['showOnHome'] == true,
      layout: HomeQuickBookingLayouts.migrate(map['layout']),
      title: title.isEmpty ? '快速預約' : title,
      subtitle: subtitle.isEmpty ? '選擇服務，開始安排毛孩行程' : subtitle,
      buttonText: button.isEmpty ? '我要預約' : button,
      showAccommodation: map['showAccommodation'] is bool
          ? map['showAccommodation'] as bool
          : true,
      showDaycare: map['showDaycare'] is bool
          ? map['showDaycare'] as bool
          : true,
      showIcon: map['showIcon'] is bool ? map['showIcon'] as bool : true,
      surfaceStyle: HomeQuickBookingSurfaces.migrate(map['surfaceStyle']),
      textAlign: HomeQuickBookingTextAligns.migrate(map['textAlign']),
    );
  }
}

/// 正式前台要同時看外觀開關與真正的服務開關。編排預覽只要開啟首頁顯示就占位。
bool homeQuickBookingVisible({
  required HomeQuickBookingSectionSetting setting,
  required bool editorPreview,
  required bool accommodationAvailable,
  required bool daycareAvailable,
}) {
  if (!setting.showOnHome) {
    return false;
  }
  if (editorPreview) {
    return true;
  }
  final bool stay = setting.showAccommodation && accommodationAvailable;
  final bool daycare = setting.showDaycare && daycareAvailable;
  return stay || daycare;
}

int _version(Object? raw) {
  final int? value = raw is num ? raw.toInt() : int.tryParse('$raw');
  if (value == null || value < 1) {
    return 1;
  }
  return value;
}

String _clip(Object? raw, int maxCharacters) {
  final String value = raw?.toString().trim() ?? '';
  if (value.length <= maxCharacters) {
    return value;
  }
  return value.substring(0, maxCharacters);
}

String _fallback(Object? raw, String fallback, int maxCharacters) {
  final String value = _clip(raw, maxCharacters);
  return value.isEmpty ? fallback : value;
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/discount_campaign_model.dart';

/// 新版首頁最新消息版型。
class HomeNewsLayouts {
  static const String compactCard = 'compactCard';
  static const String singleLine = 'singleLine';
  static const String multiLine = 'multiLine';
  static const List<String> all = <String>[compactCard, singleLine, multiLine];

  static String label(String value) {
    switch (migrate(value)) {
      case compactCard:
        return '簡約小卡';
      case multiLine:
        return '多行消息';
      default:
        return '單行消息';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    if (all.contains(value)) {
      return value;
    }
    return singleLine;
  }
}

/// 首頁消息內容來源。優惠活動不是公告裡的 promotion 類型。
class HomeNewsSources {
  static const String notices = 'notices';
  static const String campaigns = 'campaigns';
  static const String both = 'both';
  static const List<String> all = <String>[notices, campaigns, both];

  static String label(String value) {
    switch (migrate(value)) {
      case notices:
        return '店家公告';
      case campaigns:
        return '優惠活動';
      default:
        return '公告＋優惠活動';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    if (all.contains(value)) {
      return value;
    }
    return both;
  }
}

class HomeNewsSurfaces {
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
    if (all.contains(value)) {
      return value;
    }
    return solid;
  }

  static String entrySurface(String value) {
    switch (migrate(value)) {
      case translucent:
        return 'translucent';
      case transparent:
        return 'transparent';
      default:
        return 'filled';
    }
  }
}

class HomeNewsTextAligns {
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

class HomeNewsIconTypes {
  static const String campaign = 'campaign';
}

const String kHomeNewsEmptyMessage = '目前沒有符合條件的公告或優惠';
const String kHomeNewsErrorMessage = '消息暫時無法載入';
const String kHomeNewsLockedMessage = '請先到前台功能開啟『最新公告』，才能調整首頁消息版型。';

class HomeNewsSectionSetting {
  const HomeNewsSectionSetting({
    this.schemaVersion = 1,
    this.layout = HomeNewsLayouts.singleLine,
    this.source = HomeNewsSources.both,
    this.title = '最新消息',
    this.multiLineCount = 3,
    this.showSummary = true,
    this.showDate = false,
    this.showTypeBadge = true,
    this.showArrow = true,
    this.surfaceStyle = HomeNewsSurfaces.solid,
    this.textAlign = HomeNewsTextAligns.left,
  });

  final int schemaVersion;
  final String layout;
  final String source;
  final String title;
  final int multiLineCount;
  final bool showSummary;
  final bool showDate;
  final bool showTypeBadge;
  final bool showArrow;
  final String surfaceStyle;
  final String textAlign;

  bool get isHalf =>
      HomeNewsLayouts.migrate(layout) == HomeNewsLayouts.compactCard;

  String get entryTitle {
    final String text = title.trim();
    return text.isEmpty ? '最新消息' : text;
  }

  HomeNewsSectionSetting copyWith({
    int? schemaVersion,
    String? layout,
    String? source,
    String? title,
    int? multiLineCount,
    bool? showSummary,
    bool? showDate,
    bool? showTypeBadge,
    bool? showArrow,
    String? surfaceStyle,
    String? textAlign,
  }) {
    return HomeNewsSectionSetting(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      layout: layout ?? this.layout,
      source: source ?? this.source,
      title: title ?? this.title,
      multiLineCount: multiLineCount ?? this.multiLineCount,
      showSummary: showSummary ?? this.showSummary,
      showDate: showDate ?? this.showDate,
      showTypeBadge: showTypeBadge ?? this.showTypeBadge,
      showArrow: showArrow ?? this.showArrow,
      surfaceStyle: surfaceStyle ?? this.surfaceStyle,
      textAlign: textAlign ?? this.textAlign,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'layout': HomeNewsLayouts.migrate(layout),
      'source': HomeNewsSources.migrate(source),
      'title': _clip(title, 24),
      'multiLineCount': HomeNewsSectionSetting.migrateCount(multiLineCount),
      'showSummary': showSummary,
      'showDate': showDate,
      'showTypeBadge': showTypeBadge,
      'showArrow': showArrow,
      'surfaceStyle': HomeNewsSurfaces.migrate(surfaceStyle),
      'textAlign': HomeNewsTextAligns.migrate(textAlign),
    };
  }

  static HomeNewsSectionSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeNewsSectionSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final String title = _clip(map['title'], 24);
    return HomeNewsSectionSetting(
      schemaVersion: map['schemaVersion'] is num
          ? (map['schemaVersion'] as num).toInt()
          : 1,
      layout: HomeNewsLayouts.migrate(map['layout']),
      source: HomeNewsSources.migrate(map['source']),
      title: title.isEmpty ? '最新消息' : title,
      multiLineCount: migrateCount(map['multiLineCount']),
      showSummary: map['showSummary'] is bool
          ? map['showSummary'] as bool
          : true,
      showDate: map['showDate'] is bool ? map['showDate'] as bool : false,
      showTypeBadge: map['showTypeBadge'] is bool
          ? map['showTypeBadge'] as bool
          : true,
      showArrow: map['showArrow'] is bool ? map['showArrow'] as bool : true,
      surfaceStyle: HomeNewsSurfaces.migrate(map['surfaceStyle']),
      textAlign: HomeNewsTextAligns.migrate(map['textAlign']),
    );
  }

  static int migrateCount(Object? raw) {
    final int? value = raw is num ? raw.toInt() : int.tryParse('$raw');
    return value == 2 ? 2 : 3;
  }
}

/// 首頁消息的統一展示資料。公告與優惠活動進畫面之前先轉成這個模型。
class HomeNewsItem {
  const HomeNewsItem({
    required this.id,
    required this.sourceType,
    required this.title,
    required this.summary,
    required this.publishedAt,
    required this.pinned,
    required this.iconType,
  });

  final String id;
  final String sourceType;
  final String title;
  final String summary;
  final DateTime publishedAt;
  final bool pinned;
  final String iconType;

  bool get isCampaign => sourceType == HomeNewsSources.campaigns;

  static HomeNewsItem notice(Map<String, dynamic> data) {
    final String title = (data['title'] ?? '').toString().trim();
    return HomeNewsItem(
      id: (data['id'] ?? '').toString(),
      sourceType: HomeNewsSources.notices,
      title: title.isEmpty ? '未命名公告' : title,
      summary: (data['content'] ?? '').toString().trim(),
      publishedAt: _time(data['createdAt']),
      pinned: data['isPinned'] == true,
      iconType: (data['type'] ?? 'normal').toString(),
    );
  }

  static HomeNewsItem campaign(DiscountCampaignModel data) {
    final String title = data.name.trim();
    return HomeNewsItem(
      id: data.id,
      sourceType: HomeNewsSources.campaigns,
      title: title.isEmpty ? '優惠活動' : title,
      summary: data.description.trim(),
      publishedAt: data.createdAt,
      pinned: false,
      iconType: HomeNewsIconTypes.campaign,
    );
  }

  static List<HomeNewsItem> noticesFromMaps(
    Iterable<Map<String, dynamic>> raw,
  ) {
    return raw
        .where((Map<String, dynamic> item) => item['isPublished'] == true)
        .map(notice)
        .toList();
  }
}

/// 置頂公告優先，其餘依建立時間新到舊。
List<HomeNewsItem> mergeHomeNews({
  required String source,
  required List<HomeNewsItem> notices,
  required List<HomeNewsItem> campaigns,
}) {
  final String selected = HomeNewsSources.migrate(source);
  final List<HomeNewsItem> items = switch (selected) {
    HomeNewsSources.notices => List<HomeNewsItem>.from(notices),
    HomeNewsSources.campaigns => List<HomeNewsItem>.from(campaigns),
    _ => <HomeNewsItem>[...notices, ...campaigns],
  };
  items.sort((HomeNewsItem a, HomeNewsItem b) {
    if (a.pinned != b.pinned) {
      return a.pinned ? -1 : 1;
    }
    return b.publishedAt.compareTo(a.publishedAt);
  });
  return items;
}

enum HomeNewsSectionPhase { hidden, loading, unavailable, empty, ready }

class HomeNewsLoadState {
  const HomeNewsLoadState({
    this.noticesReady = false,
    this.campaignsReady = false,
    this.noticesFailed = false,
    this.campaignsFailed = false,
  });

  final bool noticesReady;
  final bool campaignsReady;
  final bool noticesFailed;
  final bool campaignsFailed;
}

/// 正式前台沒有內容時回傳 [HomeNewsSectionPhase.hidden]，排版前就拿掉區塊。
HomeNewsSectionPhase resolveHomeNewsPhase({
  required bool featureEnabled,
  required bool editorPreview,
  required String source,
  required HomeNewsLoadState load,
  required bool hasItems,
}) {
  if (!featureEnabled) {
    return HomeNewsSectionPhase.hidden;
  }
  final String selected = HomeNewsSources.migrate(source);
  final bool needNotices = selected != HomeNewsSources.campaigns;
  final bool needCampaigns = selected != HomeNewsSources.notices;
  final bool waiting =
      (needNotices && !load.noticesReady) ||
      (needCampaigns && !load.campaignsReady);
  final bool failed = switch (selected) {
    HomeNewsSources.notices => load.noticesFailed,
    HomeNewsSources.campaigns => load.campaignsFailed,
    _ => !hasItems && (load.noticesFailed || load.campaignsFailed),
  };
  if (editorPreview) {
    if (waiting) {
      return HomeNewsSectionPhase.loading;
    }
    if (failed && !hasItems) {
      return HomeNewsSectionPhase.unavailable;
    }
    if (!hasItems) {
      return HomeNewsSectionPhase.empty;
    }
    return HomeNewsSectionPhase.ready;
  }
  if (waiting || failed || !hasItems) {
    return HomeNewsSectionPhase.hidden;
  }
  return HomeNewsSectionPhase.ready;
}

bool homeNewsOccupiesSection(HomeNewsSectionPhase phase) {
  return phase != HomeNewsSectionPhase.hidden;
}

DateTime _time(Object? raw) {
  if (raw is DateTime) {
    return raw;
  }
  if (raw is Timestamp) {
    return raw.toDate();
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

String _clip(Object? raw, int maxCharacters) {
  final String value = raw?.toString().trim() ?? '';
  if (value.length <= maxCharacters) {
    return value;
  }
  return value.substring(0, maxCharacters);
}

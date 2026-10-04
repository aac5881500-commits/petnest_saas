import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/core/services/shop_policy_history.dart';

const String kHomePolicyEmptyMessage = '尚未建立入住須知';
const String kHomeFaqEmptyMessage = '尚未發布常見問題';
const String kHomeFaqLockedMessage = '請先到前台功能開啟常見問題';
const String kHomeReviewEmptyMessage = '尚未有公開評價';
const String kHomeInfoHiddenEntryMessage = '目前首頁與住宿服務都不會顯示此入口';

class HomePolicyLayouts {
  static const String compact = 'compact';
  static const String singleLine = 'singleLine';
  static const String summary = 'summary';
  static const String serviceSplit = 'serviceSplit';
  static const List<String> all = <String>[
    compact,
    singleLine,
    summary,
    serviceSplit,
  ];

  static String label(String value) {
    switch (migrate(value)) {
      case singleLine:
        return '單行入口';
      case summary:
        return '條款重點';
      case serviceSplit:
        return '服務分類';
      default:
        return '簡約小卡';
    }
  }

  static String description(String value) {
    switch (migrate(value)) {
      case singleLine:
        return '整排單行入口，適合只需要一個前往完整條款的按鈕。';
      case summary:
        return '顯示版本、適用範圍與前幾項已啟用條款標題。';
      case serviceSplit:
        return '住宿與安親各自一張入口，只顯示實際有內容的服務。';
      default:
        return '半格小卡，可與其他小卡左右並排。';
    }
  }

  static String badge(String value) {
    return migrate(value) == compact ? '半格' : '整排';
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : compact;
  }
}

class HomeFaqLayouts {
  static const String compact = 'compact';
  static const String singleLine = 'singleLine';
  static const String preview = 'preview';
  static const String horizontalCards = 'horizontalCards';
  static const String twoColumnCards = 'twoColumnCards';
  static const List<String> all = <String>[
    compact,
    singleLine,
    preview,
    horizontalCards,
    twoColumnCards,
  ];

  static String label(String value) {
    switch (migrate(value)) {
      case singleLine:
        return '單行入口';
      case preview:
        return '展開問答';
      case horizontalCards:
        return '橫向問題卡';
      case twoColumnCards:
        return '雙欄問題卡';
      default:
        return '簡約小卡';
    }
  }

  static String description(String value) {
    switch (migrate(value)) {
      case singleLine:
        return '整排單行入口，顯示題數與箭頭。';
      case preview:
        return '在首頁展開前幾題答案，其餘進入完整頁面。';
      case horizontalCards:
        return '每題一張卡，可向右滑動，最後進入全部問題。';
      case twoColumnCards:
        return '一排兩張問題卡，最後一張維持半寬。';
      default:
        return '半格小卡，顯示標題與已發布題數。';
    }
  }

  static String badge(String value) {
    switch (migrate(value)) {
      case compact:
        return '半格';
      case horizontalCards:
        return '可右滑';
      default:
        return '整排';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : compact;
  }
}

class HomeReviewLayouts {
  static const String scoreCompact = 'scoreCompact';
  static const String featured = 'featured';
  static const String carousel = 'carousel';
  static const String scoreOverview = 'scoreOverview';
  static const String scoreAndLatest = 'scoreAndLatest';
  static const List<String> all = <String>[
    scoreCompact,
    carousel,
    featured,
    scoreOverview,
    scoreAndLatest,
  ];

  static String label(String value) {
    switch (migrate(value)) {
      case scoreCompact:
        return '簡約評分小卡';
      case featured:
        return '最新精選評價';
      case scoreOverview:
        return '評分總覽';
      case scoreAndLatest:
        return '評分＋最新評價';
      default:
        return '評價橫向滑動';
    }
  }

  static String description(String value) {
    switch (migrate(value)) {
      case scoreCompact:
        return '半格小卡，顯示平均分數、星星與公開評價總數。';
      case featured:
        return '整排顯示最新一則公開評價與店家回覆標記。';
      case scoreOverview:
        return '平均分與 5 到 1 星的數量分布。';
      case scoreAndLatest:
        return '一側顯示總分，另一側顯示最新評價摘要。';
      default:
        return '橫向滑動最新公開評價，最後一張進入全部評價。';
    }
  }

  static String badge(String value) {
    switch (migrate(value)) {
      case scoreCompact:
        return '半格';
      case carousel:
        return '可右滑';
      case scoreAndLatest:
        return '推薦';
      default:
        return '整排';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : carousel;
  }
}

class HomePolicySectionSetting {
  const HomePolicySectionSetting({
    this.showOnHome = false,
    this.layout = HomePolicyLayouts.compact,
    this.title = '入住須知',
    this.subtitle = '入住前請先閱讀相關規定',
    this.keepServiceEntry = true,
    this.summaryItemCount = 3,
    this.showVersion = true,
    this.showCoverage = true,
  });

  final bool showOnHome;
  final String layout;
  final String title;
  final String subtitle;
  final bool keepServiceEntry;
  final int summaryItemCount;
  final bool showVersion;
  final bool showCoverage;

  bool get isHalf =>
      HomePolicyLayouts.migrate(layout) == HomePolicyLayouts.compact;

  String get entryTitle => _fallback(title, '入住須知');

  String get entrySubtitle => _clip(subtitle, 30);

  HomePolicySectionSetting copyWith({
    bool? showOnHome,
    String? layout,
    String? title,
    String? subtitle,
    bool? keepServiceEntry,
    int? summaryItemCount,
    bool? showVersion,
    bool? showCoverage,
  }) {
    return HomePolicySectionSetting(
      showOnHome: showOnHome ?? this.showOnHome,
      layout: layout ?? this.layout,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      keepServiceEntry: keepServiceEntry ?? this.keepServiceEntry,
      summaryItemCount: summaryItemCount ?? this.summaryItemCount,
      showVersion: showVersion ?? this.showVersion,
      showCoverage: showCoverage ?? this.showCoverage,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'showOnHome': showOnHome,
      'layout': HomePolicyLayouts.migrate(layout),
      'title': _clip(title, 12),
      'subtitle': _clip(subtitle, 30),
      'keepServiceEntry': keepServiceEntry,
      'summaryItemCount': migrateSummaryCount(summaryItemCount),
      'showVersion': showVersion,
      'showCoverage': showCoverage,
    };
  }

  static HomePolicySectionSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomePolicySectionSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final String title = _clip(map['title'], 12);
    return HomePolicySectionSetting(
      showOnHome: map['showOnHome'] == true,
      layout: HomePolicyLayouts.migrate(map['layout']),
      title: title.isEmpty ? '入住須知' : title,
      subtitle: _subtitle(map['subtitle'], '入住前請先閱讀相關規定'),
      keepServiceEntry: map['keepServiceEntry'] is bool
          ? map['keepServiceEntry'] as bool
          : true,
      summaryItemCount: migrateSummaryCount(map['summaryItemCount']),
      showVersion: map['showVersion'] is bool
          ? map['showVersion'] as bool
          : true,
      showCoverage: map['showCoverage'] is bool
          ? map['showCoverage'] as bool
          : true,
    );
  }

  static int migrateSummaryCount(Object? raw) {
    final int? value = raw is num ? raw.toInt() : int.tryParse('$raw');
    return value == 2 ? 2 : 3;
  }
}

class HomeFaqSectionSetting {
  const HomeFaqSectionSetting({
    this.showOnHome = false,
    this.layout = HomeFaqLayouts.compact,
    this.title = '常見問題',
    this.subtitle = '查看入住與服務常見疑問',
    this.keepServiceEntry = true,
    this.previewCount = 2,
    this.showAnswerPreview = false,
    this.showQuestionCount = true,
    this.showViewAll = true,
    this.leadingStyle = HomeFaqLeadingStyles.icon,
  });

  final bool showOnHome;
  final String layout;
  final String title;
  final String subtitle;
  final bool keepServiceEntry;
  final int previewCount;
  final bool showAnswerPreview;
  final bool showQuestionCount;
  final bool showViewAll;
  final String leadingStyle;

  bool get isHalf => HomeFaqLayouts.migrate(layout) == HomeFaqLayouts.compact;

  String get entryTitle => _fallback(title, '常見問題');

  String get entrySubtitle => _clip(subtitle, 30);

  HomeFaqSectionSetting copyWith({
    bool? showOnHome,
    String? layout,
    String? title,
    String? subtitle,
    bool? keepServiceEntry,
    int? previewCount,
    bool? showAnswerPreview,
    bool? showQuestionCount,
    bool? showViewAll,
    String? leadingStyle,
  }) {
    return HomeFaqSectionSetting(
      showOnHome: showOnHome ?? this.showOnHome,
      layout: layout ?? this.layout,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      keepServiceEntry: keepServiceEntry ?? this.keepServiceEntry,
      previewCount: previewCount ?? this.previewCount,
      showAnswerPreview: showAnswerPreview ?? this.showAnswerPreview,
      showQuestionCount: showQuestionCount ?? this.showQuestionCount,
      showViewAll: showViewAll ?? this.showViewAll,
      leadingStyle: leadingStyle ?? this.leadingStyle,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'showOnHome': showOnHome,
      'layout': HomeFaqLayouts.migrate(layout),
      'title': _clip(title, 12),
      'subtitle': _clip(subtitle, 30),
      'keepServiceEntry': keepServiceEntry,
      'previewCount': migratePreviewCount(previewCount),
      'showAnswerPreview': showAnswerPreview,
      'showQuestionCount': showQuestionCount,
      'showViewAll': showViewAll,
      'leadingStyle': HomeFaqLeadingStyles.migrate(leadingStyle),
    };
  }

  static HomeFaqSectionSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeFaqSectionSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final String title = _clip(map['title'], 12);
    return HomeFaqSectionSetting(
      showOnHome: map['showOnHome'] == true,
      layout: HomeFaqLayouts.migrate(map['layout']),
      title: title.isEmpty ? '常見問題' : title,
      subtitle: _subtitle(map['subtitle'], '查看入住與服務常見疑問'),
      keepServiceEntry: map['keepServiceEntry'] is bool
          ? map['keepServiceEntry'] as bool
          : true,
      previewCount: migratePreviewCount(map['previewCount']),
      showAnswerPreview: map['showAnswerPreview'] == true,
      showQuestionCount: map['showQuestionCount'] is bool
          ? map['showQuestionCount'] as bool
          : true,
      showViewAll: map['showViewAll'] is bool
          ? map['showViewAll'] as bool
          : true,
      leadingStyle: HomeFaqLeadingStyles.migrate(map['leadingStyle']),
    );
  }

  static int migratePreviewCount(Object? raw) {
    final int? value = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (value == null) {
      return 2;
    }
    if (value < 2) {
      return 2;
    }
    if (value > 5) {
      return 5;
    }
    return value;
  }
}

class HomeFaqLeadingStyles {
  static const String icon = 'icon';
  static const String number = 'number';
  static const List<String> all = <String>[icon, number];

  static String label(String value) {
    return migrate(value) == number ? '數字' : '問號圖示';
  }

  static String migrate(Object? raw) {
    return raw?.toString().trim() == number ? number : icon;
  }
}

class HomeReviewSectionSetting {
  const HomeReviewSectionSetting({
    this.showOnHome = true,
    this.layout = HomeReviewLayouts.carousel,
    this.title = '顧客評價',
    this.subtitle = '看看其他顧客的住宿心得',
    this.keepServiceEntry = true,
    this.carouselCount = 5,
    this.showCustomerName = true,
    this.showDate = true,
    this.showImages = false,
    this.showReplyBadge = true,
    this.showViewAll = true,
  });

  final bool showOnHome;
  final String layout;
  final String title;
  final String subtitle;
  final bool keepServiceEntry;
  final int carouselCount;
  final bool showCustomerName;
  final bool showDate;
  final bool showImages;
  final bool showReplyBadge;
  final bool showViewAll;

  bool get isHalf =>
      HomeReviewLayouts.migrate(layout) == HomeReviewLayouts.scoreCompact;

  String get entryTitle => _fallback(title, '顧客評價');

  String get entrySubtitle => _clip(subtitle, 30);

  HomeReviewSectionSetting copyWith({
    bool? showOnHome,
    String? layout,
    String? title,
    String? subtitle,
    bool? keepServiceEntry,
    int? carouselCount,
    bool? showCustomerName,
    bool? showDate,
    bool? showImages,
    bool? showReplyBadge,
    bool? showViewAll,
  }) {
    return HomeReviewSectionSetting(
      showOnHome: showOnHome ?? this.showOnHome,
      layout: layout ?? this.layout,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      keepServiceEntry: keepServiceEntry ?? this.keepServiceEntry,
      carouselCount: carouselCount ?? this.carouselCount,
      showCustomerName: showCustomerName ?? this.showCustomerName,
      showDate: showDate ?? this.showDate,
      showImages: showImages ?? this.showImages,
      showReplyBadge: showReplyBadge ?? this.showReplyBadge,
      showViewAll: showViewAll ?? this.showViewAll,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'showOnHome': showOnHome,
      'layout': HomeReviewLayouts.migrate(layout),
      'title': _clip(title, 12),
      'subtitle': _clip(subtitle, 30),
      'keepServiceEntry': keepServiceEntry,
      'carouselCount': migrateCarouselCount(carouselCount),
      'showCustomerName': showCustomerName,
      'showDate': showDate,
      'showImages': showImages,
      'showReplyBadge': showReplyBadge,
      'showViewAll': showViewAll,
    };
  }

  static HomeReviewSectionSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeReviewSectionSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final String title = _clip(map['title'], 12);
    return HomeReviewSectionSetting(
      showOnHome: map['showOnHome'] is bool ? map['showOnHome'] as bool : true,
      layout: HomeReviewLayouts.migrate(map['layout']),
      title: title.isEmpty ? '顧客評價' : title,
      subtitle: _subtitle(map['subtitle'], '看看其他顧客的住宿心得'),
      keepServiceEntry: map['keepServiceEntry'] is bool
          ? map['keepServiceEntry'] as bool
          : true,
      carouselCount: migrateCarouselCount(map['carouselCount']),
      showCustomerName: map['showCustomerName'] is bool
          ? map['showCustomerName'] as bool
          : true,
      showDate: map['showDate'] is bool ? map['showDate'] as bool : true,
      showImages: map['showImages'] == true,
      showReplyBadge: map['showReplyBadge'] is bool
          ? map['showReplyBadge'] as bool
          : true,
      showViewAll: map['showViewAll'] is bool
          ? map['showViewAll'] as bool
          : true,
    );
  }

  static int migrateCarouselCount(Object? raw) {
    final int? value = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (value == null) {
      return 5;
    }
    if (value < 2) {
      return 2;
    }
    if (value > 5) {
      return 5;
    }
    return value;
  }
}

class HomeInformationSectionsSetting {
  const HomeInformationSectionsSetting({
    this.policy = const HomePolicySectionSetting(),
    this.faq = const HomeFaqSectionSetting(),
    this.reviews = const HomeReviewSectionSetting(),
  });

  final HomePolicySectionSetting policy;
  final HomeFaqSectionSetting faq;
  final HomeReviewSectionSetting reviews;

  HomeInformationSectionsSetting copyWith({
    HomePolicySectionSetting? policy,
    HomeFaqSectionSetting? faq,
    HomeReviewSectionSetting? reviews,
  }) {
    return HomeInformationSectionsSetting(
      policy: policy ?? this.policy,
      faq: faq ?? this.faq,
      reviews: reviews ?? this.reviews,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'policy': policy.toMap(),
      'faq': faq.toMap(),
      'reviews': reviews.toMap(),
    };
  }

  static HomeInformationSectionsSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeInformationSectionsSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    return HomeInformationSectionsSetting(
      policy: HomePolicySectionSetting.fromMap(map['policy']),
      faq: HomeFaqSectionSetting.fromMap(map['faq']),
      reviews: HomeReviewSectionSetting.fromMap(map['reviews']),
    );
  }
}

class HomePolicySnapshot {
  const HomePolicySnapshot({
    this.version = 0,
    this.coverageLabel = '',
    this.titles = const <String>[],
    this.stayTitles = const <String>[],
    this.daycareTitles = const <String>[],
  });

  final int version;
  final String coverageLabel;
  final List<String> titles;
  final List<String> stayTitles;
  final List<String> daycareTitles;

  bool get hasContent =>
      titles.isNotEmpty || stayTitles.isNotEmpty || daycareTitles.isNotEmpty;

  bool get hasStay => stayTitles.isNotEmpty;

  bool get hasDaycare => daycareTitles.isNotEmpty;
}

class HomeFaqItem {
  const HomeFaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.sortOrder,
  });

  final String id;
  final String question;
  final String answer;
  final int sortOrder;
}

enum HomeInfoSectionPhase { hidden, loading, unavailable, empty, ready }

HomeInfoSectionPhase resolveHomeInfoPhase({
  required bool showOnHome,
  required bool editorPreview,
  bool featureEnabled = true,
  required bool ready,
  required bool failed,
  required bool hasContent,
}) {
  if (!featureEnabled || !showOnHome) {
    return HomeInfoSectionPhase.hidden;
  }
  if (!ready) {
    return editorPreview
        ? HomeInfoSectionPhase.loading
        : HomeInfoSectionPhase.hidden;
  }
  if (failed && !hasContent) {
    return editorPreview
        ? HomeInfoSectionPhase.unavailable
        : HomeInfoSectionPhase.hidden;
  }
  if (!hasContent) {
    return editorPreview
        ? HomeInfoSectionPhase.empty
        : HomeInfoSectionPhase.hidden;
  }
  return HomeInfoSectionPhase.ready;
}

bool homeInfoOccupiesSection(HomeInfoSectionPhase phase) {
  return phase != HomeInfoSectionPhase.hidden;
}

bool showPolicyServiceEntry(HomePolicySectionSetting setting) {
  return setting.keepServiceEntry;
}

bool showFaqServiceEntry(
  HomeFaqSectionSetting setting, {
  required bool featureEnabled,
}) {
  return setting.keepServiceEntry && featureEnabled;
}

bool showReviewServiceEntry(HomeReviewSectionSetting setting) {
  return setting.keepServiceEntry;
}

HomePolicySnapshot readHomePolicySnapshot(Map<String, dynamic>? raw) {
  if (raw == null) {
    return const HomePolicySnapshot();
  }
  final List<String> titles = <String>[];
  final List<String> stayTitles = <String>[];
  final List<String> daycareTitles = <String>[];
  bool stay = false;
  bool daycare = false;
  for (final String key in <String>[
    ...ShopPolicyHistory.page1Keys,
    ...ShopPolicyHistory.page2Keys,
  ]) {
    final bool stayOn = _policyEnabled(
      raw,
      key,
      PolicyApplicableService.accommodation,
    );
    final bool daycareOn = _policyEnabled(
      raw,
      key,
      PolicyApplicableService.daycare,
    );
    final String stayText = _policyText(
      raw,
      key,
      PolicyApplicableService.accommodation,
    );
    final String daycareText = _policyText(
      raw,
      key,
      PolicyApplicableService.daycare,
    );
    final bool stayVisible = stayOn && stayText.isNotEmpty;
    final bool daycareVisible = daycareOn && daycareText.isNotEmpty;
    if (!stayVisible && !daycareVisible) {
      continue;
    }
    stay = stay || stayVisible;
    daycare = daycare || daycareVisible;
    final String label = ShopPolicyHistory.sectionLabel(
      key,
      daycareVisible && !stayVisible
          ? PolicyApplicableService.daycare
          : PolicyApplicableService.accommodation,
    );
    titles.add(label);
    if (stayVisible) {
      stayTitles.add(
        ShopPolicyHistory.sectionLabel(
          key,
          PolicyApplicableService.accommodation,
        ),
      );
    }
    if (daycareVisible) {
      daycareTitles.add(
        ShopPolicyHistory.sectionLabel(key, PolicyApplicableService.daycare),
      );
    }
  }
  if (_customPolicyTexts(raw).isNotEmpty) {
    titles.add('其他條款');
    stayTitles.add('其他條款');
    final bool customStay = _customPolicyTexts(
      raw,
    ).any((String text) => text.isNotEmpty);
    stay = stay || customStay;
  }
  return HomePolicySnapshot(
    version: _policyVersion(raw),
    coverageLabel: _coverageLabel(stay: stay, daycare: daycare),
    titles: titles,
    stayTitles: stayTitles,
    daycareTitles: daycareTitles,
  );
}

List<HomeFaqItem> homeFaqsFromMaps(Iterable<Map<String, dynamic>> raw) {
  final List<HomeFaqItem> items = raw
      .where((Map<String, dynamic> item) => item['isPublished'] == true)
      .map((Map<String, dynamic> item) {
        final String question = (item['question'] ?? '').toString().trim();
        final Object? sort = item['sortOrder'];
        return HomeFaqItem(
          id: (item['id'] ?? '').toString(),
          question: question.isEmpty ? '未命名問題' : question,
          answer: (item['answer'] ?? '').toString().trim(),
          sortOrder: sort is num ? sort.toInt() : int.tryParse('$sort') ?? 999,
        );
      })
      .toList();
  items.sort(
    (HomeFaqItem a, HomeFaqItem b) => a.sortOrder.compareTo(b.sortOrder),
  );
  return items;
}

List<ReviewModel> sortPublicReviews(List<ReviewModel> reviews) {
  final List<ReviewModel> visible = reviews
      .where((ReviewModel review) => review.isVisible)
      .toList();
  visible.sort((ReviewModel a, ReviewModel b) {
    final DateTime? aTime = a.createdAt?.toDate();
    final DateTime? bTime = b.createdAt?.toDate();
    if (aTime == null && bTime == null) {
      return 0;
    }
    if (aTime == null) {
      return 1;
    }
    if (bTime == null) {
      return -1;
    }
    return bTime.compareTo(aTime);
  });
  return visible;
}

double homeReviewAverage(List<ReviewModel> reviews) {
  if (reviews.isEmpty) {
    return 0;
  }
  final int sum = reviews.fold<int>(
    0,
    (int total, ReviewModel review) => total + review.rating,
  );
  return sum / reviews.length;
}

String _coverageLabel({required bool stay, required bool daycare}) {
  if (stay && daycare) {
    return '住宿與安親';
  }
  if (daycare) {
    return '安親適用';
  }
  if (stay) {
    return '住宿適用';
  }
  return '';
}

bool _policyEnabled(Map<String, dynamic> raw, String key, String service) {
  final Object? byService = raw['enabledByService'];
  if (byService is Map && byService[service] is Map) {
    return (byService[service] as Map)[key] == true;
  }
  if (service != PolicyApplicableService.accommodation) {
    return false;
  }
  final Object? enabled = raw['enabled'];
  return enabled is Map && enabled[key] == true;
}

String _policyText(Map<String, dynamic> raw, String key, String service) {
  final Object? byService = raw['sectionTextsByService'];
  if (byService is Map && byService[service] is Map) {
    return ((byService[service] as Map)[key] ?? '').toString().trim();
  }
  if (service != PolicyApplicableService.accommodation) {
    return '';
  }
  final Object? sections = raw['sections'];
  if (sections is Map) {
    return (sections[key] ?? '').toString().trim();
  }
  return '';
}

List<String> _customPolicyTexts(Map<String, dynamic> raw) {
  final List<String> texts = <String>[];
  void add(Object? value) {
    for (final Map<String, dynamic> item
        in PolicyApplicableService.normalizeCustomPolicies(value)) {
      final String text = (item['text'] ?? '').toString().trim();
      if (text.isNotEmpty) {
        texts.add(text);
      }
    }
  }

  add(raw['customPoliciesPage1']);
  add(raw['customPoliciesPage2']);
  return texts;
}

int _policyVersion(Map<String, dynamic> raw) {
  int version = raw['version'] is num ? (raw['version'] as num).toInt() : 0;
  for (final String key in <String>['accommodationVersion', 'daycareVersion']) {
    if (raw[key] is num) {
      final int value = (raw[key] as num).toInt();
      if (value > version) {
        version = value;
      }
    }
  }
  return version < 0 ? 0 : version;
}

String _clip(Object? raw, int maxCharacters) {
  final String value = raw?.toString().trim() ?? '';
  if (value.length <= maxCharacters) {
    return value;
  }
  return value.substring(0, maxCharacters);
}

String _fallback(String value, String fallback) {
  final String text = _clip(value, 12);
  return text.isEmpty ? fallback : text;
}

String _subtitle(Object? raw, String fallback) {
  final String text = _clip(raw, 30);
  return text.isEmpty ? fallback : text;
}

// 檔案名稱：lib/core/widgets/daily_care_journal_renderer.dart
// 功能說明：客戶端正式回報頁與店主設定即時預覽共用的日誌內容呈現。
// 🐾 每日照護日誌內容 renderer（唯讀，不含 Scaffold / AppBar）

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/daily_care_journal_layout.dart';
import '../models/daily_care_photo_model.dart';
import '../models/daily_care_record_model.dart';
import '../models/daily_care_setting_model.dart';
import '../models/daily_care_stay_info.dart';
import 'daily_care_card_surface.dart';
import 'daily_care_illustrations.dart';

class DailyCareJournalThemeTokens {
  DailyCareJournalThemeTokens._();

  static const Color primary = Color(0xFF2F5D50);
  static const Color cream = Color(0xFFFFF8EE);
  static const Color mint = Color(0xFFEAF4EC);
  static const Color blue = Color(0xFFE8F1F8);
  static const Color orange = Color(0xFFFFF1E6);
  static const Color pink = Color(0xFFF8E9EE);
  static const double contentMaxWidth = 430;

  /// 半寬卡成對排列所需最小內容寬；較窄時改滿寬，避免半寬溢位。
  static const double minHalfPairWidth = 310;

  static const Color headerInk = Color(0xFF3B2F27);

  static SystemUiOverlayStyle get systemOverlay => const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  static Color fillOf(String colorKey) {
    switch (colorKey) {
      case DailyCareJournalCardStyle.colorCream:
        return cream;
      case DailyCareJournalCardStyle.colorMint:
        return mint;
      case DailyCareJournalCardStyle.colorBlue:
        return blue;
      case DailyCareJournalCardStyle.colorOrange:
        return orange;
      case DailyCareJournalCardStyle.colorPink:
        return pink;
      case DailyCareJournalCardStyle.colorTheme:
      default:
        return Colors.white.withValues(alpha: 0.94);
    }
  }
}

class DailyCareJournalScaffold extends StatelessWidget {
  const DailyCareJournalScaffold({
    super.key,
    required this.setting,
    required this.body,
    this.shopName = '',
    this.banner,
    this.leading,
  });

  final DailyCareSettingModel setting;
  final Widget body;
  final String shopName;
  final Widget? banner;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    const Color ink = DailyCareJournalThemeTokens.headerInk;
    const Color cream = DailyCareJournalThemeTokens.cream;
    final SystemUiOverlayStyle overlay =
        DailyCareJournalThemeTokens.systemOverlay;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: setting.resolvedPageColor(),
        appBar: AppBar(
          systemOverlayStyle: overlay,
          centerTitle: true,
          leading: leading,
          title: Text(
            shopName.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ink,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          backgroundColor: cream.withValues(alpha: 0.88),
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(
            color: DailyCareJournalThemeTokens.primary,
          ),
        ),
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DailyCareJournalPageBackground(setting: setting),
            ),
            Column(
              children: <Widget>[
                SizedBox(
                  height: MediaQuery.paddingOf(context).top + kToolbarHeight,
                ),
                ?banner,
                Expanded(child: body),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DailyCareJournalSessionTab {
  const DailyCareJournalSessionTab({
    required this.sessionIndex,
    required this.sessionName,
  });

  final int sessionIndex;
  final String sessionName;
}

class DailyCareJournalRenderer extends StatelessWidget {
  const DailyCareJournalRenderer({
    super.key,
    required this.setting,
    required this.stay,
    required this.dateKeys,
    required this.selectedDateKey,
    required this.sessionTabs,
    required this.selectedSessionIndex,
    required this.record,
    this.fallbackRoomName = '',
    this.photos = const <DailyCarePhotoModel>[],
    this.photosLoading = false,
    this.showPhotoSection = false,
    this.shopName = '',
    this.shopLogoUrl = '',
    this.isDaycare = false,
    this.offerName = '',
    this.footer,
    this.onDateSelected,
    this.onSessionSelected,
  });

  final DailyCareSettingModel setting;
  final DailyCareStayInfo stay;
  final List<String> dateKeys;
  final String selectedDateKey;
  final List<DailyCareJournalSessionTab> sessionTabs;
  final int selectedSessionIndex;
  final DailyCareRecordModel? record;
  final String fallbackRoomName;
  final List<DailyCarePhotoModel> photos;
  final bool photosLoading;
  final bool showPhotoSection;
  final String shopName;
  final String shopLogoUrl;
  final bool isDaycare;
  final String offerName;
  final Widget? footer;
  final ValueChanged<String>? onDateSelected;
  final ValueChanged<int>? onSessionSelected;

  static String journalKind({required bool isDaycare}) {
    return isDaycare ? '本次安親回報' : '住宿照護紀錄';
  }

  static String pageTitle({required String shopName}) {
    return shopName.trim();
  }

  static const String emptySessionPhotosLabel = '本場尚無照護照片';
  static const String emptyBookingPhotosLabel = '尚未上傳照護照片';

  static const Map<String, String> _labels = <String, String>{
    'water': '飲水',
    'dryFood': '飼料',
    'wetFood': '罐頭',
    'snack': '零食',
    'stool': '大便',
    'urine': '尿尿',
    'wandToy': '逗貓棒',
    'scratchBoard': '貓抓板',
    'jumpPlatform': '貓跳台',
    'toyBall': '玩具球',
    'catHouse': '貓屋',
    'catnip': '貓薄荷',
    'silverVine': '木天蓼',
    'catGrass': '貓草',
  };

  static const List<String> _foodKeys = <String>[
    'water',
    'dryFood',
    'wetFood',
    'snack',
  ];

  static const List<String> _toiletKeys = <String>['stool', 'urine'];

  static const List<String> _activityKeys = <String>[
    'wandToy',
    'scratchBoard',
    'jumpPlatform',
    'toyBall',
    'catHouse',
  ];

  static const List<String> _relaxKeys = <String>[
    'catnip',
    'silverVine',
    'catGrass',
  ];

  static const Set<String> _shortValues = <String>{
    '無',
    '有',
    '少',
    '一般',
    '多',
    '正常',
    '偏少',
    '偏多',
    '異常',
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String sessionName = sessionTabs.isEmpty
        ? setting.sessionLabel(selectedSessionIndex)
        : sessionTabs
              .firstWhere(
                (DailyCareJournalSessionTab tab) =>
                    tab.sessionIndex == selectedSessionIndex,
                orElse: () => sessionTabs.first,
              )
              .sessionName;

    final bool showDates = dateKeys.length > 1;
    final bool showSessions = sessionTabs.length > 1;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: DailyCareJournalThemeTokens.contentMaxWidth,
        ),
        child: Column(
          children: <Widget>[
            _buildKindSubtitle(),
            Expanded(
              child: CustomScrollView(
                slivers: <Widget>[
                  if (showDates || showSessions)
                    SliverToBoxAdapter(
                      child: _buildDateSessionSwitcher(
                        colors: colors,
                        showDates: showDates,
                        showSessions: showSessions,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: _buildHeroSummary(
                        colors: colors,
                        sessionName: sessionName,
                        filled: record != null,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(<Widget>[
                        if (record == null)
                          _EmptySessionView(setting: setting)
                        else
                          _buildRecordBody(colors: colors, record: record!),
                        if (footer != null) ...<Widget>[
                          const SizedBox(height: 16),
                          footer!,
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _headerFill {
    return const Color(0xFFFFFDFB);
  }

  Color _headerInk(ColorScheme colors) {
    return DailyCareInk.headerOf(
      header: setting.journalHeader,
      fill: _headerFill,
      colors: colors,
    );
  }

  Widget _headerSurface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(10, 8, 10, 8),
  }) {
    if (setting.journalHeader.useCardBackground &&
        setting.hasCardBackgroundVisual) {
      return DailyCareCardSurface(
        setting: setting,
        padding: padding,
        child: child,
      );
    }
    return _JournalCard(
      setting: setting,
      padding: padding,
      fill: _headerFill,
      child: child,
    );
  }

  Widget _buildDateSessionSwitcher({
    required ColorScheme colors,
    required bool showDates,
    required bool showSessions,
  }) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showDates) _buildDateSelector(colors: colors),
            if (showDates && showSessions) const SizedBox(height: 8),
            if (showSessions) _buildSessionSelector(colors: colors),
          ],
        ),
      ),
    );
  }

  Widget _buildKindSubtitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Text(
        journalKind(isDaycare: isDaycare),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: DailyCareJournalThemeTokens.primary,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildHeroSummary({
    required ColorScheme colors,
    required String sessionName,
    required bool filled,
  }) {
    final DateTime? date = _parseDateKey(selectedDateKey);
    final String viewingDate = date == null
        ? selectedDateKey
        : '${date.month}/${date.day}';
    final String roomName = stay.roomName.trim().isEmpty
        ? fallbackRoomName.trim()
        : stay.roomName.trim();
    final String roomOrOffer = isDaycare
        ? (offerName.trim().isNotEmpty
              ? offerName.trim()
              : (roomName.isEmpty ? '安親方案' : roomName))
        : (roomName.isEmpty ? '尚未分房' : roomName);
    final String fillTime = record?.updatedAt == null
        ? '尚未更新'
        : '填寫 ${_timeText(record!.updatedAt!)}';

    final bool showLogo = setting.logoVisible && shopLogoUrl.trim().isNotEmpty;
    final Color ink = _headerInk(colors);
    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _heroLine(
          icon: isDaycare ? Icons.spa_outlined : Icons.meeting_room_outlined,
          label: isDaycare ? '方案／房間' : '房間',
          value: roomOrOffer,
          ink: ink,
        ),
        _heroLine(
          icon: Icons.pets_outlined,
          label: isDaycare ? '安親寵物' : '入住寵物',
          value: stay.petNamesText,
          maxLines: 2,
          ink: ink,
        ),
        if (stay.stayDateText.isNotEmpty)
          _heroLine(
            icon: Icons.calendar_month_outlined,
            label: isDaycare ? '服務日期' : '住宿日期',
            value: stay.stayDateText,
            ink: ink,
          ),
        _heroLine(
          icon: Icons.visibility_outlined,
          label: '目前查看',
          value: '$viewingDate · $sessionName',
          ink: ink,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.schedule_outlined,
                size: 14,
                color: ink.withValues(alpha: 0.72),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fillTime,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: ink.withValues(alpha: 0.72),
                  ),
                ),
              ),
              _FilledChip(filled: filled, ink: ink),
            ],
          ),
        ),
      ],
    );
    return KeyedSubtree(
      key: const ValueKey<String>('journal-header-hero'),
      child: _headerSurface(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: showLogo
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _heroLogo(),
                  const SizedBox(width: 8),
                  Expanded(child: details),
                ],
              )
            : details,
      ),
    );
  }

  Widget _heroLogo() {
    return ClipOval(
      child: Image.network(
        shopLogoUrl,
        width: 30,
        height: 30,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
              return const SizedBox.shrink();
            },
      ),
    );
  }

  Widget _heroLine({
    required IconData icon,
    required String label,
    required String value,
    required Color ink,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: ink.withValues(alpha: 0.72)),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: ink.withValues(alpha: 0.72),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector({required ColorScheme colors}) {
    final Color ink = _headerInk(colors);
    return KeyedSubtree(
      key: const ValueKey<String>('journal-header-dates'),
      child: _headerSurface(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dateKeys.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              final String dateKey = dateKeys[index];
              final bool selected = dateKey == selectedDateKey;
              final DateTime? date = _parseDateKey(dateKey);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onDateSelected == null
                      ? null
                      : () => onDateSelected!(dateKey),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 62,
                    decoration: BoxDecoration(
                      color: selected
                          ? DailyCareJournalThemeTokens.primary
                          : ink.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? DailyCareJournalThemeTokens.primary
                            : ink.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          date == null ? dateKey : '${date.month}/${date.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date == null ? '' : _weekdayShort(date),
                          style: TextStyle(
                            fontSize: 11,
                            color: selected
                                ? Colors.white.withValues(alpha: 0.86)
                                : ink.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSessionSelector({required ColorScheme colors}) {
    return KeyedSubtree(
      key: const ValueKey<String>('journal-header-sessions'),
      child: _headerSurface(
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sessionTabs.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 6),
            itemBuilder: (BuildContext context, int index) {
              final DailyCareJournalSessionTab tab = sessionTabs[index];
              final bool selected = tab.sessionIndex == selectedSessionIndex;
              return _sessionChip(colors: colors, tab: tab, selected: selected);
            },
          ),
        ),
      ),
    );
  }

  Widget _sessionChip({
    required ColorScheme colors,
    required DailyCareJournalSessionTab tab,
    required bool selected,
  }) {
    final Color ink = _headerInk(colors);
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onSessionSelected == null
          ? null
          : () => onSessionSelected!(tab.sessionIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? DailyCareJournalThemeTokens.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              _sessionIcon(tab.sessionIndex, tab.sessionName),
              size: 16,
              color: selected ? Colors.white : ink.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 6),
            Text(
              tab.sessionName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordBody({
    required ColorScheme colors,
    required DailyCareRecordModel record,
  }) {
    final Map<String, dynamic> values = record.values;
    final List<_CareItem> foodItems = _itemsFor(
      values: values,
      builtInKeys: _foodKeys,
      category: 'food',
    );
    final List<_CareItem> toiletItems = _itemsFor(
      values: values,
      builtInKeys: _toiletKeys,
      category: 'toilet',
    );
    final List<_CareItem> activityItems = _itemsFor(
      values: values,
      builtInKeys: _activityKeys,
      category: 'activity',
    );
    final List<_CareItem> relaxItems = _itemsFor(
      values: values,
      builtInKeys: _relaxKeys,
      category: 'relax',
    );
    final List<_CareItem> otherItems = _itemsFor(
      values: values,
      builtInKeys: const <String>[],
      category: 'other',
    );
    final String generalNote = _stringValue(values['generalNote']);
    final Map<String, DailyCareJournalCardLayout> layouts =
        setting.resolvedJournalCards;
    final bool photoOn =
        showPhotoSection && setting.journalDisplay.showPhotoSection;
    String sessionName = '';
    for (final DailyCareJournalSessionTab tab in sessionTabs) {
      if (tab.sessionIndex == selectedSessionIndex) {
        sessionName = tab.sessionName;
        break;
      }
    }
    final List<DailyCarePhotoModel> sessionPhotos =
        DailyCarePhotoMatch.sessionPhotos(
          photos: photos,
          dateKey: selectedDateKey,
          sessionIndex: selectedSessionIndex,
          sessionName: sessionName,
        );

    final Map<String, _LaidCard> built = <String, _LaidCard>{};
    final Widget env = _buildEnvironmentCard(values: values);
    built[DailyCareJournalCardKeys.environment] = _LaidCard(
      layout: layouts[DailyCareJournalCardKeys.environment]!,
      forceFull: false,
      minHalfWidth: 120,
      child: env,
    );
    built[DailyCareJournalCardKeys.toilet] = _LaidCard(
      layout: layouts[DailyCareJournalCardKeys.toilet]!,
      forceFull: false,
      minHalfWidth: 120,
      child: _ToiletStatusCard(
        setting: setting,
        items: toiletItems,
        layout: layouts[DailyCareJournalCardKeys.toilet]!,
      ),
    );
    if (foodItems.isNotEmpty) {
      built[DailyCareJournalCardKeys.food] = _LaidCard(
        layout: layouts[DailyCareJournalCardKeys.food]!,
        forceFull: foodItems.any((_CareItem item) => item.longText),
        child: _CategoryCard(
          setting: setting,
          title: '生活狀況',
          layout: layouts[DailyCareJournalCardKeys.food]!,
          items: foodItems,
        ),
      );
    }
    if (activityItems.isNotEmpty) {
      built[DailyCareJournalCardKeys.activity] = _LaidCard(
        layout: layouts[DailyCareJournalCardKeys.activity]!,
        forceFull: activityItems.any((_CareItem item) => item.longText),
        child: _CategoryCard(
          setting: setting,
          title: '活動與玩樂',
          layout: layouts[DailyCareJournalCardKeys.activity]!,
          items: activityItems,
        ),
      );
    }
    if (relaxItems.isNotEmpty) {
      built[DailyCareJournalCardKeys.relax] = _LaidCard(
        layout: layouts[DailyCareJournalCardKeys.relax]!,
        forceFull: relaxItems.any((_CareItem item) => item.longText),
        child: _CategoryCard(
          setting: setting,
          title: '放鬆與用品',
          layout: layouts[DailyCareJournalCardKeys.relax]!,
          items: relaxItems,
        ),
      );
    }
    final DailyCareJournalCardLayout noteLayout =
        layouts[DailyCareJournalCardKeys.generalNote]!;
    if (_fieldEnabled('generalNote') && noteLayout.visible) {
      built[DailyCareJournalCardKeys.generalNote] = _LaidCard(
        layout: noteLayout,
        forceFull: true,
        child: _GeneralNoteCard(
          setting: setting,
          note: generalNote.isEmpty ? '無' : generalNote,
          layout: noteLayout,
        ),
      );
    }
    if (photoOn) {
      built[DailyCareJournalCardKeys.photos] = _LaidCard(
        layout: layouts[DailyCareJournalCardKeys.photos]!,
        forceFull: true,
        child: _SessionPhotoCard(
          setting: setting,
          layout: layouts[DailyCareJournalCardKeys.photos]!,
          photos: sessionPhotos,
          photosLoading: photosLoading,
          bookingHasPhotos: photos.isNotEmpty,
        ),
      );
    }
    if (otherItems.isNotEmpty) {
      built['other'] = _LaidCard(
        layout: const DailyCareJournalCardLayout(key: 'other', order: 99),
        forceFull: true,
        child: _CategoryCard(
          setting: setting,
          title: '其他紀錄',
          layout: const DailyCareJournalCardLayout(key: 'other', order: 99),
          items: otherItems,
        ),
      );
    }

    final List<_LaidCard> ordered =
        DailyCareJournalCardLayout.displaySorted(layouts)
            .where((DailyCareJournalCardLayout item) {
              if (!built.containsKey(item.key)) {
                return false;
              }
              if (item.key == DailyCareJournalCardKeys.environment ||
                  item.key == DailyCareJournalCardKeys.toilet) {
                return true;
              }
              return item.visible;
            })
            .map((DailyCareJournalCardLayout item) => built[item.key]!)
            .toList();
    if (built.containsKey('other')) {
      ordered.add(built['other']!);
    }

    final List<_LaidCard> rest = ordered
        .where((_LaidCard card) => !card.layout.isPinned)
        .toList();
    final _LaidCard? envCard = built[DailyCareJournalCardKeys.environment];
    final _LaidCard? toiletCard = built[DailyCareJournalCardKeys.toilet];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxW = constraints.maxWidth;
        final double halfW = (maxW - 10) / 2;
        final bool canHalf =
            maxW >= DailyCareJournalThemeTokens.minHalfPairWidth &&
            halfW >= 148;
        final List<Widget> rows = <Widget>[];
        if (envCard != null && toiletCard != null) {
          rows.add(
            IntrinsicHeight(
              child: Row(
                key: const ValueKey<String>('daily-care-pinned-row'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: envCard.child),
                  const SizedBox(width: 10),
                  Expanded(child: toiletCard.child),
                ],
              ),
            ),
          );
        }
        int index = 0;
        while (index < rest.length) {
          final _LaidCard current = rest[index];
          final bool currentHalf =
              canHalf &&
              current.layout.isHalf &&
              !current.forceFull &&
              halfW >= current.minHalfWidth;
          if (currentHalf && index + 1 < rest.length) {
            final _LaidCard next = rest[index + 1];
            final bool nextHalf =
                next.layout.isHalf &&
                !next.forceFull &&
                halfW >= next.minHalfWidth;
            if (nextHalf) {
              if (rows.isNotEmpty) {
                rows.add(const SizedBox(height: 10));
              }
              rows.add(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: current.child),
                    const SizedBox(width: 10),
                    Expanded(child: next.child),
                  ],
                ),
              );
              index += 2;
              continue;
            }
          }
          if (rows.isNotEmpty) {
            rows.add(const SizedBox(height: 10));
          }
          rows.add(current.child);
          index += 1;
        }
        return Column(children: rows);
      },
    );
  }

  Widget _buildEnvironmentCard({required Map<String, dynamic> values}) {
    final DailyCareJournalCardLayout? layout =
        setting.resolvedJournalCards[DailyCareJournalCardKeys.environment];
    final dynamic temperature = values['temperature'];
    final dynamic humidity = values['humidity'];
    final String temperatureText = _stringValue(temperature);
    final String humidityText = _stringValue(humidity);

    return DailyCareIllustratedShell(
      key: const ValueKey<String>('journal-card-environment'),
      setting: setting,
      layout:
          layout ??
          const DailyCareJournalCardLayout(
            key: DailyCareJournalCardKeys.environment,
          ),
      title: '環境狀況',
      fill: DailyCareJournalThemeTokens.fillOf(
        layout?.colorKey ?? DailyCareJournalCardStyle.colorMint,
      ),
      child: _EnvironmentMetrics(
        layout:
            layout ??
            const DailyCareJournalCardLayout(
              key: DailyCareJournalCardKeys.environment,
            ),
        fill: DailyCareJournalThemeTokens.fillOf(
          layout?.colorKey ?? DailyCareJournalCardStyle.colorMint,
        ),
        temperatureLabel: temperatureText.isEmpty
            ? '尚未填寫'
            : '${_cleanNumber(temperature)}°C',
        humidityLabel: humidityText.isEmpty
            ? '尚未填寫'
            : '${_cleanNumber(humidity)}%',
        emptyTemperature: temperatureText.isEmpty,
        emptyHumidity: humidityText.isEmpty,
      ),
    );
  }

  List<_CareItem> _itemsFor({
    required Map<String, dynamic> values,
    required List<String> builtInKeys,
    required String category,
  }) {
    final List<_CareItem> items = <_CareItem>[];

    for (final String key in builtInKeys) {
      if (!_fieldEnabled(key)) {
        continue;
      }

      final String value = _stringValue(values[key]);
      final bool alwaysOn = DailyCareReportFormat.isAlwaysOn(key);
      if (value.isEmpty && !alwaysOn) {
        continue;
      }

      items.add(
        _CareItem(
          label: _labels[key] ?? key,
          value: value.isEmpty ? '尚未填寫' : value,
          longText: value.isNotEmpty && !_shortValues.contains(value),
        ),
      );
    }

    for (final DailyCareCustomField field in setting.customFields) {
      if (field.category != category) {
        continue;
      }

      final String value = _stringValue(values[field.id]);
      if (value.isEmpty) {
        continue;
      }

      items.add(
        _CareItem(
          label: field.label,
          value: value,
          longText: field.inputType == 'text' || !_shortValues.contains(value),
        ),
      );
    }

    return items;
  }

  bool _fieldEnabled(String key) {
    return setting.isCareFieldEnabled(key);
  }

  String _stringValue(Object? value) {
    if (value == null) {
      return '';
    }
    try {
      return value.toString().trim();
    } catch (_) {
      return '';
    }
  }

  IconData _sessionIcon(int sessionIndex, String sessionName) {
    if (sessionName.contains('晚上') || sessionName.contains('晚間')) {
      return Icons.nightlight_outlined;
    }
    if (sessionName.contains('下午')) {
      return Icons.light_mode_outlined;
    }
    if (sessionName.contains('上午')) {
      return Icons.wb_sunny_outlined;
    }
    if (sessionIndex <= 0) {
      return Icons.wb_sunny_outlined;
    }
    if (sessionIndex == 1) {
      return Icons.light_mode_outlined;
    }
    return Icons.nightlight_outlined;
  }

  String _cleanNumber(dynamic value) {
    if (value is num) {
      if (value % 1 == 0) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    try {
      return value.toString();
    } catch (_) {
      return '';
    }
  }

  String _timeText(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _weekdayShort(DateTime value) {
    const List<String> labels = <String>['一', '二', '三', '四', '五', '六', '日'];
    return labels[value.weekday - 1];
  }

  DateTime? _parseDateKey(String value) {
    final List<String> parts = value.split('/');
    if (parts.length != 3) {
      return null;
    }

    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }

    return DateTime(year, month, day);
  }
}

class _LaidCard {
  const _LaidCard({
    required this.layout,
    required this.child,
    this.forceFull = false,
    this.minHalfWidth = 148,
  });

  final DailyCareJournalCardLayout layout;
  final Widget child;
  final bool forceFull;
  final double minHalfWidth;
}

class _CareItem {
  const _CareItem({
    required this.label,
    required this.value,
    required this.longText,
  });

  final String label;
  final String value;
  final bool longText;
}

class _EnvironmentMetrics extends StatelessWidget {
  const _EnvironmentMetrics({
    required this.layout,
    required this.fill,
    required this.temperatureLabel,
    required this.humidityLabel,
    required this.emptyTemperature,
    required this.emptyHumidity,
  });

  final DailyCareJournalCardLayout layout;
  final Color fill;
  final String temperatureLabel;
  final String humidityLabel;
  final bool emptyTemperature;
  final bool emptyHumidity;

  @override
  Widget build(BuildContext context) {
    final Color ink = DailyCareInk.of(
      layout: layout,
      fill: fill,
      colors: Theme.of(context).colorScheme,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _metricColumn(
            asset: DailyCareIllustrations.environment,
            label: '溫度',
            value: temperatureLabel,
            empty: emptyTemperature,
            ink: ink,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: SizedBox(
            height: 36,
            child: VerticalDivider(
              width: 16,
              thickness: 1,
              color: ink.withValues(alpha: 0.18),
            ),
          ),
        ),
        Expanded(
          child: _metricColumn(
            asset: DailyCareIllustrations.humidity,
            label: '濕度',
            value: humidityLabel,
            empty: emptyHumidity,
            ink: ink,
          ),
        ),
      ],
    );
  }

  Widget _metricColumn({
    required String asset,
    required String label,
    required String value,
    required bool empty,
    required Color ink,
  }) {
    return Column(
      children: <Widget>[
        DailyCareSvgIcon(asset: asset, color: ink, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ink.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: empty ? 13 : 22,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
      ],
    );
  }
}

class _ToiletStatusCard extends StatelessWidget {
  const _ToiletStatusCard({
    required this.setting,
    required this.items,
    required this.layout,
  });

  final DailyCareSettingModel setting;
  final List<_CareItem> items;
  final DailyCareJournalCardLayout layout;

  @override
  Widget build(BuildContext context) {
    final Color fill = DailyCareJournalThemeTokens.fillOf(layout.colorKey);
    final Color ink = DailyCareInk.of(
      layout: layout,
      fill: fill,
      colors: Theme.of(context).colorScheme,
    );
    _CareItem stool = const _CareItem(label: '大便', value: '無', longText: false);
    _CareItem urine = const _CareItem(label: '尿尿', value: '無', longText: false);
    for (final _CareItem item in items) {
      if (item.label == '大便') {
        stool = item;
      }
      if (item.label == '尿尿') {
        urine = item;
      }
    }
    return DailyCareIllustratedShell(
      key: const ValueKey<String>('journal-card-toilet'),
      setting: setting,
      layout: layout,
      title: '大小便狀況',
      fill: fill,
      ink: ink,
      child: Column(
        key: const ValueKey<String>('journal-toilet-vertical'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ToiletStatBlock(item: stool, ink: ink, fill: fill),
          const SizedBox(height: 8),
          _ToiletStatBlock(item: urine, ink: ink, fill: fill),
        ],
      ),
    );
  }
}

class _ToiletStatBlock extends StatelessWidget {
  const _ToiletStatBlock({
    required this.item,
    required this.ink,
    required this.fill,
  });

  final _CareItem item;
  final Color ink;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final String value = item.value.trim().isEmpty || item.value == '尚未填寫'
        ? '無'
        : item.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.label,
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: ink.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: DailyCareInk.chipFill(ink, fill),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _JournalCard extends StatelessWidget {
  const _JournalCard({
    required this.child,
    this.setting,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 10),
    this.fill,
  });

  final Widget child;
  final DailyCareSettingModel? setting;
  final EdgeInsetsGeometry padding;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Widget body = fill == null && setting != null
        ? DailyCareCardSurface(
            setting: setting!,
            padding: padding,
            child: child,
          )
        : Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: fill ?? Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(setting?.cardRadius ?? 16),
              border: Border.all(color: colors.outline.withValues(alpha: 0.08)),
            ),
            child: child,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: body,
    );
  }
}

class _FilledChip extends StatelessWidget {
  const _FilledChip({required this.filled, required this.ink});

  final bool filled;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled
            ? DailyCareJournalThemeTokens.primary.withValues(alpha: 0.16)
            : DailyCareInk.chipFill(ink, const Color(0xFFFFFDFB)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        filled ? '✓ 已填寫' : '尚未填寫',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: filled ? DailyCareJournalThemeTokens.primary : ink,
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.setting,
    required this.title,
    required this.layout,
    required this.items,
  });

  final DailyCareSettingModel setting;
  final String title;
  final DailyCareJournalCardLayout layout;
  final List<_CareItem> items;

  @override
  Widget build(BuildContext context) {
    final Color fill = DailyCareJournalThemeTokens.fillOf(layout.colorKey);
    final Color ink = DailyCareInk.of(
      layout: layout,
      fill: fill,
      colors: Theme.of(context).colorScheme,
    );
    final List<_CareItem> compactItems = items
        .where((_CareItem item) => !item.longText)
        .toList();
    final List<_CareItem> noteItems = items
        .where((_CareItem item) => item.longText)
        .toList();
    final double width = MediaQuery.sizeOf(context).width;
    final bool twoColumn = width >= 392 && compactItems.length > 1;

    return DailyCareIllustratedShell(
      setting: setting,
      layout: layout,
      title: title,
      fill: fill,
      ink: ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (twoColumn)
            ..._twoColumnRows(compactItems, ink, fill)
          else
            for (final _CareItem item in compactItems)
              _CompactValueRow(item: item, ink: ink, fill: fill),
          for (final _CareItem item in noteItems)
            _CareNoteRow(item: item, ink: ink, fill: fill),
        ],
      ),
    );
  }

  List<Widget> _twoColumnRows(List<_CareItem> items, Color ink, Color fill) {
    final List<Widget> rows = <Widget>[];

    for (int index = 0; index < items.length; index += 2) {
      final _CareItem left = items[index];
      final _CareItem? right = index + 1 < items.length
          ? items[index + 1]
          : null;

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _CompactValueRow(
                  item: left,
                  tight: true,
                  ink: ink,
                  fill: fill,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: right == null
                    ? const SizedBox.shrink()
                    : _CompactValueRow(
                        item: right,
                        tight: true,
                        ink: ink,
                        fill: fill,
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return rows;
  }
}

class _CompactValueRow extends StatelessWidget {
  const _CompactValueRow({
    required this.item,
    this.tight = false,
    required this.ink,
    required this.fill,
  });

  final _CareItem item;
  final bool tight;
  final Color ink;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final Color tone = Color.alphaBlend(
      _statusColor(
        Theme.of(context).colorScheme,
        item.value,
      ).withValues(alpha: ink.computeLuminance() > 0.62 ? 0.35 : 0.0),
      ink,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: tight ? 2 : 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ink.withValues(alpha: 0.82),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            constraints: const BoxConstraints(maxWidth: 76),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: DailyCareInk.chipFill(ink, fill),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CareNoteRow extends StatelessWidget {
  const _CareNoteRow({
    required this.item,
    required this.ink,
    required this.fill,
  });

  final _CareItem item;
  final Color ink;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: DailyCareInk.chipFill(ink, fill).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.label.isEmpty ? '照護員紀錄' : item.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ink.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            style: TextStyle(fontSize: 13, height: 1.5, color: ink),
          ),
        ],
      ),
    );
  }
}

class _GeneralNoteCard extends StatelessWidget {
  const _GeneralNoteCard({
    required this.setting,
    required this.note,
    required this.layout,
  });

  final DailyCareSettingModel setting;
  final String note;
  final DailyCareJournalCardLayout layout;

  @override
  Widget build(BuildContext context) {
    final Color fill = DailyCareJournalThemeTokens.fillOf(layout.colorKey);
    final Color ink = DailyCareInk.of(
      layout: layout,
      fill: fill,
      colors: Theme.of(context).colorScheme,
    );
    return DailyCareIllustratedShell(
      key: const ValueKey<String>('journal-card-general-note'),
      setting: setting,
      layout: layout,
      title: '今日概況',
      fill: fill,
      ink: ink,
      longText: true,
      child: Text(
        note,
        style: TextStyle(fontSize: 13, height: 1.55, color: ink),
      ),
    );
  }
}

class _SessionPhotoCard extends StatelessWidget {
  const _SessionPhotoCard({
    required this.setting,
    required this.layout,
    required this.photos,
    required this.photosLoading,
    required this.bookingHasPhotos,
  });

  final DailyCareSettingModel setting;
  final DailyCareJournalCardLayout layout;
  final List<DailyCarePhotoModel> photos;
  final bool photosLoading;
  final bool bookingHasPhotos;

  @override
  Widget build(BuildContext context) {
    final Color fill = DailyCareJournalThemeTokens.fillOf(layout.colorKey);
    final Color ink = DailyCareInk.of(
      layout: layout,
      fill: fill,
      colors: Theme.of(context).colorScheme,
    );
    Widget body;
    if (photosLoading) {
      body = Text(
        '載入照護照片…',
        style: TextStyle(fontSize: 12, color: ink.withValues(alpha: 0.7)),
      );
    } else if (photos.isEmpty) {
      body = Text(
        bookingHasPhotos
            ? DailyCareJournalRenderer.emptySessionPhotosLabel
            : DailyCareJournalRenderer.emptyBookingPhotosLabel,
        style: TextStyle(fontSize: 12, color: ink.withValues(alpha: 0.7)),
      );
    } else {
      body = _PhotoLayout(photos: photos);
    }
    return DailyCareIllustratedShell(
      setting: setting,
      layout: layout,
      title: '照護照片',
      fill: fill,
      ink: ink,
      child: body,
    );
  }
}

class _PhotoLayout extends StatelessWidget {
  const _PhotoLayout({required this.photos});

  final List<DailyCarePhotoModel> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.length == 1) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: _PhotoTile(
          photo: photos.first,
          onTap: () => _preview(context, photos.first),
        ),
      );
    }

    if (photos.length == 2) {
      return Row(
        children: <Widget>[
          Expanded(
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: _PhotoTile(
                photo: photos[0],
                onTap: () => _preview(context, photos[0]),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: _PhotoTile(
                photo: photos[1],
                onTap: () => _preview(context, photos[1]),
              ),
            ),
          ),
        ],
      );
    }

    final int visibleCount = photos.length > 4 ? 4 : photos.length;
    final int extraCount = photos.length > 4 ? photos.length - 4 : 0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibleCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 4 / 3,
      ),
      itemBuilder: (BuildContext context, int index) {
        final DailyCarePhotoModel photo = photos[index];
        final bool showMore = extraCount > 0 && index == 3;

        return _PhotoTile(
          photo: photo,
          overlayText: showMore ? '+$extraCount' : null,
          onTap: () => _preview(context, photo),
        );
      },
    );
  }

  void _preview(BuildContext context, DailyCarePhotoModel photo) {
    if (photo.previewUrl.trim().isEmpty) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(18),
          backgroundColor: Colors.black,
          child: Stack(
            children: <Widget>[
              InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.network(
                  photo.previewUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      height: 300,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton.filled(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.onTap,
    this.overlayText,
  });

  final DailyCarePhotoModel photo;
  final VoidCallback onTap;
  final String? overlayText;

  @override
  Widget build(BuildContext context) {
    final String url = photo.previewUrl.trim();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(
              color: Colors.grey.shade100,
              child: url.isEmpty
                  ? const Center(
                      child: Icon(Icons.photo_outlined, color: Colors.grey),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
            ),
            if (overlayText != null)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.42),
                child: Center(
                  child: Text(
                    overlayText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptySessionView extends StatelessWidget {
  const _EmptySessionView({required this.setting});

  final DailyCareSettingModel setting;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return _JournalCard(
      setting: setting,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.menu_book_outlined,
              size: 34,
              color: colors.onSurface.withValues(alpha: 0.28),
            ),
            const SizedBox(height: 10),
            const Text(
              '這個時段尚未有照護紀錄',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '店家完成本場照護後，內容會顯示在這裡。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(ColorScheme colors, String value) {
  switch (value) {
    case '有':
    case '正常':
    case '一般':
      return colors.primary;
    case '多':
    case '偏多':
      return colors.tertiary;
    case '少':
    case '偏少':
      return colors.secondary;
    case '異常':
      return colors.error;
    case '無':
    default:
      return colors.onSurface.withValues(alpha: 0.48);
  }
}

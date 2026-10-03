// 檔案名稱：lib/core/widgets/daily_care_share_card.dart
// 功能說明：單場每日回報的靜態分享海報。不含照片與任何操作按鈕。

import 'package:flutter/material.dart';

import '../models/daily_care_journal_layout.dart';
import '../models/daily_care_report_data.dart';
import '../models/daily_care_setting_model.dart';
import 'daily_care_card_surface.dart';
import 'daily_care_illustrations.dart';
import 'daily_care_journal_renderer.dart';

/// 分享圖邏輯寬。產圖 pixelRatio 2 時輸出寬度 1080px。
class DailyCareShareLayout {
  DailyCareShareLayout._();

  static const double logicalWidth = 540;

  static const List<List<String>> pairedTitles = <List<String>>[
    <String>['環境狀況', '大小便狀況'],
    <String>['生活狀況', '活動與玩樂'],
  ];

  static List<DailyCareReportGroup> mergeGroups(
    List<DailyCareReportGroup> groups,
  ) {
    final Map<String, List<DailyCareReportField>> fields =
        <String, List<DailyCareReportField>>{};
    final List<String> order = <String>[];
    for (final DailyCareReportGroup group in groups) {
      final String title = group.title.trim();
      if (title.isEmpty || group.fields.isEmpty) {
        continue;
      }
      if (!fields.containsKey(title)) {
        order.add(title);
        fields[title] = <DailyCareReportField>[];
      }
      fields[title]!.addAll(group.fields);
    }
    return <DailyCareReportGroup>[
      for (final String title in order)
        DailyCareReportGroup(title: title, fields: fields[title]!),
    ];
  }

  static List<DailyCareShareBand> bands(List<DailyCareReportGroup> groups) {
    final List<DailyCareReportGroup> merged = mergeGroups(groups);
    final Map<String, DailyCareReportGroup> byTitle =
        <String, DailyCareReportGroup>{
          for (final DailyCareReportGroup group in merged) group.title: group,
        };
    final Set<String> used = <String>{};
    final List<DailyCareShareBand> result = <DailyCareShareBand>[];
    for (final List<String> pair in pairedTitles) {
      final DailyCareReportGroup? left = byTitle[pair[0]];
      final DailyCareReportGroup? right = byTitle[pair[1]];
      if (left != null && right != null) {
        result.add(DailyCareShareBand.pair(left, right));
        used.add(left.title);
        used.add(right.title);
      } else if (left != null) {
        result.add(DailyCareShareBand.full(left));
        used.add(left.title);
      } else if (right != null) {
        result.add(DailyCareShareBand.full(right));
        used.add(right.title);
      }
    }
    for (final DailyCareReportGroup group in merged) {
      if (used.contains(group.title)) {
        continue;
      }
      result.add(DailyCareShareBand.full(group));
    }
    return result;
  }
}

class DailyCareShareBand {
  const DailyCareShareBand.pair(this.left, this.right) : paired = true;

  const DailyCareShareBand.full(this.left) : right = null, paired = false;

  final DailyCareReportGroup left;
  final DailyCareReportGroup? right;
  final bool paired;
}

/// 店家品牌每日照護卡。只給分享圖片，不含照片與操作按鈕。
class DailyCareShareCard extends StatelessWidget {
  const DailyCareShareCard({
    super.key,
    required this.data,
    required this.setting,
    this.logoProvider,
    this.backgroundProvider,
    this.guestName = '',
    this.daycare = false,
  });

  final DailyCareReportData data;
  final DailyCareSettingModel setting;
  final ImageProvider? logoProvider;
  final ImageProvider? backgroundProvider;
  final String guestName;
  final bool daycare;

  /// 約目前的 1.75 倍。輸出約 224px，放在圓形底托上，圖本身不裁切。
  static const double logoSize = 112;

  static const Color _ink = DailyCareJournalThemeTokens.headerInk;
  static const Color _muted = Color(0xFF6B5E54);
  static const Color _cardFill = Color(0xD1FFFDFB);
  static const Color _noteFill = Color(0xC7E7F2EA);

  @override
  Widget build(BuildContext context) {
    final List<DailyCareReportDay> days = data.days;
    final String dateText = _displayDate(
      days.isEmpty ? data.headerDateText : days.first.dateKey,
    );
    return SizedBox(
      width: DailyCareShareLayout.logicalWidth,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DailyCareJournalPageBackground(
              setting: setting,
              imageOverride: backgroundProvider,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _header(dateText),
                for (final DailyCareReportDay day in days)
                  for (final DailyCareReportSession session in day.sessions)
                    ..._session(session),
                if (days.every(
                  (DailyCareReportDay day) => day.sessions.isEmpty,
                ))
                  _panel(child: const Text('尚無本場回報')),
                const SizedBox(height: 10),
                _footer(dateText),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String dateText) {
    final String shop = data.shopName.trim();
    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (shop.isNotEmpty)
          Text(
            shop,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.15,
              shadows: <Shadow>[
                Shadow(color: Color(0xE6FFFFFF), blurRadius: 8),
              ],
            ),
          ),
        const SizedBox(height: 3),
        const Text(
          '每日照護回報',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: DailyCareJournalThemeTokens.primary,
            height: 1.15,
          ),
        ),
        if (dateText.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            dateText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _muted,
              height: 1.15,
              shadows: <Shadow>[
                Shadow(color: Color(0xE6FFFFFF), blurRadius: 6),
              ],
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (logoProvider != null) ...<Widget>[
            _logoPlate(),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.58),
                    Colors.white.withValues(alpha: 0.16),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                child: copy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPlate() {
    return SizedBox(
      width: logoSize + 16,
      height: logoSize + 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.78),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x2E3A332C),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Image(
            key: const ValueKey<String>('daily-care-share-logo'),
            image: logoProvider!,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  List<Widget> _session(DailyCareReportSession session) {
    final List<DailyCareShareBand> rows = DailyCareShareLayout.bands(
      session.groups,
    );
    final String note = session.generalNote.trim();
    return <Widget>[
      _visitCard(session),
      for (final DailyCareShareBand band in rows) ...<Widget>[
        const SizedBox(height: 8),
        band.paired && band.right != null
            ? IntrinsicHeight(
                child: Row(
                  key: ValueKey<String>(
                    'daily-care-share-pair-${band.left.title}',
                  ),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: KeyedSubtree(
                        key: ValueKey<String>(
                          'daily-care-share-card-${band.left.title}',
                        ),
                        child: _groupCard(band.left, fillHeight: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: KeyedSubtree(
                        key: ValueKey<String>(
                          'daily-care-share-card-${band.right!.title}',
                        ),
                        child: _groupCard(band.right!, fillHeight: true),
                      ),
                    ),
                  ],
                ),
              )
            : _groupCard(band.left),
      ],
      if (note.isNotEmpty) ...<Widget>[
        const SizedBox(height: 8),
        _noteCard(note),
      ],
    ];
  }

  Widget _visitCard(DailyCareReportSession session) {
    final String pet = _petName();
    final String place = <String>[
      data.roomName.trim(),
      data.roomTypeName.trim(),
    ].where((String part) => part.isNotEmpty && part != '尚未分房').join('・');
    final String guest = guestName.trim();
    final String sessionName = session.sessionName.trim();
    final String updated = session.updatedAtText.trim();
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: DailyCareSvgIcon(
                  asset: DailyCareIllustrations.paw,
                  color: DailyCareJournalThemeTokens.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pet.isEmpty ? '本次照護' : pet,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const _DoneChip(),
            ],
          ),
          if (place.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _metaLine(
              icon: daycare ? Icons.spa_outlined : Icons.meeting_room_outlined,
              text: place,
              expand: true,
            ),
          ],
          if (sessionName.isNotEmpty || updated.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (sessionName.isNotEmpty)
                  _metaLine(icon: _sessionIcon(sessionName), text: sessionName),
                if (updated.isNotEmpty)
                  _metaLine(icon: Icons.schedule_outlined, text: updated),
              ],
            ),
          ],
          if (guest.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            _metaLine(
              icon: Icons.person_outline,
              text: '飼主：$guest',
              muted: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _groupCard(DailyCareReportGroup group, {bool fillHeight = false}) {
    final String title = group.title.trim();
    if (title == '環境狀況') {
      return _environmentCard(group, fillHeight: fillHeight);
    }
    if (title == '大小便狀況') {
      return _toiletCard(group, fillHeight: fillHeight);
    }
    if (title == '放鬆與用品') {
      return _relaxCard(group, fillHeight: fillHeight);
    }
    return _chipListCard(group, fillHeight: fillHeight);
  }

  Widget _environmentCard(
    DailyCareReportGroup group, {
    bool fillHeight = false,
  }) {
    DailyCareReportField? temperature;
    DailyCareReportField? humidity;
    final List<DailyCareReportField> rest = <DailyCareReportField>[];
    for (final DailyCareReportField field in group.fields) {
      if (temperature == null &&
          (field.label.contains('溫') || field.value.contains('°'))) {
        temperature = field;
      } else if (humidity == null &&
          (field.label.contains('濕') || field.value.contains('%'))) {
        humidity = field;
      } else {
        rest.add(field);
      }
    }
    return _titledCard(
      cardKey: DailyCareJournalCardKeys.environment,
      title: group.title,
      fillHeight: fillHeight,
      child: Column(
        children: <Widget>[
          if (temperature != null || humidity != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _metric(
                    asset: DailyCareIllustrations.environment,
                    label: '溫度',
                    value: temperature?.value ?? '',
                  ),
                ),
                _divider(),
                Expanded(
                  child: _metric(
                    asset: DailyCareIllustrations.humidity,
                    label: '濕度',
                    value: humidity?.value ?? '',
                  ),
                ),
              ],
            ),
          for (final DailyCareReportField field in rest) _chipRow(field),
        ],
      ),
    );
  }

  Widget _toiletCard(DailyCareReportGroup group, {bool fillHeight = false}) {
    DailyCareReportField? stool;
    DailyCareReportField? urine;
    final List<DailyCareReportField> rest = <DailyCareReportField>[];
    for (final DailyCareReportField field in group.fields) {
      if (stool == null && field.label == '大便') {
        stool = field;
      } else if (urine == null && field.label == '尿尿') {
        urine = field;
      } else {
        rest.add(field);
      }
    }
    return _titledCard(
      cardKey: DailyCareJournalCardKeys.toilet,
      title: group.title,
      fillHeight: fillHeight,
      child: Column(
        children: <Widget>[
          if (stool != null || urine != null)
            Row(
              key: const ValueKey<String>('daily-care-share-toilet'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _toiletStat(stool, fallback: '大便')),
                _divider(),
                Expanded(child: _toiletStat(urine, fallback: '尿尿')),
              ],
            ),
          for (final DailyCareReportField field in rest) _chipRow(field),
        ],
      ),
    );
  }

  Widget _relaxCard(DailyCareReportGroup group, {bool fillHeight = false}) {
    return _titledCard(
      cardKey: DailyCareJournalCardKeys.relax,
      title: group.title,
      fillHeight: fillHeight,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final DailyCareReportField field in group.fields)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  field.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(width: 6),
                _ShareStatusChip(value: field.value),
              ],
            ),
        ],
      ),
    );
  }

  Widget _chipListCard(DailyCareReportGroup group, {bool fillHeight = false}) {
    return _titledCard(
      cardKey: _cardKey(group.title),
      title: group.title,
      fillHeight: fillHeight,
      child: Column(
        children: <Widget>[
          for (final DailyCareReportField field in group.fields)
            _chipRow(field),
        ],
      ),
    );
  }

  Widget _noteCard(String note) {
    return _titledCard(
      cardKey: DailyCareJournalCardKeys.generalNote,
      title: '今日概況',
      fill: _noteFill,
      child: Text(
        note,
        key: const ValueKey<String>('daily-care-share-note'),
        style: const TextStyle(fontSize: 13, height: 1.45, color: _ink),
      ),
    );
  }

  Widget _footer(String dateText) {
    final String pet = _petName();
    final String named = pet.isEmpty ? '牠' : pet;
    final String shop = data.shopName.trim().isEmpty
        ? '本店'
        : data.shopName.trim();
    final String lead = daycare ? '今天的照護時光順利完成 ♡' : '今天也有好好照顧$named ♡';
    final String body = daycare
        ? '謝謝您把$named交給我們照顧，希望這份紀錄讓您更放心，也留下今天的小日常。'
        : '謝謝您的信任，希望這份小小的紀錄，讓您不在身邊時也能安心了解牠今天的狀況。';
    final String code = data.bookingCode.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          lead,
          key: const ValueKey<String>('daily-care-share-footer'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _ink,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, height: 1.35, color: _ink),
        ),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '— $shop',
            key: const ValueKey<String>('daily-care-share-signature'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: _muted,
              height: 1.1,
            ),
          ),
        ),
        if (code.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            dateText.isEmpty ? '回報編號 $code' : '回報編號 $code · $dateText',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: _muted.withValues(alpha: 0.7)),
          ),
        ],
      ],
    );
  }

  Widget _titledCard({
    required String cardKey,
    required String title,
    required Widget child,
    Color? fill,
    bool fillHeight = false,
  }) {
    final DailyCareJournalCardLayout layout =
        setting.resolvedJournalCards[cardKey] ??
        DailyCareJournalCardLayout(key: cardKey);
    return _panel(
      fill: fill,
      fillHeight: fillHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DailyCareTitleIcon(layout: layout, color: _ink, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _panel({required Widget child, Color? fill, bool fillHeight = false}) {
    final double radius = setting.cardRadius <= 0 ? 16 : setting.cardRadius;
    final Widget padded = Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill ?? _cardFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0x1F3A332C)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x123A332C),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: fillHeight
          ? SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: padded,
            )
          : padded,
    );
  }

  Widget _metric({
    required String asset,
    required String label,
    required String value,
  }) {
    return Column(
      children: <Widget>[
        DailyCareSvgIcon(
          asset: asset,
          color: DailyCareJournalThemeTokens.primary,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _muted,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _toiletStat(DailyCareReportField? field, {required String fallback}) {
    return Column(
      children: <Widget>[
        Text(
          field?.label ?? fallback,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _muted,
          ),
        ),
        const SizedBox(height: 6),
        _ShareStatusChip(value: field?.value ?? ''),
      ],
    );
  }

  Widget _chipRow(DailyCareReportField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              field.label,
              style: const TextStyle(
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _ShareStatusChip(value: field.value),
        ],
      ),
    );
  }

  Widget _metaLine({
    required IconData icon,
    required String text,
    bool muted = false,
    bool expand = false,
  }) {
    final Widget label = Text(
      text,
      style: TextStyle(
        fontSize: muted ? 12 : 13,
        height: 1.25,
        fontWeight: muted ? FontWeight.w600 : FontWeight.w700,
        color: muted ? _muted : _ink,
      ),
    );
    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: muted ? _muted : _ink),
        const SizedBox(width: 4),
        if (expand) Expanded(child: label) else label,
      ],
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 36,
        child: VerticalDivider(
          width: 16,
          thickness: 1,
          color: _muted.withValues(alpha: 0.28),
        ),
      ),
    );
  }

  String _petName() {
    final String pets = data.petNames.trim();
    if (pets.isEmpty || pets == '尚未指定寵物') {
      return '';
    }
    return pets;
  }

  String _cardKey(String title) {
    switch (title) {
      case '環境狀況':
        return DailyCareJournalCardKeys.environment;
      case '生活狀況':
        return DailyCareJournalCardKeys.food;
      case '大小便狀況':
        return DailyCareJournalCardKeys.toilet;
      case '活動與玩樂':
        return DailyCareJournalCardKeys.activity;
      case '放鬆與用品':
        return DailyCareJournalCardKeys.relax;
      case '今日概況':
        return DailyCareJournalCardKeys.generalNote;
      default:
        return title;
    }
  }

  IconData _sessionIcon(String sessionName) {
    if (sessionName.contains('晚上') || sessionName.contains('晚間')) {
      return Icons.nightlight_outlined;
    }
    if (sessionName.contains('下午')) {
      return Icons.light_mode_outlined;
    }
    return Icons.wb_sunny_outlined;
  }

  String _displayDate(String raw) {
    final String compact = raw.replaceAll(' ', '').trim();
    if (compact.isEmpty) {
      return '';
    }
    return compact.replaceAll('/', ' / ');
  }
}

class _DoneChip extends StatelessWidget {
  const _DoneChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: DailyCareJournalThemeTokens.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '✓ 已完成',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: DailyCareJournalThemeTokens.primary,
        ),
      ),
    );
  }
}

class _ShareStatusChip extends StatelessWidget {
  const _ShareStatusChip({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    const Color ink = DailyCareShareCard._ink;
    const Color fill = Color(0xFFFFFDFB);
    final Color tone = _shareStatusColor(Theme.of(context).colorScheme, value);
    final String text = value.trim().isEmpty ? '無' : value.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: DailyCareInk.chipFill(ink, fill),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }
}

Color _shareStatusColor(ColorScheme colors, String value) {
  switch (value.trim()) {
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
      return colors.onSurface.withValues(alpha: 0.55);
  }
}

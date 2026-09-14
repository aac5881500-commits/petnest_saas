// 檔案名稱：lib/core/widgets/daily_care_journal_renderer.dart
// 功能說明：客戶端正式回報頁與店主設定即時預覽共用的日誌內容呈現。
// 🐾 每日照護日誌內容 renderer（唯讀，不含 Scaffold / AppBar）

import 'package:flutter/material.dart';

import '../models/daily_care_photo_model.dart';
import '../models/daily_care_record_model.dart';
import '../models/daily_care_setting_model.dart';
import '../models/daily_care_stay_info.dart';
import 'daily_care_card_surface.dart';

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
  final ValueChanged<String>? onDateSelected;
  final ValueChanged<int>? onSessionSelected;

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

  static const Map<String, IconData> _fieldIcons = <String, IconData>{
    'water': Icons.water_drop_outlined,
    'dryFood': Icons.rice_bowl_outlined,
    'wetFood': Icons.inventory_2_outlined,
    'snack': Icons.cookie_outlined,
    'stool': Icons.health_and_safety_outlined,
    'urine': Icons.water_outlined,
    'wandToy': Icons.sports_esports_outlined,
    'scratchBoard': Icons.texture_outlined,
    'jumpPlatform': Icons.stairs_outlined,
    'toyBall': Icons.sports_baseball_outlined,
    'catHouse': Icons.home_outlined,
    'catnip': Icons.eco_outlined,
    'silverVine': Icons.local_florist_outlined,
    'catGrass': Icons.grass_outlined,
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

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: _buildHeroSummary(
            colors: colors,
            sessionName: sessionName,
            filled: record != null,
          ),
        ),
        const SizedBox(height: 10),
        _buildDateSelector(colors: colors),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _buildSessionSelector(colors: colors),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
            children: <Widget>[
              _buildStatusRow(colors: colors),
              const SizedBox(height: 12),
              if (record == null)
                _EmptySessionView(setting: setting)
              else
                _buildRecordBody(colors: colors, record: record!),
            ],
          ),
        ),
      ],
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

    return _JournalCard(
      setting: setting,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '住宿照護紀錄',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
              _PetAvatarStack(pets: stay.pets),
              const SizedBox(width: 8),
              _FilledChip(filled: filled),
            ],
          ),
          const SizedBox(height: 8),
          _heroLine(label: '房間', value: roomName.isEmpty ? '尚未分房' : roomName),
          _heroLine(label: '入住寵物', value: stay.petNamesText),
          if (stay.stayDateText.isNotEmpty)
            _heroLine(label: '住宿日期', value: stay.stayDateText),
          _heroLine(label: '目前查看', value: '$viewingDate · $sessionName'),
        ],
      ),
    );
  }

  Widget _heroLine({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector({required ColorScheme colors}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: _JournalCard(
        setting: setting,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: SizedBox(
          height: 58,
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
                          ? colors.primary
                          : Colors.white.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? colors.primary
                            : colors.outline.withValues(alpha: 0.18),
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
                            color: selected
                                ? colors.onPrimary
                                : colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date == null ? '' : _weekdayShort(date),
                          style: TextStyle(
                            fontSize: 11,
                            color: selected
                                ? colors.onPrimary.withValues(alpha: 0.86)
                                : colors.onSurface.withValues(alpha: 0.55),
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
    if (sessionTabs.length == 1) {
      return _JournalCard(
        setting: setting,
        padding: const EdgeInsets.all(4),
        child: _sessionChip(
          colors: colors,
          tab: sessionTabs.first,
          selected: true,
        ),
      );
    }

    return _JournalCard(
      setting: setting,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: sessionTabs.map((DailyCareJournalSessionTab tab) {
          final bool selected = tab.sessionIndex == selectedSessionIndex;
          return Expanded(
            child: _sessionChip(colors: colors, tab: tab, selected: selected),
          );
        }).toList(),
      ),
    );
  }

  Widget _sessionChip({
    required ColorScheme colors,
    required DailyCareJournalSessionTab tab,
    required bool selected,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onSessionSelected == null
          ? null
          : () => onSessionSelected!(tab.sessionIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              _sessionIcon(tab.sessionIndex, tab.sessionName),
              size: 16,
              color: selected
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                tab.sessionName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({required ColorScheme colors}) {
    final String timeText = record?.updatedAt == null
        ? '尚未更新'
        : _timeText(record!.updatedAt!);

    return _JournalCard(
      setting: setting,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.schedule_outlined,
            size: 15,
            color: colors.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '填寫時間 $timeText',
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ),
          _FilledChip(filled: record != null),
        ],
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
    final String generalNote = _fieldEnabled('generalNote')
        ? _stringValue(values['generalNote'])
        : '';

    return Column(
      children: <Widget>[
        _buildEnvironmentCard(colors: colors, values: values),
        if (foodItems.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _CategoryCard(
            title: '生活狀況',
            icon: Icons.restaurant_outlined,
            items: foodItems,
            setting: setting,
          ),
        ],
        if (toiletItems.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _CategoryCard(
            title: '大小便狀況',
            icon: Icons.health_and_safety_outlined,
            items: toiletItems,
            setting: setting,
          ),
        ],
        if (activityItems.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _CategoryCard(
            title: '活動與玩樂',
            icon: Icons.sports_esports_outlined,
            items: activityItems,
            setting: setting,
          ),
        ],
        if (relaxItems.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _CategoryCard(
            title: '放鬆與用品',
            icon: Icons.spa_outlined,
            items: relaxItems,
            setting: setting,
          ),
        ],
        if (otherItems.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _CategoryCard(
            title: '其他紀錄',
            icon: Icons.edit_note_outlined,
            items: otherItems,
            setting: setting,
          ),
        ],
        if (generalNote.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _GeneralNoteCard(note: generalNote, setting: setting),
        ],
        if (showPhotoSection) ...<Widget>[
          const SizedBox(height: 10),
          _SessionPhotoCard(
            setting: setting,
            photos: photos,
            photosLoading: photosLoading,
          ),
        ],
      ],
    );
  }

  Widget _buildEnvironmentCard({
    required ColorScheme colors,
    required Map<String, dynamic> values,
  }) {
    final dynamic temperature = values['temperature'];
    final dynamic humidity = values['humidity'];
    final bool hasTemperature =
        temperature != null && _stringValue(temperature).isNotEmpty;
    final bool hasHumidity =
        humidity != null && _stringValue(humidity).isNotEmpty;

    if (!hasTemperature && !hasHumidity) {
      return const SizedBox.shrink();
    }

    return _JournalCard(
      setting: setting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionTitle(
            icon: Icons.thermostat_outlined,
            title: '環境狀況',
            colors: colors,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              if (hasTemperature)
                Expanded(
                  child: _environmentTile(
                    colors: colors,
                    icon: Icons.thermostat_outlined,
                    label: '室內溫度',
                    value: '${_cleanNumber(temperature)}°C',
                  ),
                ),
              if (hasTemperature && hasHumidity) const SizedBox(width: 8),
              if (hasHumidity)
                Expanded(
                  child: _environmentTile(
                    colors: colors,
                    icon: Icons.water_drop_outlined,
                    label: '室內濕度',
                    value: '${_cleanNumber(humidity)}%',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _environmentTile({
    required ColorScheme colors,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                colors.primary.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.55),
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: colors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.52),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
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
      if (value.isEmpty) {
        continue;
      }

      items.add(
        _CareItem(
          label: _labels[key] ?? key,
          value: value,
          icon: _fieldIcons[key] ?? Icons.circle_outlined,
          longText: !_shortValues.contains(value),
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
          icon: Icons.notes_outlined,
          longText: field.inputType == 'text' || !_shortValues.contains(value),
        ),
      );
    }

    return items;
  }

  bool _fieldEnabled(String key) {
    return setting.enabledFields.contains(key);
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

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required ColorScheme colors,
  }) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _CareItem {
  const _CareItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.longText,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool longText;
}

class _JournalCard extends StatelessWidget {
  const _JournalCard({
    required this.child,
    this.setting,
    this.longText = false,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 10),
  });

  final Widget child;
  final DailyCareSettingModel? setting;
  final bool longText;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Widget body = setting == null
        ? Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outline.withValues(alpha: 0.08)),
            ),
            child: child,
          )
        : DailyCareCardSurface(
            setting: setting!,
            longText: longText,
            padding: padding,
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
  const _FilledChip({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color tone = filled ? colors.primary : colors.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled
            ? colors.primary.withValues(alpha: 0.12)
            : colors.outline.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        filled ? '✓ 已填寫' : '尚未填寫',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tone,
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.setting,
  });

  final String title;
  final IconData icon;
  final List<_CareItem> items;
  final DailyCareSettingModel setting;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<_CareItem> compactItems = items
        .where((_CareItem item) => !item.longText)
        .toList();
    final List<_CareItem> noteItems = items
        .where((_CareItem item) => item.longText)
        .toList();
    final double width = MediaQuery.sizeOf(context).width;
    final bool twoColumn = width >= 392 && compactItems.length > 1;

    return _JournalCard(
      setting: setting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (twoColumn)
            ..._twoColumnRows(compactItems)
          else
            for (final _CareItem item in compactItems)
              _CompactValueRow(item: item),
          for (final _CareItem item in noteItems) _CareNoteRow(item: item),
        ],
      ),
    );
  }

  List<Widget> _twoColumnRows(List<_CareItem> items) {
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
              Expanded(child: _CompactValueRow(item: left, tight: true)),
              const SizedBox(width: 8),
              Expanded(
                child: right == null
                    ? const SizedBox.shrink()
                    : _CompactValueRow(item: right, tight: true),
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
  const _CompactValueRow({required this.item, this.tight = false});

  final _CareItem item;
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color tone = _statusColor(colors, item.value);

    return Padding(
      padding: EdgeInsets.only(bottom: tight ? 2 : 4),
      child: Row(
        children: <Widget>[
          Icon(
            item.icon,
            size: 15,
            color: colors.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.78),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            constraints: const BoxConstraints(maxWidth: 72),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                tone.withValues(alpha: 0.16),
                Colors.white,
              ),
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
  const _CareNoteRow({required this.item});

  final _CareItem item;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.label.isEmpty ? '照護員紀錄' : item.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.onSurface.withValues(alpha: 0.52),
            ),
          ),
          const SizedBox(height: 4),
          Text(item.value, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

class _GeneralNoteCard extends StatelessWidget {
  const _GeneralNoteCard({required this.note, required this.setting});

  final String note;
  final DailyCareSettingModel setting;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return _JournalCard(
      setting: setting,
      longText: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.notes_outlined, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '今日概況',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: colors.onSurface.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionPhotoCard extends StatelessWidget {
  const _SessionPhotoCard({
    required this.setting,
    required this.photos,
    required this.photosLoading,
  });

  final DailyCareSettingModel setting;
  final List<DailyCarePhotoModel> photos;
  final bool photosLoading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    if (photosLoading) {
      return _JournalCard(
        setting: setting,
        child: Row(
          children: <Widget>[
            Icon(Icons.photo_outlined, size: 16, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              '載入照護照片…',
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      );
    }

    if (photos.isEmpty) {
      return _JournalCard(
        setting: setting,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.photo_outlined,
              size: 16,
              color: colors.onSurface.withValues(alpha: 0.40),
            ),
            const SizedBox(width: 8),
            Text(
              '今日尚未上傳照護照片',
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      );
    }

    return _JournalCard(
      setting: setting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.photo_outlined, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              const Text(
                '今日照護照片',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PhotoLayout(photos: photos),
        ],
      ),
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

class _PetAvatarStack extends StatelessWidget {
  const _PetAvatarStack({required this.pets});

  final List<DailyCareStayPet> pets;

  @override
  Widget build(BuildContext context) {
    if (pets.isEmpty) {
      return const SizedBox.shrink();
    }

    final int visibleCount = pets.length > 3 ? 3 : pets.length;
    final int extraCount = pets.length > 3 ? pets.length - 3 : 0;
    final double width = 26.0 + ((visibleCount - 1) * 18);

    return SizedBox(
      width: width,
      height: 28,
      child: Stack(
        children: <Widget>[
          for (int index = 0; index < visibleCount; index++)
            Positioned(
              left: index * 18.0,
              child: _PetMiniAvatar(
                pet: pets[index],
                overlayText: extraCount > 0 && index == visibleCount - 1
                    ? '+$extraCount'
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _PetMiniAvatar extends StatelessWidget {
  const _PetMiniAvatar({required this.pet, this.overlayText});

  final DailyCareStayPet pet;
  final String? overlayText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        color: const Color(0xFFF1F3F6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (pet.hasPhoto)
            Image.network(
              pet.photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.pets, size: 14, color: Colors.grey);
              },
            )
          else
            const Icon(Icons.pets, size: 14, color: Colors.grey),
          if (overlayText != null)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Text(
                  overlayText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
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

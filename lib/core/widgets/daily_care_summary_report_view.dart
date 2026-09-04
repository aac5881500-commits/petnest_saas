// lib/core/widgets/daily_care_summary_report_view.dart
// 🐾 住宿照護統計報告（精簡版）
// 把整筆住宿濃縮成一張紙本風格統計圖，不逐場全文列出。

import 'package:flutter/material.dart';

import '../models/daily_care_report_data.dart';

class DailyCareSummaryReportView extends StatelessWidget {
  const DailyCareSummaryReportView({
    super.key,
    required this.data,
    this.logoProvider,
  });

  final DailyCareReportData data;
  final ImageProvider? logoProvider;

  static const Color cream = Color(0xFFFFF8F1);
  static const Color ink = Color(0xFF3A2A20);
  static const Color muted = Color(0xFF8A7A6C);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFE8DFD4);

  @override
  Widget build(BuildContext context) {
    final DailyCareReportStats? stats = data.stats;
    final Color brand = data.brandColor;

    return ColoredBox(
      color: cream,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(data: data, logoProvider: logoProvider),
            const SizedBox(height: 16),
            _StayCard(data: data),
            if (stats != null) ...<Widget>[
              const SizedBox(height: 12),
              _CompletionCard(stats: stats, brand: brand),
              if (stats.activityStatus != null) ...<Widget>[
                const SizedBox(height: 12),
                _SectionCard(
                  title: '活動力',
                  brand: brand,
                  child: _ScaleField(
                    field: stats.activityStatus!,
                    brand: brand,
                    completedSessions: stats.completedSessions,
                  ),
                ),
              ],
              if (stats.groups.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _TwoColumnStats(stats: stats, brand: brand),
              ],
              if (stats.hasEnvironment) ...<Widget>[
                const SizedBox(height: 12),
                _EnvironmentCard(stats: stats, brand: brand),
              ],
              const SizedBox(height: 12),
              _OverviewCard(stats: stats, brand: brand),
            ],
            const SizedBox(height: 18),
            _Footer(data: data),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data, this.logoProvider});

  final DailyCareReportData data;
  final ImageProvider? logoProvider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _Logo(logoProvider: logoProvider, brand: data.brandColor),
        const SizedBox(height: 10),
        Text(
          data.shopName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: DailyCareSummaryReportView.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: data.brandColor,
          ),
        ),
        if (data.headerDateText.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            data.headerDateText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: DailyCareSummaryReportView.muted,
            ),
          ),
        ],
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.logoProvider, required this.brand});

  final ImageProvider? logoProvider;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: brand.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoProvider == null
          ? Icon(Icons.pets, color: brand, size: 32)
          : Image(
              image: logoProvider!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.pets, color: brand, size: 32);
              },
            ),
    );
  }
}

class _StayCard extends StatelessWidget {
  const _StayCard({required this.data});

  final DailyCareReportData data;

  @override
  Widget build(BuildContext context) {
    return _Paper(
      brand: data.brandColor,
      child: Column(
        children: <Widget>[
          _kv('入住寵物', data.petNames),
          _kv('房間', data.roomName),
          if (data.roomTypeName.isNotEmpty) _kv('房型', data.roomTypeName),
          _kv('入住日期', data.checkInText),
          _kv('退房日期', data.checkOutText),
          _kv('住宿晚數', data.nightsText),
          if (data.bookingCode.isNotEmpty)
            _kv('訂單編號', data.bookingCode, last: true)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 7),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: DailyCareSummaryReportView.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: DailyCareSummaryReportView.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.stats, required this.brand});

  final DailyCareReportStats stats;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    return _Paper(
      brand: brand,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _metric('住宿晚數', '${stats.stayNights} 晚', brand),
              _metric('應填照護', '${stats.expectedSessions} 次', brand),
              _metric(
                '完成照護',
                stats.missingSessions > 0
                    ? '${stats.completedSessions} / ${stats.expectedSessions}'
                    : '${stats.completedSessions} 次',
                brand,
              ),
              _metric('完成率', '${stats.completionPercent}%', brand, last: true),
            ],
          ),
          if (stats.missingSessions > 0) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFBE8DC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '有 ${stats.missingSessions} 次照護未填寫',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC45C26),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color brand, {bool last = false}) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: last ? 0 : 6),
        child: Column(
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: DailyCareSummaryReportView.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TwoColumnStats extends StatelessWidget {
  const _TwoColumnStats({required this.stats, required this.brand});

  final DailyCareReportStats stats;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final List<DailyCareReportStatGroup> left = <DailyCareReportStatGroup>[];
    final List<DailyCareReportStatGroup> right = <DailyCareReportStatGroup>[];
    final List<DailyCareReportStatGroup> extra = <DailyCareReportStatGroup>[];

    for (final DailyCareReportStatGroup group in stats.groups) {
      if (group.title == '生活狀況' || group.title == '大小便') {
        left.add(group);
      } else if (group.title == '活動與玩樂' || group.title == '放鬆與用品') {
        right.add(group);
      } else {
        extra.add(group);
      }
    }

    return Column(
      children: <Widget>[
        if (left.isNotEmpty || right.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _groupStack(left)),
              const SizedBox(width: 10),
              Expanded(child: _groupStack(right)),
            ],
          ),
        for (final DailyCareReportStatGroup group in extra) ...<Widget>[
          const SizedBox(height: 10),
          _SectionCard(
            title: group.title,
            brand: brand,
            child: _GroupFields(
              fields: group.fields,
              brand: brand,
              completedSessions: stats.completedSessions,
            ),
          ),
        ],
      ],
    );
  }

  Widget _groupStack(List<DailyCareReportStatGroup> groups) {
    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: <Widget>[
        for (int index = 0; index < groups.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: 10),
          _SectionCard(
            title: groups[index].title,
            brand: brand,
            child: _GroupFields(
              fields: groups[index].fields,
              brand: brand,
              completedSessions: stats.completedSessions,
            ),
          ),
        ],
      ],
    );
  }
}

class _GroupFields extends StatelessWidget {
  const _GroupFields({
    required this.fields,
    required this.brand,
    required this.completedSessions,
  });

  final List<DailyCareReportStatField> fields;
  final Color brand;
  final int completedSessions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int index = 0; index < fields.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: 10),
          _ScaleField(
            field: fields[index],
            brand: brand,
            completedSessions: completedSessions,
          ),
        ],
      ],
    );
  }
}

class _ScaleField extends StatelessWidget {
  const _ScaleField({
    required this.field,
    required this.brand,
    required this.completedSessions,
  });

  final DailyCareReportStatField field;
  final Color brand;
  final int completedSessions;

  @override
  Widget build(BuildContext context) {
    final int total = completedSessions < 1
        ? field.observedCount
        : completedSessions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          field.label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: DailyCareSummaryReportView.ink,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: field.options
              .map(
                (DailyCareReportStatOption option) => Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(
                        option.label,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: DailyCareSummaryReportView.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _StatDot(filled: option.isPrimary, brand: brand),
                      const SizedBox(height: 3),
                      Text(
                        '${option.count}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: option.isPrimary
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: option.isPrimary
                              ? brand
                              : DailyCareSummaryReportView.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        if (field.isYesNo && total > 0) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            _yesNoHint(field, total),
            style: const TextStyle(
              fontSize: 10.5,
              color: DailyCareSummaryReportView.muted,
            ),
          ),
        ],
      ],
    );
  }

  String _yesNoHint(DailyCareReportStatField field, int total) {
    int yes = 0;
    int no = 0;
    for (final DailyCareReportStatOption option in field.options) {
      if (option.label == '有') {
        yes = option.count;
      }
      if (option.label == '無') {
        no = option.count;
      }
    }
    return '有 $yes / $total 次　無 $no / $total 次';
  }
}

class _StatDot extends StatelessWidget {
  const _StatDot({required this.filled, required this.brand});

  final bool filled;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? brand : Colors.transparent,
        border: Border.all(
          color: filled ? brand : const Color(0xFFC9BDB0),
          width: 1.6,
        ),
      ),
    );
  }
}

class _EnvironmentCard extends StatelessWidget {
  const _EnvironmentCard({required this.stats, required this.brand});

  final DailyCareReportStats stats;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '環境統計',
      brand: brand,
      child: Row(
        children: <Widget>[
          if (stats.avgTemperature != null)
            Expanded(
              child: _envBlock(
                title: '室溫',
                avg: _num(stats.avgTemperature, '°C'),
                min: _num(stats.minTemperature, '°C'),
                max: _num(stats.maxTemperature, '°C'),
                brand: brand,
              ),
            ),
          if (stats.avgTemperature != null && stats.avgHumidity != null)
            const SizedBox(width: 10),
          if (stats.avgHumidity != null)
            Expanded(
              child: _envBlock(
                title: '濕度',
                avg: _num(stats.avgHumidity, '%', digits: 0),
                min: _num(stats.minHumidity, '%', digits: 0),
                max: _num(stats.maxHumidity, '%', digits: 0),
                brand: brand,
              ),
            ),
        ],
      ),
    );
  }

  Widget _envBlock({
    required String title,
    required String avg,
    required String min,
    required String max,
    required Color brand,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Text(
            '平均$title',
            style: const TextStyle(
              fontSize: 11,
              color: DailyCareSummaryReportView.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            avg,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: brand,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(child: _mini('最低', min)),
              Expanded(child: _mini('最高', max)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: DailyCareSummaryReportView.muted,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: DailyCareSummaryReportView.ink,
          ),
        ),
      ],
    );
  }

  String _num(double? value, String unit, {int digits = 1}) {
    if (value == null) {
      return '—';
    }
    final String text = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(digits);
    return '$text$unit';
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.stats, required this.brand});

  final DailyCareReportStats stats;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '住宿概況',
      brand: brand,
      child: stats.overviewLines.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int index = 0; index < stats.overviewLines.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == stats.overviewLines.length - 1 ? 0 : 6,
                    ),
                    child: Text(
                      '${stats.overviewLines[index].dateText}　${stats.overviewLines[index].text}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: DailyCareSummaryReportView.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            )
          : Text(
              stats.overviewNoteDays > 0
                  ? '住宿期間共有 ${stats.overviewNoteDays} 天照護概況，詳細內容請查看完整版。'
                  : '住宿期間沒有另存照護概況文字，詳細內容請查看完整版。',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: DailyCareSummaryReportView.ink,
              ),
            ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.data});

  final DailyCareReportData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(height: 1, color: DailyCareSummaryReportView.line),
        const SizedBox(height: 12),
        const Text(
          '感謝您的入住 🐾',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: DailyCareSummaryReportView.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.shopName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: DailyCareSummaryReportView.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '本照護統計由 PetNest 系統產生',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: DailyCareSummaryReportView.muted,
          ),
        ),
        Text(
          '產生日期：${data.generatedAtText}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: DailyCareSummaryReportView.muted,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.brand,
    required this.child,
  });

  final String title;
  final Color brand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Paper(
      brand: brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: brand,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Paper extends StatelessWidget {
  const _Paper({required this.brand, required this.child});

  final Color brand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: DailyCareSummaryReportView.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brand.withValues(alpha: 0.14)),
      ),
      child: child,
    );
  }
}

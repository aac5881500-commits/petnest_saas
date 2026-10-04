// 檔案名稱：lib/features/booking/widgets/care_statistics_view.dart
// 功能說明：整筆訂單照護統計的共用畫面。顧客端與店主端共用，只負責呈現。

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_date_helper.dart';
import '../../../core/models/daily_care_journal_layout.dart';
import '../../../core/models/daily_care_record_model.dart';
import '../../../core/models/daily_care_statistics.dart';
import '../../../core/services/daily_care_statistics_service.dart';
import '../../../core/widgets/daily_care_illustrations.dart';
import '../../../core/widgets/daily_care_journal_renderer.dart';

class CareStatisticsBody extends StatefulWidget {
  const CareStatisticsBody({
    super.key,
    required this.request,
    required this.records,
    this.adminCaption = '',
  });

  final DailyCareStatisticsRequest request;
  final List<DailyCareRecordModel> records;
  final String adminCaption;

  @override
  State<CareStatisticsBody> createState() => _CareStatisticsBodyState();
}

class _CareStatisticsBodyState extends State<CareStatisticsBody> {
  static const double _maxWidth = 1180;
  static const double _desktop = 960;

  int _mode = 0;
  String? _petId;
  final Set<String> _expanded = <String>{};
  bool _notesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final BookingCareStatistics stats = DailyCareStatisticsService.build(
      request: widget.request,
      records: widget.records,
      selectedPetId: _petId,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= _desktop;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: stats.isEmpty
                ? ListView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 24 : 16,
                      12,
                      wide ? 24 : 16,
                      28,
                    ),
                    children: <Widget>[_empty(stats)],
                  )
                : wide && _mode == 1
                ? _recordsDesktop(stats, constraints.maxWidth)
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 24 : 16,
                      12,
                      wide ? 24 : 16,
                      28,
                    ),
                    children: <Widget>[
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: _sections(stats)),
                            const SizedBox(width: 16),
                            SizedBox(width: 300, child: _summary(stats)),
                          ],
                        )
                      else ...<Widget>[
                        _summary(stats),
                        const SizedBox(height: 12),
                        _sections(stats),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _summary(BookingCareStatistics stats) {
    final Color ink = DailyCareJournalThemeTokens.headerInk;
    return _card(
      key: const ValueKey<String>('care-statistics-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '本次照護摘要',
            style: TextStyle(
              color: ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (widget.adminCaption.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              widget.adminCaption.trim(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A7A6C)),
            ),
          ],
          const SizedBox(height: 10),
          _summaryLine('寵物', stats.petName),
          if (stats.periodText.isNotEmpty)
            _summaryLine(
              widget.request.isDaycare ? '服務日期' : '住宿期間',
              stats.periodText,
            ),
          _summaryLine(
            '回報進度',
            stats.progressText,
            valueKey: 'care-statistics-progress',
          ),
          if (stats.petChoices.length > 1) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stats.petChoices.map((CarePetRef pet) {
                final bool selected = pet.id == stats.petId;
                return ChoiceChip(
                  key: ValueKey<String>('care-statistics-pet-${pet.id}'),
                  label: Text(pet.name),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _petId = pet.id;
                    _expanded.clear();
                  }),
                );
              }).toList(),
            ),
          ],
          if (stats.sampleNotice.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              stats.sampleNotice,
              key: const ValueKey<String>('care-statistics-sample-notice'),
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8D6E63),
              ),
            ),
          ],
          if (stats.progressHint.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              stats.progressHint,
              key: const ValueKey<String>('care-statistics-progress-hint'),
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Color(0xFF8A7A6C),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value, {String? valueKey}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8A7A6C)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              key: valueKey == null ? null : ValueKey<String>(valueKey),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: DailyCareJournalThemeTokens.headerInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sections(BookingCareStatistics stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _modeSwitch(),
        const SizedBox(height: 12),
        if (_mode == 0) _overview(stats) else _records(stats),
      ],
    );
  }

  Widget _modeSwitch() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<int>(
        key: const ValueKey<String>('care-statistics-mode'),
        showSelectedIcon: false,
        segments: const <ButtonSegment<int>>[
          ButtonSegment<int>(
            value: 0,
            label: Text('統計總覽'),
            icon: Icon(Icons.donut_small_outlined, size: 16),
          ),
          ButtonSegment<int>(
            value: 1,
            label: Text('照護紀錄'),
            icon: Icon(Icons.view_timeline_outlined, size: 16),
          ),
        ],
        selected: <int>{_mode},
        onSelectionChanged: (Set<int> next) {
          setState(() => _mode = next.first);
        },
      ),
    );
  }

  Widget _overview(BookingCareStatistics stats) {
    final List<Widget> cards = <Widget>[
      if (stats.environment != null)
        _environmentCard(stats.environment!)
      else
        _emptyZoneCard(
          cardKey: DailyCareJournalCardKeys.environment,
          title: '環境狀況',
        ),
      if (stats.toilet != null) _zoneCard(stats.toilet!),
      if (stats.life != null) _zoneCard(stats.life!),
      if (stats.activity != null) _zoneCard(stats.activity!),
      if (stats.relax != null) _zoneCard(stats.relax!),
      if (stats.other != null && stats.other!.zone.hasData)
        _zoneCard(stats.other!),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns = width >= 760
            ? 3
            : width >= 520
            ? 2
            : 1;
        return Column(
          children: <Widget>[
            if (cards.isNotEmpty) _cardGrid(cards, columns),
            if (stats.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _notesCard(stats.notes),
            ],
          ],
        );
      },
    );
  }

  Widget _cardGrid(List<Widget> cards, int columns) {
    if (columns <= 1) {
      return Column(children: _spaced(cards));
    }
    final List<Widget> rows = <Widget>[];
    for (int index = 0; index < cards.length; index += columns) {
      final List<Widget> slice = cards.sublist(
        index,
        math.min(index + columns, cards.length),
      );
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int column = 0; column < columns; column++) ...<Widget>[
              if (column > 0) const SizedBox(width: 12),
              Expanded(
                child: column < slice.length
                    ? slice[column]
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }
    return Column(children: _spaced(rows));
  }

  Widget _records(BookingCareStatistics stats) {
    if (stats.timeline.isEmpty) {
      return _recordsEmpty();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _spaced(<Widget>[
        _recordSummary(stats),
        if (stats.completedReportCount >= 2) _compareHint(),
        _environmentRecordCard(stats),
        ..._dateGroups(stats),
      ]),
    );
  }

  List<Widget> _spaced(List<Widget> children) {
    final List<Widget> spaced = <Widget>[];
    for (int index = 0; index < children.length; index++) {
      if (index > 0) {
        spaced.add(const SizedBox(height: 12));
      }
      spaced.add(children[index]);
    }
    return spaced;
  }

  Widget _environmentCard(CareEnvironmentStatistics environment) {
    return _sectionCard(
      cardKey: DailyCareJournalCardKeys.environment,
      title: '環境狀況',
      footer: environment.footerText,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (environment.temperature != null)
            Expanded(child: _numericColumn(environment.temperature!)),
          if (environment.temperature != null && environment.humidity != null)
            const SizedBox(width: 12),
          if (environment.humidity != null)
            Expanded(child: _numericColumn(environment.humidity!)),
        ],
      ),
    );
  }

  Widget _numericColumn(CareNumericSeries series) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '平均${series.label}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF8A7A6C)),
        ),
        const SizedBox(height: 2),
        Text(
          '${series.averageText}${series.unit}',
          key: ValueKey<String>('care-statistics-${series.key}-average'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: DailyCareJournalThemeTokens.headerInk,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '範圍 ${series.minimumText}–${series.maximumText}${series.unit}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF8A7A6C)),
        ),
        const SizedBox(height: 8),
        _rangeBar(series),
        if (series.singleSample)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '目前僅 1 筆有效紀錄',
              style: TextStyle(fontSize: 11, color: Color(0xFF8D6E63)),
            ),
          ),
      ],
    );
  }

  Widget _rangeBar(CareNumericSeries series) {
    final double span = series.maximum - series.minimum;
    final double t = span <= 0
        ? 0.5
        : ((series.average - series.minimum) / span).clamp(0.0, 1.0);
    return Column(
      children: <Widget>[
        SizedBox(
          height: 16,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double left = (constraints.maxWidth - 10) * t;
              return Stack(
                children: <Widget>[
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: DailyCareJournalThemeTokens.primary.withValues(
                          alpha: 0.25,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: 3,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: DailyCareJournalThemeTokens.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              '${series.minimumText}${series.unit}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A7A6C)),
            ),
            Text(
              '${series.maximumText}${series.unit}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A7A6C)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _emptyZoneCard({required String cardKey, required String title}) {
    return _sectionCard(
      cardKey: cardKey,
      title: title,
      footer: '',
      child: Text(
        '尚無資料',
        key: ValueKey<String>('care-statistics-zone-empty-$cardKey'),
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8A7A6C),
        ),
      ),
    );
  }

  Widget _zoneCard(CareCategoryStatistics category) {
    final CareZoneScore zone = category.zone;
    if (!zone.hasData) {
      return _emptyZoneCard(cardKey: category.key, title: category.title);
    }
    final bool open = _expanded.contains(category.key);
    final String detailKey = category.key == 'food'
        ? DailyCareJournalCardKeys.food
        : category.key;
    return _sectionCard(
      cardKey: detailKey,
      title: category.title,
      footer: zone.footerText,
      child: Column(
        children: <Widget>[
          SizedBox(
            width: 112,
            height: 112,
            child: CustomPaint(
              painter: _ScoreRingPainter(percent: zone.percent!),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${zone.percent}%',
                      key: ValueKey<String>(
                        'care-statistics-zone-${category.key}',
                      ),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: DailyCareJournalThemeTokens.headerInk,
                      ),
                    ),
                    Text(
                      zone.caption,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A7A6C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: ValueKey<String>('care-statistics-detail-${category.key}'),
              onPressed: () => setState(() {
                if (open) {
                  _expanded.remove(category.key);
                } else {
                  _expanded.add(category.key);
                }
              }),
              child: Text(open ? '收合明細' : '查看明細'),
            ),
          ),
          if (open)
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '有效紀錄 ${zone.observationCount} 筆',
                    style: const TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                  ...zone.breakdown.map((CareStatusCount item) {
                    return Text(
                      '${item.label} ${item.ratio.count} 筆',
                      style: const TextStyle(fontSize: 12.5, height: 1.5),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _notesCard(List<CareNoteEntry> notes) {
    final bool expanded = _notesExpanded || notes.length <= 3;
    final List<CareNoteEntry> visible = expanded
        ? notes
        : notes.sublist(notes.length - 3);
    return _sectionCard(
      cardKey: DailyCareJournalCardKeys.generalNote,
      title: '照護記事',
      footer: '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ...visible.map((CareNoteEntry note) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    note.heading,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: DailyCareJournalThemeTokens.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note.text,
                    style: const TextStyle(fontSize: 13.5, height: 1.45),
                  ),
                ],
              ),
            );
          }),
          if (notes.length > 3)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey<String>('care-statistics-notes-more'),
                onPressed: () =>
                    setState(() => _notesExpanded = !_notesExpanded),
                child: Text(expanded ? '收合' : '查看全部 ${notes.length} 則'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recordsDesktop(BookingCareStatistics stats, double width) {
    final double aside = math.min(400, math.max(280, width * 0.34));
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ListView(
              children: <Widget>[
                _modeSwitch(),
                const SizedBox(height: 12),
                _records(stats),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: aside,
            child: ListView(
              children: <Widget>[
                _summary(stats),
                const SizedBox(height: 12),
                _environmentAside(stats),
                const SizedBox(height: 12),
                _overallAside(stats),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordSummary(BookingCareStatistics stats) {
    final String done = stats.expectedReportCount == null
        ? '${stats.completedReportCount} 場'
        : '${stats.completedReportCount} / ${stats.expectedReportCount} 場';
    return _card(
      key: const ValueKey<String>('care-statistics-record-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '照護紀錄',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: DailyCareJournalThemeTokens.headerInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stats.petName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          if (stats.periodText.isNotEmpty)
            Text(
              '服務期間　${stats.periodText}',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFF8A7A6C),
              ),
            ),
          Text(
            '已完成　　$done',
            key: const ValueKey<String>('care-statistics-record-progress'),
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Color(0xFF8A7A6C),
            ),
          ),
          Text(
            '目前累積 ${stats.completedReportCount} 場有效照護紀錄',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Color(0xFF8A7A6C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compareHint() {
    return const Text(
      '↑ ↓ 表示與上一場照護紀錄相比，僅供快速查看變化。',
      key: ValueKey<String>('care-statistics-compare-hint'),
      style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF8A7A6C)),
    );
  }

  Widget _recordsEmpty() {
    return _card(
      key: const ValueKey<String>('care-statistics-record-empty'),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '尚無已完成的照護紀錄',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: DailyCareJournalThemeTokens.headerInk,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '完成第一場回報後，這裡會開始整理本次住宿的照護變化。',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF8A7A6C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _environmentRecordCard(BookingCareStatistics stats) {
    final CareEnvironmentStatistics? environment = stats.environment;
    final bool hasData =
        environment?.temperature != null || environment?.humidity != null;
    return _sectionCard(
      cardKey: DailyCareJournalCardKeys.environment,
      title: '環境紀錄',
      footer: '',
      child: hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (environment!.temperature != null)
                  _climateAverage('平均溫度', environment.temperature!),
                if (environment.humidity != null)
                  _climateAverage('平均濕度', environment.humidity!),
                const SizedBox(height: 8),
                ..._climateRows(stats),
              ],
            )
          : const Text(
              '尚無資料',
              key: ValueKey<String>('care-statistics-environment-empty'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A7A6C),
              ),
            ),
    );
  }

  Widget _climateAverage(String label, CareNumericSeries series) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A7A6C)),
            ),
          ),
          Text(
            '${series.averageText}${series.unit}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  List<Widget> _climateRows(BookingCareStatistics stats) {
    final List<Widget> rows = <Widget>[];
    String? currentDate;
    for (int index = 0; index < stats.timeline.length; index++) {
      final double? temperature = _pointAt(
        stats.environment?.temperature,
        index,
      );
      final double? humidity = _pointAt(stats.environment?.humidity, index);
      if (temperature == null && humidity == null) {
        continue;
      }
      final CareTimelineSlot slot = stats.timeline[index];
      if (slot.dateKey != currentDate) {
        currentDate = slot.dateKey;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              _monthDay(slot.dateKey),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: DailyCareJournalThemeTokens.primary,
              ),
            ),
          ),
        );
      }
      final List<String> values = <String>[
        slot.sessionLabel,
        if (temperature != null) '${_plainNumber(temperature)}°C',
        if (humidity != null) '${_plainNumber(humidity)}%',
      ];
      rows.add(
        Text(
          values.join('　'),
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
      );
    }
    return rows;
  }

  double? _pointAt(CareNumericSeries? series, int index) {
    if (series == null || index < 0 || index >= series.points.length) {
      return null;
    }
    return series.points[index];
  }

  String _plainNumber(double value) {
    if ((value - value.roundToDouble()).abs() < 0.001) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  List<Widget> _dateGroups(BookingCareStatistics stats) {
    final List<Widget> blocks = <Widget>[];
    String? currentDate;
    final List<int> indexes = <int>[];
    void flush() {
      if (currentDate == null || indexes.isEmpty) {
        return;
      }
      final String dateKey = currentDate;
      final List<int> copy = List<int>.from(indexes);
      blocks.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _weekdayHeading(dateKey),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: DailyCareJournalThemeTokens.headerInk,
              ),
            ),
            Text(
              '${copy.length} 場照護',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A7A6C)),
            ),
            const SizedBox(height: 8),
            ...copy.map((int index) => _sessionCard(stats, index)),
          ],
        ),
      );
      indexes.clear();
    }

    for (int index = 0; index < stats.timeline.length; index++) {
      final String dateKey = stats.timeline[index].dateKey;
      if (currentDate != dateKey) {
        flush();
        currentDate = dateKey;
      }
      indexes.add(index);
    }
    flush();
    return blocks;
  }

  Widget _sessionCard(BookingCareStatistics stats, int index) {
    final CareTimelineSlot slot = stats.timeline[index];
    final int? toilet = _zoneAt(stats.toilet, index);
    final int? life = _zoneAt(stats.life, index);
    final int? activity = _zoneAt(stats.activity, index);
    final int? relax = _zoneAt(stats.relax, index);
    final int? previousToilet = index == 0
        ? null
        : _zoneAt(stats.toilet, index - 1);
    final int? previousLife = index == 0
        ? null
        : _zoneAt(stats.life, index - 1);
    final int? previousActivity = index == 0
        ? null
        : _zoneAt(stats.activity, index - 1);
    final int? previousRelax = index == 0
        ? null
        : _zoneAt(stats.relax, index - 1);
    final double? temperature = _pointAt(stats.environment?.temperature, index);
    final double? humidity = _pointAt(stats.environment?.humidity, index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _card(
        key: ValueKey<String>('care-record-${slot.recordId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: DailyCareJournalThemeTokens.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    slot.sessionLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _metric(
                    '大小便',
                    toilet,
                    DailyCareZoneScore.changeMark(
                      current: toilet,
                      previous: previousToilet,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metric(
                    '生活',
                    life,
                    DailyCareZoneScore.changeMark(
                      current: life,
                      previous: previousLife,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _metric(
                    '活動',
                    activity,
                    DailyCareZoneScore.changeMark(
                      current: activity,
                      previous: previousActivity,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metric(
                    '放鬆',
                    relax,
                    DailyCareZoneScore.changeMark(
                      current: relax,
                      previous: previousRelax,
                    ),
                  ),
                ),
              ],
            ),
            if (temperature != null || humidity != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                <String>[
                  if (temperature != null) '${_plainNumber(temperature)}°C',
                  if (humidity != null) '${_plainNumber(humidity)}%',
                ].join('　'),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF8A7A6C),
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: ValueKey<String>('care-record-detail-${slot.recordId}'),
                onPressed: () => _openSessionDetail(stats, index),
                child: const Text('查看明細'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _zoneAt(CareCategoryStatistics? category, int index) {
    if (category == null || category.fields.isEmpty) {
      return null;
    }
    return DailyCareZoneScore.percentOfValues(
      category.fields.map((CareFieldStatistics field) {
        if (index < 0 || index >= field.timeline.length) {
          return null;
        }
        return field.timeline[index];
      }),
    );
  }

  Widget _metric(String label, int? score, String? mark) {
    final Color markColor = switch (mark) {
      '↑' => DailyCareJournalThemeTokens.primary,
      '↓' => const Color(0xFF8D6E63),
      _ => const Color(0xFF8A7A6C),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8A7A6C)),
        ),
        const SizedBox(height: 2),
        Row(
          children: <Widget>[
            Text(
              score == null ? '—' : '$score',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DailyCareJournalThemeTokens.headerInk,
              ),
            ),
            if (mark != null) ...<Widget>[
              const SizedBox(width: 4),
              Text(
                mark,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: markColor,
                ),
              ),
            ],
          ],
        ),
        if (score != null) ...<Widget>[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 3,
              value: (score / 100).clamp(0, 1).toDouble(),
              backgroundColor: const Color(0xFFE7E0D8),
              color: DailyCareJournalThemeTokens.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _environmentAside(BookingCareStatistics stats) {
    final CareNumericSeries? temperature = stats.environment?.temperature;
    final CareNumericSeries? humidity = stats.environment?.humidity;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '環境平均',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: DailyCareJournalThemeTokens.headerInk,
            ),
          ),
          const SizedBox(height: 8),
          if (temperature == null && humidity == null)
            const Text(
              '尚無資料',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A7A6C),
              ),
            )
          else ...<Widget>[
            if (temperature != null)
              _summaryLine(
                '平均溫度',
                '${temperature.averageText}${temperature.unit}',
              ),
            if (humidity != null)
              _summaryLine('平均濕度', '${humidity.averageText}${humidity.unit}'),
          ],
        ],
      ),
    );
  }

  Widget _overallAside(BookingCareStatistics stats) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '整筆訂單目前整體狀況',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: DailyCareJournalThemeTokens.headerInk,
            ),
          ),
          const SizedBox(height: 8),
          _asideZone('大小便狀況', stats.toilet),
          _asideZone('生活狀況', stats.life),
          _asideZone('活動與玩樂', stats.activity),
          _asideZone('放鬆與用品', stats.relax),
        ],
      ),
    );
  }

  Widget _asideZone(String title, CareCategoryStatistics? category) {
    final bool hasData = category?.zone.hasData == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
          Text(
            hasData ? '${category!.zone.percent}' : '尚無資料',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  void _openSessionDetail(BookingCareStatistics stats, int index) {
    final bool wide = MediaQuery.sizeOf(context).width >= _desktop;
    final Widget body = _sessionDetail(stats, index);
    if (wide) {
      showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
              child: body,
            ),
          );
        },
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DailyCareJournalThemeTokens.cream,
      builder: (BuildContext context) {
        return FractionallySizedBox(heightFactor: 0.82, child: body);
      },
    );
  }

  Widget _sessionDetail(BookingCareStatistics stats, int index) {
    final CareTimelineSlot slot = stats.timeline[index];
    final List<CareNoteEntry> notes = stats.notes
        .where(
          (CareNoteEntry note) =>
              note.dateKey == slot.dateKey &&
              note.sessionLabel == slot.sessionLabel,
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: <Widget>[
        Text(
          _weekdayHeading(slot.dateKey),
          style: const TextStyle(fontSize: 12, color: Color(0xFF8A7A6C)),
        ),
        Text(
          slot.sessionLabel,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: DailyCareJournalThemeTokens.headerInk,
          ),
        ),
        const SizedBox(height: 12),
        ..._detailSection('大小便狀況', stats.toilet, index),
        ..._detailSection('生活狀況', stats.life, index),
        ..._detailSection('活動與玩樂', stats.activity, index),
        ..._detailSection('放鬆與用品', stats.relax, index),
        ..._detailSection('其他紀錄', stats.other, index),
        if (notes.isNotEmpty) ...<Widget>[
          const Text(
            '今日概況',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          ...notes.map(
            (CareNoteEntry note) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                note.text,
                style: const TextStyle(fontSize: 14, height: 1.45),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _detailSection(
    String title,
    CareCategoryStatistics? category,
    int index,
  ) {
    if (category == null) {
      return const <Widget>[];
    }
    final List<Widget> rows = <Widget>[];
    for (final CareFieldStatistics field in category.fields) {
      final String? value = index < field.timeline.length
          ? field.timeline[index]
          : null;
      if (value == null || value.trim().isEmpty) {
        continue;
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 88,
                child: Text(
                  field.label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A7A6C),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (rows.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      ...rows,
      const SizedBox(height: 10),
    ];
  }

  String _monthDay(String dateKey) {
    final DateTime? date = DailyCareDateHelper.parseDateKey(dateKey);
    if (date == null) {
      return dateKey;
    }
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _weekdayHeading(String dateKey) {
    final DateTime? date = DailyCareDateHelper.parseDateKey(dateKey);
    if (date == null) {
      return dateKey;
    }
    const List<String> days = <String>['一', '二', '三', '四', '五', '六', '日'];
    return '${_monthDay(dateKey)}（${days[date.weekday - 1]}）';
  }

  Widget _sectionCard({
    required String cardKey,
    required String title,
    required String footer,
    required Widget child,
  }) {
    return _card(
      key: ValueKey<String>('care-statistics-card-$cardKey'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DailyCareSvgIcon(
                asset: DailyCareIllustrations.forCard(cardKey),
                color: DailyCareJournalThemeTokens.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: DailyCareJournalThemeTokens.headerInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
          if (footer.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              footer,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A7A6C)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({Key? key, required Widget child}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xD1FFFDFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: child,
    );
  }

  Widget _empty(BookingCareStatistics stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _summary(stats),
        const SizedBox(height: 12),
        _card(
          key: const ValueKey<String>('care-statistics-empty'),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '目前尚無已完成的照護回報',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: DailyCareJournalThemeTokens.headerInk,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '完成第一場回報後，這裡會開始產生本次照護統計。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Color(0xFF8A7A6C),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  _ScoreRingPainter({required this.percent});

  final int percent;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = const Color(0xFFE7E0D8);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    final double fraction = (percent.clamp(0, 100)) / 100;
    if (fraction <= 0) {
      return;
    }
    final Paint value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = DailyCareJournalThemeTokens.primary;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction, false, value);
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.percent != percent;
  }
}

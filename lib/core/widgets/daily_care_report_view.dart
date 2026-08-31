// lib/core/widgets/daily_care_report_view.dart
// 🐾 每日照護報告獨立排版
// 專門給 PNG 產圖，不是 App 畫面截圖。

import 'package:flutter/material.dart';

import '../models/daily_care_report_data.dart';

class DailyCareReportView extends StatelessWidget {
  const DailyCareReportView({
    super.key,
    required this.data,
    this.logoProvider,
    this.showHeader = true,
    this.showStayInfo = true,
    this.showFooter = true,
    this.days,
  });

  final DailyCareReportData data;
  final ImageProvider? logoProvider;
  final bool showHeader;
  final bool showStayInfo;
  final bool showFooter;
  final List<DailyCareReportDay>? days;

  static const Color cream = Color(0xFFFFF8F1);
  static const Color ink = Color(0xFF3A2A20);
  static const Color muted = Color(0xFF8A7A6C);

  @override
  Widget build(BuildContext context) {
    final Color brand = data.brandColor;
    final List<DailyCareReportDay> visibleDays = days ?? data.days;

    return ColoredBox(
      color: cream,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showHeader) _Header(data: data, logoProvider: logoProvider),
            if (showStayInfo) ...<Widget>[
              const SizedBox(height: 18),
              _StayCard(data: data),
            ],
            if (data.isFullStay && showHeader && showStayInfo) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                '住宿期間共 ${visibleDays.length} 天照護紀錄',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: brand,
                ),
              ),
            ],
            for (final DailyCareReportDay day in visibleDays) ...<Widget>[
              const SizedBox(height: 22),
              _DayBlock(day: day, brand: brand, isFullStay: data.isFullStay),
            ],
            if (showFooter) ...<Widget>[
              const SizedBox(height: 22),
              _Footer(data: data),
            ],
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
        const SizedBox(height: 12),
        Text(
          data.shopName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: DailyCareReportView.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: data.brandColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.headerDateText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: DailyCareReportView.muted,
            letterSpacing: 0.6,
          ),
        ),
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
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: brand.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoProvider == null
          ? Icon(Icons.pets, color: brand, size: 34)
          : Image(
              image: logoProvider!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.pets, color: brand, size: 34);
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.brandColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: <Widget>[
          _row('房間', data.roomName),
          if (data.roomTypeName.isNotEmpty) _row('房型', data.roomTypeName),
          _row('入住寵物', data.petNames),
          _row('入住日期', data.checkInText),
          _row('退房日期', data.checkOutText),
          _row('住宿晚數', data.nightsText),
          if (data.bookingCode.isNotEmpty) _row('訂單編號', data.bookingCode, last: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: DailyCareReportView.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: DailyCareReportView.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({
    required this.day,
    required this.brand,
    required this.isFullStay,
  });

  final DailyCareReportDay day;
  final Color brand;
  final bool isFullStay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (isFullStay) ...<Widget>[
          Text(
            day.dateTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: brand,
            ),
          ),
          const SizedBox(height: 8),
        ] else ...<Widget>[
          Text(
            '今日照護紀錄',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: brand,
            ),
          ),
          const SizedBox(height: 10),
        ],
        for (int index = 0; index < day.sessions.length; index++) ...<Widget>[
          _SessionCard(session: day.sessions[index], brand: brand),
          if (index < day.sessions.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.brand});

  final DailyCareReportSession session;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DFD4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  session.sessionName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: DailyCareReportView.ink,
                  ),
                ),
              ),
              if (session.updatedAtText.isNotEmpty)
                Text(
                  session.updatedAtText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: DailyCareReportView.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          for (final DailyCareReportGroup group in session.groups) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              group.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: brand,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: group.fields
                  .map(
                    (DailyCareReportField field) => _FieldChip(
                      field: field,
                      brand: brand,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (session.generalNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '🐾 今日概況',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: brand,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    session.generalNote,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.55,
                      color: DailyCareReportView.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip({required this.field, required this.brand});

  final DailyCareReportField field;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final Color tone = switch (field.badge) {
      DailyCareReportBadgeKind.good => const Color(0xFF2E7D32),
      DailyCareReportBadgeKind.yes => const Color(0xFF2E6B8A),
      DailyCareReportBadgeKind.no => const Color(0xFF7A746C),
      DailyCareReportBadgeKind.normal => const Color(0xFF3D6F9F),
      DailyCareReportBadgeKind.warn => const Color(0xFFC45C26),
      DailyCareReportBadgeKind.none => DailyCareReportView.ink,
    };
    final Color bg = switch (field.badge) {
      DailyCareReportBadgeKind.good => const Color(0xFFE8F5E9),
      DailyCareReportBadgeKind.yes => const Color(0xFFE3F2F4),
      DailyCareReportBadgeKind.no => const Color(0xFFF2EFEA),
      DailyCareReportBadgeKind.normal => const Color(0xFFE8F1F8),
      DailyCareReportBadgeKind.warn => const Color(0xFFFBE8DC),
      DailyCareReportBadgeKind.none => const Color(0xFFF6F1EA),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '${field.emoji.isEmpty ? '' : '${field.emoji} '}${field.label}',
            style: const TextStyle(
              fontSize: 12,
              color: DailyCareReportView.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              field.value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
          ),
        ],
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
        Container(height: 1, color: const Color(0xFFE4D8CA)),
        const SizedBox(height: 14),
        const Text(
          '感謝您的入住 🐾',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: DailyCareReportView.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.petNames.isEmpty || data.petNames == '尚未指定寵物'
              ? '期待再次見面'
              : '期待再次與${data.petNames}見面',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: DailyCareReportView.muted,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          data.shopName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: DailyCareReportView.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '本照護紀錄由 PetNest 系統產生',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: DailyCareReportView.muted),
        ),
        Text(
          '產生日期：${data.generatedAtText}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: DailyCareReportView.muted),
        ),
      ],
    );
  }
}

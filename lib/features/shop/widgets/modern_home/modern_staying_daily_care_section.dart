import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/booking_kind.dart';
import '../../../../core/models/daily_care_date_helper.dart';
import '../../../../core/models/daily_care_entitlement.dart';
import '../../../../core/models/daily_care_record_model.dart';
import '../../../../core/models/daily_care_setting_model.dart';
import '../../../../core/models/daily_care_stay_info.dart';
import '../../../../core/models/home_theme_model.dart';
import '../../../../core/services/daily_care_record_service.dart';
import '../../../../core/models/daily_care_photo_model.dart';
import '../../../../core/services/inspection_owner_context.dart';
import '../../../../core/services/daily_care_setting_service.dart';
import '../../../booking/pages/customer_daily_care_page.dart';
import 'home_diary_widgets.dart';
import '../../../../core/models/booking_medication_task.dart';
import '../../../../core/models/booking_service_task.dart';
import '../../../booking/pages/booking_detail_page.dart';

class ModernStayingDailyCareSection extends StatelessWidget {
  const ModernStayingDailyCareSection({
    super.key,
    required this.shopId,
    required this.theme,
    this.platformPreview = false,
  });

  final String shopId;
  final HomeThemeModel theme;
  final bool platformPreview;

  @override
  Widget build(BuildContext context) {
    if (platformPreview ||
        InspectionOwnerContext.active ||
        shopId.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, auth) {
        final user = auth.data;
        if (user == null) return const SizedBox.shrink();
        return _Stays(
          key: ValueKey((shopId, user.uid)),
          shopId: shopId,
          userId: user.uid,
          theme: theme,
        );
      },
    );
  }
}

class _Stays extends StatefulWidget {
  const _Stays({
    super.key,
    required this.shopId,
    required this.userId,
    required this.theme,
  });

  final String shopId, userId;
  final HomeThemeModel theme;

  @override
  State<_Stays> createState() => _StaysState();
}

class _StaysState extends State<_Stays> {
  late final _bookings = FirebaseFirestore.instance
      .collection('bookings')
      .where('userId', isEqualTo: widget.userId)
      .where('shopId', isEqualTo: widget.shopId)
      .where('status', isEqualTo: 'checked_in')
      .snapshots();
  late final _settings = DailyCareSettingService.instance.streamSetting(
    widget.shopId,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _bookings,
      builder: (context, bookings) {
        final stays =
            bookings.data?.docs.where((doc) {
              final data = doc.data();
              return !BookingKind.isDaycare(data) &&
                  data['checkOutAt'] == null &&
                  data['checkedOutAt'] == null &&
                  data['actualEndAt'] == null;
            }).toList() ??
            [];
        if (stays.isEmpty) return const SizedBox.shrink();
        return StreamBuilder<DailyCareSettingModel>(
          stream: _settings,
          builder: (context, settings) {
            return Column(
              children: [
                for (final stay in stays)
                  Column(
                    key: ValueKey(stay.id),
                    children: [
                      if (!DailyCareEntitlement.explicitlyNoReports(
                        stay.data(),
                      ))
                        _StayCard(
                          shopId: widget.shopId,
                          bookingId: stay.id,
                          booking: stay.data(),
                          setting: settings.data,
                          theme: widget.theme,
                        ),
                      StayingServiceUpdates(
                        booking: stay.data(),
                        theme: widget.theme,
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BookingDetailPage(
                              data: stay.data(),
                              docId: stay.id,
                              showCare: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StayCard extends StatefulWidget {
  const _StayCard({
    required this.shopId,
    required this.bookingId,
    required this.booking,
    required this.setting,
    required this.theme,
  });

  final String shopId, bookingId;
  final Map<String, dynamic> booking;
  final DailyCareSettingModel? setting;
  final HomeThemeModel theme;

  @override
  State<_StayCard> createState() => _StayCardState();
}

class _StayCardState extends State<_StayCard> {
  late final _records = DailyCareRecordService.instance.streamBookingRecords(
    bookingId: widget.bookingId,
  );

  @override
  Widget build(BuildContext context) {
    final raw = widget.booking['dailyCareEntitlement'];
    final entitlement = DailyCareEntitlement.fromMap(
      raw is Map ? Map<String, dynamic>.from(raw) : null,
    );
    final setting = widget.setting;
    final count = DailyCareEntitlement.hasExplicitFinalReports(widget.booking)
        ? entitlement.finalReports
        : (setting?.enabled == true ? setting!.sessionCount : 0);
    if (count <= 0) return const SizedBox.shrink();
    final stay = DailyCareStayInfo.fromBookingMap(widget.booking);
    final careDay = stay.currentCareDate();
    final dateKey = DailyCareDateHelper.dateKey(careDay);
    final theme = widget.theme;

    return StreamBuilder<List<DailyCareRecordModel>>(
      stream: _records,
      builder: (context, snapshot) {
        final completed = (snapshot.data ?? [])
            .where(
              (record) =>
                  record.countsAsCompleted &&
                  record.sessionIndex >= 0 &&
                  record.sessionIndex < count &&
                  DailyCarePhotoMatch.canonicalDateKey(record.recordDate) ==
                      dateKey,
            )
            .toList();
        final done = completed.map((record) => record.sessionIndex).toSet();
        final label =
            dateKey ==
                DailyCareDateHelper.dateKey(DailyCareDateHelper.todayInTaipei())
            ? '今日'
            : dateKey;
        final accent = theme.primaryColor;
        final ink = theme.textColor;
        final muted = ink.withValues(alpha: .72);
        final tint = Color.alphaBlend(
          accent.withValues(alpha: .13),
          theme.cardColor,
        );
        final ready = snapshot.hasData && !snapshot.hasError;
        final progressText = snapshot.hasError
            ? '暫時無法讀取回報進度'
            : ready
            ? '$label ${done.length}／$count 場已更新'
            : '正在讀取回報進度';
        if (theme.storybook.enabled &&
            theme.storybook.diary.enabled &&
            theme.storybook.diary.compactCare) {
          return HomeDiaryCareRibbon(
            petNames: stay.petNamesText,
            petPhotoUrl:
                stay.pets.where((pet) => pet.hasPhoto).firstOrNull?.photoUrl ??
                '',
            progressText: progressText,
            theme: theme,
            count: count,
            completed: done,
            ready: ready,
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CustomerDailyCarePage(
                  shopId: widget.shopId,
                  bookingId: widget.bookingId,
                  roomName: stay.roomName,
                  initialDate: careDay,
                  initialSessionIndex: done.isEmpty
                      ? null
                      : completed.last.sessionIndex,
                ),
              ),
            ),
          );
        }
        return Card(
          elevation: 0,
          color: theme.cardColor,
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: accent.withValues(alpha: .28)),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tint, theme.cardColor, theme.cardColor],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.pets_rounded, color: accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '住宿中的寶貝',
                              style: TextStyle(
                                color: muted,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              stay.petNamesText,
                              style: TextStyle(
                                color: ink,
                                fontSize: 19,
                                height: 1.3,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: accent.withValues(alpha: .6),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    progressText,
                    style: TextStyle(color: ink, fontWeight: FontWeight.w700),
                  ),
                  if (ready) ...[
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 6.0;
                        final minWidth = MediaQuery.textScalerOf(
                          context,
                        ).scale(84);
                        final columns =
                            ((constraints.maxWidth + gap) / (minWidth + gap))
                                .floor()
                                .clamp(1, count.clamp(1, 3));
                        final width =
                            (constraints.maxWidth - gap * (columns - 1)) /
                            columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: 8,
                          children: [
                            for (var index = 0; index < count; index++)
                              SizedBox(
                                width: width,
                                child: _CareStage(
                                  label:
                                      entitlement
                                          .sessionLabelAt(index)
                                          .isNotEmpty
                                      ? entitlement.sessionLabelAt(index)
                                      : setting?.sessionLabel(index) ??
                                            '第 ${index + 1} 場',
                                  updated: done.contains(index),
                                  accent: accent,
                                  ink: ink,
                                  muted: muted,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: ink,
                        backgroundColor: tint,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          15,
                          8,
                          12,
                          8,
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      iconAlignment: IconAlignment.end,
                      icon: Icon(
                        Icons.arrow_forward_rounded,
                        color: accent,
                        size: 17,
                      ),
                      label: const Text('查看回報'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CustomerDailyCarePage(
                            shopId: widget.shopId,
                            bookingId: widget.bookingId,
                            roomName: stay.roomName,
                            initialDate: careDay,
                            initialSessionIndex: done.isEmpty
                                ? null
                                : completed.last.sessionIndex,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CareStage extends StatelessWidget {
  const _CareStage({
    required this.label,
    required this.updated,
    required this.accent,
    required this.ink,
    required this.muted,
  });

  final String label;
  final bool updated;
  final Color accent, ink, muted;

  @override
  Widget build(BuildContext context) {
    final status = updated ? '已更新' : '待更新';
    return Semantics(
      label: '$label，$status',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: accent.withValues(alpha: updated ? .85 : .19),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                updated ? Icons.check_circle_rounded : Icons.schedule_rounded,
                size: 14,
                color: updated ? accent : muted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  status,
                  style: TextStyle(color: updated ? ink : muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StayingServiceUpdates extends StatelessWidget {
  const StayingServiceUpdates({
    super.key,
    required this.booking,
    required this.theme,
    required this.onOpen,
    this.today,
  });
  final Map<String, dynamic> booking;
  final HomeThemeModel theme;
  final VoidCallback onOpen;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final date = BookingMedicationTask.dateKey(
      today ?? DailyCareDateHelper.todayInTaipei(),
    );
    if (booking['status'] != 'checked_in' ||
        booking['checkOutAt'] != null ||
        booking['checkedOutAt'] != null ||
        booking['actualEndAt'] != null) {
      return const SizedBox.shrink();
    }
    final medication = BookingMedicationTask.fromBooking(booking);
    final services = BookingServiceTask.fromBooking(booking);
    if (medication.isEmpty && services.isEmpty) {
      return const SizedBox.shrink();
    }
    final todayMedication = medication
        .where((task) => task.day == date)
        .toList();
    final todayServices = services.where((task) => task.day == date).toList();

    Widget entry(String title, IconData icon, int total, int recorded) {
      final accent = theme.primaryColor;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: Color.alphaBlend(
            accent.withValues(alpha: .065),
            theme.cardColor,
          ),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: theme.storybook.diary.enabled
                                ? theme.storybook.diary.fontFamily
                                : null,
                            color: theme.textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          total == 0 ? '今日無安排' : '今日 $recorded／$total 次已記錄',
                          style: TextStyle(
                            fontFamily: theme.storybook.diary.enabled
                                ? theme.storybook.diary.fontFamily
                                : null,
                            color: theme.secondaryTextColor,
                            fontSize: 11,
                          ),
                        ),
                        if (total > 0) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              value: recorded / total,
                              color: accent,
                              backgroundColor: accent.withValues(alpha: .12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.chevron_right, color: accent, size: 18),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (medication.isNotEmpty)
          entry(
            '餵藥與用藥',
            Icons.medication_outlined,
            todayMedication.length,
            todayMedication.where((task) => task.result != 'pending').length,
          ),
        if (services.isNotEmpty)
          entry(
            '專屬加購',
            Icons.auto_awesome_outlined,
            todayServices.length,
            todayServices.where((task) => !task.pending).length,
          ),
      ],
    );
  }
}

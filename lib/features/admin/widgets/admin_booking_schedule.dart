import 'dart:async';
import '../../../core/models/booking_service_task.dart';
import '../../medication/care_task_dialog.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/services/pet_shop_form_answers.dart';
import '../../../core/widgets/member_avatar.dart';
import 'booking_care_display.dart';

import '../../../core/models/booking_kind.dart';
import '../../../core/models/booking_medication_task.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/services/daily_care_report_eligibility.dart';
import '../../../core/services/daily_care_setting_service.dart';
import '../../medication/medication_task_page.dart';
import '../../medication/medication_widgets.dart'
    show
        medicationTypes,
        openMedicationArrangement,
        checkMedicationOrderConfirmation;

enum BookingScheduleKind { arrival, departure, service, medication }

class BookingScheduleEntry {
  const BookingScheduleEntry({
    required this.kind,
    required this.time,
    required this.title,
    this.detail = '',
    this.slot = '',
    this.completed = false,
    this.service,
    this.medication,
    this.requestStatus,
    this.petIds = const [],
  });

  final BookingScheduleKind kind;
  final DateTime time;
  final String title, detail, slot;
  final bool completed;
  final BookingServiceTask? service;
  final BookingMedicationTask? medication;
  final String? requestStatus;
  final List<String> petIds;

  String? get taskKey {
    if (medication != null) return 'medication:${medication!.id}';
    if (service != null) return 'service:${service!.id}';
    return null;
  }

  String get day =>
      BookingMedicationTask.dateKey(BookingMedicationTask.taipei(time));
  String get timeLabel =>
      slot.isEmpty ? BookingMedicationTask.timeLabel(time) : slot;
}

class AdminBookingScheduleData {
  const AdminBookingScheduleData({
    required this.shopId,
    required this.bookingId,
    required this.booking,
    required this.canEdit,
  });

  final String shopId, bookingId;
  final Map<String, dynamic> booking;
  final bool canEdit;

  bool get daycare => BookingKind.isDaycare(booking);
  String get status => '${booking['status'] ?? ''}';
  bool get ended =>
      const {'cancelled', 'checked_out', 'completed'}.contains(status);
  bool get arrived =>
      const {'checked_in', 'checked_out', 'completed'}.contains(status) ||
      booking['actualStartAt'] != null ||
      booking['checkInAt'] != null ||
      booking['checkedInAt'] != null;
  bool get awaitingConfirmation => const {
    'pending',
    'pending_payment',
    'pending_confirmation',
    'unpaid',
  }.contains(status);

  bool get hasMedication => [
    booking['medication'],
    booking['medicationRequest'],
  ].whereType<Map>().any((data) => data.isNotEmpty);

  bool medicationEnabled(Map<String, dynamic>? shop) {
    final setting = shop?['medicationSetting'];
    return setting is Map && setting['enabled'] == true;
  }

  bool reportsEnabled(Map<String, dynamic>? shop) {
    final setting = shop?['dailyCareSetting'];
    if (setting is! Map ||
        setting[daycare ? 'daycareEnabled' : 'enabled'] != true ||
        !DailyCareReportEligibility.includeInReportCenter(
          booking: booking,
          daycare: daycare,
        )) {
      return false;
    }
    return DailyCareReportEligibility.isEntitled(
      DailyCareReportEligibility.resolvedEntitlement(
        booking: booking,
        setting: DailyCareSettingModel.fromMap(
          DailyCareSettingFirestoreValue.sanitizeMap(
            DailyCareSettingFirestoreValue.copyRawMap(setting),
          ),
        ),
        daycare: daycare,
      ),
    );
  }

  static DateTime? _instant(Object? value) => switch (value) {
    Timestamp value => value.toDate(),
    DateTime value => value,
    String value => DateTime.tryParse(value),
    _ => null,
  };

  static Iterable<Map> _maps(Object? value) =>
      value is List ? value.whereType<Map>() : const [];

  static final _clock = RegExp(r'(?<!\d)([01]?\d|2[0-3]):([0-5]\d)(?!\d)');
  static final _calendarDay = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static DateTime? _slotTime(String day, String label) {
    if (!_calendarDay.hasMatch(day)) return null;
    final clock = _clock.firstMatch(label);
    if (clock == null) return null;
    return DateTime.tryParse(
      '${day}T${clock[1]!.padLeft(2, '0')}:${clock[2]}:00+08:00',
    );
  }

  String _day(Object? value) {
    if (value is String && _calendarDay.hasMatch(value)) return value;
    final date = _instant(value);
    return date == null
        ? ''
        : BookingMedicationTask.dateKey(BookingMedicationTask.taipei(date));
  }

  String get stayStartDay => _day(booking['startDate']);
  String get stayEndDay => _day(booking['endDate']);

  List<BookingScheduleEntry> entries({required bool showMedication}) {
    final items = <BookingScheduleEntry>[];
    final firstDay = stayStartDay;
    final lastDay = stayEndDay;
    final arrivedAt = _instant(
      booking['actualStartAt'] ??
          booking['checkInAt'] ??
          booking['checkedInAt'],
    );
    final endedAt = _instant(
      booking['actualEndAt'] ??
          booking['checkOutAt'] ??
          booking['checkedOutAt'],
    );
    String actual(DateTime? value) =>
        value == null ? '' : '實際 ${BookingMedicationTask.timeLabel(value)}';

    if (daycare) {
      final start = _instant(booking['scheduledStartAt'] ?? booking['startAt']);
      final end = _instant(booking['scheduledEndAt'] ?? booking['endAt']);
      if (start != null) {
        items.add(
          BookingScheduleEntry(
            kind: BookingScheduleKind.arrival,
            time: start,
            title: '安親送達',
            completed: arrived,
            detail: actual(arrivedAt),
          ),
        );
      }
      if (end != null) {
        items.add(
          BookingScheduleEntry(
            kind: BookingScheduleKind.departure,
            time: end,
            title: '安親接回',
            completed: endedAt != null || (ended && status != 'cancelled'),
            detail: actual(endedAt),
          ),
        );
      }
    }

    final pets = {
      for (final pet in _maps(booking['pets']))
        '${pet['petId'] ?? pet['id'] ?? ''}':
            '${pet['name'] ?? pet['petName'] ?? ''}',
    };
    for (final addon in _maps(booking['addons'])) {
      final name = '${addon['name'] ?? addon['label'] ?? '分時服務'}';
      if (!daycare && addon['type'] == 'time') {
        final label = '${addon['label'] ?? name}';
        final departure = label.contains('退房') || name.contains('退房');
        final arrival = label.contains('入住') || name.contains('入住');
        if (!departure && !arrival) continue;
        final time = _slotTime(departure ? lastDay : firstDay, label);
        if (time == null) continue;
        items.add(
          BookingScheduleEntry(
            kind: departure
                ? BookingScheduleKind.departure
                : BookingScheduleKind.arrival,
            time: time,
            title: departure ? '住宿退房' : '住宿入住',
            slot: _slotLabel(label),
            completed: departure
                ? endedAt != null || (ended && status != 'cancelled')
                : arrived,
            detail: actual(departure ? endedAt : arrivedAt),
          ),
        );
      }
    }
    for (final task in BookingServiceTask.fromBooking(booking)) {
      items.add(
        BookingScheduleEntry(
          kind: BookingScheduleKind.service,
          time: task.scheduledAt,
          title: task.title,
          detail: task.pet,
          slot: task.slot,
          petIds: [task.petId],
          service: task,
          completed: !task.pending,
        ),
      );
    }

    if (showMedication) {
      items.addAll(_medicationRequests(pets));
      for (final task in BookingMedicationTask.fromBooking(booking)) {
        items.add(
          BookingScheduleEntry(
            kind: BookingScheduleKind.medication,
            time: task.scheduledAt,
            title: task.types,
            detail: task.pet,
            completed: !task.pending,
            medication: task,
            petIds: [if (task.petId.isNotEmpty) task.petId],
          ),
        );
      }
    }
    return items..sort((a, b) => a.time.compareTo(b.time));
  }

  Iterable<BookingScheduleEntry> _medicationRequests(
    Map<String, String> pets,
  ) sync* {
    final medication = booking['medication'];
    final state = medication is Map ? medication['state'] : null;
    if (state != null &&
        state != 'pending_shop' &&
        state != 'pending_customer') {
      return;
    }
    final status = state == 'pending_customer' ? '待飼主確認' : '尚未跟客戶核對';
    if (medication is Map) {
      final proposed = BookingMedicationTask.fromBooking({
        ...booking,
        'medication': {...medication, 'state': 'confirmed'},
      });
      if (proposed.isNotEmpty) {
        for (final task in proposed) {
          yield BookingScheduleEntry(
            kind: BookingScheduleKind.medication,
            time: task.scheduledAt,
            title: task.types,
            detail: task.pet,
            requestStatus: status,
            petIds: [if (task.petId.isNotEmpty) task.petId],
          );
        }
        return;
      }
    }
    final stored = medication is Map ? medication['request'] : null;
    final request = stored is Map ? stored : booking['medicationRequest'];
    if (request is! Map) return;
    final first = DateTime.tryParse(_day(booking['startDate']));
    final last = DateTime.tryParse(_day(booking['endDate']));
    final seen = <(String, String, String, DateTime)>{};
    for (final entry in _maps(request['preferences'])) {
      final petId = '${entry['petId'] ?? ''}';
      final name = pets[petId] ?? '寵物';
      final types = entry['types'];
      final labels = types is List
          ? types
                .map((type) => medicationTypes[type])
                .whereType<String>()
                .toSet()
                .join('、')
          : '';
      final title = labels.isEmpty ? '用藥協助' : labels;
      final dates = _maps(entry['dates']).toList();
      if (dates.isEmpty && first != null && last != null) {
        final start = DateTime.utc(first.year, first.month, first.day);
        final end = DateTime.utc(last.year, last.month, last.day);
        for (var offset = 0; offset < 181; offset++) {
          final day = start.add(Duration(days: offset));
          if (day.isAfter(end) || (day == end && offset > 0)) break;
          dates.add({
            'date': BookingMedicationTask.dateKey(day),
            'times': entry['times'],
          });
        }
      }
      for (final date in dates) {
        final times = date['times'];
        if (times is! List) continue;
        for (final label in times.whereType<String>()) {
          final time = _slotTime('${date['date'] ?? ''}', label);
          if (time == null ||
              !seen.add((petId, title, '${entry['name'] ?? ''}', time))) {
            continue;
          }
          yield BookingScheduleEntry(
            kind: BookingScheduleKind.medication,
            time: time,
            title: title,
            detail: name,
            requestStatus: status,
            petIds: [if (petId.isNotEmpty) petId],
          );
        }
      }
    }
  }

  static String _slotLabel(String label) => _clock
      .allMatches(label)
      .map((m) => '${m[1]!.padLeft(2, '0')}:${m[2]}')
      .join('–');
}

enum AdminBookingScheduleView { next, progress, timeline }

class AdminBookingSchedule extends StatefulWidget {
  const AdminBookingSchedule({
    super.key,
    required this.data,
    required this.entries,
    required this.view,
    this.onViewTimeline,
    this.initialDay,
    this.display = const BookingCareDisplay(),
    this.onViewFinance,
    this.onViewOrderConfirmation,
    this.onSelectTask,
    this.selectedTaskKey,
    this.minimumGridWidth = 900,
    this.showAllDays = false,
    this.onSelectDay,
  });

  final AdminBookingScheduleData data;
  final List<BookingScheduleEntry> entries;
  final AdminBookingScheduleView view;
  final VoidCallback? onViewTimeline;
  final String? initialDay;
  final BookingCareDisplay display;
  final VoidCallback? onViewFinance;
  final VoidCallback? onViewOrderConfirmation;
  final ValueChanged<BookingScheduleEntry>? onSelectTask;
  final String? selectedTaskKey;
  final double minimumGridWidth;
  final bool showAllDays;
  final ValueChanged<String>? onSelectDay;

  @override
  State<AdminBookingSchedule> createState() => _AdminBookingScheduleState();
}

class _AdminBookingScheduleState extends State<AdminBookingSchedule> {
  Timer? _clock;
  String? _selectedDay;
  (String, String)? _photoScope;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _photos;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _photoStream() {
    final id = PetShopFormAnswers.bookingUserId(widget.data.booking);
    final scope = (widget.data.shopId.trim(), id.trim());
    if (_photoScope != scope) {
      _photoScope = scope;
      _photos = scope.$1.isEmpty || scope.$2.isEmpty
          ? null
          : FirebaseFirestore.instance
                .collection('shops')
                .doc(scope.$1)
                .collection('members')
                .doc(scope.$2)
                .collection('pets')
                .snapshots();
    }
    return _photos;
  }

  String _groupKey(BookingScheduleEntry entry) {
    if (entry.petIds.length == 1) return 'pet:${entry.petIds.single}';
    if (entry.petIds.length > 1) return 'shared';
    if (entry.kind == BookingScheduleKind.medication) {
      return 'name:${entry.detail}';
    }
    return 'booking';
  }

  String _groupName(String group, BookingScheduleEntry entry) =>
      switch (group) {
        'booking' => '入住與服務',
        'shared' => '共同照護',
        _ => entry.detail.isEmpty ? '寵物' : entry.detail,
      };

  Widget _avatars(
    BookingScheduleEntry entry,
    Map<String, String> photos, {
    double size = 30,
  }) {
    if (!widget.display.showPhotos ||
        (entry.petIds.isEmpty &&
            entry.kind != BookingScheduleKind.medication)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Wrap(
        spacing: 3,
        children: [
          for (final id in (entry.petIds.isEmpty ? [''] : entry.petIds).take(2))
            if (photos[id]?.isNotEmpty == true)
              MemberAvatar(imageUrl: photos[id], name: entry.detail, size: size)
            else
              CircleAvatar(
                radius: size / 2,
                child: Icon(Icons.pets_outlined, size: size * .52),
              ),
        ],
      ),
    );
  }

  Map<String, String> _photoUrls(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> members,
  ) {
    String photo(Map data) {
      for (final key in ['photoUrl', 'imageUrl']) {
        final value = (data[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return {
      for (final doc in members)
        if (photo(doc.data()).isNotEmpty) doc.id: photo(doc.data()),
      for (final pet in AdminBookingScheduleData._maps(
        widget.data.booking['pets'],
      ))
        if (photo(pet).isNotEmpty)
          (pet['petId'] ?? pet['id'] ?? '').toString(): photo(pet),
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clock?.cancel();
    if (TickerMode.of(context)) {
      _clock = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _status(BookingScheduleEntry entry, DateTime now) {
    final task = entry.medication;
    if (entry.service?.petId.isEmpty == true) return '寵物資料待核對';
    if (entry.service case final service?) {
      if (!service.pending) return '已記錄・${service.resultLabel}';
    }
    if (entry.completed) {
      return task == null ? '已完成' : '已記錄・${task.resultLabel}';
    }
    if (widget.data.ended) {
      return widget.data.status == 'cancelled' ? '訂單已取消' : '訂單已結束';
    }
    if (entry.requestStatus case final status?) return status;
    if (widget.data.awaitingConfirmation) return '訂單待確認';
    if (entry.time.isAfter(now)) {
      final minutes = (entry.time.difference(now).inSeconds / 60).ceil();
      return minutes <= 15 ? '還有 $minutes 分鐘' : '待到點';
    }
    if (_servicePassed(entry, now)) return '預約時段已過';
    return task != null ? '已到點・${task.resultLabel}' : '已到預約時段';
  }

  bool _servicePassed(BookingScheduleEntry entry, DateTime now) {
    if (entry.service != null || entry.kind != BookingScheduleKind.service) {
      return false;
    }
    final clocks = entry.slot.split('–');
    final end = clocks.length > 1
        ? AdminBookingScheduleData._slotTime(entry.day, clocks.last)
        : null;
    if (end != null && end.isAfter(entry.time)) return !now.isBefore(end);
    return entry.day.compareTo(
          BookingMedicationTask.dateKey(BookingMedicationTask.taipei(now)),
        ) <
        0;
  }

  bool _canRecord(BookingScheduleEntry entry) =>
      widget.data.canEdit &&
      ((entry.medication?.pending == true &&
              BookingMedicationTask.canRecord(widget.data.booking)) ||
          (entry.service?.pending == true &&
              entry.service!.petId.isNotEmpty &&
              BookingServiceTask.canRecord(widget.data.booking)));

  bool _canReviewMedication(BookingScheduleEntry entry) =>
      entry.kind == BookingScheduleKind.medication &&
      entry.requestStatus != null &&
      widget.data.canEdit &&
      !widget.data.ended &&
      widget.data.booking['settlementLocked'] != true &&
      widget.data.booking['settlementConfirmed'] != true &&
      widget.data.booking['settledAt'] == null;

  Future<void> _reviewMedication(BookingScheduleEntry entry) async {
    final medication = widget.data.booking['medication'];
    if (!widget.data.daycare &&
        entry.requestStatus == '尚未跟客戶核對' &&
        medication is Map &&
        medication['request'] is Map) {
      openMedicationArrangement(
        context,
        bookingId: widget.data.bookingId,
        booking: widget.data.booking,
        onViewOrderConfirmation: widget.onViewOrderConfirmation,
      );
      return;
    }
    if (!await checkMedicationOrderConfirmation(
          context,
          widget.data.booking,
          onViewOrderConfirmation: widget.onViewOrderConfirmation,
        ) ||
        !mounted) {
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MedicationTaskPage.arrangement(
          shopId: widget.data.shopId,
          bookingId: widget.data.bookingId,
        ),
      ),
    );
  }

  void _openResult(BookingScheduleEntry entry) {
    final onSelectTask = widget.onSelectTask;
    if (onSelectTask != null) {
      _selectedDay = entry.day;
      onSelectTask(entry);
      return;
    }
    openCareReportResult(
      context,
      shopId: widget.data.shopId,
      bookingId: widget.data.bookingId,
      taskId: entry.medication?.id ?? entry.service!.id,
      medication: entry.medication != null,
      canManage: widget.data.canEdit,
    );
  }

  ({
    Color tone,
    Color ink,
    IconData icon,
    String status,
    bool successful,
    bool urgent,
  })
  _presentation(BookingScheduleEntry entry, DateTime now) {
    final colors = Theme.of(context).colorScheme;
    final status = _status(entry, now);
    final due =
        !entry.completed &&
        !widget.data.ended &&
        entry.requestStatus == null &&
        !widget.data.awaitingConfirmation &&
        !_servicePassed(entry, now) &&
        !entry.time.isAfter(now);
    final soon =
        !entry.completed &&
        !widget.data.ended &&
        entry.requestStatus == null &&
        !widget.data.awaitingConfirmation &&
        entry.time.isAfter(now) &&
        entry.time.difference(now) <= BookingMedicationTask.advanceNotice;
    final successful =
        entry.completed &&
        (entry.medication == null || entry.medication!.result == 'done') &&
        (entry.service == null || entry.service!.result == 'done');
    final requested = entry.requestStatus != null;
    final tone = requested
        ? const Color(0xFFF0EDFA)
        : due
        ? colors.errorContainer
        : soon
        ? const Color(0xFFFFE7C3)
        : successful
        ? const Color(0xFFE4F4E8)
        : colors.surfaceContainerLow;
    final ink = requested
        ? const Color(0xFF534176)
        : due
        ? colors.onErrorContainer
        : soon
        ? const Color(0xFF713B00)
        : successful
        ? const Color(0xFF285F3A)
        : colors.onSurfaceVariant;
    final icon = switch (entry.kind) {
      BookingScheduleKind.arrival => Icons.login,
      BookingScheduleKind.departure => Icons.logout,
      BookingScheduleKind.service => Icons.event_available_outlined,
      BookingScheduleKind.medication => Icons.medication_outlined,
    };
    return (
      tone: tone,
      ink: ink,
      icon: icon,
      status: status,
      successful: successful,
      urgent: due || soon,
    );
  }

  Widget _item(
    BookingScheduleEntry entry,
    DateTime now, {
    bool featured = false,
    Map<String, String> photos = const {},
  }) {
    final colors = Theme.of(context).colorScheme;
    final (:tone, :ink, :icon, :status, :successful, :urgent) = _presentation(
      entry,
      now,
    );
    final room = '${widget.data.booking['roomName'] ?? ''}'.trim();
    final details = [
      if (entry.service?.actualAt case final actual?)
        '實際 ${BookingMedicationTask.timeLabel(actual)}',
      if (entry.service?.record['note'] case final String note
          when note.isNotEmpty)
        note,
      if (featured) entry.day.replaceAll('-', '/'),
      if (entry.detail.isNotEmpty) entry.detail,
      if (featured && room.isNotEmpty) room,
      if (entry.medication?.actualAt case final actual?)
        '實際 ${BookingMedicationTask.timeLabel(actual)}',
    ].join(' · ');
    final action = _canRecord(entry)
        ? FilledButton(
            onPressed: () => _openResult(entry),
            child: const Text('填寫結果'),
          )
        : _canReviewMedication(entry)
        ? OutlinedButton(
            onPressed: () => _reviewMedication(entry),
            child: Text(entry.requestStatus == '待飼主確認' ? '查看待確認安排' : '到店核對用藥'),
          )
        : widget.onSelectTask != null && entry.taskKey != null
        ? OutlinedButton(
            onPressed: () => _openResult(entry),
            child: const Text('查看詳細'),
          )
        : featured && widget.onViewTimeline != null
        ? OutlinedButton(
            onPressed: widget.onViewTimeline,
            child: const Text('查看完整時程'),
          )
        : null;
    if (!featured) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tone,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ink.withValues(alpha: .18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.timeLabel.replaceAll('–', '–\n'),
                    style: TextStyle(color: ink, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    successful ? Icons.check_circle_outline : icon,
                    size: 18,
                    color: ink,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _avatars(entry, photos),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (details.isNotEmpty) Text(details),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (action != null) ...[const SizedBox(height: 6), action],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: urgent ? ink.withValues(alpha: .32) : colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                entry.completed ? Icons.check_circle_outline : icon,
                color: ink,
                size: 19,
              ),
              if (featured)
                Text(
                  entry.medication != null ? '下一項用藥' : '下一個預約時段',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              Text(
                status,
                style: TextStyle(color: ink, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${entry.timeLabel}  ${entry.title}',
            style: featured
                ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  )
                : Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
          ),
          if (details.isNotEmpty) Text(details, style: TextStyle(color: ink)),
          if (action != null) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ],
      ),
    );
  }

  Map<String, List<BookingScheduleEntry>> _group(
    List<BookingScheduleEntry> entries,
  ) {
    final groups = <String, List<BookingScheduleEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(_groupKey(entry), () => []).add(entry);
    }
    return groups;
  }

  Widget _groupHeading(
    String key,
    BookingScheduleEntry entry,
    Map<String, String> photos,
  ) => Row(
    children: [
      _avatars(entry, photos, size: 32),
      Expanded(
        child: Text(
          _groupName(key, entry),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );

  Widget _list(
    List<BookingScheduleEntry> entries,
    DateTime now,
    Map<String, String> photos,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final entry in entries)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _item(entry, now, photos: photos),
        ),
    ],
  );

  Widget _petGroups(
    List<BookingScheduleEntry> entries,
    DateTime now,
    Map<String, String> photos,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final group in _group(entries).entries)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _groupHeading(group.key, group.value.first, photos),
              _list(group.value, now, photos),
            ],
          ),
        ),
    ],
  );

  Widget _selectedInstructions(BookingScheduleEntry entry) {
    final taskId = entry.medication?.id;
    final medication = widget.data.booking['medication'];
    if (taskId == null || medication is! Map) return const SizedBox.shrink();
    final task = AdminBookingScheduleData._maps(
      medication['tasks'],
    ).where((item) => item['id'] == taskId).firstOrNull;
    final ids = task?['medicineIds'];
    final request = medication['request'];
    if (ids is! List || request is! Map) return const SizedBox.shrink();
    final medicines = AdminBookingScheduleData._maps(
      request['medicines'],
    ).where((item) => ids.contains(item['id'])).toList();
    if (medicines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('藥品與使用指示', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final medicine in medicines)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                [medicine['name'], medicine['dose']]
                    .whereType<String>()
                    .where((value) => value.trim().isNotEmpty)
                    .join(' · '),
              ),
              subtitle: Text((medicine['instruction'] ?? '').toString()),
            ),
        ],
      ),
    );
  }

  Widget _grid(
    List<BookingScheduleEntry> entries,
    DateTime now,
    Map<String, String> photos,
  ) {
    final colors = Theme.of(context).colorScheme;
    final times = entries
        .map((entry) => BookingMedicationTask.timeLabel(entry.time))
        .toSet();
    final groups = _group(entries);
    final minimumWidth = 145 + times.length * 138.0;
    return LayoutBuilder(
      builder: (context, constraints) => _ScheduleGridScroll(
        key: ValueKey(entries.first.day),
        overflows: minimumWidth > constraints.maxWidth,
        child: SizedBox(
          width: minimumWidth.clamp(constraints.maxWidth, double.infinity),
          child: Table(
            border: TableBorder.all(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            columnWidths: const {0: FixedColumnWidth(145)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: colors.surfaceContainerLow),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('寵物／服務'),
                  ),
                  for (final time in times)
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(time, textAlign: TextAlign.center),
                    ),
                ],
              ),
              for (final group in groups.entries)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: _groupHeading(
                        group.key,
                        group.value.first,
                        photos,
                      ),
                    ),
                    for (final time in times)
                      _gridCell(
                        group.value.where(
                          (entry) =>
                              BookingMedicationTask.timeLabel(entry.time) ==
                              time,
                        ),
                        now,
                        photos,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openGridEntry(
    BookingScheduleEntry entry,
    DateTime now,
    Map<String, String> photos,
  ) {
    if (_canReviewMedication(entry) && entry.requestStatus == '尚未跟客戶核對') {
      _reviewMedication(entry);
      return;
    }
    if (entry.medication != null || entry.service != null) {
      _openResult(entry);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(entry.title),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _item(entry, now, photos: photos),
              _selectedInstructions(entry),
            ],
          ),
        ),
        actions: [
          if (entry.kind == BookingScheduleKind.medication &&
              widget.onViewFinance != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onViewFinance!();
              },
              child: const Text('查看用藥費與結算'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _gridCell(
    Iterable<BookingScheduleEntry> entries,
    DateTime now,
    Map<String, String> photos,
  ) {
    if (entries.isEmpty) return const Center(child: Text('—'));
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  backgroundColor: _presentation(entry, now).tone,
                  foregroundColor: _presentation(entry, now).ink,
                  side:
                      widget.selectedTaskKey != null &&
                          widget.selectedTaskKey == entry.taskKey
                      ? BorderSide(color: colors.primary, width: 2)
                      : BorderSide(color: colors.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _openGridEntry(entry, now, photos),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _status(entry, now),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayContent(List<BookingScheduleEntry> entries, DateTime now) {
    Widget render(Map<String, String> photos) => LayoutBuilder(
      builder: (context, constraints) => switch (widget.display.layout) {
        BookingCareLayout.grid
            when constraints.maxWidth >= widget.minimumGridWidth =>
          _grid(entries, now, photos),
        BookingCareLayout.pets => _petGroups(entries, now, photos),
        _ => _list(entries, now, photos),
      },
    );
    if (!widget.display.showPhotos) return render(const {});
    final stream = _photoStream();
    if (stream == null) return render(_photoUrls(const []));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) =>
          render(_photoUrls(snapshot.data?.docs ?? const [])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = BookingMedicationTask.dateKey(
      BookingMedicationTask.taipei(now),
    );
    final entries = widget.entries;
    if (entries.isEmpty) return const SizedBox.shrink();
    switch (widget.view) {
      case AdminBookingScheduleView.next:
        if (widget.data.ended) return const SizedBox.shrink();
        final next = entries
            .where(
              (entry) =>
                  entry.requestStatus == null &&
                  !entry.completed &&
                  !_servicePassed(entry, now),
            )
            .firstOrNull;
        return next == null
            ? const SizedBox.shrink()
            : _item(next, now, featured: true);
      case AdminBookingScheduleView.progress:
        final requests = entries
            .where((entry) => entry.requestStatus != null)
            .toList();
        if (requests.isNotEmpty && !widget.data.ended) {
          final pets = requests.map((entry) => entry.detail).toSet();
          final days = requests.map((entry) => entry.day).toSet();
          final names = pets.join('、');
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EDFA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(
                      Icons.medication_outlined,
                      size: 20,
                      color: Color(0xFF534176),
                    ),
                    Text(
                      '用藥申請',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${requests.first.requestStatus} · ${requests.length} 個時段 · ${days.length} 天',
                ),
                if (names.isNotEmpty) Text(names),
                TextButton(
                  onPressed: widget.onViewTimeline,
                  child: const Text('查看用藥申請'),
                ),
              ],
            ),
          );
        }
        final tasks = entries
            .where((entry) => entry.medication != null && entry.day == today)
            .toList();
        if (tasks.isEmpty) return const SizedBox.shrink();
        final done = tasks.where((entry) => entry.completed).length;
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '今日用藥 · 已記錄 $done／${tasks.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: done / tasks.length),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onViewTimeline,
                  child: const Text('查看照護時程'),
                ),
              ],
            ),
          ),
        );
      case AdminBookingScheduleView.timeline:
        final days = entries.map((entry) => entry.day).toSet().toList();
        final defaultDay = days.firstWhere(
          (day) => day.compareTo(today) >= 0,
          orElse: () => days.last,
        );
        final preferredDay = _selectedDay ?? widget.initialDay;
        final day = days.contains(preferredDay) ? preferredDay! : defaultDay;
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  entries.any(
                        (entry) => entry.kind == BookingScheduleKind.medication,
                      )
                      ? '預約與用藥時程'
                      : '預約時程',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (!widget.showAllDays)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final date in days)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                '${date.substring(5).replaceAll('-', '/')}${date == today ? ' · 今日' : ''}',
                              ),
                              selected: date == day,
                              onSelected: (_) =>
                                  setState(() => _selectedDay = date),
                            ),
                          ),
                      ],
                    ),
                  ),
                for (final date in widget.showAllDays ? days : [day]) ...[
                  if (widget.showAllDays)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${date.replaceAll('-', '/')}${date == today ? ' · 今日' : ''}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (widget.onSelectDay case final selectDay?)
                            TextButton.icon(
                              onPressed: () => selectDay(date),
                              icon: const Icon(Icons.edit_note_outlined),
                              label: const Text('填寫當日紀錄'),
                            ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 4),
                  _dayContent(
                    entries.where((entry) => entry.day == date).toList(),
                    now,
                  ),
                ],
              ],
            ),
          ),
        );
    }
  }
}

class _ScheduleGridScroll extends StatefulWidget {
  const _ScheduleGridScroll({
    super.key,
    required this.overflows,
    required this.child,
  });

  final bool overflows;
  final Widget child;

  @override
  State<_ScheduleGridScroll> createState() => _ScheduleGridScrollState();
}

class _ScheduleGridScrollState extends State<_ScheduleGridScroll> {
  final _controller = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: behavior.copyWith(
        scrollbars: false,
        dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
      ),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: widget.overflows,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(bottom: widget.overflows ? 10 : 0),
          child: widget.child,
        ),
      ),
    );
  }
}

import '../admin/widgets/admin_booking_schedule.dart';
import '../admin/widgets/admin_booking_form_answers_section.dart';
import 'package:flutter/material.dart';
import '../../core/models/booking_kind.dart';
import '../../core/models/daily_care_setting_model.dart';
import '../../core/services/daily_care_setting_service.dart';
import '../admin/widgets/admin_daily_care_report_shortcut.dart';
import '../admin/widgets/order_care_progress_tables.dart';
import '../../core/models/daily_care_report_center_snapshot.dart';
import '../../core/services/daily_care_report_center_service.dart';
import '../room/daily_care_record_edit_launcher.dart';

import '../../core/models/booking_medication_task.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/shop_task_center_service.dart';
import 'medication_widgets.dart';
import 'service_task_page.dart';
import '../../core/models/booking_service_task.dart';
import '../../core/services/booking_settlement_math.dart';
import '../admin/widgets/admin_internal_handover_card.dart';

class MedicationTaskPage extends StatefulWidget {
  const MedicationTaskPage({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.taskId,
    this.scheduledAt = '',
    this.inlineResult = false,
    this.embedded = false,
    this.canManage = true,
  }) : recordDay = null;

  const MedicationTaskPage.orderRecords({
    super.key,
    required this.shopId,
    required this.bookingId,
    this.canManage = true,
    this.taskId,
    this.embedded = false,
    this.recordDay,
  }) : scheduledAt = '',
       inlineResult = true;

  const MedicationTaskPage.arrangement({
    super.key,
    required this.shopId,
    required this.bookingId,
  }) : recordDay = null,
       taskId = null,
       scheduledAt = '',
       inlineResult = false,
       canManage = true,
       embedded = false;

  final String shopId, bookingId, scheduledAt;
  final String? taskId, recordDay;
  final bool inlineResult, canManage, embedded;

  @override
  State<MedicationTaskPage> createState() => _MedicationTaskPageState();
}

class _MedicationTaskPageState extends State<MedicationTaskPage> {
  late final _access = ShopTaskCenterService.instance.loadAccess(widget.shopId);
  late final _booking = BookingService.instance.streamBooking(widget.bookingId);

  late String? _selectedTaskId = widget.inlineResult ? widget.taskId : null;
  bool _pendingOnly = false;
  bool? _medicationFilter;
  late final _reportSetting = DailyCareSettingService.instance.streamSetting(
    widget.shopId,
  );

  late final _reportProgress = DailyCareReportCenterService.instance
      .streamToday(shopId: widget.shopId, canOperate: widget.canManage);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : AppBar(
            title: Text(
              widget.inlineResult
                  ? '訂單回報與表單'
                  : widget.taskId == null
                  ? '用藥交接與安排'
                  : '填寫用藥結果',
            ),
          ),
    body: FutureBuilder<ShopTaskAccess>(
      future: _access,
      builder: (context, access) {
        if (access.hasError) return const Center(child: Text('無法驗證店家權限'));
        if (!access.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!access.data!.canViewBookings) {
          return const Center(child: Text('你沒有操作這筆用藥的權限'));
        }
        return StreamBuilder<Map<String, dynamic>?>(
          stream: _booking,
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('無法讀取這筆用藥'));
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final booking = snapshot.data;
            if (booking == null || booking['shopId'] != widget.shopId) {
              return const Center(child: Text('找不到這筆用藥'));
            }
            if (widget.inlineResult) {
              return _buildOrderRecords(context, booking);
            }
            if (widget.scheduledAt.isNotEmpty &&
                !BookingMedicationTask.fromBooking(booking).any(
                  (task) =>
                      task.id == widget.taskId &&
                      task.scheduledAt.isAtSameMomentAs(
                        DateTime.tryParse(widget.scheduledAt) ??
                            DateTime.utc(1970),
                      ),
                )) {
              return const Center(child: Text('這個用藥時段已變更，請回今日待辦查看'));
            }
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      if (widget.taskId == null)
                        AdminInternalHandoverCard(
                          shopId: widget.shopId,
                          bookingId: widget.bookingId,
                          compact: true,
                          readOnly: BookingSettlementMath.isSettlementLocked(
                            booking,
                          ),
                        ),
                      if (widget.taskId == null)
                        Card.outlined(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            leading: const Icon(Icons.calendar_month_outlined),
                            title: const Text(
                              '時程與費用',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: const Text('查看各貓咪的預約時段與用藥費'),
                            children: [
                              BookingMedicationPanel(
                                bookingId: widget.bookingId,
                                booking: booking,
                                staff: true,
                                arrangementLayout: true,
                              ),
                            ],
                          ),
                        )
                      else ...[
                        BookingMedicationPanel(
                          bookingId: widget.bookingId,
                          booking: booking,
                          staff: true,
                          taskId: widget.taskId,
                          canManage: widget.canManage,
                        ),
                        Card(
                          child: ExpansionTile(
                            title: const Text('查看用藥交接備註'),
                            children: [
                              AdminInternalHandoverCard(
                                shopId: widget.shopId,
                                bookingId: widget.bookingId,
                                compact: true,
                                readOnly: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );

  Widget _buildDailyReport(Map<String, dynamic> booking) {
    return StreamBuilder<DailyCareSettingModel>(
      stream: _reportSetting,
      builder: (context, snapshot) {
        final setting = snapshot.data;
        if (snapshot.hasError) {
          return const Center(child: Text('無法讀取每日回報設定'));
        }
        if (setting == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final daycare = BookingKind.isDaycare(booking);
        final enabled = daycare ? setting.daycareEnabled : setting.enabled;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!enabled)
              const Card.outlined(
                child: ListTile(
                  leading: Icon(Icons.assignment_outlined),
                  title: Text('店家尚未開啟每日回報'),
                ),
              )
            else if (!AdminDailyCareReportShortcut.shouldShow(
              booking,
              setting: setting,
            ))
              const Card.outlined(
                child: ListTile(
                  leading: Icon(Icons.assignment_outlined),
                  title: Text('本訂單目前沒有可填寫的每日回報'),
                ),
              )
            else
              StreamBuilder<DailyCareReportCenterSnapshot>(
                stream: _reportProgress,
                builder: (context, reports) {
                  if (reports.hasError || (reports.data?.hasError ?? false)) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('無法讀取回報進度，請稍後重試'),
                    );
                  }
                  if (!reports.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return OrderDailyCareProgressTable(
                    sessions: reports.data!.items
                        .where((item) => item.bookingId == widget.bookingId)
                        .toList(),
                    onSelect: (item) => DailyCareRecordEditLauncher.open(
                      context: context,
                      shopId: item.shopId,
                      bookingId: item.bookingId,
                      recordDate: item.recordDate,
                      sessionIndex: item.sessionIndex,
                      roomId: item.roomId,
                      roomName: item.roomName,
                      serviceType: item.serviceType,
                      petIds: item.petIds,
                      setting: setting,
                      entitlement: item.entitlement,
                      readOnly: item.reportsLocked,
                      asDialog: true,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildOrderRecords(
    BuildContext context,
    Map<String, dynamic> booking,
  ) {
    final tasks = BookingMedicationTask.fromBooking(booking);
    final services = BookingServiceTask.fromBooking(booking);
    final canRecord =
        widget.canManage && BookingMedicationTask.canRecord(booking);
    final canRecordService =
        widget.canManage && BookingServiceTask.canRecord(booking);
    void showAll(String key) {
      if (mounted && _selectedTaskId == key) {
        setState(() => _selectedTaskId = null);
      }
    }

    void recorded(String key) {
      if (!mounted) return;
      if (widget.recordDay != null) {
        Navigator.of(context).pop();
      } else {
        showAll(key);
      }
    }

    Widget detail(Widget child, String key) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showAll(key),
            icon: const Icon(Icons.close),
            label: const Text('關閉項目詳細'),
          ),
        ),
        Expanded(child: child),
      ],
    );

    Widget? selectedDetail;
    final selectedService = services
        .where((task) => 'service:${task.id}' == _selectedTaskId)
        .firstOrNull;
    if (selectedService != null) {
      final key = 'service:${selectedService.id}';
      selectedDetail = detail(
        ServiceTaskPage(
          key: ValueKey(key),
          shopId: widget.shopId,
          bookingId: widget.bookingId,
          taskId: selectedService.id,
          scheduledAt: selectedService.scheduledAt.toUtc().toIso8601String(),
          canManage: widget.canManage,
          onRecorded: () => recorded(key),
        ),
        key,
      );
    }

    final selected = tasks
        .where((task) => 'medication:${task.id}' == _selectedTaskId)
        .firstOrNull;
    if (selected != null) {
      final key = 'medication:${selected.id}';
      final panel = BookingMedicationPanel(
        key: ValueKey(selected.id),
        bookingId: widget.bookingId,
        booking: booking,
        staff: true,
        taskId: selected.id,
        canManage: widget.canManage,
        inlineTaskResult: true,
        onTaskRecorded: () => recorded(key),
      );
      selectedDetail = detail(
        canRecord
            ? panel
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: panel,
              ),
        key,
      );
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final room = '${booking['roomName'] ?? ''}'.trim();
    final customer = '${booking['customerName'] ?? ''}'.trim();
    final code = '${booking['bookingCode'] ?? ''}'.trim();
    final pending =
        tasks.where((task) => task.pending).length +
        services.where((task) => task.pending).length;
    final count = tasks.length + services.length;
    final medication = medMap(booking['medication']);
    final schedule = AdminBookingScheduleData(
      shopId: widget.shopId,
      bookingId: widget.bookingId,
      booking: booking,
      canEdit: widget.canManage,
    );
    final arrival = schedule.stayStartDay.replaceAll('-', '/');
    final departure = schedule.stayEndDay.replaceAll('-', '/');
    final visibleEntries = schedule.entries(showMedication: true).where((
      entry,
    ) {
      if (entry.taskKey == null) return false;
      final isMedication = entry.medication != null;
      final isPending = entry.medication?.pending ?? entry.service!.pending;
      return (!_pendingOnly || isPending) &&
          (_medicationFilter == null || _medicationFilter == isMedication);
    }).toList();

    final recordDay = widget.recordDay;
    final openInDialog = recordDay == null;

    void openDay(String day, {String? taskKey}) {
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: '關閉照護紀錄',
        transitionDuration: const Duration(milliseconds: 280),
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
        pageBuilder: (dialogContext, animation, secondaryAnimation) => Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              elevation: 16,
              color: Theme.of(dialogContext).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: 1000,
                height: MediaQuery.sizeOf(dialogContext).height * .9,
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 12, 16),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.edit_note_rounded),
                          ),
                          title: Text(
                            '${day.replaceAll('-', '/')} 照護紀錄',
                            style: Theme.of(dialogContext).textTheme.titleLarge,
                          ),
                          subtitle: const Text('核對時程、補填用藥資料與記錄執行結果'),
                          trailing: CloseButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: MedicationTaskPage.orderRecords(
                          shopId: widget.shopId,
                          bookingId: widget.bookingId,
                          canManage: widget.canManage,
                          taskId: taskKey,
                          embedded: true,
                          recordDay: day,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final entries = recordDay == null
        ? visibleEntries
        : visibleEntries.where((entry) => entry.day == recordDay).toList();
    final timeline = entries.isEmpty
        ? const Text('當日沒有可顯示的照護時程。')
        : AdminBookingSchedule(
            data: schedule,
            entries: entries,
            view: AdminBookingScheduleView.timeline,
            initialDay: recordDay ?? selected?.day ?? selectedService?.day,
            minimumGridWidth: 0,
            showAllDays: openInDialog,
            onSelectDay: openInDialog ? openDay : null,
            selectedTaskKey: openInDialog ? null : _selectedTaskId,
            onSelectTask: (entry) {
              if (openInDialog) {
                openDay(entry.day, taskKey: entry.taskKey);
              } else {
                setState(() => _selectedTaskId = entry.taskKey);
              }
            },
          );

    if (recordDay != null) {
      if (selectedDetail != null) return selectedDetail;
      return ListView(padding: const EdgeInsets.all(20), children: [timeline]);
    }

    return ListView(
      key: ValueKey('order-care-${widget.bookingId}'),
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width < 700 ? 12 : 24,
        20,
        MediaQuery.sizeOf(context).width < 700 ? 12 : 24,
        28,
      ),
      children: [
        Card.outlined(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: colors.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          code.isEmpty ? '訂單資訊' : code,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 24,
                  runSpacing: 14,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          room.isEmpty ? '尚未分房' : '房間 $room',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (customer.isNotEmpty)
                          Text(
                            '飼主 $customer',
                            style: theme.textTheme.bodyMedium,
                          ),
                        if (!schedule.daycare &&
                            (arrival.isNotEmpty || departure.isNotEmpty))
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              if (arrival.isNotEmpty) Text('入住 $arrival'),
                              if (departure.isNotEmpty) Text('退房 $departure'),
                            ],
                          ),
                      ],
                    ),
                    if (count > 0)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _OrderCareCount(
                            value: pending,
                            label: '待記錄',
                            emphasized: pending > 0,
                          ),
                          _OrderCareCount(value: count - pending, label: '已記錄'),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _sectionTitle(context, '照護待辦'),
        if (count > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('全部紀錄'),
                  selected: !_pendingOnly,
                  onSelected: (_) => setState(() => _pendingOnly = false),
                ),
                ChoiceChip(
                  label: Text('待處理 $pending'),
                  selected: _pendingOnly,
                  onSelected: (_) => setState(() => _pendingOnly = true),
                ),
              ],
            ),
          ),
        if (tasks.isNotEmpty && services.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              for (final (value, label) in <(bool?, String)>[
                (null, '所有類型'),
                (true, '用藥 ${tasks.length}'),
                (false, '預約服務 ${services.length}'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _medicationFilter == value,
                  onSelected: (_) => setState(() => _medicationFilter = value),
                ),
            ],
          ),
        if (count > 0 && visibleEntries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('目前篩選條件下沒有照護項目。'),
          ),
        if (!canRecord && !canRecordService && pending > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              booking['status'] == 'confirmed'
                  ? '辦理入住後，可在這裡填寫照護結果。'
                  : '目前可查看照護安排與紀錄。',
            ),
          ),
        if (tasks.isEmpty && medication.isNotEmpty)
          BookingMedicationPanel(
            bookingId: widget.bookingId,
            booking: booking,
            staff: true,
            canManage: widget.canManage,
            arrangementLayout: true,
          ),
        if (count == 0 && medication.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('這筆訂單目前沒有照護排程。'),
          ),
        if (visibleEntries.isNotEmpty)
          if (MediaQuery.sizeOf(context).width < 700)
            OrderCareScheduleProgressTable(
              entries: visibleEntries,
              onSelect: (entry) => openDay(entry.day, taskKey: entry.taskKey),
            )
          else
            timeline,
        const SizedBox(height: 20),
        _buildDailyReport(booking),
        AdminBookingFormAnswersSection(
          shopId: widget.shopId,
          bookingId: widget.bookingId,
          data: booking,
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _OrderCareCount extends StatelessWidget {
  const _OrderCareCount({
    required this.value,
    required this.label,
    this.emphasized = false,
  });

  final int value;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized
            ? colors.primaryContainer
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          '$value $label',
          style: theme.textTheme.labelLarge?.copyWith(
            color: emphasized
                ? colors.onPrimaryContainer
                : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

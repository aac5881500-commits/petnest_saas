import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_experience.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_overview_layout.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/shop/widgets/booking/policy_sign_method_field.dart';
// 店主單筆訂單工作區：依工作切換資料，保留已開啟分頁的編輯與捲動狀態。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'admin_booking_medication_fees.dart';
import 'admin_booking_schedule.dart';
import 'admin_internal_handover_card.dart';
import 'booking_care_display.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/services/daycare_payment_display.dart';

class AdminBookingWorkspaceContent {
  const AdminBookingWorkspaceContent({
    this.summary = const <Widget>[],
    this.care = const <Widget>[],
    this.charges = const <Widget>[],
    this.details = const <Widget>[],
    this.activity = const <Widget>[],
    this.preferenceScope = '',
    this.alerts = const [],
    this.balance,
    this.pets,
    this.carePreview,
    this.schedule,
    this.medicationDetails,
    this.careReport,
    this.initialSection = 0,
    this.contacts,
  });
  final List<Widget> summary, care, charges, details, activity;
  final Widget? balance, pets, carePreview, contacts;
  final String preferenceScope;
  final int initialSection;
  final List<String> alerts;
  final AdminBookingScheduleData? schedule;
  final Widget? medicationDetails, careReport;
}

class AdminBookingOrderWorkspace extends StatefulWidget {
  const AdminBookingOrderWorkspace({
    super.key,
    required this.content,
    required this.overview,
    required this.banners,
    required this.finance,
    required this.documents,
    required this.activity,
    this.actions,
    this.nextAction,
    this.handoverHasContent = false,
  });
  final AdminBookingWorkspaceContent content;
  final Widget overview;
  final List<Widget> banners, finance, documents, activity;
  final Widget? actions, nextAction;
  final bool handoverHasContent;

  @override
  State<AdminBookingOrderWorkspace> createState() =>
      AdminBookingOrderWorkspaceState();
}

class AdminBookingOrderWorkspaceState
    extends State<AdminBookingOrderWorkspace> {
  final GlobalKey<AdminBookingDetailExperienceState> _experienceKey =
      GlobalKey<AdminBookingDetailExperienceState>();
  void select(int index) => _experienceKey.currentState?.select(index);
  void showDocuments() => select(3);

  Stream<Map<String, dynamic>?>? _shopStream;
  String? _scheduleShopId;

  @override
  Widget build(BuildContext context) {
    final shopId = widget.content.schedule?.shopId;
    if (_scheduleShopId != shopId) {
      _scheduleShopId = shopId;
      _shopStream = shopId == null || shopId.isEmpty
          ? null
          : ShopService.instance.streamShop(shopId);
    }
    return StreamBuilder<Map<String, dynamic>?>(
      key: ValueKey(shopId),
      stream: _shopStream,
      builder: (context, snapshot) =>
          _workspace(context, snapshot.hasError ? null : snapshot.data),
    );
  }

  Widget _workspace(BuildContext context, Map<String, dynamic>? shop) {
    final schedule = widget.content.schedule;
    final medicationOn = schedule?.hasMedication == true;
    final entries =
        schedule?.entries(showMedication: medicationOn) ??
        const <BookingScheduleEntry>[];
    final requests = entries
        .where((entry) => entry.requestStatus != null)
        .toList();
    final timeline = entries
        .where((entry) => entry.requestStatus == null)
        .toList();
    Widget scheduleView(
      AdminBookingScheduleView view,
      BookingCareDisplay display,
    ) => AdminBookingSchedule(
      display: display,
      onViewFinance: () => select(2),
      data: schedule!,
      entries: timeline,
      view: view,
      onViewTimeline: () => select(1),
    );
    final brand = ShopFrontendTheme.of(context);
    final theme = ShopFrontendTheme(
      home: brand.home,
      primaryColor: brand.primaryColor,
      secondaryColor: brand.secondaryColor,
      pageBackgroundColor: const Color(0xFFF4F5F7),
      cardColor: Colors.white,
      titleColor: const Color(0xFF273349),
      bodyTextColor: const Color(0xFF39465B),
      subtitleColor: const Color(0xFF778091),
      borderColor: const Color(0xFFE4E7EE),
      buttonColor: brand.buttonColor,
      onPrimaryColor: brand.onPrimaryColor,
      primarySoft: Color.alphaBlend(
        brand.primaryColor.withValues(alpha: 0.10),
        Colors.white,
      ),
      disabledColor: brand.disabledColor,
    );
    return ShopFrontendThemeInherited(
      theme: theme,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: const Color(0xFFE7E9EF),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE7E9EF)),
            ),
          ),
        ),
        child: ColoredBox(
          color: const Color(0xFFF4F5F7),
          child: AdminBookingDetailExperience(
            key: _experienceKey,
            scope: widget.content.preferenceScope,
            initialSection: widget.content.initialSection,
            alerts: [
              ...widget.content.alerts,
              if (widget.content.carePreview != null) '有用藥／照護資料',
              if (widget.handoverHasContent) '有交接提醒',
            ],
            hasCareDisplay: schedule != null,
            workflow: schedule != null,
            worksheetPrimarySection: schedule?.ended == true
                ? 2
                : schedule?.arrived == true ? 1 : 0,
            worksheetHeader: schedule == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _spaced([
                      ...widget.banners,
                      widget.overview,
                      if (schedule.arrived && !schedule.ended && timeline.isNotEmpty)
                        scheduleView(AdminBookingScheduleView.next, const BookingCareDisplay()),
                    ]),
                  ),
            sectionBuilder: (index, experience, display) {
              if (index == 0) {
                return _overviewLayout(
                  theme,
                  experience,
                  featured: timeline.isEmpty || schedule!.arrived || schedule.ended
                      ? null
                      : scheduleView(AdminBookingScheduleView.next, display),
                  progress: requests.isEmpty
                      ? null
                      : _surface(
                          theme,
                          title: '用藥需求待確認',
                          icon: Icons.medication_outlined,
                          action: '查看照護',
                          onTap: () => select(1),
                          child: const Text('可先在照護分頁留下店內速記。'),
                        ),
                );
              }
              final hasMedicationFees =
                  schedule != null &&
                  AdminBookingMedicationFees.hasFeeData(schedule.booking);
              final panels = <int, List<Widget>>{
                1: [
                  if (schedule != null)
                    _BookingCareDesk(
                      key: ValueKey(schedule.bookingId),
                      entries: timeline,
                      pending: requests.isNotEmpty,
                      timeline: (items) => AdminBookingSchedule(
                        display: display,
                        data: schedule,
                        entries: items,
                        view: AdminBookingScheduleView.timeline,
                        onViewFinance: () => select(2),
                        onViewTimeline: () => select(1),
                      ),
                      medicine: medicationOn ? widget.content.medicationDetails : null,
                      note: schedule.canEdit && schedule.shopId.isNotEmpty
                          ? AdminInternalHandoverCard(
                              shopId: schedule.shopId,
                              bookingId: schedule.bookingId,
                              readOnly: BookingSettlementMath.isSettlementLocked(schedule.booking),
                              compact: true,
                            )
                          : null,
                      report: schedule.reportsEnabled(shop) ? widget.content.careReport : null,
                    ),
                  ...widget.content.care,
                ],
                2: [
                  if (widget.nextAction != null) widget.nextAction!,
                  ...widget.finance,
                  if (hasMedicationFees)
                    AdminBookingMedicationFees(
                      booking: schedule.booking,
                      inFinance: true,
                      canEdit: schedule.canEdit,
                      shopId: schedule.shopId,
                      bookingId: schedule.bookingId,
                    ),
                  ...widget.content.charges,
                ],
                3: [...widget.content.details, ...widget.documents],
                4: [...widget.activity, ...widget.content.activity],
              };
              final children = panels[index]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children.isEmpty
                    ? [const Text('目前沒有資料')]
                    : _spaced(children),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _overviewLayout(
    ShopFrontendTheme theme,
    BookingDetailExperience experience, {
    Widget? featured,
    Widget? progress,
  }) {
    final blocks = <String, Widget>{
      if (widget.content.schedule == null) 'overview': Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _spaced([...widget.banners, widget.overview, if (widget.content.schedule == null) ?featured]),
      ),
      'actions': _surface(
        theme,
        title: '入住與訂單操作',
        icon: Icons.task_alt,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _spaced([
            if (widget.nextAction != null) widget.nextAction!,
            if (widget.actions != null) widget.actions!,
            if (widget.nextAction == null && widget.actions == null)
              const Text('目前沒有待執行操作'),
          ]),
        ),
      ),
      if (widget.content.balance != null) 'balance': _balanceLink(theme),
      if (widget.content.pets != null)
        'pets': _surface(
          theme,
          title: '入住寵物',
          subtitle: '健康提醒與寵物資料',
          icon: Icons.pets_outlined,
          child: widget.content.pets!,
        ),
      'progress': ?progress,
      'next': ?featured,
      if (widget.content.carePreview != null && widget.content.schedule == null)
        'care': _surface(
          theme,
          title: '照護待辦',
          icon: Icons.medication_outlined,
          action: '前往處理',
          onTap: () => select(1),
          child: widget.content.carePreview!,
        ),
      if (widget.content.contacts != null)
        'contacts': _surface(
          theme,
          title: '快速聯絡',
          icon: Icons.call_outlined,
          child: widget.content.contacts!,
        ),
      if (widget.content.summary.isNotEmpty)
        'summary': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _spaced(widget.content.summary),
        ),
      if (widget.content.schedule == null) 'resources': _surface(
        theme,
        title: '完整訂單資料',
        icon: Icons.folder_open_outlined,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => select(2),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('帳務與費用'),
            ),
            OutlinedButton.icon(
              onPressed: () => select(3),
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('資料與表單'),
            ),
            OutlinedButton.icon(
              onPressed: () => select(4),
              icon: const Icon(Icons.history),
              label: Text(widget.handoverHasContent ? '紀錄・有交接提醒' : '進度與交接'),
            ),
          ],
        ),
      ),
    };
    return AdminBookingOverviewLayout(
      operations: widget.content.schedule != null,
      layout: switch (experience) {
        BookingDetailExperience.single => BookingOverviewLayout.bands,
        BookingDetailExperience.dual => BookingOverviewLayout.split,
        BookingDetailExperience.tabs => BookingOverviewLayout.split,
        BookingDetailExperience.master => BookingOverviewLayout.pets,
        BookingDetailExperience.stages => BookingOverviewLayout.columns,
      },
      blocks: blocks,
    );
  }

  Widget _surface(
    ShopFrontendTheme theme, {
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
    String? action,
    VoidCallback? onTap,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE7E9EF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: theme.primaryColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF273349),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF778091),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null)
              TextButton(onPressed: onTap, child: Text(action)),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );

  Widget _balanceLink(ShopFrontendTheme theme) => _surface(
    theme,
    title: '收款摘要',
    icon: Icons.account_balance_wallet_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.content.balance!,
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => select(2),
          icon: const Icon(Icons.receipt_long_outlined, size: 17),
          label: const Text('查看費用與交易'),
        ),
      ],
    ),
  );

  List<Widget> _spaced(List<Widget> items) => [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) const SizedBox(height: 16),
      items[i],
    ],
  ];
}

/// 只沿用金流服務提供的金額，不在 UI 重算帳務。
enum _CareArea { schedule, medicine, report }

class _BookingCareDesk extends StatefulWidget {
  const _BookingCareDesk({
    super.key,
    required this.entries,
    required this.pending,
    required this.timeline,
    this.medicine,
    this.note,
    this.report,
  });

  final List<BookingScheduleEntry> entries;
  final bool pending;
  final Widget Function(List<BookingScheduleEntry>) timeline;
  final Widget? medicine, note, report;

  @override
  State<_BookingCareDesk> createState() => _BookingCareDeskState();
}

class _BookingCareDeskState extends State<_BookingCareDesk> {
  _CareArea _area = _CareArea.schedule;
  final _visited = <_CareArea>{_CareArea.schedule};
  String? _day;
  bool _allDays = false;

  @override
  Widget build(BuildContext context) {
    final days = widget.entries.map((entry) => entry.day).toSet().toList()..sort();
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final today = now.toIso8601String().substring(0, 10);
    final defaultDay = days.firstWhere((day) => day.compareTo(today) >= 0,
        orElse: () => days.lastOrNull ?? '');
    final day = days.contains(_day) ? _day : defaultDay;
    final entries = _allDays ? widget.entries : widget.entries.where((entry) => entry.day == day).toList();
    final colors = Theme.of(context).colorScheme;
    final areas = {
      _CareArea.schedule: ('照護時程', Icons.event_note_outlined),
      if (widget.medicine != null || widget.note != null)
        _CareArea.medicine: ('用藥', Icons.medication_outlined),
      if (widget.report != null)
        _CareArea.report: ('回報', Icons.assignment_outlined),
    };
    final active = areas.containsKey(_area) ? _area : _CareArea.schedule;

    Widget areaBody(_CareArea area) => switch (area) {
      _CareArea.schedule => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          if (days.length > 1)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('全部日期'),
                  selected: _allDays,
                  onSelected: (_) => setState(() => _allDays = true),
                ),
                for (final date in days)
                  ChoiceChip(
                    label: Text(date == today ? '今天' : date.substring(5).replaceAll('-', '/')),
                    selected: !_allDays && date == day,
                    onSelected: (_) => setState(() { _day = date; _allDays = false; }),
                  ),
              ],
            ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('目前沒有已安排的照護時程。'),
            )
          else
            widget.timeline(entries),
        ],
      ),
      _CareArea.medicine => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          if (widget.note != null) widget.note!,
          if (widget.medicine != null) widget.medicine!,
        ],
      ),
      _CareArea.report => widget.report ?? const SizedBox.shrink(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text('入住照護', style: Theme.of(context).textTheme.titleLarge),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final item in areas.entries)
                      ChoiceChip(
                        avatar: Icon(item.value.$2, size: 17),
                        label: Text(item.value.$1),
                        selected: active == item.key,
                        onSelected: (_) => setState(() { _area = item.key; _visited.add(item.key); }),
                      ),
                  ],
                ),
                if (widget.pending && active == _CareArea.schedule)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _area = _CareArea.medicine;
                      _visited.add(_area);
                    }),
                    icon: Icon(Icons.info_outline, color: colors.primary, size: 18),
                    label: const Text('有用藥需求待確認'),
                  ),
              ],
            ),
          ),
        ),
        for (final area in areas.keys)
          if (_visited.contains(area))
            Offstage(
              key: ValueKey(area),
              offstage: area != active,
              child: TickerMode(enabled: area == active, child: areaBody(area)),
            ),
      ],
    );
  }
}

class AdminBookingWorkspaceBalance extends StatelessWidget {
  const AdminBookingWorkspaceBalance({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final int refund = BookingSettlementMath.refundDue(data: data);
    final int due = BookingPaymentStatus.resolveDueNow(data);
    final int medicationEstimate =
        BookingSettlementMath.pendingMedicationEstimate(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          refund > 0 ? '待退款' : '本次應收',
          style: TextStyle(fontSize: 12, color: theme.muted),
        ),
        const SizedBox(height: 6),
        Text(
          'NT\$ ${refund > 0 ? refund : due}',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: refund > 0 ? Colors.red.shade700 : theme.titleColor,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ),
        if (medicationEstimate > 0)
          _row('用藥預估（退房結算）', medicationEstimate, theme.muted),
        _row(
          medicationEstimate > 0 ? '預估總額（含用藥）' : '訂單總額',
          BookingSettlementMath.orderDisplayTotal(
            data,
            DaycarePaymentDisplay.resolveTotal(data),
          ),
          theme.titleColor,
        ),
        _row('已收款', BookingPaymentStatus.resolvePaid(data), theme.muted),
      ],
    );
  }

  Widget _row(String label, int amount, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(
          'NT\$ $amount',
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class AdminBookingWorkspaceOrigin extends StatelessWidget {
  const AdminBookingWorkspaceOrigin({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final DateTime? created = SafeParse.parseDate(data['createdAt']);
    final String source = (data['source'] ?? '').toString().trim();
    final String sign = (data['policySignMethod'] ?? '').toString().trim();
    final List<String> lines = <String>[
      '建立時間：${created == null ? '未記錄' : '${created.year}-${created.month}-${created.day} ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}'}',
      '訂單來源：${source == 'admin' ? '店家代建' : (source == 'app' ? '客戶預約' : (source.isEmpty ? '未記錄' : source))}',
      if (source == 'admin')
        '建立人：${(data['createdByEmail'] ?? '').toString().trim().isEmpty ? '未記錄' : data['createdByEmail']}',
      if (sign.isNotEmpty) '條款確認：${PolicySignMethods.label(sign)}',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '訂單建立資訊',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: theme.titleColor,
            ),
          ),
          const SizedBox(height: 8),
          for (final String line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

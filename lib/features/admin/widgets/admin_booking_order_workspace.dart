import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/inventory_binding_model.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_explanations.dart';
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
                : schedule?.arrived == true
                ? 1
                : 0,
            worksheetHeader: schedule == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _spaced([
                      ...widget.banners,
                      widget.overview,
                      if (schedule.arrived &&
                          !schedule.ended &&
                          timeline.isNotEmpty)
                        scheduleView(
                          AdminBookingScheduleView.next,
                          const BookingCareDisplay(),
                        ),
                    ]),
                  ),
            sectionBuilder: (index, experience, display) {
              if (index == 0) {
                return _overviewLayout(
                  theme,
                  experience,
                  featured:
                      timeline.isEmpty || schedule!.arrived || schedule.ended
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
                      booking: schedule.daycare ? null : schedule.booking,
                      shopId: schedule.shopId,
                      bookingId: schedule.bookingId,
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
                      medicine: medicationOn
                          ? widget.content.medicationDetails
                          : null,
                      note: schedule.canEdit && schedule.shopId.isNotEmpty
                          ? AdminInternalHandoverCard(
                              shopId: schedule.shopId,
                              bookingId: schedule.bookingId,
                              readOnly:
                                  BookingSettlementMath.isSettlementLocked(
                                    schedule.booking,
                                  ),
                              compact: true,
                            )
                          : null,
                      report: schedule.reportsEnabled(shop)
                          ? widget.content.careReport
                          : null,
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
      if (widget.content.schedule == null)
        'overview': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _spaced([
            ...widget.banners,
            widget.overview,
            if (widget.content.schedule == null) ?featured,
          ]),
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
      if (widget.content.schedule == null)
        'resources': _surface(
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
enum _CareArea { schedule, time, value, custom, timed, other, medicine, report }

class _BookingCareAddons extends StatelessWidget {
  const _BookingCareAddons({required this.items, required this.pets});

  final List<Map<String, dynamic>> items, pets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        for (final item in items)
          Card.outlined(
            margin: EdgeInsets.zero,
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _details(context, item, theme),
            ),
          ),
      ],
    );
  }

  Widget _details(
    BuildContext context,
    Map<String, dynamic> item,
    ThemeData theme,
  ) {
    final name = SafeParse.parseString(item['name'] ?? item['label']).trim();
    final count = SafeParse.parseMoney(item['count'] ?? item['quantity'] ?? 1);
    final price = SafeParse.parseMoney(item['price']);
    final recordedAmount = item['total'] ?? item['amount'];
    final amount = recordedAmount == null
        ? price * count
        : SafeParse.parseMoney(recordedAmount);
    final details = addonExplanation(
      item,
      pets,
      schedules: true,
      includePetSchedule: false,
    );
    final schedules = addonPetSchedules(item, pets);
    final bindings = InventoryBindingModel.listFromValue(
      item['inventoryBindings'],
    );
    final description = SafeParse.parseString(
      item['description'] ?? item['desc'],
    ).trim();
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: const Icon(Icons.card_giftcard_outlined, size: 20),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    name.isEmpty ? '未記載品名的加購' : name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (recordedAmount != null || item['price'] != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          amount == 0 ? '免費' : 'NT\$ $amount',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (description.isNotEmpty) Text(description),
              if (SafeParse.parseMoney(item['extraReports']) > 0)
                Text(
                  '每服務日加購 ${SafeParse.parseMoney(item['extraReports'])} 場回報',
                ),
              if (SafeParse.parseList(item['serviceDates']).isNotEmpty)
                Text(
                  '服務日期：${SafeParse.parseList(item['serviceDates']).join('、')}',
                ),
              if (details.isNotEmpty)
                Text(details, style: const TextStyle(height: 1.5)),
              for (final schedule in schedules) ...[
                Text(
                  schedule.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final time in schedule.times) Text(time),
              ],
              if (bindings.isNotEmpty || item['useInventory'] == true) ...[
                const Divider(),
                const Text(
                  '庫存用料（訂單記錄）',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (bindings.isEmpty) const Text('這筆訂單未保存庫存品項明細。'),
                for (final binding in bindings)
                  Text(
                    '${binding.inventoryItemName.trim().isEmpty ? '品項 ${binding.inventoryItemId}' : binding.inventoryItemName}'
                    ' · 每份 ${binding.quantityPerUnit} ${binding.unit}'
                    '${count > 1 ? '，共 ${binding.quantityPerUnit * count} ${binding.unit}' : ''}',
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingCareDesk extends StatefulWidget {
  const _BookingCareDesk({
    super.key,
    required this.entries,
    required this.pending,
    required this.timeline,
    this.booking,
    required this.shopId,
    required this.bookingId,
    this.medicine,
    this.note,
    this.report,
  });

  final List<BookingScheduleEntry> entries;
  final bool pending;
  final Map<String, dynamic>? booking;
  final String shopId, bookingId;
  final Widget Function(List<BookingScheduleEntry>) timeline;
  final Widget? medicine, note, report;

  @override
  State<_BookingCareDesk> createState() => _BookingCareDeskState();
}

class _BookingCareDeskState extends State<_BookingCareDesk> {
  late final _inventory = widget.booking == null || widget.shopId.isEmpty
      ? null
      : FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection(InventoryConstants.consumptionsCollection)
            .doc(InventoryConstants.bookingAddonDeductId(widget.bookingId))
            .snapshots();

  _CareArea _area = _CareArea.schedule;
  final _visited = <_CareArea>{_CareArea.schedule};
  String? _day;
  bool _allDays = false;

  @override
  Widget build(BuildContext context) {
    final days = widget.entries.map((entry) => entry.day).toSet().toList()
      ..sort();
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final today = now.toIso8601String().substring(0, 10);
    final defaultDay = days.firstWhere(
      (day) => day.compareTo(today) >= 0,
      orElse: () => days.lastOrNull ?? '',
    );
    final day = days.contains(_day) ? _day : defaultDay;
    final entries = _allDays
        ? widget.entries
        : widget.entries.where((entry) => entry.day == day).toList();
    final colors = Theme.of(context).colorScheme;
    final addonGroups = <_CareArea, List<Map<String, dynamic>>>{};
    final addons = SafeParse.parseMapList(widget.booking?['addons']).toList();
    if (!addons.any(
      (item) => const {'daily_care', 'dailyCare'}.contains(item['type']),
    )) {
      final entitlement = DailyCareEntitlement.fromMap(
        SafeParse.parseMap(widget.booking?['dailyCareEntitlement']),
      );
      final line = entitlement.toAddonLine();
      if (line != null) addons.add(line);
    }
    for (final item in addons) {
      final group = switch (item['type']) {
        'time' || 'time_addon' => _CareArea.time,
        'value' => _CareArea.value,
        'custom' => _CareArea.custom,
        'daily_timed' => _CareArea.timed,
        _ => _CareArea.other,
      };
      addonGroups.putIfAbsent(group, () => []).add(item);
    }
    final areas = {
      _CareArea.schedule: ('照護時程', Icons.event_note_outlined),
      if (addonGroups.containsKey(_CareArea.time))
        _CareArea.time: ('入退房時間', Icons.schedule_outlined),
      if (addonGroups.containsKey(_CareArea.value))
        _CareArea.value: ('加值服務', Icons.add_circle_outline),
      if (addonGroups.containsKey(_CareArea.custom))
        _CareArea.custom: ('客製服務', Icons.pets_outlined),
      if (addonGroups.containsKey(_CareArea.timed))
        _CareArea.timed: ('每日分時段', Icons.event_available_outlined),
      if (addonGroups.containsKey(_CareArea.other))
        _CareArea.other: ('其他加購', Icons.receipt_long_outlined),
      if (widget.medicine != null ||
          (widget.booking == null && widget.note != null))
        _CareArea.medicine: ('用藥協助', Icons.medication_outlined),
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
                    label: Text(
                      date == today
                          ? '今天'
                          : date.substring(5).replaceAll('-', '/'),
                    ),
                    selected: !_allDays && date == day,
                    onSelected: (_) => setState(() {
                      _day = date;
                      _allDays = false;
                    }),
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
          if (widget.note != null)
            Card.outlined(
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('店內用藥交接備註'),
                subtitle: const Text('僅店內人員可見，可記錄藥名、用量與照護注意事項'),
                children: [widget.note!],
              ),
            ),
          if (widget.medicine != null) widget.medicine!,
        ],
      ),
      _CareArea.report => widget.report ?? const SizedBox.shrink(),
      _ => _BookingCareAddons(
        items: addonGroups[area] ?? const [],
        pets: SafeParse.parseMapList(widget.booking?['pets']),
      ),
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
                        onSelected: (_) => setState(() {
                          _area = item.key;
                          _visited.add(item.key);
                        }),
                      ),
                  ],
                ),
                if (widget.pending && active == _CareArea.schedule)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _area = _CareArea.medicine;
                      _visited.add(_area);
                    }),
                    icon: Icon(
                      Icons.info_outline,
                      color: colors.primary,
                      size: 18,
                    ),
                    label: const Text('有用藥需求待確認'),
                  ),
              ],
            ),
          ),
        ),
        if (addonGroups.containsKey(active) && _inventory != null)
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _inventory,
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text('目前無法確認本單庫存扣除紀錄。');
              final record = snapshot.data?.data();
              final lines = SafeParse.parseMapList(record?['lines']);
              if (record?['status'] != 'completed' || lines.isEmpty) {
                return const SizedBox.shrink();
              }
              return Card.outlined(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Text(
                        '本單加購庫存扣除紀錄',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text('以下為整筆訂單的扣除紀錄。'),
                      for (final line in lines)
                        Text(
                          '${line['itemName'] ?? line['inventoryItemId'] ?? '庫存品項'} · ${line['quantity']} ${line['unit'] ?? ''}',
                        ),
                    ],
                  ),
                ),
              );
            },
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

// 檔案名稱：lib/core/widgets/shop_task_center_panel.dart
// 功能說明：今日待辦列表（Panel / BottomSheet / 全頁共用）

import 'package:flutter/material.dart';

import '../models/daily_care_entitlement.dart';
import '../models/daily_care_record_model.dart';
import '../models/daily_care_setting_model.dart';
import '../models/shop_task_item.dart';
import '../services/daily_care_setting_service.dart';
import '../services/shop_task_center_service.dart';
import 'package:petnest_saas/core/navigation/admin_booking_route.dart';
import '../../features/room/daily_care_record_edit_launcher.dart';
import '../../features/medication/medication_task_page.dart';
import '../../features/medication/service_task_page.dart';

class ShopTaskCenterPanel extends StatefulWidget {
  const ShopTaskCenterPanel({
    super.key,
    required this.shopId,
    required this.canViewBookings,
    required this.canFillDailyCare,
    this.canManageDevices = false,
    this.showViewAll = true,
    this.closeBeforeOpen = true,
    this.careOnly = false,
    this.onViewAll,
    this.onOpenCamera,
    this.onOpenOrder,
  });

  final String shopId;
  final bool canViewBookings;
  final bool canFillDailyCare;
  final bool canManageDevices;
  final bool careOnly;
  final bool showViewAll;
  final bool closeBeforeOpen;
  final VoidCallback? onViewAll;
  final void Function(ShopTaskItem item)? onOpenCamera;
  final ValueChanged<ShopTaskItem>? onOpenOrder;

  @override
  State<ShopTaskCenterPanel> createState() => _ShopTaskCenterPanelState();
}

class _ShopTaskCenterPanelState extends State<ShopTaskCenterPanel> {
  ShopTaskCenterBinding? _binding;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(ShopTaskCenterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId ||
        oldWidget.canViewBookings != widget.canViewBookings ||
        oldWidget.canFillDailyCare != widget.canFillDailyCare ||
        oldWidget.canManageDevices != widget.canManageDevices) {
      _binding?.close();
      _open();
    }
  }

  void _open() {
    _binding = ShopTaskCenterService.instance.openBinding(
      shopId: widget.shopId,
      canViewBookings: widget.canViewBookings,
      canFillDailyCare: widget.canFillDailyCare,
      canManageDevices: widget.canManageDevices,
    );
  }

  @override
  void dispose() {
    _binding?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShopTaskCenterBinding? binding = _binding;
    if (binding == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return StreamBuilder<ShopTaskCenterSnapshot>(
      stream: binding.snapshots,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _laneMessage(
            '目前無法取得待辦事項，請稍後再試。',
            onRetry: () {
              binding.close();
              setState(_open);
            },
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ShopTaskCenterContent(
          snapshot: snapshot.data!,
          careOnly: widget.careOnly,
          onRetryServices: binding.retryServices,
          showViewAll: widget.showViewAll,
          closeBeforeOpen: widget.closeBeforeOpen,
          onViewAll: widget.onViewAll,
          onOpenCamera: widget.onOpenCamera,
          onOpenOrder: widget.onOpenOrder,
          onRetrySettings: binding.retryShop,
          onRetryMedication: binding.retryMedication,
          onRetryBooking: binding.retryBooking,
          onRetryCare: binding.retryCare,
          onRetryCamera: binding.retryCamera,
        );
      },
    );
  }
}

Widget _laneMessage(String message, {VoidCallback? onRetry}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(message, style: const TextStyle(fontSize: 14, height: 1.45)),
        if (onRetry != null) ...<Widget>[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ],
    ),
  );
}

class ShopTaskCenterContent extends StatefulWidget {
  const ShopTaskCenterContent({
    super.key,
    required this.snapshot,
    required this.showViewAll,
    required this.closeBeforeOpen,
    this.careOnly = false,
    this.onViewAll,
    this.onOpenCamera,
    this.onOpenOrder,
    this.onRetrySettings,
    this.onRetryServices,
    this.onRetryMedication,
    this.onRetryBooking,
    this.onRetryCare,
    this.onRetryCamera,
  });

  final ShopTaskCenterSnapshot snapshot;
  final bool careOnly;
  final bool showViewAll;
  final bool closeBeforeOpen;
  final VoidCallback? onViewAll;
  final void Function(ShopTaskItem item)? onOpenCamera;
  final ValueChanged<ShopTaskItem>? onOpenOrder;
  final VoidCallback? onRetrySettings;
  final VoidCallback? onRetryServices;
  final VoidCallback? onRetryMedication;
  final VoidCallback? onRetryBooking;
  final VoidCallback? onRetryCare;
  final VoidCallback? onRetryCamera;

  @override
  State<ShopTaskCenterContent> createState() => _ShopTaskCenterContentState();
}

class _ShopTaskCenterContentState extends State<ShopTaskCenterContent> {
  ShopTaskType? _filter;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final colors = Theme.of(context).colorScheme;
    final medicationItems = snapshot.ofType(ShopTaskType.medication);
    final serviceItems = snapshot.ofType(ShopTaskType.timedService);
    final careItems = snapshot.ofType(ShopTaskType.dailyCare);
    final bookingItems = snapshot.ofType(ShopTaskType.booking);
    final cameraItems = snapshot.ofType(ShopTaskType.cameraShare);
    final categories = [
      if (snapshot.serviceEnabled)
        (
          ShopTaskType.timedService,
          '陪玩／預約服務',
          Icons.event_available_outlined,
          serviceItems.length,
        ),
      if (snapshot.medicationEnabled)
        (
          ShopTaskType.medication,
          '用藥',
          Icons.medication_outlined,
          medicationItems.length,
        ),
      if (snapshot.careEnabled)
        (ShopTaskType.dailyCare, '照護回報', Icons.pets_outlined, careItems.length),
      if (snapshot.bookingEnabled && !widget.careOnly)
        (
          ShopTaskType.booking,
          '訂單確認',
          Icons.receipt_long_outlined,
          bookingItems.length,
        ),
      if (snapshot.cameraEnabled && !widget.careOnly)
        (
          ShopTaskType.cameraShare,
          '攝影機',
          Icons.videocam_outlined,
          cameraItems.length,
        ),
    ];
    final filter = categories.any((entry) => entry.$1 == _filter)
        ? _filter
        : null;
    return ColoredBox(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: colors.surfaceContainerLow,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.checklist_rounded, color: colors.primary),
                    const SizedBox(width: 10),
                    Text(
                      widget.careOnly ? '照護待辦' : '今日待辦',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  snapshot.hasLaneLoading
                      ? '正在更新店內待辦'
                      : snapshot.hasLaneError
                      ? '部分分類讀取失敗，已載入的待辦仍可處理'
                      : '${categories.fold<int>(0, (sum, category) => sum + category.$4)} 項待處理 · 點選分類查看明細',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(
                          '全部 ${categories.fold<int>(0, (sum, category) => sum + category.$4)}',
                        ),
                        selected: filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                      for (final (type, label, icon, count) in categories)
                        ChoiceChip(
                          avatar: Icon(icon, size: 16),
                          label: Text('$label $count'),
                          selected: filter == type,
                          onSelected: (selected) =>
                              setState(() => _filter = selected ? type : null),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (snapshot.settingsErrorCode.isNotEmpty)
            _laneMessage(
              shopTaskLaneErrorMessage(
                laneLabel: '店家功能設定',
                code: snapshot.settingsErrorCode,
              ),
              onRetry: widget.onRetrySettings,
            ),
          if (snapshot.serviceEnabled && snapshot.serviceLoading)
            _laneMessage('預約服務讀取中'),
          if (snapshot.medicationEnabled && snapshot.medicationLoading)
            _laneMessage('用藥待辦讀取中'),
          if (snapshot.medicationErrorCode.isNotEmpty)
            _laneMessage(
              shopTaskLaneErrorMessage(
                laneLabel: '用藥',
                code: snapshot.medicationErrorCode,
              ),
              onRetry: widget.onRetryMedication,
            ),
          if (snapshot.careEnabled && snapshot.careLoading)
            _laneMessage('每日照護讀取中'),
          if (snapshot.careErrorCode.isNotEmpty)
            _laneMessage(
              shopTaskLaneErrorMessage(
                laneLabel: '每日照護',
                code: snapshot.careErrorCode,
              ),
              onRetry: widget.onRetryCare,
            ),
          if (snapshot.bookingEnabled && snapshot.bookingLoading)
            _laneMessage('訂單讀取中'),
          if (snapshot.bookingErrorCode.isNotEmpty)
            _laneMessage(
              shopTaskLaneErrorMessage(
                laneLabel: '訂單',
                code: snapshot.bookingErrorCode,
              ),
              onRetry: widget.onRetryBooking,
            ),
          if (snapshot.cameraEnabled && snapshot.cameraLoading)
            _laneMessage('攝影機分享讀取中'),
          if (snapshot.cameraErrorCode.isNotEmpty)
            _laneMessage(
              shopTaskLaneErrorMessage(
                laneLabel: '攝影機分享',
                code: snapshot.cameraErrorCode,
              ),
              onRetry: widget.onRetryCamera,
            ),
          if (snapshot.serviceErrorCode.isNotEmpty)
            _laneMessage(
              shopTaskLaneErrorMessage(
                laneLabel: '預約服務',
                code: snapshot.serviceErrorCode,
              ),
              onRetry: widget.onRetryServices,
            ),
          if (!snapshot.hasLaneLoading &&
              !snapshot.hasLaneError &&
              !snapshot.serviceEnabled &&
              !snapshot.medicationEnabled &&
              !snapshot.bookingEnabled &&
              !snapshot.careEnabled &&
              !snapshot.cameraEnabled)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 32),
              child: Text('目前沒有你可處理的待辦'),
            ),
          if ((widget.careOnly &&
                  !snapshot.hasLaneLoading &&
                  !snapshot.hasLaneError &&
                  medicationItems.isEmpty &&
                  serviceItems.isEmpty &&
                  careItems.isEmpty) ||
              snapshot.isAllClear ||
              (filter != null &&
                  !snapshot.hasLaneLoading &&
                  !snapshot.hasLaneError &&
                  snapshot.ofType(filter).isEmpty))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colors.secondaryContainer,
                    foregroundColor: colors.onSecondaryContainer,
                    child: const Icon(Icons.check_circle_outline),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    filter == null ? '目前沒有待處理事項' : '這個分類目前沒有待辦',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '有新項目時會自動更新',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          if (!snapshot.isAllClear) ...<Widget>[
            if ((filter == null ||
                    filter == ShopTaskType.medication ||
                    filter == ShopTaskType.timedService) &&
                (medicationItems.isNotEmpty || serviceItems.isNotEmpty))
              _GroupBlock(
                title: filter == ShopTaskType.medication
                    ? '用藥待辦'
                    : filter == ShopTaskType.timedService
                    ? '陪玩與預約服務'
                    : '照護時程',
                count: filter == ShopTaskType.medication
                    ? medicationItems.length
                    : filter == ShopTaskType.timedService
                    ? serviceItems.length
                    : medicationItems.length + serviceItems.length,
                children: [
                  for (final item
                      in ([...medicationItems, ...serviceItems]..sort((a, b) {
                            final priority = a.priority.compareTo(b.priority);
                            return priority != 0
                                ? priority
                                : (a.createdAt ?? DateTime(1970)).compareTo(
                                    b.createdAt ?? DateTime(1970),
                                  );
                          }))
                          .where(
                            (item) => filter == null || item.type == filter,
                          ))
                    _TaskCard(
                      icon: item.type == ShopTaskType.medication
                          ? Icons.medication_outlined
                          : Icons.pets_outlined,
                      photo: '${item.metadata['petPhoto'] ?? ''}',
                      title: item.title,
                      subtitle: item.subtitle,
                      statusLabel: item.statusLabel,
                      urgency: '${item.metadata['urgency'] ?? ''}',
                      actionLabel: item.metadata['reviewMedication'] == true
                          ? (item.metadata['awaitingCustomer'] == true
                                ? '查看安排'
                                : '確認安排')
                          : item.metadata['needsIdentity'] == true
                          ? '核對寵物'
                          : '填寫結果',
                      onAction: () {
                        final openOrder = widget.onOpenOrder;
                        if (openOrder != null &&
                            (item.metadata['reviewMedication'] == true ||
                             item.metadata['needsIdentity'] == true)) {
                          openOrder(item);
                          return;
                        }
                        final navigator = Navigator.of(context);
                        if (widget.closeBeforeOpen) navigator.pop();
                        navigator.push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                item.metadata['reviewMedication'] == true ||
                                    item.metadata['needsIdentity'] == true
                                ? AdminBookingRouteGate(
                                    bookingId: item.targetId,
                                  )
                                : item.type == ShopTaskType.medication
                                ? MedicationTaskPage(
                                    shopId: item.shopId,
                                    bookingId: item.targetId,
                                    taskId: '${item.metadata['taskId']}',
                                    scheduledAt:
                                        '${item.metadata['scheduledAt']}',
                                  )
                                : ServiceTaskPage(
                                    shopId: item.shopId,
                                    bookingId: item.targetId,
                                    taskId: '${item.metadata['taskId']}',
                                    scheduledAt:
                                        '${item.metadata['scheduledAt']}',
                                  ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            if (careItems.isNotEmpty &&
                (filter == null || filter == ShopTaskType.dailyCare))
              _GroupBlock(
                title: '每日照護',
                count: careItems.length,
                children: careItems
                    .map(
                      (ShopTaskItem item) => _CareTile(
                        item: item,
                        closeBeforeOpen: widget.closeBeforeOpen,
                      ),
                    )
                    .toList(),
              ),
            if (!widget.careOnly &&
                bookingItems.isNotEmpty &&
                (filter == null || filter == ShopTaskType.booking))
              _GroupBlock(
                title: '訂單',
                count: bookingItems.length,
                children: bookingItems
                    .map(
                      (ShopTaskItem item) => _BookingTile(
                        item: item,
                        closeBeforeOpen: widget.closeBeforeOpen,
                      ),
                    )
                    .toList(),
              ),
            if (!widget.careOnly &&
                cameraItems.isNotEmpty &&
                (filter == null || filter == ShopTaskType.cameraShare))
              _GroupBlock(
                title: '攝影機分享',
                count: cameraItems.length,
                children: cameraItems
                    .map(
                      (ShopTaskItem item) => _CameraTile(
                        item: item,
                        closeBeforeOpen: widget.closeBeforeOpen,
                        onOpen: widget.onOpenCamera,
                      ),
                    )
                    .toList(),
              ),
          ],
          if (widget.showViewAll && widget.onViewAll != null) ...<Widget>[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onViewAll,
                  icon: const Icon(Icons.open_in_new, size: 17),
                  label: const Text('查看全部待辦'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({
    required this.title,
    required this.count,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _CareTile extends StatelessWidget {
  const _CareTile({required this.item, required this.closeBeforeOpen});

  final ShopTaskItem item;
  final bool closeBeforeOpen;

  @override
  Widget build(BuildContext context) {
    return _TaskCard(
      icon: Icons.pets_outlined,
      title: item.title.isEmpty ? '照護待填' : item.title,
      subtitle: item.subtitle,
      statusLabel: item.statusLabel,
      actionLabel: item.canOpen ? '立即填寫' : null,
      onAction: item.canOpen ? () => _openCare(context, item) : null,
    );
  }

  Future<void> _openCare(BuildContext context, ShopTaskItem item) async {
    final Map<String, dynamic> meta = item.metadata;
    final String bookingId = (meta['bookingId'] ?? '').toString();
    final String roomId = (meta['roomId'] ?? '').toString();
    final String roomName = (meta['roomName'] ?? '').toString();
    final int sessionIndex = meta['sessionIndex'] is int
        ? meta['sessionIndex'] as int
        : int.tryParse('${meta['sessionIndex']}') ?? 0;
    final DateTime recordDate = DateTime(
      meta['recordDateYear'] as int? ?? DateTime.now().year,
      meta['recordDateMonth'] as int? ?? DateTime.now().month,
      meta['recordDateDay'] as int? ?? DateTime.now().day,
    );

    final DailyCareSettingModel setting = await DailyCareSettingService.instance
        .getSetting(item.shopId);

    if (!context.mounted) {
      return;
    }

    if (closeBeforeOpen && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (!context.mounted) {
      return;
    }
    DailyCareEntitlement? entitlement;
    final Object? rawEntitlement = meta['entitlement'];
    if (rawEntitlement is Map) {
      entitlement = DailyCareEntitlement.fromMap(
        Map<String, dynamic>.from(rawEntitlement),
      );
    }
    await DailyCareRecordEditLauncher.open(
      context: context,
      shopId: item.shopId,
      bookingId: bookingId,
      recordDate: recordDate,
      sessionIndex: sessionIndex,
      roomId: roomId,
      roomName: roomName,
      serviceType: DailyCareServiceTypes.parse(meta['serviceType']),
      petIds: _readPetIds(meta['petIds']),
      setting: setting,
      entitlement: entitlement,
    );
  }

  List<String> _readPetIds(Object? raw) {
    if (raw is Iterable) {
      return raw
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.item, required this.closeBeforeOpen});

  final ShopTaskItem item;
  final bool closeBeforeOpen;

  @override
  Widget build(BuildContext context) {
    final String stayDates = (item.metadata['stayDates'] ?? '').toString();
    final String createdLabel = (item.metadata['createdLabel'] ?? '')
        .toString();
    final String petNames = (item.metadata['petNames'] ?? '').toString();

    return _TaskCard(
      icon: Icons.receipt_long_outlined,
      title: item.title,
      subtitle: [
        item.subtitle,
        if (stayDates.isNotEmpty) stayDates,
        if (petNames.isNotEmpty && petNames != '尚未指定寵物') petNames,
        if (createdLabel.isNotEmpty) createdLabel,
      ].join('\n'),
      statusLabel: item.statusLabel,
      actionLabel: item.canOpen ? '查看訂單' : null,
      onAction: item.canOpen
          ? () {
              if (closeBeforeOpen && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AdminBookingRouteGate(bookingId: item.targetId),
                ),
              );
            }
          : null,
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({
    required this.item,
    required this.closeBeforeOpen,
    this.onOpen,
  });

  final ShopTaskItem item;
  final bool closeBeforeOpen;
  final void Function(ShopTaskItem item)? onOpen;

  @override
  Widget build(BuildContext context) {
    return _TaskCard(
      icon: Icons.videocam_outlined,
      title: item.title,
      subtitle: item.subtitle,
      statusLabel: item.statusLabel,
      actionLabel: onOpen == null ? null : '處理申請',
      onAction: onOpen == null
          ? null
          : () {
              if (closeBeforeOpen && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              onOpen!(item);
            },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    this.photo = '',
    this.urgency = '',
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String statusLabel;
  final String photo;
  final String urgency;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = switch (urgency) {
      'due' => colors.errorContainer,
      'soon' => const Color(0xFFFFE4B9),
      _ => colors.tertiaryContainer,
    };
    final statusInk = switch (urgency) {
      'due' => colors.onErrorContainer,
      'soon' => const Color(0xFF743900),
      _ => colors.onTertiaryContainer,
    };
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (photo.isNotEmpty)
              ClipOval(
                child: Image.network(
                  photo,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, s) => Icon(icon, size: 32),
                ),
              )
            else
              CircleAvatar(
                radius: 16,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: Icon(icon, size: 17),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusInk,
                ),
              ),
            ),
          ],
        ),
        if (subtitle.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    final action = actionLabel == null || onAction == null
        ? null
        : FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!));
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: urgency.isEmpty ? colors.outlineVariant : statusInk,
        ),
      ),
      child: action == null
          ? details
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 560) {
                  return Row(
                    children: [
                      Expanded(child: details),
                      const SizedBox(width: 16),
                      action,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    details,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                );
              },
            ),
    );
  }
}

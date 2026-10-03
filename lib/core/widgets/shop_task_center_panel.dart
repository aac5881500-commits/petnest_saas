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

class ShopTaskCenterPanel extends StatefulWidget {
  const ShopTaskCenterPanel({
    super.key,
    required this.shopId,
    required this.canViewBookings,
    required this.canFillDailyCare,
    this.canManageDevices = false,
    this.showViewAll = true,
    this.closeBeforeOpen = true,
    this.onViewAll,
    this.onOpenCamera,
  });

  final String shopId;
  final bool canViewBookings;
  final bool canFillDailyCare;
  final bool canManageDevices;
  final bool showViewAll;
  final bool closeBeforeOpen;
  final VoidCallback? onViewAll;
  final void Function(ShopTaskItem item)? onOpenCamera;

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
        return _TaskList(
          snapshot: snapshot.data!,
          showViewAll: widget.showViewAll,
          closeBeforeOpen: widget.closeBeforeOpen,
          onViewAll: widget.onViewAll,
          onOpenCamera: widget.onOpenCamera,
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

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.snapshot,
    required this.showViewAll,
    required this.closeBeforeOpen,
    this.onViewAll,
    this.onOpenCamera,
    this.onRetryBooking,
    this.onRetryCare,
    this.onRetryCamera,
  });

  final ShopTaskCenterSnapshot snapshot;
  final bool showViewAll;
  final bool closeBeforeOpen;
  final VoidCallback? onViewAll;
  final void Function(ShopTaskItem item)? onOpenCamera;
  final VoidCallback? onRetryBooking;
  final VoidCallback? onRetryCare;
  final VoidCallback? onRetryCamera;

  @override
  Widget build(BuildContext context) {
    final List<ShopTaskItem> careItems = snapshot.ofType(
      ShopTaskType.dailyCare,
    );
    final List<ShopTaskItem> bookingItems = snapshot.ofType(
      ShopTaskType.booking,
    );
    final List<ShopTaskItem> cameraItems = snapshot.ofType(
      ShopTaskType.cameraShare,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '今日待辦',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                snapshot.hasLaneLoading
                    ? '${snapshot.totalCount}（部分讀取中）'
                    : '${snapshot.totalCount}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        if (snapshot.careEnabled && snapshot.careLoading)
          _laneMessage('每日照護讀取中'),
        if (snapshot.careErrorCode.isNotEmpty)
          _laneMessage(
            shopTaskLaneErrorMessage(
              laneLabel: '每日照護',
              code: snapshot.careErrorCode,
            ),
            onRetry: onRetryCare,
          ),
        if (snapshot.bookingEnabled && snapshot.bookingLoading)
          _laneMessage('訂單讀取中'),
        if (snapshot.bookingErrorCode.isNotEmpty)
          _laneMessage(
            shopTaskLaneErrorMessage(
              laneLabel: '訂單',
              code: snapshot.bookingErrorCode,
            ),
            onRetry: onRetryBooking,
          ),
        if (snapshot.cameraEnabled && snapshot.cameraLoading)
          _laneMessage('攝影機分享讀取中'),
        if (snapshot.cameraErrorCode.isNotEmpty)
          _laneMessage(
            shopTaskLaneErrorMessage(
              laneLabel: '攝影機分享',
              code: snapshot.cameraErrorCode,
            ),
            onRetry: onRetryCamera,
          ),
        if (!snapshot.bookingEnabled &&
            !snapshot.careEnabled &&
            !snapshot.cameraEnabled)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: Text('目前沒有你可處理的待辦'),
          ),
        if (snapshot.isAllClear)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.check_circle_outline,
                  size: 36,
                  color: Color(0xFF2E7D32),
                ),
                SizedBox(height: 10),
                Text(
                  '✓ 今日待辦已完成',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  '目前沒有需要處理的項目',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        if (!snapshot.isAllClear) ...<Widget>[
          if (careItems.isNotEmpty)
            _GroupBlock(
              title: '每日照護',
              count: careItems.length,
              children: careItems
                  .map(
                    (ShopTaskItem item) =>
                        _CareTile(item: item, closeBeforeOpen: closeBeforeOpen),
                  )
                  .toList(),
            ),
          if (bookingItems.isNotEmpty)
            _GroupBlock(
              title: '訂單',
              count: bookingItems.length,
              children: bookingItems
                  .map(
                    (ShopTaskItem item) => _BookingTile(
                      item: item,
                      closeBeforeOpen: closeBeforeOpen,
                    ),
                  )
                  .toList(),
            ),
          if (cameraItems.isNotEmpty)
            _GroupBlock(
              title: '攝影機分享',
              count: cameraItems.length,
              children: cameraItems
                  .map(
                    (ShopTaskItem item) => _CameraTile(
                      item: item,
                      closeBeforeOpen: closeBeforeOpen,
                      onOpen: onOpenCamera,
                    ),
                  )
                  .toList(),
            ),
        ],
        if (showViewAll && onViewAll != null) ...<Widget>[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onViewAll,
                child: const Text('查看全部待辦'),
              ),
            ),
          ),
        ],
      ],
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
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String statusLabel;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
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
              Text(
                statusLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC62828),
                ),
              ),
            ],
          ),
          if (subtitle.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Colors.black54,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
          ],
        ],
      ),
    );
  }
}

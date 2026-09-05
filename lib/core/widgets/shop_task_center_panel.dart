// 檔案名稱：lib/core/widgets/shop_task_center_panel.dart
// 功能說明：今日待辦列表（Panel / BottomSheet / 全頁共用）

import 'package:flutter/material.dart';

import '../models/daily_care_setting_model.dart';
import '../models/shop_task_item.dart';
import '../services/daily_care_setting_service.dart';
import '../services/shop_task_center_service.dart';
import '../../features/admin/pages/admin_booking_detail_page.dart';
import '../../features/room/pages/daily_care_record_edit_page.dart';

class ShopTaskCenterPanel extends StatelessWidget {
  const ShopTaskCenterPanel({
    super.key,
    required this.shopId,
    required this.canViewBookings,
    required this.canFillDailyCare,
    this.showViewAll = true,
    this.closeBeforeOpen = true,
    this.onViewAll,
    this.onRetry,
  });

  final String shopId;
  final bool canViewBookings;
  final bool canFillDailyCare;
  final bool showViewAll;
  final bool closeBeforeOpen;
  final VoidCallback? onViewAll;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ShopTaskCenterSnapshot>(
      stream: ShopTaskCenterService.instance.streamSnapshot(
        shopId: shopId,
        canViewBookings: canViewBookings,
        canFillDailyCare: canFillDailyCare,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(context);
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final ShopTaskCenterSnapshot data = snapshot.data!;
        if (data.hasError) {
          return _errorView(context, message: data.errorMessage);
        }

        return _TaskList(
          snapshot: data,
          showViewAll: showViewAll,
          closeBeforeOpen: closeBeforeOpen,
          onViewAll: onViewAll,
        );
      },
    );
  }

  Widget _errorView(BuildContext context, {String? message}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message ?? '目前無法取得待辦事項，請稍後再試。',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('重新整理')),
        ],
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.snapshot,
    required this.showViewAll,
    required this.closeBeforeOpen,
    this.onViewAll,
  });

  final ShopTaskCenterSnapshot snapshot;
  final bool showViewAll;
  final bool closeBeforeOpen;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final List<ShopTaskItem> careItems = snapshot.ofType(
      ShopTaskType.dailyCare,
    );
    final List<ShopTaskItem> bookingItems = snapshot.ofType(
      ShopTaskType.booking,
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
                '${snapshot.totalCount}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        if (snapshot.totalCount == 0)
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
          )
        else ...<Widget>[
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
    final String sessionName = (meta['sessionName'] ?? item.subtitle)
        .toString();
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DailyCareRecordEditPage(
          shopId: item.shopId,
          bookingId: bookingId,
          roomId: roomId,
          roomName: roomName,
          recordDate: recordDate,
          sessionIndex: sessionIndex,
          sessionName: sessionName,
          customFields: setting.customFields,
          enabledFields: setting.enabledFields,
          photoEnabled: setting.photoEnabled,
        ),
      ),
    );
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
                      AdminBookingDetailPage(bookingId: item.targetId),
                ),
              );
            }
          : null,
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

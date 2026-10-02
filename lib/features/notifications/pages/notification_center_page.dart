// 檔案名稱：lib/features/notifications/pages/notification_center_page.dart
// 功能說明：通知中心閱讀介面。篩選與日期分組只使用已載入的通知，不另開查詢。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/fcm_message_service.dart';
import '../../../core/models/app_notification_model.dart';
import '../../../core/models/customer_notification_kind.dart';
import '../../../core/services/notification_service.dart';
import 'package:petnest_saas/features/booking/pages/my_reviews_page.dart';

const Color _kPlatformBlue = Color(0xFF1565C0);
const double _kInboxMaxWidth = 840;

enum CustomerPlatformFilter { all, important, marketing }

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  NotificationService get _notificationService => NotificationService.instance;

  late Stream<List<AppNotificationModel>> _stream;
  final ScrollController _scrollController = ScrollController();
  List<AppNotificationModel>? _cached;
  CustomerNoticeLane _lane = CustomerNoticeLane.primary;
  String _shopFilter = '';
  CustomerPlatformFilter _platformFilter = CustomerPlatformFilter.all;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _stream = _notificationService.notificationStream();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 只給下拉更新與錯誤頁「重試」使用，不在分類切換或一般重建時呼叫。
  void _reloadStream() {
    setState(() {
      _stream = _notificationService.notificationStream();
    });
  }

  Future<void> _markAllAsRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await _notificationService.markAllAsRead();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已將全部通知設為已讀')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('設定已讀失敗：$error')));
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _handleNotificationTap(AppNotificationModel notification) async {
    try {
      if (!notification.isRead) {
        await _notificationService.markAsRead(notification.id);
      }
      if (!mounted) return;

      switch (notification.type) {
        case 'booking_status':
        case 'booking_message':
        case 'check_in':
          if (notification.bookingId.isNotEmpty) {
            await FcmMessageService.instance.openBookingDetail(
              notification.bookingId,
            );
          }
          break;
        case 'review':
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MyReviewsPage()),
          );
          break;
        case 'shop_chat':
          final String shopId = notification.shopId;
          final String threadId = (notification.data['threadId'] ?? '')
              .toString();
          if (shopId.isNotEmpty && threadId.isNotEmpty) {
            await FcmMessageService.instance.openShopChat(
              shopId: shopId,
              threadId: threadId,
            );
          }
          break;
        default:
          break;
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('讀取通知失敗：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotificationModel>>(
      stream: _stream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<AppNotificationModel>> snapshot,
          ) {
            if (snapshot.hasData && snapshot.data != null) {
              _cached = snapshot.data;
            }
            final List<AppNotificationModel> notifications =
                snapshot.connectionState == ConnectionState.waiting
                ? (_cached ?? const <AppNotificationModel>[])
                : (snapshot.data ?? _cached ?? const <AppNotificationModel>[]);
            final int unread = notifications
                .where((AppNotificationModel item) => !item.isRead)
                .length;
            final bool wide = MediaQuery.sizeOf(context).width >= 720;
            return Scaffold(
              backgroundColor: const Color(0xFFF6F7FB),
              appBar: AppBar(
                centerTitle: false,
                title: const Text('通知中心'),
                actions: wide
                    ? const <Widget>[]
                    : <Widget>[
                        _MarkAllButton(
                          busy: _markingAll,
                          onPressed: unread == 0 ? null : _markAllAsRead,
                        ),
                      ],
              ),
              body: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kInboxMaxWidth),
                  child: _buildBody(
                    snapshot: snapshot,
                    notifications: notifications,
                    unread: unread,
                    wide: wide,
                  ),
                ),
              ),
            );
          },
    );
  }

  Widget _buildBody({
    required AsyncSnapshot<List<AppNotificationModel>> snapshot,
    required List<AppNotificationModel> notifications,
    required int unread,
    required bool wide,
  }) {
    if (snapshot.hasError && notifications.isEmpty) {
      return _NotificationErrorView(
        error: snapshot.error,
        onRetry: _reloadStream,
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting &&
        notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _InboxHeader(
          notifications: notifications,
          lane: _lane,
          shopFilter: _shopFilter,
          platformFilter: _platformFilter,
          wide: wide,
          markingAll: _markingAll,
          onLane: (CustomerNoticeLane lane) {
            setState(() => _lane = lane);
          },
          onShop: (String shopId) {
            setState(() => _shopFilter = shopId);
          },
          onPlatform: (CustomerPlatformFilter filter) {
            setState(() => _platformFilter = filter);
          },
          onMarkAll: unread == 0 ? null : _markAllAsRead,
        ),
        Expanded(child: _list(notifications)),
      ],
    );
  }

  Widget _list(List<AppNotificationModel> notifications) {
    if (notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _reloadStream(),
        child: const _ScrollableMessage(child: _EmptyNotificationView()),
      );
    }
    final bool narrowed =
        (_lane == CustomerNoticeLane.shop && _shopFilter.isNotEmpty) ||
        (_lane == CustomerNoticeLane.platform &&
            _platformFilter != CustomerPlatformFilter.all);
    final List<AppNotificationModel> visible = notifications
        .where(
          (AppNotificationModel item) => notificationInCustomerView(
            item,
            lane: _lane,
            shopId: _shopFilter,
            platformFilter: _platformFilter,
          ),
        )
        .toList();
    if (visible.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _reloadStream(),
        child: _ScrollableMessage(
          child: _FilteredEmptyView(
            showClear: narrowed,
            onClear: () => setState(() {
              _shopFilter = '';
              _platformFilter = CustomerPlatformFilter.all;
            }),
          ),
        ),
      );
    }
    final List<NotificationDayGroup> groups = groupNotificationsByDay(
      visible,
      DateTime.now(),
    );
    return RefreshIndicator(
      onRefresh: () async => _reloadStream(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: groups.fold<int>(
          0,
          (int count, NotificationDayGroup group) =>
              count + 1 + group.items.length,
        ),
        itemBuilder: (BuildContext context, int index) {
          int cursor = index;
          for (final NotificationDayGroup group in groups) {
            if (cursor == 0) {
              return _DayHeader(title: group.title);
            }
            cursor -= 1;
            if (cursor < group.items.length) {
              try {
                return _notificationTile(group.items[cursor]);
              } catch (_) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: _FallbackNotificationCard(),
                );
              }
            }
            cursor -= group.items.length;
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _notificationTile(AppNotificationModel notification) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _NotificationCard(
        notification: notification,
        onTap: () => _handleNotificationTap(notification),
      ),
    );
  }
}

class _MarkAllButton extends StatelessWidget {
  const _MarkAllButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.done_all, size: 18),
      label: const Text('全部已讀'),
    );
  }
}

class _InboxHeader extends StatelessWidget {
  const _InboxHeader({
    required this.notifications,
    required this.lane,
    required this.shopFilter,
    required this.platformFilter,
    required this.wide,
    required this.markingAll,
    required this.onLane,
    required this.onShop,
    required this.onPlatform,
    required this.onMarkAll,
  });

  final List<AppNotificationModel> notifications;
  final CustomerNoticeLane lane;
  final String shopFilter;
  final CustomerPlatformFilter platformFilter;
  final bool wide;
  final bool markingAll;
  final ValueChanged<CustomerNoticeLane> onLane;
  final ValueChanged<String> onShop;
  final ValueChanged<CustomerPlatformFilter> onPlatform;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    final int unread = notifications
        .where((AppNotificationModel item) => !item.isRead)
        .length;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    unread == 0 ? '目前沒有未讀通知' : '未讀 $unread 則',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
                if (wide)
                  _MarkAllButton(busy: markingAll, onPressed: onMarkAll),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: CustomerNoticeLane.values.map((
                CustomerNoticeLane laneItem,
              ) {
                final int count = notifications
                    .where(
                      (AppNotificationModel item) =>
                          classifyCustomerNotification(item).lane == laneItem,
                    )
                    .length;
                final String label = customerLaneLabel(laneItem);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _choiceChip(
                    label: '$label $count',
                    selected: lane == laneItem,
                    onSelected: () => onLane(laneItem),
                  ),
                );
              }).toList(),
            ),
          ),
          if (lane == CustomerNoticeLane.shop) _shopChips(),
          if (lane == CustomerNoticeLane.platform) _platformChips(),
        ],
      ),
    );
  }

  Widget _shopChips() {
    final List<AppNotificationModel> shops = notifications
        .where(
          (AppNotificationModel item) =>
              classifyCustomerNotification(item).lane ==
              CustomerNoticeLane.shop,
        )
        .toList();
    final Map<String, String> names = <String, String>{};
    for (final AppNotificationModel item in shops) {
      final String id = item.shopId.trim();
      if (id.isEmpty || names.containsKey(id)) continue;
      names[id] = customerShopDisplayName(item);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            _choiceChip(
              label: '全部店家',
              selected: shopFilter.isEmpty,
              onSelected: () => onShop(''),
            ),
            ...names.entries.map(
              (MapEntry<String, String> entry) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _choiceChip(
                  label: entry.value,
                  selected: shopFilter == entry.key,
                  onSelected: () => onShop(entry.key),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _platformChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: CustomerPlatformFilter.values.map((
            CustomerPlatformFilter item,
          ) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _choiceChip(
                label: customerPlatformFilterLabel(item),
                selected: platformFilter == item,
                onSelected: () => onPlatform(item),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? _kPlatformBlue : const Color(0xFF374151),
      ),
      selectedColor: const Color(0xFFEAF3FF),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? const Color(0xFF93C5FD) : const Color(0xFFE5E7EB),
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    try {
      return _buildCard(context);
    } catch (_) {
      return const _FallbackNotificationCard();
    }
  }

  Widget _buildCard(BuildContext context) {
    final bool unread = !notification.isRead;
    final bool canOpen = notificationCanOpen(notification);
    final _NotificationVisual visual = _notificationVisual(notification);
    return Material(
      color: unread ? const Color(0xFFF4F7FB) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 80),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: unread ? _kPlatformBlue : const Color(0xFFE5E7EB),
                    width: 3,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: visual.background,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        visual.icon,
                        size: 18,
                        color: visual.foreground,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _NoticeMeta(notification: notification),
                          Text(
                            notification.title.isEmpty
                                ? '通知'
                                : notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.2,
                              fontWeight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          if (notification.body.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              notification.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            notificationClockLabel(notification.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (unread)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: const BoxDecoration(
                          color: _kPlatformBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (canOpen)
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Color(0xFF9CA3AF),
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
}

class _FallbackNotificationCard extends StatelessWidget {
  const _FallbackNotificationCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 80),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        alignment: Alignment.centerLeft,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '通知',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 2),
            Text(
              '時間未記錄',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrollableMessage extends StatelessWidget {
  const _ScrollableMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: child,
        ),
      ],
    );
  }
}

class _EmptyNotificationView extends StatelessWidget {
  const _EmptyNotificationView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.notifications_none_rounded,
              size: 56,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 12),
            Text(
              '目前沒有通知',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              '訂單、聊天與重要提醒會顯示在這裡',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeMeta extends StatelessWidget {
  const _NoticeMeta({required this.notification});

  final AppNotificationModel notification;

  @override
  Widget build(BuildContext context) {
    try {
      return _buildMeta();
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildMeta() {
    final CustomerNoticePlacement placement = classifyCustomerNotification(
      notification,
    );
    if (placement.lane == CustomerNoticeLane.primary) {
      return const SizedBox.shrink();
    }
    final String label = placement.lane == CustomerNoticeLane.shop
        ? '${customerShopDisplayName(notification)} · ${placement.shopTag}'
        : (placement.platformTone == CustomerPlatformTone.important
              ? '重要'
              : '推廣');
    final bool important =
        placement.platformTone == CustomerPlatformTone.important;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: important ? const Color(0xFF1E3A8A) : const Color(0xFF6B7280),
        ),
      ),
    );
  }
}

class _FilteredEmptyView extends StatelessWidget {
  const _FilteredEmptyView({required this.onClear, required this.showClear});

  final VoidCallback onClear;
  final bool showClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              '此分類暫無通知',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (showClear) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(onPressed: onClear, child: const Text('清除篩選')),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationErrorView extends StatelessWidget {
  const _NotificationErrorView({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            const Text(
              '通知載入失敗',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? '發生未知錯誤',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重試')),
          ],
        ),
      ),
    );
  }
}

class NotificationDayGroup {
  const NotificationDayGroup({required this.title, required this.items});

  final String title;
  final List<AppNotificationModel> items;
}

class _NotificationVisual {
  const _NotificationVisual({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
}

String customerLaneLabel(CustomerNoticeLane lane) {
  switch (lane) {
    case CustomerNoticeLane.primary:
      return '主要';
    case CustomerNoticeLane.shop:
      return '店家';
    case CustomerNoticeLane.platform:
      return '平台';
  }
}

String customerPlatformFilterLabel(CustomerPlatformFilter filter) {
  switch (filter) {
    case CustomerPlatformFilter.all:
      return '全部';
    case CustomerPlatformFilter.important:
      return '重要';
    case CustomerPlatformFilter.marketing:
      return '推廣';
  }
}

int customerLaneUnreadCount(
  List<AppNotificationModel> notifications,
  CustomerNoticeLane lane,
) {
  return notifications.where((AppNotificationModel item) {
    return !item.isRead && classifyCustomerNotification(item).lane == lane;
  }).length;
}

bool notificationInCustomerView(
  AppNotificationModel notification, {
  required CustomerNoticeLane lane,
  required String shopId,
  required CustomerPlatformFilter platformFilter,
}) {
  final CustomerNoticePlacement placement = classifyCustomerNotification(
    notification,
  );
  if (placement.lane != lane) return false;
  if (lane == CustomerNoticeLane.shop &&
      shopId.isNotEmpty &&
      notification.shopId != shopId) {
    return false;
  }
  if (lane == CustomerNoticeLane.platform) {
    if (platformFilter == CustomerPlatformFilter.important &&
        placement.platformTone != CustomerPlatformTone.important) {
      return false;
    }
    if (platformFilter == CustomerPlatformFilter.marketing &&
        placement.platformTone != CustomerPlatformTone.marketing) {
      return false;
    }
  }
  return true;
}

bool notificationCanOpen(AppNotificationModel notification) {
  switch (notification.type) {
    case 'booking_status':
    case 'booking_message':
    case 'check_in':
      return notification.bookingId.isNotEmpty;
    case 'review':
      return true;
    case 'shop_chat':
      final String threadId = (notification.data['threadId'] ?? '').toString();
      return notification.shopId.isNotEmpty && threadId.isNotEmpty;
    default:
      return false;
  }
}

_NotificationVisual _notificationVisual(AppNotificationModel notification) {
  switch (notification.type) {
    case 'booking_status':
      final String status = (notification.data['status'] ?? '').toString();
      final bool calendar =
          status == 'confirmed' ||
          status == 'checked_in' ||
          status == 'pending';
      return _NotificationVisual(
        icon: calendar
            ? Icons.calendar_today_outlined
            : Icons.receipt_long_outlined,
        background: const Color(0xFFEAF3FF),
        foreground: _kPlatformBlue,
      );
    case 'booking_message':
    case 'shop_chat':
      return const _NotificationVisual(
        icon: Icons.chat_bubble_outline,
        background: Color(0xFFEEF2FF),
        foreground: Color(0xFF4338CA),
      );
    case 'review':
      return const _NotificationVisual(
        icon: Icons.star_outline,
        background: Color(0xFFFFFBEB),
        foreground: Color(0xFFB45309),
      );
    case 'check_in':
      return const _NotificationVisual(
        icon: Icons.notifications_active_outlined,
        background: Color(0xFFFFF7ED),
        foreground: Color(0xFFC2410C),
      );
    case 'payment':
    case 'payment_success':
    case 'payment_failed':
    case 'payment_pending':
    case 'refund':
      return const _NotificationVisual(
        icon: Icons.payments_outlined,
        background: Color(0xFFECFDF3),
        foreground: Color(0xFF166534),
      );
    default:
      final CustomerNoticePlacement placement = classifyCustomerNotification(
        notification,
      );
      if (placement.platformTone == CustomerPlatformTone.important) {
        return const _NotificationVisual(
          icon: Icons.campaign_outlined,
          background: Color(0xFFE8EEF9),
          foreground: Color(0xFF1E3A8A),
        );
      }
      if (placement.lane == CustomerNoticeLane.shop) {
        return const _NotificationVisual(
          icon: Icons.storefront_outlined,
          background: Color(0xFFFFF7ED),
          foreground: Color(0xFFC2410C),
        );
      }
      return const _NotificationVisual(
        icon: Icons.notifications_none_rounded,
        background: Color(0xFFF3F4F6),
        foreground: Color(0xFF6B7280),
      );
  }
}

String notificationDayLabel(DateTime? createdAt, DateTime now) {
  if (createdAt == null) return '時間未記錄';
  final DateTime day = DateTime(createdAt.year, createdAt.month, createdAt.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  if (day == today) return '今天';
  if (day == today.subtract(const Duration(days: 1))) return '昨天';
  return '更早';
}

String notificationClockLabel(DateTime? createdAt) {
  if (createdAt == null) return '時間未記錄';
  final String hour = createdAt.hour.toString().padLeft(2, '0');
  final String minute = createdAt.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

List<NotificationDayGroup> groupNotificationsByDay(
  List<AppNotificationModel> notifications,
  DateTime now,
) {
  final List<NotificationDayGroup> dated = <NotificationDayGroup>[];
  final List<AppNotificationModel> undated = <AppNotificationModel>[];
  for (final AppNotificationModel notification in notifications) {
    if (notification.createdAt == null) {
      undated.add(notification);
      continue;
    }
    final String title = notificationDayLabel(notification.createdAt, now);
    if (dated.isNotEmpty && dated.last.title == title) {
      dated.last.items.add(notification);
    } else {
      dated.add(
        NotificationDayGroup(
          title: title,
          items: <AppNotificationModel>[notification],
        ),
      );
    }
  }
  if (undated.isNotEmpty) {
    dated.add(NotificationDayGroup(title: '時間未記錄', items: undated));
  }
  return dated;
}

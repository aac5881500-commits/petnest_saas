// 檔案名稱：lib/features/notifications/pages/notification_center_page.dart
// 功能說明：顯示目前登入使用者的通知、單筆已讀與全部已讀
// 🔔 App 通知中心頁面

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/fcm_message_service.dart';
import '../../../core/models/app_notification_model.dart';
import '../../../core/services/notification_service.dart';
import 'package:petnest_saas/features/booking/pages/my_reviews_page.dart';

class NotificationCenterPage extends StatelessWidget {
  const NotificationCenterPage({super.key});

  NotificationService get _notificationService => NotificationService.instance;

  Future<void> _markAllAsRead(BuildContext context) async {
    try {
      await _notificationService.markAllAsRead();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已將全部通知設為已讀')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('設定已讀失敗：$error')));
    }
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    AppNotificationModel notification,
  ) async {
    try {
      if (!notification.isRead) {
        await _notificationService.markAsRead(notification.id);
      }

      if (!context.mounted) {
        return;
      }

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

      // 下一步再依照通知類型導向：
      // 1. 訂單詳細頁
      // 2. 訂單聊天室
      // 3. 評價頁面
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('讀取通知失敗：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知中心'),
        actions: [
          IconButton(
            tooltip: '全部設為已讀',
            onPressed: () => _markAllAsRead(context),
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotificationModel>>(
        stream: _notificationService.notificationStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _NotificationErrorView(error: snapshot.error);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? <AppNotificationModel>[];

          if (notifications.isEmpty) {
            return const _EmptyNotificationView();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 400));
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: notifications.length,
              separatorBuilder: (_, __) {
                return const SizedBox(height: 8);
              },
              itemBuilder: (context, index) {
                final notification = notifications[index];

                return _NotificationCard(
                  notification: notification,
                  onTap: () {
                    _handleNotificationTap(context, notification);
                  },
                );
              },
            ),
          );
        },
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
    final theme = Theme.of(context);
    final iconData = _notificationIcon(notification.type);

    final backgroundColor = notification.isRead
        ? theme.colorScheme.surface
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.35);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotificationIcon(
                iconData: iconData,
                isRead: notification.isRead,
              ),
              const SizedBox(width: 12),
              Expanded(child: _NotificationContent(notification: notification)),
              if (!notification.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({required this.iconData, required this.isRead});

  final IconData iconData;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isRead
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: isRead
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.primary,
      ),
    );
  }
}

class _NotificationContent extends StatelessWidget {
  const _NotificationContent({required this.notification});

  final AppNotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notification.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        if (notification.body.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            notification.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          _formatNotificationTime(notification.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EmptyNotificationView extends StatelessWidget {
  const _EmptyNotificationView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '目前沒有通知',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '訂單狀態、聊天訊息與入住提醒會顯示在這裡。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationErrorView extends StatelessWidget {
  const _NotificationErrorView({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              '通知載入失敗',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? '發生未知錯誤',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _notificationIcon(String type) {
  switch (type) {
    case 'booking_status':
      return Icons.receipt_long_rounded;

    case 'booking_message':
      return Icons.chat_bubble_outline_rounded;

    case 'shop_chat':
      return Icons.forum_outlined;

    case 'review':
      return Icons.star_outline_rounded;

    case 'check_in':
      return Icons.hotel_rounded;

    default:
      return Icons.notifications_none_rounded;
  }
}

String _formatNotificationTime(DateTime? createdAt) {
  if (createdAt == null) {
    return '剛剛';
  }

  final now = DateTime.now();
  final difference = now.difference(createdAt);

  if (difference.isNegative) {
    return '剛剛';
  }

  if (difference.inMinutes < 1) {
    return '剛剛';
  }

  if (difference.inHours < 1) {
    return '${difference.inMinutes} 分鐘前';
  }

  if (difference.inDays < 1) {
    return '${difference.inHours} 小時前';
  }

  if (difference.inDays < 7) {
    return '${difference.inDays} 天前';
  }

  final month = createdAt.month.toString().padLeft(2, '0');
  final day = createdAt.day.toString().padLeft(2, '0');
  final hour = createdAt.hour.toString().padLeft(2, '0');
  final minute = createdAt.minute.toString().padLeft(2, '0');

  return '${createdAt.year}/$month/$day $hour:$minute';
}

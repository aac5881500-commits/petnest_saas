// lib/features/shop/widgets/chat/shop_chat_message_list.dart
// 💬 聊天訊息列表：前後台共用

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/shop_chat_message_model.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_image_viewer.dart';

class ShopChatMessageList extends StatelessWidget {
  const ShopChatMessageList({
    super.key,
    required this.messages,
    required this.shopName,
    required this.primaryColor,
    this.showShopReadReceipt = false,
    this.shopHasReadLast = false,
    this.onLoadOlder,
    this.loadingOlder = false,
  });

  final List<ShopChatMessageModel> messages;
  final String shopName;
  final Color primaryColor;
  final bool showShopReadReceipt;
  final bool shopHasReadLast;
  final VoidCallback? onLoadOlder;
  final bool loadingOlder;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (onLoadOlder != null &&
            notification.metrics.maxScrollExtent > 40 &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 80) {
          onLoadOlder!();
        }
        return false;
      },
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        itemCount: messages.length + (loadingOlder ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (loadingOlder && index == messages.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final int reversedIndex = messages.length - 1 - index;
          final ShopChatMessageModel message = messages[reversedIndex];
          final ShopChatMessageModel? previous =
              reversedIndex > 0 ? messages[reversedIndex - 1] : null;
          final bool showDate = previous == null ||
              !_sameDay(previous.createdAt, message.createdAt);
          final bool isLastCustomer = reversedIndex == messages.length - 1 &&
              message.senderType == ShopChatSenderTypes.customer;
          return Column(
            children: <Widget>[
              if (showDate) _DateDivider(time: message.createdAt),
              _Bubble(
                message: message,
                shopName: shopName,
                primaryColor: primaryColor,
              ),
              if (showShopReadReceipt && isLastCustomer && shopHasReadLast)
                const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 8, bottom: 6),
                    child: Text(
                      '已讀',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.time});

  final DateTime? time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        _label(),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    );
  }

  String _label() {
    if (time == null) {
      return '';
    }
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(time!.year, time!.month, time!.day);
    if (day == today) {
      return '今天';
    }
    if (day == today.subtract(const Duration(days: 1))) {
      return '昨天';
    }
    return DateFormat('yyyy/MM/dd').format(time!);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.shopName,
    required this.primaryColor,
  });

  final ShopChatMessageModel message;
  final String shopName;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final bool mine = !message.isFromShop;
    final String timeText = _timeLabel(message.createdAt);
    final Widget content = message.isImage
        ? GestureDetector(
            onTap: () {
              if (message.imageUrl.isNotEmpty) {
                ShopChatImageViewer.open(context, message.imageUrl);
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                message.imageUrl,
                width: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 120,
                  height: 80,
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          )
        : Text(
            message.text,
            style: TextStyle(
              color: mine ? Colors.white : const Color(0xFF2A221C),
              height: 1.35,
            ),
          );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: message.isImage
              ? const EdgeInsets.all(4)
              : const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: mine ? primaryColor : const Color(0xFFF3EEE8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: <Widget>[
              if (!mine && !message.isImage)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    shopName,
                    style: TextStyle(
                      fontSize: 11,
                      color: primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              content,
              const SizedBox(height: 4),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 10,
                  color: mine ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeLabel(DateTime? time) {
    if (time == null) {
      return '';
    }
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(time.year, time.month, time.day);
    final String hm = DateFormat('HH:mm').format(time);
    if (day == today) {
      return hm;
    }
    return '${DateFormat('M/d').format(time)} $hm';
  }
}

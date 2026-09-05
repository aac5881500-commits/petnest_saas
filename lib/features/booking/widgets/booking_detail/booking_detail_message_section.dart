// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_message_section.dart
// 功能說明：顯示留言列表、送出留言
// 💬 訂單留言區塊

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_message_service.dart';

class BookingDetailMessageSection extends StatefulWidget {
  const BookingDetailMessageSection({
    super.key,
    required this.bookingId,
    required this.senderType,
    required this.bookingStatus,
  });

  final String bookingId;
  final String senderType; // customer / shop
  final String bookingStatus;

  @override
  State<BookingDetailMessageSection> createState() =>
      _BookingDetailMessageSectionState();
}

class _BookingDetailMessageSectionState
    extends State<BookingDetailMessageSection> {
  final TextEditingController _controller = TextEditingController();

  bool _sending = false;
  bool _markedAsRead = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsReadOnce();
    });
  }

  Future<void> _markAsReadOnce() async {
    if (_markedAsRead) return;

    _markedAsRead = true;

    await BookingMessageService.instance.markAsRead(
      bookingId: widget.bookingId,
      readerType: widget.senderType,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    setState(() {
      _sending = true;
    });

    try {
      await BookingMessageService.instance.sendMessage(
        bookingId: widget.bookingId,
        text: text,
        senderType: widget.senderType,
      );

      _controller.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }

    if (mounted) {
      setState(() {
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked =
        widget.bookingStatus == 'cancelled' ||
        widget.bookingStatus == 'completed';

    final lockedText = widget.bookingStatus == 'cancelled'
        ? '此訂單已取消，無法留言'
        : '此訂單已完成，無法留言';
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.chat_bubble_outline),
                SizedBox(width: 8),
                Text(
                  '訂單留言',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            StreamBuilder<List<Map<String, dynamic>>>(
              stream: BookingMessageService.instance.streamMessages(
                widget.bookingId,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('留言載入失敗，請稍後再試');
                }
                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('尚無留言', textAlign: TextAlign.center),
                  );
                }

                return Column(
                  children: messages.map((message) {
                    final senderType = message['senderType']?.toString() ?? '';

                    final isMine = senderType == widget.senderType;

                    final text = message['text']?.toString() ?? '';

                    final createdAt = message['createdAt'];

                    String timeText = '';

                    if (createdAt is Timestamp) {
                      final dt = createdAt.toDate();

                      timeText =
                          '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
                          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    }

                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 400),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isMine
                                ? Colors.green.shade200
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(text),

                            const SizedBox(height: 4),

                            Text(
                              timeText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 16),

            if (isLocked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  lockedText,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '輸入留言...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  ElevatedButton(
                    onPressed: _sending ? null : _sendMessage,
                    child: Text(_sending ? '送出中' : '送出'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

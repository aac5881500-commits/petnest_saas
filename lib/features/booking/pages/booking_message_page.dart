// lib/features/booking/pages/booking_message_page.dart
// 訂單留言完整頁：沿用 BookingMessageService，完成／取消後只可查看。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_message_service.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';

class BookingMessagePage extends StatefulWidget {
  const BookingMessagePage({
    super.key,
    required this.bookingId,
    required this.bookingStatus,
    required this.senderType,
    this.shopId = '',
  });

  final String bookingId;
  final String bookingStatus;
  final String senderType;
  final String shopId;

  @override
  State<BookingMessagePage> createState() => _BookingMessagePageState();
}

class _BookingMessagePageState extends State<BookingMessagePage> {
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
    if (_markedAsRead) {
      return;
    }
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
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
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
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
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
    final bool locked =
        widget.bookingStatus == 'cancelled' ||
        widget.bookingStatus == 'completed';
    return ShopFrontendThemeScope(
      shopId: widget.shopId,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: BookingDetailUi.of(context).background,
          appBar: AppBar(
            title: const Text('訂單留言'),
            backgroundColor: BookingDetailUi.of(context).background,
          ),
          body: BookingDetailUi.constrain(
            Column(
              children: <Widget>[
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: BookingMessageService.instance.streamMessages(
                      widget.bookingId,
                    ),
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
                        ) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                '留言載入失敗，請稍後再試',
                                style: TextStyle(
                                  color: BookingDetailUi.of(context).muted,
                                ),
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final List<Map<String, dynamic>> messages =
                              snapshot.data!;
                          if (messages.isEmpty) {
                            return Center(
                              child: Text(
                                '尚無留言',
                                style: TextStyle(
                                  color: BookingDetailUi.of(context).muted,
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.all(
                              BookingDetailUi.pagePadding,
                            ),
                            itemCount: messages.length,
                            itemBuilder: (BuildContext context, int index) {
                              final Map<String, dynamic> message =
                                  messages[index];
                              final bool mine =
                                  SafeParse.parseString(
                                    message['senderType'],
                                  ) ==
                                  widget.senderType;
                              final DateTime? created = SafeParse.parseDate(
                                message['createdAt'],
                              );
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  constraints: const BoxConstraints(
                                    maxWidth: 400,
                                  ),
                                  decoration: BookingDetailUi.cardDecoration(
                                    context,
                                    color: mine
                                        ? BookingDetailUi.of(
                                            context,
                                          ).primarySoft
                                        : BookingDetailUi.of(context).card,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        SafeParse.parseString(message['text']),
                                      ),
                                      if (created != null)
                                        Text(
                                          '${created.year}/${created.month.toString().padLeft(2, '0')}/${created.day.toString().padLeft(2, '0')} ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: BookingDetailUi.of(
                                              context,
                                            ).muted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(BookingDetailUi.pagePadding),
                  child: locked
                      ? Text(
                          widget.bookingStatus == 'cancelled'
                              ? '此訂單已取消，無法新增留言'
                              : '此訂單已完成，無法新增留言',
                          style: TextStyle(
                            color: BookingDetailUi.of(context).muted,
                          ),
                        )
                      : Row(
                          children: <Widget>[
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

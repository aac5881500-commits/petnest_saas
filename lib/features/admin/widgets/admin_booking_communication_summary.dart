import '../../../core/models/booking_order_form_answers.dart';
import '../../../core/models/home_theme_model.dart';
import '../../../core/services/booking_form_visibility.dart';
import '../../custom_form/widgets/order_form_answers_view.dart';
import 'admin_booking_form_answers_section.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/safe_parse.dart';
import '../../../core/services/daycare_time_helper.dart';
import '../../booking/widgets/booking_detail/booking_detail_message_section.dart';
import 'admin_internal_handover_card.dart';

/// Staff-only overview; message read status changes only when opening the thread.
class AdminBookingCommunicationSummary extends StatelessWidget {
  const AdminBookingCommunicationSummary({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.booking,
    required this.readOnly,
  });
  final String shopId, bookingId;
  final Map<String, dynamic> booking;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final note = '${booking['note'] ?? ''}'.trim();
    final source = '${booking['adminOrderSource'] ?? ''}'.trim();
    final message = '${booking['lastMessageText'] ?? ''}'.trim();
    final unread =
        int.tryParse('${booking['shopUnreadMessageCount'] ?? 0}') ?? 0;
    final at = SafeParse.parseDate(booking['lastMessageAt']);
    final customer = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FF),
        border: Border.all(color: const Color(0xFFD7E2F5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined, size: 20),
              SizedBox(width: 8),
              Text(
                '客戶備註',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (source.isNotEmpty)
            Text('下單方式：$source', style: const TextStyle(fontSize: 12)),
          Text(
            note.isEmpty ? '無備註' : note,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.5),
          ),
          if (note.isNotEmpty)
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  scrollable: true,
                  title: const Text('客戶備註'),
                  content: Text(note, style: const TextStyle(height: 1.5)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('關閉'),
                    ),
                  ],
                ),
              ),
              child: const Text('查看完整備註'),
            ),
          const SizedBox(height: 12),
          const Text(
            '飼主提供',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
    final handover = AdminInternalHandoverCard(
      shopId: shopId,
      bookingId: bookingId,
      readOnly: readOnly,
      preview: true,
    );
    final messageCard = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 20),
              const Text('訂單留言', style: TextStyle(fontWeight: FontWeight.w800)),
              if (unread > 0)
                Text(
                  '新留言 $unread 則',
                  style: const TextStyle(
                    color: Color(0xFFB54747),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.isEmpty
                ? '目前沒有留言'
                : '${booking['lastMessageSenderType'] == 'shop' ? '店家' : '飼主'}：$message',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              if (at != null)
                Text(
                  DaycareTimeHelper.formatDateTimeOrUnrecorded(at),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('查看／回覆'),
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => Dialog(
                    insetPadding: const EdgeInsets.all(16),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: 900,
                      height: MediaQuery.sizeOf(context).height * .85,
                      child: Column(
                        children: [
                          const ListTile(
                            title: Text('訂單留言'),
                            trailing: CloseButton(),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: BookingDetailMessageSection(
                                bookingId: bookingId,
                                senderType: 'shop',
                                bookingStatus: '${booking['status'] ?? ''}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final desktop = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        handover,
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE1E4EE)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '飼主資訊與留言',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                '客戶備註、送單表單與訂單留言一起查看',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, bounds) => bounds.maxWidth >= 680
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: customer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AdminBookingCustomerFormCard(
                              booking: booking,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          customer,
                          const SizedBox(height: 12),
                          AdminBookingCustomerFormCard(booking: booking),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              messageCard,
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, bounds) => bounds.maxWidth < 680
          ? BookingCommunicationTabs(
              pages: [
                handover,
                customer,
                AdminBookingCustomerFormCard(booking: booking),
                messageCard,
              ],
              unread: unread,
            )
          : desktop,
    );
  }
}

/// The submitted snapshot remains read-only and follows the same visibility rules.
class AdminBookingCustomerFormCard extends StatelessWidget {
  const AdminBookingCustomerFormCard({super.key, required this.booking});
  final Map<String, dynamic> booking;
  @override
  Widget build(BuildContext context) {
    final raw =
        booking['customFormAnswers'] ??
        booking['bookingFormAnswers'] ??
        booking['formAnswers'];
    final petAnswers = BookingOrderFormAnswers.resolveByPetId(
      booking: booking,
      admin: false,
    );
    final visible = BookingFormVisibility.showCustomerSubmitForm(
      data: booking,
      hasAnswers: AdminBookingFormAnswersSection.hasVisibleAnswers(
        raw,
        petAnswersByPetId: petAnswers,
      ),
    );
    Widget answers() => OrderFormAnswersView(
      orderRaw: raw,
      petAnswersByPetId: petAnswers,
      pets: AdminBookingFormAnswersSection.petsOf(booking),
      theme: HomeThemeModel.classicDefault,
      orderTitle: '訂單資訊',
    );
    final count = AdminBookingFormAnswersSection.filledCount(
      raw,
      petAnswersByPetId: petAnswers,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F3),
        border: Border.all(color: const Color(0xFFE9DECA)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_outlined, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '飼主送單表單',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!visible)
            const Text('此訂單沒有飼主送單表單')
          else ...[
            Text(
              '已填 $count 題・飼主提供，僅供查看',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(child: answers()),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('查看完整表單'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    insetPadding: const EdgeInsets.all(16),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: 900,
                      height: MediaQuery.sizeOf(context).height * .85,
                      child: Column(
                        children: [
                          const ListTile(
                            title: Text('飼主送單表單・唯讀'),
                            trailing: CloseButton(),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: answers(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class BookingCommunicationTabs extends StatefulWidget {
  const BookingCommunicationTabs({
    super.key,
    required this.pages,
    this.unread = 0,
  });
  final List<Widget> pages;
  final int unread;
  @override
  State<BookingCommunicationTabs> createState() =>
      _BookingCommunicationTabsState();
}

class _BookingCommunicationTabsState extends State<BookingCommunicationTabs> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE1E4EE)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '交接與飼主資訊',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final entry in [
              '交接',
              '備註',
              '表單',
              widget.unread > 0 ? '留言 ${widget.unread}' : '留言',
            ].asMap().entries)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextButton(
                    onPressed: () => setState(() => selected = entry.key),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: const Size(0, 44),
                      backgroundColor: selected == entry.key
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                    ),
                    child: Text(entry.value, maxLines: 1),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 350),
          child: SingleChildScrollView(child: widget.pages[selected]),
        ),
      ],
    ),
  );
}

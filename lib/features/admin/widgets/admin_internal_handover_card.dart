import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/models/internal_handover_entry.dart';
import '../../../core/services/daycare_time_helper.dart';
import '../../../core/services/internal_handover_note_service.dart';
import 'internal_handover_composer.dart';

class AdminInternalHandoverCard extends StatefulWidget {
  const AdminInternalHandoverCard({
    super.key,
    required this.shopId,
    required this.bookingId,
    this.readOnly = false,
    this.compact = false,
    this.preview = false,
  });
  final String shopId, bookingId;
  final bool readOnly, compact, preview;
  @override
  State<AdminInternalHandoverCard> createState() =>
      _AdminInternalHandoverCardState();
}

class _AdminInternalHandoverCardState extends State<AdminInternalHandoverCard> {
  late final _current = InternalHandoverNoteService.instance.stream(
    shopId: widget.shopId,
    bookingId: widget.bookingId,
  );
  late final _history = InternalHandoverNoteService.instance.streamEntries(
    shopId: widget.shopId,
    bookingId: widget.bookingId,
  );

  void _open() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('內部交接・僅店家可見'), trailing: CloseButton()),
            Flexible(
              child: SingleChildScrollView(
                child: AdminInternalHandoverCard(
                  shopId: widget.shopId,
                  bookingId: widget.bookingId,
                  readOnly: widget.readOnly,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _current,
    builder: (context, current) => StreamBuilder<List<InternalHandoverEntry>>(
      stream: _history,
      builder: (context, history) {
        if (current.hasError || history.hasError) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('無法讀取店內交接，請確認連線與權限後重試。'),
          );
        }
        if (!current.hasData || !history.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }
        final entries = [...history.data!];
        final data = current.data?.data();
        if (data != null && '${data['text'] ?? ''}'.trim().isNotEmpty) {
          final latest = InternalHandoverEntry.fromMap('current', data);
          if (!entries.any((entry) => entry.revision == latest.revision)) {
            entries.insert(0, latest);
          }
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.preview ? const Color(0xFFFFF8EC) : Colors.white,
            border: Border.all(color: const Color(0xFFF0DAB4)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: Color(0xFF8B5A24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '內部交接（${entries.length}筆）',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (widget.preview)
                    TextButton.icon(
                      onPressed: _open,
                      icon: Icon(
                        widget.readOnly ? Icons.history : Icons.add,
                        size: 16,
                      ),
                      label: Text(widget.readOnly ? '查看全部' : '新增／查看'),
                    ),
                ],
              ),
              const Text(
                '僅店家可見',
                style: TextStyle(fontSize: 12, color: Color(0xFF8B5A24)),
              ),
              const SizedBox(height: 12),
              if (!widget.preview && !widget.readOnly) ...[
                InternalHandoverComposer(
                  onSave: (category, content) =>
                      InternalHandoverNoteService.instance.appendEntry(
                        shopId: widget.shopId,
                        bookingId: widget.bookingId,
                        category: category,
                        content: content,
                      ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  '交接紀錄・最新在上',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
              ],
              if (entries.isEmpty) const Text('尚無交接事項'),
              for (final entry in widget.preview ? entries.take(3) : entries)
                InternalHandoverEntryTile(
                  entry: entry,
                  preview: widget.preview,
                ),
              if (widget.preview && entries.length > 3)
                TextButton(
                  onPressed: _open,
                  child: Text('查看全部 ${entries.length} 筆交接'),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class InternalHandoverEntryTile extends StatelessWidget {
  const InternalHandoverEntryTile({
    super.key,
    required this.entry,
    this.preview = false,
  });
  final InternalHandoverEntry entry;
  final bool preview;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE9E5DD)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          entry.category,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF8B5A24),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          entry.content,
          maxLines: preview ? 3 : null,
          overflow: preview ? TextOverflow.ellipsis : null,
          style: const TextStyle(height: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          '${entry.author.isEmpty ? '原有紀錄' : entry.author}・${DaycareTimeHelper.formatDateTimeOrUnrecorded(entry.createdAt)}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    ),
  );
}

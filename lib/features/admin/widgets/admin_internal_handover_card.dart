// 檔案名稱：lib/features/admin/widgets/admin_internal_handover_card.dart
// 功能說明：內部交接備註卡片：衝突檢測、儲存提示、最後修改人。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/internal_handover_note_service.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';

class AdminInternalHandoverCard extends StatefulWidget {
  const AdminInternalHandoverCard({
    super.key,
    required this.shopId,
    required this.bookingId,
    this.readOnly = false,
  });

  final String shopId;
  final String bookingId;
  final bool readOnly;

  @override
  State<AdminInternalHandoverCard> createState() =>
      _AdminInternalHandoverCardState();
}

class _AdminInternalHandoverCardState extends State<AdminInternalHandoverCard>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _controller = TextEditingController();
  int _revision = 0;
  String _loadedText = '';
  String _meta = '';
  bool _saving = false;
  bool _initialized = false;

  bool get _dirty => _controller.text != _loadedText;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _errorText(Object error) {
    if (error is FirebaseException) {
      return '儲存失敗：[${error.plugin}/${error.code}] ${error.message ?? ''}\n'
          '路徑：shops/${widget.shopId}/internal_handover_notes/${widget.bookingId}';
    }
    return '儲存失敗：$error\n'
        '路徑：shops/${widget.shopId}/internal_handover_notes/${widget.bookingId}';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await InternalHandoverNoteService.instance.save(
        shopId: widget.shopId,
        bookingId: widget.bookingId,
        text: _controller.text,
        expectedRevision: _revision,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _loadedText = _controller.text;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('內部交接備註已儲存')));
    } on InternalHandoverConflictException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('其他員工剛更新過交接備註，請重新載入後再儲存。')));
    } on InternalHandoverLockedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('訂單已鎖定，內部交接備註無法再修改。')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorText(error))));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: InternalHandoverNoteService.instance.stream(
        shopId: widget.shopId,
        bookingId: widget.bookingId,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> data =
                snapshot.data?.data() ?? const <String, dynamic>{};
            final String remote = (data['text'] ?? '').toString();
            final int revision = (data['revision'] as num?)?.toInt() ?? 0;
            if (!_initialized || (_revision != revision && !_dirty)) {
              _loadedText = remote;
              _revision = revision;
              if (_controller.text != remote) {
                _controller.text = remote;
              }
              _initialized = true;
              final String email = (data['updatedByEmail'] ?? '').toString();
              final DateTime? at = SafeParse.parseDate(data['updatedAt']);
              if (email.isEmpty && at == null) {
                _meta = '尚未填寫';
              } else {
                final String when =
                    DaycareTimeHelper.formatDateTimeOrUnrecorded(at);
                _meta = email.isEmpty ? '最後修改：$when' : '最後修改：$email　$when';
              }
            }
            final bool locked = widget.readOnly;
            return AdminBookingDetailCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '內部交接備註（僅店家可見）',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locked ? '訂單已鎖定，內部交接備註為唯讀。' : '客戶交代、待辦、下一班注意事項。僅店內可見。',
                    style: TextStyle(fontSize: 12, color: theme.muted),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    maxLines: 6,
                    readOnly: locked,
                    decoration: InputDecoration(
                      hintText: '例如：明天接回前提前準備藥品',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _meta,
                    style: TextStyle(fontSize: 12, color: theme.muted),
                  ),
                  if (!locked) ...<Widget>[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? '儲存中…' : '儲存交接備註'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
    );
  }
}

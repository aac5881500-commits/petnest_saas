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
    this.compact = false,
  });

  final String shopId;
  final String bookingId;
  final bool readOnly;
  final bool compact;

  @override
  State<AdminInternalHandoverCard> createState() =>
      _AdminInternalHandoverCardState();
}

class _AdminInternalHandoverCardState extends State<AdminInternalHandoverCard>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _controller = TextEditingController();
  late final _stream = InternalHandoverNoteService.instance.stream(
    shopId: widget.shopId,
    bookingId: widget.bookingId,
  );
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
      return error.code == 'permission-denied'
          ? '目前帳號無法儲存這筆店內備註。'
          : '暫時無法儲存店內備註，請稍後再試。';
    }
    return '暫時無法儲存店內備註，請稍後再試。';
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
      stream: _stream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.hasError) {
              final error = snapshot.error;
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error is FirebaseException && error.code == 'permission-denied'
                      ? '目前無法存取店內備註。若店主也看不到，請確認店內交接的權限設定已上線。'
                      : '暫時無法載入店內備註，請重新開啟訂單再試。',
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              );
            }
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
                    widget.compact ? '用藥交接備註' : '內部交接備註（僅店家可見）',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locked
                        ? '店內交接紀錄'
                        : widget.compact
                        ? '店內可見。可記下貓名、藥名、每次用量、剩餘量和注意事項。'
                        : '客戶交代、待辦、下一班注意事項。僅店內可見。',
                    style: TextStyle(fontSize: 12, color: theme.muted),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: PageStorageKey('handover-input-${widget.bookingId}'),
                    controller: _controller,
                    minLines: widget.compact ? 3 : 5,
                    maxLines: 8,
                    maxLength: 4000,
                    readOnly: locked || _saving,
                    decoration: InputDecoration(
                      hintText: widget.compact
                          ? '例如：喵喵｜藥名｜每次用量與單位｜剩餘量｜注意事項'
                          : '例如：明天接回前提前準備藥品',
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
                        onPressed: _saving || !_dirty ? null : _save,
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

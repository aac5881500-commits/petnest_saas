// 檔案名稱：lib/features/shop/widgets/camera/shop_camera_access_panel.dart
// 功能說明：店主查看並處理外部品牌分享申請。進行中即時更新，已結束分頁載入。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:petnest_saas/core/models/camera_access_policy.dart';
import 'package:petnest_saas/core/models/camera_brand.dart';
import 'package:petnest_saas/core/services/camera_access_service.dart';
import 'package:petnest_saas/features/booking/widgets/camera_brand_launch.dart';

class ShopCameraAccessPanel extends StatefulWidget {
  const ShopCameraAccessPanel({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopCameraAccessPanel> createState() => _ShopCameraAccessPanelState();
}

class _ShopCameraAccessPanelState extends State<ShopCameraAccessPanel> {
  String _filter = cameraRequestFilterAll;
  String? _busyId;
  int _closedLimit = 20;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _active;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _closed;

  @override
  void initState() {
    super.initState();
    _bind(active: true, closed: true);
  }

  void _bind({required bool active, required bool closed}) {
    if (active) {
      _active = CameraAccessService.instance.watchShopActiveRequests(
        widget.shopId,
      );
    }
    if (closed) {
      _closed = CameraAccessService.instance.watchShopClosedRequests(
        widget.shopId,
        limit: _closedLimit,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _active,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> activeSnap,
          ) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _closed,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                    closedSnap,
                  ) {
                    if (activeSnap.hasError || closedSnap.hasError) {
                      return _Message(
                        title: '分享申請讀取失敗',
                        message: '請確認你有管理攝影機權限後再試。',
                        onRetry: () =>
                            setState(() => _bind(active: true, closed: true)),
                      );
                    }
                    if (!activeSnap.hasData || !closedSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    activeDocs = activeSnap.data!.docs;
                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    closedDocs = closedSnap.data!.docs;
                    final int pendingCount = activeDocs
                        .where(
                          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                              (doc.data()['status'] ?? '').toString() ==
                              cameraRequestPending,
                        )
                        .length;
                    final int revokeCount = activeDocs
                        .where(
                          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                              (doc.data()['status'] ?? '').toString() ==
                              cameraRequestRevocationPending,
                        )
                        .length;
                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    source = _filter == cameraRequestClosed
                        ? closedDocs
                        : (_filter == cameraRequestFilterAll
                              ? <QueryDocumentSnapshot<Map<String, dynamic>>>[
                                  ...activeDocs,
                                  ...closedDocs,
                                ]
                              : activeDocs);
                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    visible = source.where((
                      QueryDocumentSnapshot<Map<String, dynamic>> doc,
                    ) {
                      return cameraRequestMatchesFilter(
                        (doc.data()['status'] ?? '').toString(),
                        _filter,
                      );
                    }).toList();
                    visible.sort(_newestFirst);
                    return LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool desktop = constraints.maxWidth >= 900;
                            return ListView(
                              padding: EdgeInsets.fromLTRB(
                                desktop ? 24 : 16,
                                12,
                                desktop ? 24 : 16,
                                24,
                              ),
                              children: <Widget>[
                                Text(
                                  '待處理 $pendingCount　待取消分享 $revokeCount',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'PetNest 關閉入口不會自動移除原廠 App 的觀看權限，請至原廠 App 取消分享。',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    _chip('全部', cameraRequestFilterAll),
                                    _chip(
                                      '待處理 $pendingCount',
                                      cameraRequestPending,
                                    ),
                                    _chip('需補資料', cameraRequestNeedsInfo),
                                    _chip('已發送邀請', cameraRequestInvited),
                                    _chip('已確認可觀看', cameraRequestConfirmed),
                                    _chip(
                                      '待取消分享 $revokeCount',
                                      cameraRequestRevocationPending,
                                    ),
                                    _chip('已結束', cameraRequestClosed),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (visible.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 24),
                                    child: Text('此狀態目前沒有申請'),
                                  )
                                else
                                  ...visible.map((
                                    QueryDocumentSnapshot<Map<String, dynamic>>
                                    doc,
                                  ) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _RequestCard(
                                        data: doc.data(),
                                        busy: _busyId == doc.id,
                                        onAction:
                                            (String action, String reason) {
                                              return _run(
                                                doc.id,
                                                action,
                                                reason,
                                              );
                                            },
                                      ),
                                    );
                                  }),
                                if (_filter == cameraRequestFilterAll ||
                                    _filter == cameraRequestClosed)
                                  if (closedDocs.length >= _closedLimit)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _closedLimit += 20;
                                            _bind(active: false, closed: true);
                                          });
                                        },
                                        child: const Text('載入更多已結束紀錄'),
                                      ),
                                    ),
                              ],
                            );
                          },
                    );
                  },
            );
          },
    );
  }

  Widget _chip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _filter == value,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Future<void> _run(String requestId, String action, String reason) async {
    setState(() => _busyId = requestId);
    try {
      await CameraAccessService.instance.shopUpdate(
        shopId: widget.shopId,
        requestId: requestId,
        action: action,
        reason: reason,
      );
      if (!mounted) {
        return;
      }
      final String text = action == 'mark_invited'
          ? '已記錄為已發送邀請。請確認你已在原廠 App 手動分享。'
          : '申請狀態已更新';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } on CameraAccessException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }
}

int _newestFirst(
  QueryDocumentSnapshot<Map<String, dynamic>> left,
  QueryDocumentSnapshot<Map<String, dynamic>> right,
) {
  return _millis(
    right.data()['createdAt'],
  ).compareTo(_millis(left.data()['createdAt']));
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.data,
    required this.busy,
    required this.onAction,
  });

  final Map<String, dynamic> data;
  final bool busy;
  final Future<void> Function(String action, String reason) onAction;

  @override
  Widget build(BuildContext context) {
    final String status = (data['status'] ?? '').toString();
    final String account = (data['externalAccount'] ?? '').toString();
    final String provider = (data['provider'] ?? '').toString();
    final String brand = cameraBrandLabel(provider).isEmpty
        ? '未開放品牌'
        : cameraBrandLabel(provider);
    final String needs = (data['needsInfoReason'] ?? '').toString().trim();
    final String revoke = cameraSyncReasonLabel(
      (data['revocationReason'] ?? data['closeReason'] ?? '').toString(),
    );
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${(data['roomName'] ?? '').toString()}　${(data['customerName'] ?? '').toString()}　${(data['bookingKindLabel'] ?? '住宿').toString()}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text('$brand　${cameraRequestStatusLabel(status)}'),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '分享帳號 $account',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: account.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: account));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已複製分享帳號')),
                            );
                          }
                        },
                  child: const Text('複製'),
                ),
              ],
            ),
            Text(
              '期間 ${(data['servicePeriodLabel'] ?? '').toString()}　申請 ${_timeLabel(data['createdAt'])}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            if (needs.isNotEmpty && status == cameraRequestNeedsInfo)
              Text('補資料原因：$needs'),
            if (revoke.isNotEmpty &&
                (status == cameraRequestRevocationPending ||
                    status == cameraRequestClosed))
              Text(
                status == cameraRequestClosed ? '結束原因：$revoke' : '取消原因：$revoke',
              ),
            const SizedBox(height: 4),
            CameraBrandActions(providerId: provider),
            Wrap(
              spacing: 8,
              children: <Widget>[
                if (status == cameraRequestPending ||
                    status == cameraRequestNeedsInfo) ...<Widget>[
                  TextButton(
                    onPressed: busy ? null : () => onAction('mark_invited', ''),
                    child: const Text('已發送邀請'),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => _askInfo(context),
                    child: const Text('要求補資料'),
                  ),
                ],
                if (status == cameraRequestInvited ||
                    status == cameraRequestConfirmed)
                  TextButton(
                    onPressed: busy ? null : () => _confirmRemoved(context),
                    child: const Text('已取消分享'),
                  ),
                if (status == cameraRequestRevocationPending)
                  FilledButton(
                    onPressed: busy ? null : () => _confirmRemoved(context),
                    child: const Text('已取消分享'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _askInfo(BuildContext context) async {
    final TextEditingController reason = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('要求補資料'),
          content: TextField(
            controller: reason,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '請說明顧客要修正的內容'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, reason.text.trim()),
              child: const Text('送出'),
            ),
          ],
        );
      },
    );
    reason.dispose();
    if (value == null || !context.mounted) {
      return;
    }
    if (value.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請填寫需要顧客補充的說明')));
      return;
    }
    await onAction('needs_info', value);
  }

  Future<void> _confirmRemoved(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('確認已取消分享'),
          content: const Text('請確認你已到原廠 App 移除這組帳號的觀看權限。PetNest 不會自動移除原廠權限。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('我已在原廠 App 移除'),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      await onAction('mark_revoked', '');
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重試')),
          ],
        ),
      ),
    );
  }
}

String _timeLabel(Object? value) {
  if (value is Timestamp) {
    final DateTime time = value.toDate().toLocal();
    final String month = time.month.toString().padLeft(2, '0');
    final String day = time.day.toString().padLeft(2, '0');
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '${time.year}-$month-$day $hour:$minute';
  }
  return '時間未記錄';
}

int _millis(Object? value) {
  if (value is Timestamp) {
    return value.millisecondsSinceEpoch;
  }
  return 0;
}

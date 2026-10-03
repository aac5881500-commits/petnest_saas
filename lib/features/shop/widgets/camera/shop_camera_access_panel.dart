// 檔案名稱：lib/features/shop/widgets/camera/shop_camera_access_panel.dart
// 功能說明：店主查看並處理外部品牌分享申請。進行中即時更新，已結束分頁載入。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:petnest_saas/core/models/camera_access_policy.dart';
import 'package:petnest_saas/core/models/camera_brand.dart';
import 'package:petnest_saas/core/services/camera_access_service.dart';
import 'package:petnest_saas/core/services/shop_task_center_service.dart';
import 'package:petnest_saas/features/booking/widgets/camera_brand_launch.dart';

class ShopCameraAccessPanel extends StatefulWidget {
  const ShopCameraAccessPanel({
    super.key,
    required this.shopId,
    this.focusRequestId,
    this.initialFilter,
  });

  final String shopId;
  final String? focusRequestId;
  final String? initialFilter;

  @override
  State<ShopCameraAccessPanel> createState() => _ShopCameraAccessPanelState();
}

class _ShopCameraAccessPanelState extends State<ShopCameraAccessPanel> {
  static const String _filterOpen = 'open';
  late String _filter;
  String? _busyId;
  int _closedLimit = 20;
  int _activeGeneration = 0;
  int _closedGeneration = 0;
  bool _closedStarted = false;
  bool _focusScrolled = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _activeDocs;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _closedDocs;
  String _activeErrorCode = '';
  String _closedErrorCode = '';
  bool _activeLoading = true;
  bool _closedLoading = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activeSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _closedSub;
  final Map<String, GlobalKey> _cardKeys = <String, GlobalKey>{};

  bool get _wantsClosed {
    return _filter == cameraRequestClosed || _filter == cameraRequestFilterAll;
  }

  @override
  void initState() {
    super.initState();
    final String initial = (widget.initialFilter ?? '').trim();
    _filter = initial.isEmpty ? _filterOpen : initial;
    _listenActive();
    if (_wantsClosed) {
      _listenClosed();
    }
  }

  @override
  void didUpdateWidget(ShopCameraAccessPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) {
      _activeDocs = null;
      _closedDocs = null;
      _closedStarted = false;
      _focusScrolled = false;
      _listenActive();
      if (_wantsClosed) {
        _listenClosed();
      } else {
        _closedGeneration++;
        _closedSub?.cancel();
        _closedSub = null;
      }
    }
  }

  @override
  void dispose() {
    _activeGeneration++;
    _closedGeneration++;
    _activeSub?.cancel();
    _closedSub?.cancel();
    super.dispose();
  }

  void _listenActive() {
    final int generation = ++_activeGeneration;
    _activeSub?.cancel();
    _activeLoading = true;
    _activeErrorCode = '';
    _activeSub = CameraAccessService.instance
        .watchShopActiveRequests(widget.shopId)
        .listen(
          (QuerySnapshot<Map<String, dynamic>> snapshot) {
            if (!mounted || generation != _activeGeneration) {
              return;
            }
            setState(() {
              _activeDocs = snapshot.docs;
              _activeLoading = false;
              _activeErrorCode = '';
            });
            _revealFocus();
          },
          onError: (Object error) {
            if (!mounted || generation != _activeGeneration) {
              return;
            }
            final String code = firebaseFailureCode(error);
            debugPrint(
              'watchShopActiveRequests code=$code shopId=${widget.shopId} '
              'source=camera_access_requests.active',
            );
            setState(() {
              _activeLoading = false;
              _activeErrorCode = code;
            });
          },
        );
  }

  void _listenClosed() {
    final int generation = ++_closedGeneration;
    _closedStarted = true;
    _closedSub?.cancel();
    _closedLoading = true;
    _closedErrorCode = '';
    _closedSub = CameraAccessService.instance
        .watchShopClosedRequests(widget.shopId, limit: _closedLimit)
        .listen(
          (QuerySnapshot<Map<String, dynamic>> snapshot) {
            if (!mounted || generation != _closedGeneration) {
              return;
            }
            setState(() {
              _closedDocs = snapshot.docs;
              _closedLoading = false;
              _closedErrorCode = '';
            });
            _revealFocus();
          },
          onError: (Object error) {
            if (!mounted || generation != _closedGeneration) {
              return;
            }
            final String code = firebaseFailureCode(error);
            debugPrint(
              'watchShopClosedRequests code=$code shopId=${widget.shopId} '
              'source=camera_access_requests.closed limit=$_closedLimit',
            );
            setState(() {
              _closedLoading = false;
              _closedErrorCode = code;
            });
          },
        );
  }

  void _selectFilter(String value) {
    setState(() => _filter = value);
    if (_wantsClosed && !_closedStarted) {
      _listenClosed();
    }
  }

  void _revealFocus() {
    final String requestId = (widget.focusRequestId ?? '').trim();
    if (requestId.isEmpty || _focusScrolled) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusScrolled) {
        return;
      }
      final BuildContext? target = _cardKeys[requestId]?.currentContext;
      if (target == null) {
        return;
      }
      _focusScrolled = true;
      Scrollable.ensureVisible(
        target,
        alignment: 0.2,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  GlobalKey _keyFor(String id) {
    return _cardKeys.putIfAbsent(id, GlobalKey.new);
  }

  @override
  Widget build(BuildContext context) {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> activeDocs =
        _activeDocs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> closedDocs =
        _closedDocs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final int pendingCount = _activeDocs == null
        ? 0
        : activeDocs
              .where(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    (doc.data()['status'] ?? '').toString() ==
                    cameraRequestPending,
              )
              .length;
    final int revokeCount = _activeDocs == null
        ? 0
        : activeDocs
              .where(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    (doc.data()['status'] ?? '').toString() ==
                    cameraRequestRevocationPending,
              )
              .length;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
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
              _activeLoading
                  ? '進行中的申請讀取中'
                  : (_activeErrorCode.isNotEmpty
                        ? '進行中的申請暫時無法計數'
                        : '待邀請 $pendingCount　待取消分享 $revokeCount'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'PetNest 標記處理狀態不會自動變更原廠 App 的觀看權限，邀請與取消仍需在原廠 App 手動完成。',
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
                _chip('進行中', _filterOpen),
                _chip('全部', cameraRequestFilterAll),
                _chip(
                  _activeDocs == null ? '待邀請' : '待邀請 $pendingCount',
                  cameraRequestPending,
                ),
                _chip('需補資料', cameraRequestNeedsInfo),
                _chip('已發送邀請', cameraRequestInvited),
                _chip('已確認可觀看', cameraRequestConfirmed),
                _chip(
                  _activeDocs == null ? '待取消分享' : '待取消分享 $revokeCount',
                  cameraRequestRevocationPending,
                ),
                _chip('已結束', cameraRequestClosed),
              ],
            ),
            const SizedBox(height: 12),
            if (_filter == cameraRequestFilterAll) ...<Widget>[
              const Text('進行中', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ..._activeSection(activeDocs),
              const SizedBox(height: 16),
              Text(
                '已載入的歷史紀錄（最近 $_closedLimit 筆，不是全部已結束申請）',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ..._closedSection(closedDocs),
            ] else if (_filter == cameraRequestClosed)
              ..._closedSection(closedDocs)
            else if (_filter == _filterOpen)
              ..._activeSection(activeDocs)
            else
              ..._activeSection(
                activeDocs.where((
                  QueryDocumentSnapshot<Map<String, dynamic>> doc,
                ) {
                  return (doc.data()['status'] ?? '').toString() == _filter;
                }).toList(),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _activeSection(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (_activeLoading && _activeDocs == null) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_activeErrorCode.isNotEmpty) {
      return <Widget>[
        _Message(
          title: '進行中的申請讀取失敗',
          message: cameraAccessQueryErrorMessage(
            code: _activeErrorCode,
            source: '進行中的分享申請',
          ),
          onRetry: () => setState(_listenActive),
        ),
      ];
    }
    return _cards(docs, emptyText: '此狀態目前沒有進行中的申請');
  }

  List<Widget> _closedSection(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (!_closedStarted || _closedLoading && _closedDocs == null) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_closedErrorCode.isNotEmpty) {
      return <Widget>[
        _Message(
          title: '已結束紀錄讀取失敗',
          message: cameraAccessQueryErrorMessage(
            code: _closedErrorCode,
            source: '已結束的分享申請',
          ),
          onRetry: () => setState(_listenClosed),
        ),
      ];
    }
    final List<Widget> cards = _cards(docs, emptyText: '目前沒有已載入的結束紀錄');
    if (docs.length >= _closedLimit) {
      cards.add(
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              setState(() {
                _closedLimit += 20;
              });
              _listenClosed();
            },
            child: const Text('載入更多已結束紀錄'),
          ),
        ),
      );
    }
    return cards;
  }

  List<Widget> _cards(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String emptyText,
  }) {
    if (docs.isEmpty) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(emptyText),
        ),
      ];
    }
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> visible =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
          ..sort(_newestFirst);
    return visible.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final String focusId = (widget.focusRequestId ?? '').trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: KeyedSubtree(
          key: _keyFor(doc.id),
          child: _RequestCard(
            data: doc.data(),
            busy: _busyId == doc.id,
            highlighted: focusId.isNotEmpty && focusId == doc.id,
            onAction: (String action, String reason) {
              return _run(doc.id, action, reason);
            },
          ),
        ),
      );
    }).toList();
  }

  Widget _chip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _filter == value,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => _selectFilter(value),
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
    this.highlighted = false,
  });

  final Map<String, dynamic> data;
  final bool busy;
  final bool highlighted;
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
      color: highlighted ? const Color(0xFFFFF7ED) : Colors.white,
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

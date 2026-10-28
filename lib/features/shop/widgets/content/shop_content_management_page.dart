import 'package:petnest_saas/core/services/announcement_notification.dart';
import 'package:petnest_saas/core/services/shop_campaign_service.dart';
import 'package:petnest_saas/features/shop/pages/campaigns/campaign_entry_button.dart';
import 'package:petnest_saas/features/shop/pages/campaigns/shop_campaign_center_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_content_order.dart';
import '../shop_dashboard_navigation.dart';
import 'shop_content_editor_dialog.dart';

enum ShopContentKind { faq, announcement }

/// FAQ and announcement management share the same loading, writing and draft
/// lifecycle. Their public page wrappers keep existing navigation unchanged.
class ShopContentManagementPage extends StatefulWidget {
  const ShopContentManagementPage({
    super.key,
    required this.shopId,
    required this.kind,
  });
  final String shopId;
  final ShopContentKind kind;

  @override
  State<ShopContentManagementPage> createState() =>
      _ShopContentManagementPageState();
}

class _ShopContentManagementPageState extends State<ShopContentManagementPage>
    with ShopDashboardLeaveAware<ShopContentManagementPage> {
  late DocumentReference<Map<String, dynamic>> _shop;
  late CollectionReference<Map<String, dynamic>> _items;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _shopStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _itemsStream;
  bool _busy = false;
  bool _dialogOpen = false;

  bool get _isFaq => widget.kind == ShopContentKind.faq;
  String get _noun => _isFaq ? '常見問題' : '公告';
  String get _visibilityKey =>
      _isFaq ? 'showFaqSection' : 'showAnnouncementSection';
  @override
  bool get dashboardHasUnsavedChanges => false;
  @override
  bool get dashboardIsBusy => _busy || _dialogOpen;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant ShopContentManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId || oldWidget.kind != widget.kind) {
      _busy = false;
      _dialogOpen = false;
      _connect();
    }
  }

  void _connect() {
    _shop = FirebaseFirestore.instance.collection('shops').doc(widget.shopId);
    _items = _shop.collection(_isFaq ? 'faqs' : 'announcements');
    _shopStream = _shop.snapshots();
    _itemsStream = _items.snapshots();
  }

  void _retry() => setState(_connect);

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _write(Future<void> Function() action, String success) async {
    if (_busy || _dialogOpen) return;
    final shopId = widget.shopId;
    final kind = widget.kind;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && widget.shopId == shopId && widget.kind == kind) {
        _message(success);
      }
    } catch (_) {
      if (mounted && widget.shopId == shopId && widget.kind == kind) {
        _message('操作失敗，請確認網路與權限後重試。');
      }
    } finally {
      if (mounted && widget.shopId == shopId && widget.kind == kind) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _edit([
    QueryDocumentSnapshot<Map<String, dynamic>>? document,
  ]) async {
    if (_busy || _dialogOpen) return;
    final shopId = widget.shopId;
    final kind = widget.kind;
    final isFaq = _isFaq;
    final items = _items;
    // Allocate once per editor. Retrying after an uncertain write acknowledgement
    // updates this same document instead of creating duplicate content.
    final target = document?.reference ?? items.doc();
    final data = document?.data() ?? <String, dynamic>{};
    num? newSortOrder;
    ShopContentDraft? savedDraft;
    bool notificationQueued = false;
    final notification = AnnouncementNotification(
      (action, payload) =>
          ShopCampaignService.instance.call(shopId, action, payload),
      items.doc().id,
    );
    setState(() => _dialogOpen = true);
    try {
      bool canNotify = false;
      if (!isFaq) {
        try {
          final access = await ShopCampaignService.instance.call(
            shopId,
            'bootstrap',
          );
          canNotify = (access['permissions'] as Map?)?['send'] == true;
        } catch (_) {
          // Announcement publishing stays available if notification service is offline.
        }
      }
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ShopContentEditorDialog(
          isFaq: isFaq,
          canNotify: canNotify,
          isNew: document == null,
          initial: ShopContentDraft(
            title: data[isFaq ? 'question' : 'title']?.toString() ?? '',
            body: data[isFaq ? 'answer' : 'content']?.toString() ?? '',
            isPublished: document == null || data['isPublished'] == true,
            type: data['type']?.toString() ?? 'normal',
          ),
          onSave: (draft) async {
            if (document == null && isFaq && newSortOrder == null) {
              final snapshot = await items.get(
                const GetOptions(source: Source.server),
              );
              newSortOrder = nextShopFaqSortOrder(
                snapshot.docs.map((doc) => doc.data()['sortOrder']),
              );
            }
            final updates = <String, dynamic>{
              isFaq ? 'question' : 'title': draft.title,
              isFaq ? 'answer' : 'content': draft.body,
              'isPublished': draft.isPublished,
              if (!isFaq) 'type': draft.type,
              'updatedAt': FieldValue.serverTimestamp(),
            };
            if (document == null) {
              await target.set({
                ...updates,
                if (isFaq) 'sortOrder': newSortOrder,
                if (!isFaq) 'isPinned': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
            } else {
              await target.update(updates);
            }
            savedDraft = draft;
            if (!isFaq && draft.notifyMembers) {
              try {
                notificationQueued = await notification.submit(
                  announcementId: target.id,
                  title: draft.title,
                  body: draft.body,
                  type: draft.type,
                  channel: draft.notificationChannel,
                  confirm: (preview) async {
                    if (!mounted) return false;
                    return await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (dialogContext) => AlertDialog(
                            scrollable: true,
                            title: const Text('公告已發布・確認會員通知'),
                            content: SizedBox(
                              width: 480,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${preview['title']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text('${preview['body']}'),
                                  const Divider(height: 24),
                                  Text('通知全店符合資格的會員：${preview['count']} 位'),
                                  Text(
                                    '排除 ${preview['excluded']} 位未綁定、停用或不符合資格的會員。',
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    preview['channel'] == 'push'
                                        ? 'App 通知＋手機通知列提醒（依會員與裝置設定）'
                                        : '只放入 App 通知中心',
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('取消通知不會撤下已發布的公告；通知草稿可在推廣中心繼續編輯。'),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('只保留公告與通知草稿'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: Text('確認通知 ${preview['count']} 位'),
                              ),
                            ],
                          ),
                        ) ==
                        true;
                  },
                );
              } catch (error) {
                throw AnnouncementNotificationException(
                  '公告已發布，會員通知尚未確認完成。${error is AnnouncementNotificationException ? error.message : ShopCampaignService.error(error)} 可重試此筆操作；同一通知不會重複發送。',
                );
              }
            }
          },
        ),
      );
      if (saved == true &&
          mounted &&
          widget.shopId == shopId &&
          widget.kind == kind) {
        if (!isFaq && savedDraft?.isPublished == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                notificationQueued
                    ? '公告已發布，會員通知已排入發送。可到推廣中心查看紀錄。'
                    : savedDraft!.notifyMembers
                    ? notification.lastRecipientCount == 0
                          ? '公告已發布，目前沒有可通知會員；通知草稿已保留。'
                          : '公告已發布，通知尚未發送；草稿已保留在推廣中心。'
                    : '公告已發布，未發送會員通知。',
              ),
              action: SnackBarAction(
                label: notificationQueued || savedDraft!.notifyMembers
                    ? '查看紀錄'
                    : '通知會員',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ShopCampaignCenterPage(
                      shopId: shopId,
                      announcementId:
                          notificationQueued || savedDraft!.notifyMembers
                          ? null
                          : target.id,
                      filterAnnouncementId:
                          notificationQueued || savedDraft!.notifyMembers
                          ? target.id
                          : null,
                      initialTitle: savedDraft!.title,
                      initialBody: savedDraft!.body,
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          _message('$_noun已儲存');
        }
      }
    } finally {
      if (mounted && widget.shopId == shopId && widget.kind == kind) {
        setState(() => _dialogOpen = false);
      }
    }
  }

  Future<void> _delete(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    if (_busy || _dialogOpen) return;
    final shopId = widget.shopId;
    final kind = widget.kind;
    final title =
        document.data()[_isFaq ? 'question' : 'title']?.toString() ?? _noun;
    setState(() => _dialogOpen = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text('刪除$_noun'),
        content: Text('確定要刪除「$title」嗎？\n\n刪除後無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('確認刪除'),
          ),
        ],
      ),
    );
    if (!mounted || widget.shopId != shopId || widget.kind != kind) return;
    setState(() => _dialogOpen = false);
    if (confirmed == true) await _write(document.reference.delete, '$_noun已刪除');
  }

  Future<void> _move(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
    int from,
    int to,
  ) async {
    final ranks = movedShopFaqRanks(
      documents.map((doc) => doc.id).toList(),
      from,
      to,
    );
    await _write(() async {
      final batch = FirebaseFirestore.instance.batch();
      for (final document in documents) {
        final rank = ranks[document.id]!;
        if (document.data()['sortOrder'] == rank) continue;
        batch.update(document.reference, {
          'sortOrder': rank,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }, '排序已更新');
  }

  Widget _error(String message) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _retry,
          icon: const Icon(Icons.refresh),
          label: const Text('重試'),
        ),
      ],
    ),
  );

  Widget _visibility() => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _shopStream,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _error('前台顯示設定讀取失敗。');
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        );
      }
      if (!snapshot.data!.exists) return _error('找不到店家，請重新確認。');
      final data = snapshot.data!.data()!;
      final title = _isFaq ? '前台顯示常見問題' : '前台顯示公告欄';
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: SwitchListTile.adaptive(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(_isFaq ? '關閉後，前台首頁不會顯示常見問題入口。' : '關閉後，前台首頁不會顯示公告區塊。'),
          value: data[_visibilityKey] != false,
          onChanged: _busy || _dialogOpen
              ? null
              : (value) {
                  final shop = _shop;
                  final key = _visibilityKey;
                  _write(
                    () => shop.update({
                      key: value,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }),
                    '前台顯示設定已更新',
                  );
                },
        ),
      );
    },
  );

  Widget _list() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _itemsStream,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: _error('$_noun讀取失敗。'));
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final docs = snapshot.data!.docs.toList();
      docs.sort((a, b) {
        final first = a.data();
        final second = b.data();
        if (_isFaq) {
          return compareShopFaqOrder(
            firstId: a.id,
            firstOrder: first['sortOrder'],
            secondId: b.id,
            secondOrder: second['sortOrder'],
          );
        }
        final firstPinned = first['isPinned'] == true;
        final secondPinned = second['isPinned'] == true;
        if (firstPinned != secondPinned) return firstPinned ? -1 : 1;
        final firstRawTime = first['createdAt'];
        final secondRawTime = second['createdAt'];
        final firstTime = firstRawTime is Timestamp
            ? firstRawTime.millisecondsSinceEpoch
            : -1;
        final secondTime = secondRawTime is Timestamp
            ? secondRawTime.millisecondsSinceEpoch
            : -1;
        final result = secondTime.compareTo(firstTime);
        if (result != 0) return result;
        return a.id.compareTo(b.id);
      });
      if (docs.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isFaq ? Icons.quiz_outlined : Icons.campaign_outlined,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text('目前尚無$_noun'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy || _dialogOpen ? null : _edit,
                  icon: const Icon(Icons.add),
                  label: Text('新增$_noun'),
                ),
              ],
            ),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: docs.length,
        itemBuilder: (context, index) => _card(docs, index),
      );
    },
  );

  Widget _card(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int index,
  ) {
    final doc = docs[index];
    final data = doc.data();
    final title =
        data[_isFaq ? 'question' : 'title']?.toString() ?? '未命名$_noun';
    final body = data[_isFaq ? 'answer' : 'content']?.toString() ?? '';
    final published = data['isPublished'] == true;
    final pinned = data['isPinned'] == true;
    final type = shopAnnouncementType(data['type']);
    final disabled = _busy || _dialogOpen;
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey(doc.id),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: disabled ? null : () => _edit(doc),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        published ? '已上架' : '未上架',
                        style: TextStyle(
                          color: published
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                      if (!_isFaq) Text(type.label),
                      if (pinned && !_isFaq) const Text('置頂'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(body, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch.adaptive(
                      value: published,
                      onChanged: disabled
                          ? null
                          : (value) => _write(
                              () => doc.reference.update({
                                'isPublished': value,
                                'updatedAt': FieldValue.serverTimestamp(),
                              }),
                              value ? '$_noun已上架' : '$_noun已下架',
                            ),
                    ),
                    const Text('上架'),
                  ],
                ),
                if (_isFaq) ...[
                  IconButton(
                    tooltip: '上移',
                    onPressed: disabled || index == 0
                        ? null
                        : () => _move(docs, index, index - 1),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: '下移',
                    onPressed: disabled || index == docs.length - 1
                        ? null
                        : () => _move(docs, index, index + 1),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                ] else
                  TextButton.icon(
                    onPressed: disabled
                        ? null
                        : () => _write(
                            () => doc.reference.update({
                              'isPinned': !pinned,
                              'updatedAt': FieldValue.serverTimestamp(),
                            }),
                            pinned ? '已取消置頂' : '公告已置頂',
                          ),
                    icon: Icon(
                      pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 18,
                    ),
                    label: Text(pinned ? '取消置頂' : '置頂'),
                  ),
                if (!_isFaq && published)
                  CampaignEntryButton(
                    shopId: widget.shopId,
                    announcementId: doc.id,
                    historyOnly: true,
                    label: '通知紀錄',
                  ),
                if (!_isFaq && published)
                  CampaignEntryButton(
                    shopId: widget.shopId,
                    announcementId: doc.id,
                    title: title,
                    body: body.length > 2000 ? body.substring(0, 2000) : body,
                    label: '通知會員',
                  ),
                TextButton.icon(
                  onPressed: disabled ? null : () => _edit(doc),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('編輯'),
                ),
                TextButton.icon(
                  onPressed: disabled ? null : () => _delete(doc),
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('刪除'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => dashboardGuard(
    Scaffold(
      appBar: AppBar(
        title: Text('$_noun管理'),
        actions: [
          IconButton(
            tooltip: '新增$_noun',
            icon: const Icon(Icons.add),
            onPressed: _busy || _dialogOpen ? null : _edit,
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              _visibility(),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(child: _list()),
            ],
          ),
        ),
      ),
    ),
  );
}

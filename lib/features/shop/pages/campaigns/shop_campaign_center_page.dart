import 'dart:async';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_campaign_service.dart';
import 'shop_campaign_editor_page.dart';

typedef CampaignApi =
    Future<Map<String, dynamic>> Function(
      String action,
      Map<String, dynamic> data,
    );

class ShopCampaignCenterPage extends StatefulWidget {
  const ShopCampaignCenterPage({
    super.key,
    required this.shopId,
    this.initialMemberId,
    this.announcementId,
    this.initialTitle,
    this.initialBody,
    this.api,
    this.filterAnnouncementId,
  });
  final String shopId;
  final String? initialMemberId, announcementId, initialTitle, initialBody;
  final CampaignApi? api;
  final String? filterAnnouncementId;
  @override
  State<ShopCampaignCenterPage> createState() => _ShopCampaignCenterPageState();
}

class _ShopCampaignCenterPageState extends State<ShopCampaignCenterPage> {
  Map<String, dynamic>? _data;
  Object? _error;
  bool _loading = true;
  Timer? _timer;
  bool _inFlight = false;
  String _filter = 'all';
  Future<Map<String, dynamic>> _call(
    String action,
    Map<String, dynamic> data,
  ) => widget.api != null
      ? widget.api!(action, data)
      : ShopCampaignService.instance.call(widget.shopId, action, data);
  @override
  void initState() {
    super.initState();
    _load(openInitial: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool openInitial = false}) async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final data = await _call('bootstrap', {});
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });
      final jobs = (data['campaigns'] as List? ?? []).whereType<Map>();
      _timer?.cancel();
      if (jobs.any((job) => ['queued', 'processing'].contains(job['status']))) {
        _timer = Timer(const Duration(seconds: 10), () => _load());
      }
      if (openInitial &&
          (widget.initialMemberId != null || widget.announcementId != null) &&
          _canDraft) {
        await _edit();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    } finally {
      _inFlight = false;
    }
  }

  bool get _canDraft => (_data?['permissions'] as Map?)?['draft'] == true;
  Future<void> _edit([Map<String, dynamic>? draft]) async {
    _timer?.cancel();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShopCampaignEditorPage(
          shopId: widget.shopId,
          api: _call,
          canSend: (_data?['permissions'] as Map?)?['send'] == true,
          draft: draft,
          initialMemberId: draft == null ? widget.initialMemberId : null,
          announcementId: draft == null ? widget.announcementId : null,
          initialTitle: widget.initialTitle,
          initialBody: widget.initialBody,
        ),
      ),
    );
    // Clear the request flag before reloading after the initial editor returns.
    if (mounted) {
      _inFlight = false;
      await _load();
    }
  }

  Future<void> _detail(Map<String, dynamic> job) async {
    try {
      final detail = await _call('detail', {'campaignId': job['id']});
      if (!mounted) return;
      final record = Map<String, dynamic>.from(detail['campaign'] as Map);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .8,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '${record['title']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text('${record['body']}'),
                const Divider(height: 32),
                Text('發送人：${record['senderName'] ?? record['sentBy'] ?? ''}'),
                Text(
                  '對象 ${record['recipientCount']} 位 · 排除 ${record['excludedCount']} 位',
                ),
                Text('狀態：${campaignStatusLabel('${record['status']}')}'),
                const SizedBox(height: 12),
                for (final entry in (record['counts'] as Map? ?? {}).entries)
                  Text('${deliveryLabel('${entry.key}')}：${entry.value}'),
                const SizedBox(height: 12),
                const Text('推播「受理」代表服務商接受請求，不代表裝置收到或會員已讀。狀態不明不會自動重推，避免重複打擾。'),
                const Divider(height: 32),
                const Text(
                  '收件處理明細（最多 100 筆）',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final raw in detail['deliveries'] as List? ?? [])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('會員 ${raw['uid']}'),
                    subtitle: Text(
                      '${raw['inbox'] == 'created' ? '站內通知已建立' : '已略過'} · ${deliveryLabel('${raw['push']}')}\n${raw['reason'] ?? ''}',
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ShopCampaignService.error(error))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobs = (_data?['campaigns'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final shown = jobs
        .where(
          (job) =>
              widget.filterAnnouncementId == null ||
              job['announcementId'] == widget.filterAnnouncementId,
        )
        .where(
          (job) =>
              _filter == 'all' ||
              (_filter == 'draft'
                  ? job['status'] == 'draft'
                  : job['status'] != 'draft'),
        )
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('會員推廣與通知'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _canDraft
          ? FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('新增推廣／通知'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ShopCampaignService.error(_error!)),
                    TextButton(
                      onPressed: () => _load(),
                      child: const Text('重新載入'),
                    ),
                  ],
                ),
              ),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  children: [
                    const Text(
                      '把合適的消息，送給自己的會員',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '公告發布時可同步設定全會員通知；指定個別會員或 VIP 可在這裡建立。訂單與入住提醒由系統自動處理。下方顯示最近 100 筆紀錄。',
                      style: TextStyle(height: 1.6),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in const {
                          'all': '全部',
                          'draft': '草稿',
                          'sent': '發送紀錄',
                        }.entries)
                          ChoiceChip(
                            label: Text(item.value),
                            selected: _filter == item.key,
                            onSelected: (_) =>
                                setState(() => _filter = item.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (shown.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.campaign_outlined, size: 40),
                              SizedBox(height: 12),
                              Text('目前沒有推廣或通知'),
                              SizedBox(height: 6),
                              Text(
                                '可從這裡建立，也可從已上架公告或會員詳細頁開始。',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final job in shown)
                      Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Icon(
                            job['category'] == 'shop_notice'
                                ? Icons.notifications_outlined
                                : Icons.campaign_outlined,
                          ),
                          title: Text(
                            '${job['title']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${campaignStatusLabel('${job['status']}')} · ${job['channel'] == 'push' ? '站內＋推播' : '站內通知'}\n${job['status'] == 'draft' ? '尚未送出' : '對象 ${job['recipientCount']} 位 · 站內已建立 ${(job['counts'] as Map?)?['inbox'] ?? 0} 筆'}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: job['status'] == 'draft' && _canDraft
                              ? () => _edit(job)
                              : () => _detail(job),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

String campaignStatusLabel(String status) =>
    const {
      'draft': '草稿',
      'queued': '等待發送',
      'processing': '處理中',
      'completed': '處理完成',
    }[status] ??
    status;
String deliveryLabel(String state) =>
    const {
      'inbox': '站內通知已建立',
      'skipped': '略過會員',
      'accepted': '推播已受理',
      'partial': '部分裝置受理',
      'opted_out': '會員已關閉此類推播',
      'no_token': '沒有可用裝置',
      'failed': '推播未受理',
      'unknown': '推播結果不明',
      'attempting': '推播結果確認中',
      'not_requested': '未要求推播',
    }[state] ??
    state;

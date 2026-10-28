import 'package:petnest_saas/core/services/announcement_notification.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_campaign_service.dart';
import 'shop_campaign_center_page.dart';

class ShopCampaignEditorPage extends StatefulWidget {
  const ShopCampaignEditorPage({
    super.key,
    required this.shopId,
    required this.api,
    required this.canSend,
    this.draft,
    this.initialMemberId,
    this.announcementId,
    this.initialTitle,
    this.initialBody,
  });
  final String shopId;
  final CampaignApi api;
  final bool canSend;
  final Map<String, dynamic>? draft;
  final String? initialMemberId, announcementId, initialTitle, initialBody;
  @override
  State<ShopCampaignEditorPage> createState() => _ShopCampaignEditorPageState();
}

class _ShopCampaignEditorPageState extends State<ShopCampaignEditorPage>
    with ShopDashboardLeaveAware<ShopCampaignEditorPage> {
  @override
  bool get dashboardHasUnsavedChanges => _dirty;
  @override
  bool get dashboardIsBusy => _busy;
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _body;
  late final String _id;
  late String _category, _channel, _audience, _announcement;
  int _version = 0;
  final Set<String> _selected = {};
  bool _busy = false,
      _confirming = false,
      _dirty = false,
      _allowLeave = false,
      _membersLoading = true;
  List<Map<String, dynamic>> _members = [];
  String _search = '';
  Object? _membersError;
  @override
  void initState() {
    super.initState();
    final d = widget.draft ?? {};
    _id =
        d['id']?.toString() ??
        List.generate(
          28,
          (_) =>
              'abcdefghijklmnopqrstuvwxyz0123456789'[Random.secure().nextInt(
                36,
              )],
        ).join();
    _title = TextEditingController(
      text: AnnouncementNotification.excerpt(
        '${d['title'] ?? widget.initialTitle ?? ''}',
        80,
      ),
    );
    _body = TextEditingController(
      text: AnnouncementNotification.excerpt(
        '${d['body'] ?? widget.initialBody ?? ''}',
        2000,
      ),
    );
    _version = (d['version'] as num?)?.toInt() ?? 0;
    _category =
        '${d['category'] ?? (widget.announcementId != null ? 'shop_notice' : 'shop_marketing')}';
    _channel = '${d['channel'] ?? 'inbox'}';
    _audience =
        '${d['audience'] ?? (widget.initialMemberId != null ? 'selected' : 'all')}';
    _announcement = '${d['announcementId'] ?? widget.announcementId ?? ''}';
    _selected.addAll((d['memberIds'] as List? ?? []).map((e) => e.toString()));
    if (widget.initialMemberId != null) _selected.add(widget.initialMemberId!);
    _loadMembers();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final result = await widget.api('members', {});
      if (mounted) {
        setState(() {
          _members = (result['members'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _membersLoading = false;
          _membersError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _membersError = error;
          _membersLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> get _draft => {
    'title': _title.text.trim(),
    'body': _body.text.trim(),
    'category': _category,
    'channel': _channel,
    'audience': _audience,
    'memberIds': _selected.toList(),
    'announcementId': _announcement,
  };
  void _changed() => setState(() => _dirty = true);
  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  void _close() {
    setState(() {
      _allowLeave = true;
      _busy = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _save({bool preview = false}) async {
    if (_busy || _form.currentState?.validate() != true) return;
    if (_audience == 'selected' && _selected.isEmpty) {
      _message('請至少勾選一位會員。');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await widget.api(preview ? 'preview' : 'save', {
        'campaignId': _id,
        'version': _version,
        'draft': _draft,
      });
      if (!mounted) return;
      _version = ((result['campaign'] as Map)['version'] as num).toInt();
      setState(() => _dirty = false);
      if (!preview) {
        _message('草稿已儲存，尚未發送。');
        return;
      }
      final summary = Map<String, dynamic>.from(result['preview'] as Map);
      final count = (summary['count'] as num).toInt();
      setState(() => _confirming = true);
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('預覽與確認發送'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_body.text),
                  const Divider(height: 28),
                  Text(
                    '可通知 $count 位會員',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text('排除 ${summary['excluded']} 位：手動會員、停用帳號或不符合通知資格。'),
                  const SizedBox(height: 8),
                  Text(
                    _channel == 'push'
                        ? '建立站內通知，並依會員通知設定嘗試手機推播。'
                        : '僅建立站內通知，不發送手機推播。',
                  ),
                  const SizedBox(height: 8),
                  const Text('推廣與服務通知都不會標記為強制通知；手機推播受會員設定與裝置狀態影響。'),
                  if (count == 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        '沒有可通知會員，請返回調整對象。',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('返回調整'),
            ),
            FilledButton(
              onPressed: count > 0 ? () => Navigator.pop(context, true) : null,
              child: Text('確認發送給 $count 位'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      setState(() => _confirming = false);
      await widget.api('send', {
        'campaignId': _id,
        'revision': summary['revision'],
      });
      if (mounted) {
        _message('已建立發送工作，可在發送紀錄查看處理結果。');
        _close();
      }
    } catch (error) {
      if (mounted) _message(ShopCampaignService.error(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  Widget _section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final filtered = _members
        .where(
          (m) => '${m['name']} ${m['phone']}'.toLowerCase().contains(
            _search.toLowerCase(),
          ),
        )
        .toList();
    return PopScope(
      canPop: _allowLeave || (!_busy && !_dirty),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _busy) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('離開未儲存的草稿？'),
            content: const Text('尚未儲存的內容會捨棄。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('繼續編輯'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('捨棄並離開'),
              ),
            ],
          ),
        );
        if (leave == true && mounted) _close();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        appBar: AppBar(title: const Text('編輯推廣／通知')),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : () => _save(),
                  child: const Text('儲存草稿'),
                ),
                if (widget.canSend)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _save(preview: true),
                    icon: _busy && !_confirming
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.visibility_outlined),
                    label: const Text('預覽並發送'),
                  ),
              ],
            ),
          ),
        ),
        body: IgnorePointer(
          ignoring: _busy,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (!widget.canSend)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('你可編輯草稿；正式發送需由店主或具發送權限的人員執行。'),
                      ),
                    _section('1. 通知內容', [
                      if (_announcement.isNotEmpty)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.link),
                          title: const Text('引用已發布公告'),
                          subtitle: const Text('發送前會再次檢查上架狀態。通知會保留本次內容快照。'),
                          trailing: IconButton(
                            tooltip: '解除公告引用',
                            onPressed: () {
                              _announcement = '';
                              _changed();
                            },
                            icon: const Icon(Icons.link_off),
                          ),
                        ),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: '分類',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'shop_marketing',
                            child: Text('會員推廣／活動優惠'),
                          ),
                          DropdownMenuItem(
                            value: 'shop_notice',
                            child: Text('店家公告／營業異動'),
                          ),
                        ],
                        onChanged: (v) {
                          _category = v!;
                          _changed();
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _title,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: '通知標題 *',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _changed(),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? '請輸入標題' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _body,
                        minLines: 5,
                        maxLines: 10,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: '通知內容 *',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _changed(),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? '請輸入內容' : null,
                      ),
                    ]),
                    _section('2. 收件對象', [
                      DropdownButtonFormField<String>(
                        initialValue: _audience,
                        decoration: const InputDecoration(
                          labelText: '本店會員範圍',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('全店會員')),
                          DropdownMenuItem(
                            value: 'vip',
                            child: Text('常客（VIP 標籤）'),
                          ),
                          DropdownMenuItem(
                            value: 'selected',
                            child: Text('指定會員／個別客戶'),
                          ),
                        ],
                        onChanged: (v) {
                          _audience = v!;
                          _changed();
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '手動會員未綁定 App 帳號者、黑名單及停用帳號將被排除。實際可發送人數以伺服器預覽為準；單次最多 5000 位。',
                      ),
                      if (_membersLoading) const LinearProgressIndicator(),
                      if (_membersError != null)
                        TextButton(
                          onPressed: _loadMembers,
                          child: const Text('會員名單讀取失敗，點此重試'),
                        ),
                      if (_audience == 'selected') ...[
                        const SizedBox(height: 12),
                        Text('已選 ${_selected.length} 位'),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      _selected.addAll(
                                        filtered
                                            .where(
                                              (m) => m['reachable'] == true,
                                            )
                                            .map((m) => '${m['id']}'),
                                      );
                                      _changed();
                                    },
                              child: const Text('勾選搜尋結果'),
                            ),
                            TextButton(
                              onPressed: _busy || _selected.isEmpty
                                  ? null
                                  : () {
                                      _selected.clear();
                                      _changed();
                                    },
                              child: const Text('清除選取'),
                            ),
                          ],
                        ),
                        if (!_membersLoading &&
                            _membersError == null &&
                            filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('沒有符合的會員。請調整搜尋，或確認會員已綁定 App 帳號。'),
                          ),
                        TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: '搜尋姓名、電話',
                          ),
                          onChanged: (v) => setState(() => _search = v),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 340),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final m = filtered[index];
                              final reachable = m['reachable'] == true;
                              return CheckboxListTile(
                                value: _selected.contains(m['id']),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  '${m['name']}${m['vip'] == true ? ' · 常客' : ''}',
                                ),
                                subtitle: Text(
                                  reachable ? '${m['phone']}' : '無法接收 App 通知',
                                ),
                                onChanged: !reachable
                                    ? null
                                    : (v) {
                                        if (v == true) {
                                          _selected.add('${m['id']}');
                                        } else {
                                          _selected.remove('${m['id']}');
                                        }
                                        _changed();
                                      },
                              );
                            },
                          ),
                        ),
                      ],
                    ]),
                    _section('3. 通知方式', [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _channel,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'inbox',
                            child: Text('只放入 App 通知中心'),
                          ),
                          DropdownMenuItem(
                            value: 'push',
                            child: Text('App 通知＋手機通知列提醒'),
                          ),
                        ],
                        onChanged: (v) {
                          _channel = v!;
                          _changed();
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'App 通知保留在通知中心「店家」分類。手機提醒出現在鎖定畫面或通知列，需會員允許通知；不包含簡訊或 LINE。訂單狀態與入住提醒由系統自動處理。',
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

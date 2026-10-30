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
    this.isRepeat = false,
    this.initialPurpose,
    this.draft,
    this.initialMemberId,
    this.announcementId,
    this.initialTitle,
    this.initialBody,
  });
  final String shopId;
  final bool isRepeat;
  final String? initialPurpose;
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
  late String _category, _channel, _audience, _announcement, _purpose;
  int _version = 0;
  final Set<String> _selected = {};
  bool _accountServiceReady = false;
  bool _customize = false;
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
    _announcement = '${d['announcementId'] ?? widget.announcementId ?? ''}';
    final existingPurpose = '${d['purpose'] ?? ''}';
    _purpose = existingPurpose.isNotEmpty
        ? existingPurpose
        : widget.initialPurpose ??
              (_announcement.isNotEmpty
                  ? 'announcement'
                  : d['category'] == 'shop_marketing'
                  ? 'promotion'
                  : 'personal');
    _category = _purpose == 'promotion'
        ? 'shop_marketing'
        : _purpose == 'announcement'
        ? '${d['category'] ?? 'shop_notice'}'
        : 'shop_notice';
    _channel = 'push';
    _audience =
        '${d['audience'] ?? (_announcement.isNotEmpty
                ? 'all'
                : _purpose == 'promotion' && widget.initialMemberId == null
                ? 'vip'
                : 'selected')}';
    _selected.addAll((d['memberIds'] as List? ?? []).map((e) => e.toString()));
    if (widget.initialMemberId != null) _selected.add(widget.initialMemberId!);
    if (_audience == 'selected') {
      _loadMembers();
    } else {
      _membersLoading = false;
    }
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
          _accountServiceReady = result['accountNotices'] == true;
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

  bool _reachable(Map<String, dynamic> member) => _purpose == 'member_account'
      ? _accountServiceReady &&
            (member['accountReachable'] == true || member['reachable'] == true)
      : member['reachable'] == true;

  void _changePurpose(String value) {
    setState(() {
      _purpose = value;
      _category = value == 'promotion' ? 'shop_marketing' : 'shop_notice';
      if (value == 'member_account') _audience = 'selected';
      _selected.removeWhere(
        (id) => !_members.any((m) => m['id'] == id && _reachable(m)),
      );
      _dirty = true;
    });
    if (_audience == 'selected' && _members.isEmpty) {
      setState(() => _membersLoading = true);
      _loadMembers();
    }
  }

  Future<void> _applyTemplate(String kind) async {
    if (_title.text.isNotEmpty || _body.text.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('取代目前訊息？'),
          content: const Text('套用範本會取代目前的標題與內容。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('保留原文'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('套用範本'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    final templates = <String, List<String>>{
      'restriction': [
        '會員服務事項說明',
        '您好，關於您在本店的服務使用狀態，有事項需要與您說明。請聯絡本店確認相關原因、影響範圍與後續處理方式；如有疑問或希望提出說明，我們會協助處理。',
      ],
      'information': [
        '請協助補充服務資料',
        '您好，為協助處理您的服務事項，請與本店聯繫確認需要補充的資料與後續處理方式。請勿透過公開公告提供個人資料。',
      ],
      'result': [
        '會員服務事項處理進度',
        '您好，您先前與本店聯繫的服務事項已有處理進度，請與本店確認詳細結果及後續安排。如有疑問，歡迎聯絡我們。',
      ],
    };
    final content = templates[kind]!;
    _title.text = content[0];
    _body.text = content[1];
    _changed();
  }

  Map<String, dynamic> get _draft => {
    'title': _title.text.trim(),
    'body': _body.text.trim(),
    'category': _category,
    'purpose': _purpose,
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
    if (_purpose == 'member_account' && !_accountServiceReady) {
      _message('通知服務尚未支援會員權益告知，請先更新後端；目前不會送出。');
      return;
    }
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      _message('請填寫通知標題與內容。');
      return;
    }
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
                  for (final raw in (summary['recipients'] as List? ?? []))
                    Text(
                      '• ${raw['name']}${raw['restricted'] == true ? '（服務受限會員）' : ''}',
                    ),
                  if ((summary['count'] as num) > 20)
                    const Text('僅列前 20 位；送出範圍以上方人數為準。'),
                  if (_purpose == 'member_account')
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('此訊息只告知所選客戶，不會變更會員狀態。手機只顯示中性提醒，詳細內容留在 App。'),
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
        appBar: AppBar(
          title: Text(
            widget.isRepeat
                ? '再次通知會員'
                : _announcement.isNotEmpty
                ? '確認公告通知'
                : _purpose == 'member_account'
                ? '會員權益通知'
                : _purpose == 'promotion'
                ? '新增分眾推廣'
                : '個別客戶通知',
          ),
        ),
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
                    if (_announcement.isEmpty)
                      _section(
                        _purpose == 'member_account'
                            ? '只告知指定客戶'
                            : _purpose == 'promotion'
                            ? '把優惠送給合適的會員'
                            : '先選客戶，再寫訊息',
                        [
                          Text(
                            _purpose == 'member_account'
                                ? '適合服務限制、停權或黑名單相關說明。需明確勾選客戶；手機只顯示中性提醒。'
                                : _purpose == 'promotion'
                                ? '預設以 VIP 為對象，也能手動選擇部分會員。一般公告請從公告管理發布。'
                                : '適合一對一聯繫或通知少數客戶；不會預設推給全店。',
                          ),
                        ],
                      ),
                    if (!widget.canSend)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('你可編輯草稿；正式發送需由店主或具發送權限的人員執行。'),
                      ),
                    if (_announcement.isNotEmpty && !_customize)
                      _section(widget.isRepeat ? '再次發送這則公告' : '公告通知已準備好', [
                        const Text(
                          '內容已從公告帶入，不必重新設定。',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _title.text,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(_body.text),
                        const Divider(height: 28),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar: const Icon(
                                Icons.people_outline,
                                size: 18,
                              ),
                              label: Text(
                                _audience == 'all'
                                    ? '全店會員'
                                    : _audience == 'vip'
                                    ? 'VIP 會員'
                                    : '指定 ${_selected.length} 位會員',
                              ),
                            ),
                            const Chip(
                              avatar: Icon(
                                Icons.notifications_outlined,
                                size: 18,
                              ),
                              label: Text('App＋手機提醒'),
                            ),
                          ],
                        ),
                        if (widget.isRepeat)
                          const Text('這會新增一次發送紀錄，會員可能再次收到相同內容。'),
                        const SizedBox(height: 8),
                        const Text('會員關閉這間店的手機提醒後，仍可在 App 查看內容。'),
                        TextButton.icon(
                          onPressed: () => setState(() => _customize = true),
                          icon: const Icon(Icons.tune, size: 18),
                          label: const Text('需要時再調整內容或對象'),
                        ),
                      ])
                    else ...[
                      _section('1. 選擇通知對象', [
                        DropdownButtonFormField<String>(
                          key: ValueKey('audience_$_purpose'),
                          initialValue: _audience,
                          decoration: const InputDecoration(
                            labelText: '本店會員範圍',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            if (_purpose != 'member_account')
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('全店會員'),
                              ),
                            if (_purpose != 'member_account')
                              const DropdownMenuItem(
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
                            if (_audience == 'selected' && _members.isEmpty) {
                              _membersLoading = true;
                              _loadMembers();
                            }
                            _changed();
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '一般通知與推廣會排除服務受限會員；權益通知只限明確選取的客戶。未綁定 App、已刪除或平台停用帳號無法接收，實際人數以預覽為準。',
                        ),
                        if (_purpose == 'member_account' &&
                            !_membersLoading &&
                            !_accountServiceReady)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('此功能需要新版通知服務，請先更新後端。尚未更新前不會送出權益通知。'),
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
                                              .where((m) => _reachable(m))
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
                                final reachable = _reachable(m);
                                return CheckboxListTile(
                                  value: _selected.contains(m['id']),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(
                                    '${m['name']}${m['vip'] == true ? ' · 常客' : ''}',
                                  ),
                                  subtitle: Text(
                                    m['restricted'] == true
                                        ? (_purpose == 'member_account' &&
                                                  reachable
                                              ? '${m['phone']}・服務受限，可收權益告知'
                                              : '服務受限・不接收一般推廣')
                                        : reachable
                                        ? '${m['phone']}'
                                        : '未綁定 App 或無法接收通知',
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
                      _section('2. 撰寫訊息', [
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
                        if (_announcement.isEmpty)
                          DropdownButtonFormField<String>(
                            initialValue: _purpose,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: '訊息用途',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'personal',
                                child: Text('個別客戶通知'),
                              ),
                              DropdownMenuItem(
                                value: 'promotion',
                                child: Text('分眾推廣／活動優惠'),
                              ),
                              DropdownMenuItem(
                                value: 'member_account',
                                child: Text('會員權益／服務限制告知'),
                              ),
                            ],
                            onChanged: (value) => _changePurpose(value!),
                          ),
                        if (_purpose == 'member_account') ...[
                          const SizedBox(height: 12),
                          const Text(
                            '可告知停權、黑名單、服務限制或處理結果；這裡只發送訊息，不執行停權。請使用具體、中性的說明。',
                          ),
                          PopupMenuButton<String>(
                            onSelected: _applyTemplate,
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'restriction',
                                child: Text('服務限制告知範本'),
                              ),
                              PopupMenuItem(
                                value: 'information',
                                child: Text('資料補充範本'),
                              ),
                              PopupMenuItem(
                                value: 'result',
                                child: Text('處理進度範本'),
                              ),
                            ],
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('套用告知範本 ▾'),
                            ),
                          ),
                        ],
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
                    ],
                    if (_announcement.isEmpty || _customize)
                      _section('通知方式', [
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.notifications_active_outlined),
                          title: Text('App 通知＋手機提醒'),
                          subtitle: Text('統一發送；手機是否接收，由會員的各店設定與裝置權限決定。'),
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

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_campaign_service.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';

typedef LinePreparationApi =
    Future<Map<String, dynamic>> Function(
      String action,
      Map<String, dynamic> data,
    );

class ShopLinePreparationPage extends StatefulWidget {
  const ShopLinePreparationPage({super.key, required this.shopId, this.api});
  final String shopId;
  final LinePreparationApi? api;
  @override
  State<ShopLinePreparationPage> createState() =>
      _ShopLinePreparationPageState();
}

class _ShopLinePreparationPageState extends State<ShopLinePreparationPage>
    with ShopDashboardLeaveAware<ShopLinePreparationPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _account = TextEditingController();
  final _channel = TextEditingController();
  final Set<String> _uses = {'booking'};
  bool _loading = true, _saving = false, _canEdit = false, _dirty = false;
  int _version = 0;
  String? _error;
  @override
  bool get dashboardHasUnsavedChanges => _dirty;
  @override
  bool get dashboardIsBusy => _saving;

  Future<Map<String, dynamic>> _call(
    String action,
    Map<String, dynamic> data,
  ) =>
      widget.api?.call(action, data) ??
      ShopCampaignService.instance.call(widget.shopId, action, data);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _account.dispose();
    _channel.dispose();
    super.dispose();
  }

  void _apply(Map<String, dynamic> data) {
    final config = data['configuration'] as Map? ?? {};
    _name.text = '${config['displayName'] ?? ''}';
    _account.text = '${config['officialAccountId'] ?? ''}';
    _channel.text = '${config['channelId'] ?? ''}';
    _uses
      ..clear()
      ..addAll(
        (config['requestedUses'] as List? ?? ['booking']).map((e) => '$e'),
      );
    _version = (data['version'] as num?)?.toInt() ?? 0;
    _canEdit = data['canEdit'] == true;
    _dirty = false;
  }

  Future<void> _load() async {
    if (_dirty && !await dashboardConfirmLeave()) return;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _call('linePreparation', {});
      if (mounted) {
        setState(() => _apply(data));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _canEdit = false;
          _error = '暫時無法讀取 LINE 準備資料。若尚未部署新版通知服務，可先查看下方清單，更新後再儲存。';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_canEdit || _saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = await _call('saveLinePreparation', {
        'version': _version,
        'configuration': {
          'displayName': _name.text.trim(),
          'officialAccountId': _account.text.trim(),
          'channelId': _channel.text.trim(),
          'requestedUses': _uses.toList()..sort(),
        },
      });
      if (!mounted) return;
      setState(() => _apply(data));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('準備資料已儲存，LINE 尚未連線、尚未開通發送。')),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = '儲存失敗，內容仍保留；請檢查連線與權限。若另一視窗已更新，請先重新讀取。');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('儲存失敗，內容已保留。請檢查連線後重試，或重新讀取最新版本。')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _card(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final editable = _canEdit && !_loading && !_saving;
    return dashboardGuard(
      Scaffold(
        appBar: AppBar(
          title: const Text('LINE 通知前置設定'),
          actions: [
            IconButton(
              tooltip: '重新讀取',
              onPressed: _saving || _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: editable && _dirty ? _save : null,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? '儲存中…' : '儲存準備資料'),
            ),
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _card('先準備，之後再開通', [
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('尚未連線')),
                        Chip(label: Text('尚未開通發送')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'LINE 是店家自費選配。這裡只保存準備資料，不會申請方案、扣款或傳送 LINE；目前 App＋手機通知照常使用。',
                    ),
                  ]),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (!_loading && !_canEdit && _error == null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('僅店主可修改串接準備資料；目前為檢視模式。'),
                    ),
                  _card('1. 店家的官方帳號資料', [
                    const Text(
                      '還沒有帳號可以先留空。填寫資料不代表驗證成功；請勿在此貼上 Access Token 或 Channel Secret。',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      enabled: editable,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: '官方帳號顯示名稱',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _dirty = true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _account,
                      enabled: editable,
                      maxLength: 65,
                      decoration: const InputDecoration(
                        labelText: 'LINE 官方帳號 ID',
                        hintText: '@你的店家帳號',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _dirty = true),
                      validator: (value) =>
                          value!.trim().isNotEmpty &&
                              !RegExp(
                                r'^@[A-Za-z0-9_.-]{1,64}$',
                              ).hasMatch(value.trim())
                          ? '請填 @ 開頭的官方帳號公開 ID'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _channel,
                      enabled: editable,
                      maxLength: 20,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Messaging API Channel ID（選填）',
                        helperText: '這是數字識別碼，不是權杖或密鑰。',
                        helperMaxLines: 2,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _dirty = true),
                      validator: (value) =>
                          value!.trim().isNotEmpty &&
                              !RegExp(r'^\d{5,20}$').hasMatch(value.trim())
                          ? '請填數字 Channel ID，勿填 Token 或 Secret'
                          : null,
                    ),
                  ]),
                  _card('2. 預計用在哪些通知', [
                    const Text('只記錄開通需求，不會立即啟用。'),
                    for (final entry in const {
                      'booking': '訂單與入住提醒',
                      'personal': '個別客戶服務通知',
                      'promotion': '活動與優惠推廣',
                    }.entries)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value),
                        value: _uses.contains(entry.key),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: editable
                            ? (value) => setState(() {
                                if (value == true) {
                                  _uses.add(entry.key);
                                } else {
                                  _uses.remove(entry.key);
                                }
                                _dirty = true;
                              })
                            : null,
                      ),
                  ]),
                  _card('3. 正式開通前還需要', [
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.storefront_outlined),
                      title: Text('建立官方帳號並啟用 Messaging API'),
                      subtitle: Text('由店家持有與管理自己的 LINE 官方帳號。'),
                    ),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.key_outlined),
                      title: Text('安全設定金鑰並驗證連線'),
                      subtitle: Text('正式金鑰需由伺服器安全保管，這一階段不收取金鑰。'),
                    ),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.verified_user_outlined),
                      title: Text('完成 Webhook 驗證與客戶綁定'),
                      subtitle: Text('客戶加店家好友、確認綁定與接收設定後，才具備發送條件。'),
                    ),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.account_balance_wallet_outlined),
                      title: Text('店主確認方案與訊息額度'),
                      subtitle: Text('LINE 費用由店家負擔；平台不會代訂方案或自動加購訊息。'),
                    ),
                  ]),
                  _card('店主可先準備的入口', [
                    const Text('官方帳號管理：'),
                    const SelectableText('https://manager.line.biz/'),
                    const SizedBox(height: 12),
                    const Text('LINE Developers：'),
                    const SelectableText(
                      'https://developers.line.biz/console/',
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

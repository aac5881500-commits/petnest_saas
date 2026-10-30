import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/notification_setting_service.dart';

class NotificationSettingPage extends StatefulWidget {
  const NotificationSettingPage({
    super.key,
    this.shopId = '',
    this.shopName = '',
    this.knownShops = const {},
    this.store,
  });
  final String shopId, shopName;
  final Map<String, String> knownShops;
  final NotificationSettingsStore? store;
  @override
  State<NotificationSettingPage> createState() =>
      _NotificationSettingPageState();
}

class _NotificationSettingPageState extends State<NotificationSettingPage> {
  late final NotificationSettingsStore _service;
  late Stream<Map<String, dynamic>> _stream;
  String? _updating;
  String _search = '';
  @override
  void initState() {
    super.initState();
    _service = widget.store ?? NotificationSettingService.instance;
    _stream = _service.settingsDataStream();
    // Missing keys already use defaults. No initial write can overwrite preferences.
  }

  Future<void> _update(
    String key,
    bool value, {
    String shopId = '',
    String shopName = '',
  }) async {
    if (_updating != null) return;
    setState(() => _updating = '$shopId/$key');
    try {
      if (shopId.isEmpty) {
        await _service.updateSetting(key: key, value: value);
      } else {
        await _service.updateShopSetting(
          shopId: shopId,
          shopName: shopName,
          key: key,
          value: value,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('儲存失敗，請檢查連線後重試；設定以重新讀取結果為準。')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = null);
    }
  }

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    ),
  );

  Widget _toggle({
    required String title,
    required String subtitle,
    required String keyName,
    required bool value,
    String shopId = '',
    String shopName = '',
    bool allowed = true,
  }) => SwitchListTile.adaptive(
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: !allowed || _updating != null
        ? null
        : (value) =>
              _update(keyName, value, shopId: shopId, shopName: shopName),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('通知設定')),
    body: StreamBuilder<Map<String, dynamic>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('無法讀取通知設定，請確認登入狀態與網路。'),
                TextButton(
                  onPressed: () =>
                      setState(() => _stream = _service.settingsDataStream()),
                  child: const Text('重新載入'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final rawOverrides = data['shopOverrides'];
        final overrides = rawOverrides is Map ? rawOverrides : const {};
        final shops = <String, String>{...widget.knownShops};
        for (final entry in overrides.entries) {
          final local = entry.value;
          if (local is Map) {
            shops.putIfAbsent(
              '${entry.key}',
              () => '${local['shopName'] ?? entry.key}',
            );
          }
        }
        if (widget.shopId.trim().isNotEmpty) {
          shops[widget.shopId.trim()] = widget.shopName.trim().isEmpty
              ? widget.shopId
              : widget.shopName.trim();
        }
        final entries =
            shops.entries
                .where(
                  (e) => '${e.value} ${e.key}'.toLowerCase().contains(
                    _search.toLowerCase(),
                  ),
                )
                .toList()
              ..sort((a, b) => a.value.compareTo(b.value));
        final enabled = data['enabled'] != false;
        final notice = enabled && data['shopNotice'] != false;
        final marketing = enabled && data['shopMarketing'] != false;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '管理手機提醒，訊息仍會保留',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '以下開關只控制手機鎖定畫面／通知列提醒。關閉後，仍可在 App 通知中心閱讀；不會發送簡訊或 LINE。',
                ),
                if (_updating != null) const LinearProgressIndicator(),
                _heading('訂單與入住通知'),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('重要服務通知・固定保留'),
                    subtitle: Text(
                      '訂單確認、付款、入住提醒與訂單異動由系統產生，無法在 App 內關閉。店家不能把優惠設為強制通知。',
                    ),
                  ),
                ),
                _heading('所有店家的手機提醒'),
                Card(
                  child: Column(
                    children: [
                      _toggle(
                        title: '店家公告',
                        subtitle: '所有店家公告與營業異動的總開關',
                        keyName: 'shopNotice',
                        value: notice,
                        allowed: enabled,
                      ),
                      _toggle(
                        title: '優惠與活動',
                        subtitle: '所有店家活動與優惠的總開關',
                        keyName: 'shopMarketing',
                        value: marketing,
                        allowed: enabled,
                      ),
                    ],
                  ),
                ),
                if (!enabled)
                  Card(
                    child: Column(
                      children: [
                        const ListTile(
                          title: Text('你先前已關閉所有選用手機提醒'),
                          subtitle: Text('重新開啟後，仍會遵守下方各類別與各店設定；重要通知不受影響。'),
                        ),
                        TextButton(
                          onPressed: _updating != null
                              ? null
                              : () => _update('enabled', true),
                          child: const Text('重新開啟選用手機提醒'),
                        ),
                      ],
                    ),
                  ),
                _heading('每間店獨立設定'),
                const Text('各店開關可再關閉該店的提醒；全域總開關關閉時，各店也不會推播。'),
                const SizedBox(height: 12),
                if (shops.length > 3)
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: '搜尋店家',
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                if (entries.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        '目前沒有可顯示的店家。可從店家的會員頁，或通知中心進入設定；已設定的店家會保留在這裡。',
                      ),
                    ),
                  ),
                for (final entry in entries)
                  Builder(
                    builder: (context) {
                      final raw = overrides[entry.key];
                      final local = raw is Map ? raw : const {};
                      return Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.storefront_outlined),
                              title: Text(entry.value),
                              subtitle: Text('店家代碼：${entry.key}'),
                            ),
                            _toggle(
                              title: '店家公告提醒',
                              subtitle: notice
                                  ? '公告與營業時間異動'
                                  : '已被「所有店家公告」總開關關閉',
                              keyName: 'shopNotice',
                              value: notice && local['shopNotice'] != false,
                              allowed: notice,
                              shopId: entry.key,
                              shopName: entry.value,
                            ),
                            _toggle(
                              title: '優惠與活動提醒',
                              subtitle: marketing
                                  ? '此店的活動、優惠與會員推廣'
                                  : '已被「所有店家優惠與活動」總開關關閉',
                              keyName: 'shopMarketing',
                              value:
                                  marketing && local['shopMarketing'] != false,
                              allowed: marketing,
                              shopId: entry.key,
                              shopName: entry.value,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                _heading('平台通知'),
                Card(
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.lock_outline),
                        title: Text('平台重要通知・固定保留'),
                        subtitle: Text('帳號安全與重要服務資訊'),
                      ),
                      _toggle(
                        title: '平台推廣與優惠',
                        subtitle: 'PetNest 平台活動與新功能推薦',
                        keyName: 'platformMarketing',
                        value: enabled && data['platformMarketing'] != false,
                        allowed: enabled,
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '手機系統仍可關閉整個 App 的通知。手機提醒需完成裝置設定並允許通知；重要訊息也無法保證跳出，請在 App 查看。',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

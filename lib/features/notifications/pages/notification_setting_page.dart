// 檔案名稱：lib/features/notifications/pages/notification_setting_page.dart
// 功能說明：讓會員管理全部通知、訂單、聊天、評價與入住提醒開關
// 🔔 會員通知設定頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/notification_setting_service.dart';

class _SettingHeading extends StatelessWidget {
  const _SettingHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class NotificationSettingPage extends StatefulWidget {
  const NotificationSettingPage({super.key});

  @override
  State<NotificationSettingPage> createState() =>
      _NotificationSettingPageState();
}

class _NotificationSettingPageState extends State<NotificationSettingPage> {
  final NotificationSettingService _service =
      NotificationSettingService.instance;

  bool _initializing = true;
  String? _updatingKey;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    try {
      await _service.ensureDefaultSettings();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('建立通知設定失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  Future<void> _updateSetting({
    required String key,
    required bool value,
  }) async {
    if (_updatingKey != null) {
      return;
    }

    setState(() {
      _updatingKey = key;
    });

    try {
      await _service.updateSetting(key: key, value: value);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新通知設定失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _updatingKey = null;
        });
      }
    }
  }

  Widget _buildSwitchTile({
    required String settingKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    bool enabled = true,
  }) {
    final bool updating = _updatingKey == settingKey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile(
        value: value,
        onChanged: enabled && !updating
            ? (bool nextValue) {
                _updateSetting(key: settingKey, value: nextValue);
              }
            : null,
        secondary: updating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知設定')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<Map<String, bool>>(
              stream: _service.settingStream(),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<Map<String, bool>> snapshot,
                  ) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '讀取通知設定失敗\n${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final Map<String, bool> settings = snapshot.data!;

                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: <Widget>[
                            const _SettingHeading('必要通知'),
                            _buildSwitchTile(
                              settingKey: 'primary',
                              title: '主要通知',
                              subtitle: '訂單、付款、入住與其他重要服務狀態。',
                              icon: Icons.receipt_long_outlined,
                              value: true,
                              enabled: false,
                            ),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: Text(
                                '此類通知無法在 App 內關閉，避免錯過重要服務資訊。',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            const _SettingHeading('店家通知'),
                            _buildSwitchTile(
                              settingKey: 'shopMarketing',
                              title: '店家活動與優惠',
                              subtitle: '所屬店家的活動、優惠與優惠券',
                              icon: Icons.local_offer_outlined,
                              value: settings['shopMarketing'] ?? true,
                            ),
                            _buildSwitchTile(
                              settingKey: 'shopNotice',
                              title: '店家公告與服務異動',
                              subtitle: '店家公告與服務異動，卡片會標示來源店家',
                              icon: Icons.storefront_outlined,
                              value: settings['shopNotice'] ?? true,
                            ),
                            const _SettingHeading('平台通知'),
                            _buildSwitchTile(
                              settingKey: 'platformImportant',
                              title: '平台重要通知',
                              subtitle: '條款更新、安全提醒與重大服務公告',
                              icon: Icons.campaign_outlined,
                              value: true,
                              enabled: false,
                            ),
                            _buildSwitchTile(
                              settingKey: 'platformMarketing',
                              title: '平台推廣與優惠',
                              subtitle: 'PetNest 平台活動與新功能推薦',
                              icon: Icons.card_giftcard_outlined,
                              value: settings['platformMarketing'] ?? true,
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                '手機系統通知仍可由手機設定關閉；網頁版目前不支援手機推播。',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: Color(0xFF6B7280),
                                ),
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
}

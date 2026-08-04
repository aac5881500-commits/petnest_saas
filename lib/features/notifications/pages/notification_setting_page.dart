// lib/features/notifications/pages/notification_setting_page.dart
// 🔔 會員通知設定頁
// 功能：讓會員管理全部通知、訂單、聊天、評價與入住提醒開關

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/notification_setting_service.dart';

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
                    final bool allEnabled = settings['enabled'] ?? true;

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: <Widget>[
                        _buildSwitchTile(
                          settingKey: 'enabled',
                          title: '全部通知',
                          subtitle: '關閉後將停止接收所有 App 推播通知',
                          icon: Icons.notifications_active_outlined,
                          value: allEnabled,
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 12),
                          child: Text(
                            '通知類型',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildSwitchTile(
                          settingKey: 'bookingStatus',
                          title: '訂單狀態通知',
                          subtitle: '訂單確認、入住、完成或取消時通知',
                          icon: Icons.receipt_long_outlined,
                          value: settings['bookingStatus'] ?? true,
                          enabled: allEnabled,
                        ),
                        _buildSwitchTile(
                          settingKey: 'bookingMessage',
                          title: '訂單聊天室通知',
                          subtitle: '店家在訂單聊天室傳送新訊息時通知',
                          icon: Icons.chat_bubble_outline,
                          value: settings['bookingMessage'] ?? true,
                          enabled: allEnabled,
                        ),
                        _buildSwitchTile(
                          settingKey: 'reviewReminder',
                          title: '評價提醒',
                          subtitle: '住宿完成後提醒你留下評價',
                          icon: Icons.star_outline,
                          value: settings['reviewReminder'] ?? true,
                          enabled: allEnabled,
                        ),
                        _buildSwitchTile(
                          settingKey: 'checkInReminder',
                          title: '入住提醒',
                          subtitle: '入住日前提醒預約時間與相關資訊',
                          icon: Icons.event_available_outlined,
                          value: settings['checkInReminder'] ?? true,
                          enabled: allEnabled,
                        ),
                      ],
                    );
                  },
            ),
    );
  }
}

// lib/features/room/pages/housekeeping_setting_page.dart
// 🧹 房務設定
// 功能：設定退房後是否自動將退房當日設為清潔中

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/housekeeping_setting_model.dart';
import 'package:petnest_saas/core/services/housekeeping_setting_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';

class HousekeepingSettingPage extends StatefulWidget {
  const HousekeepingSettingPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<HousekeepingSettingPage> createState() =>
      _HousekeepingSettingPageState();
}

class _HousekeepingSettingPageState extends State<HousekeepingSettingPage> {
  bool _autoCleaningAfterCheckout = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final HousekeepingSettingModel setting = await HousekeepingSettingService
          .instance
          .getSetting(widget.shopId);

      if (!mounted) return;

      setState(() {
        _autoCleaningAfterCheckout = setting.autoCleaningAfterCheckout;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('房務設定載入失敗：$error')));
    }
  }

  Future<void> _saveSetting() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      await HousekeepingSettingService.instance.saveSetting(
        shopId: widget.shopId,
        autoCleaningAfterCheckout: _autoCleaningAfterCheckout,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('房務設定已儲存')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('房務設定儲存失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('房務設定'),
        actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '退房後自動進入清潔中',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '完成退房後，退房當日自動變成清潔中，'
                          '直到房務完成清潔才可重新開放。',
                        ),
                      ),
                      value: _autoCleaningAfterCheckout,
                      onChanged: _saving
                          ? null
                          : (bool value) {
                              setState(() {
                                _autoCleaningAfterCheckout = value;
                              });
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveSetting,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? '儲存中...' : '儲存設定'),
                  ),
                ),
              ],
            ),
    );
  }
}

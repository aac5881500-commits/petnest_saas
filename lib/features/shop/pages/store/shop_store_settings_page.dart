// lib/features/shop/pages/store/shop_store_settings_page.dart
// 🛒 賣場設定

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';

class ShopStoreSettingsPage extends StatefulWidget {
  const ShopStoreSettingsPage({
    super.key,
    required this.shopId,
    required this.canManage,
  });

  final String shopId;
  final bool canManage;

  @override
  State<ShopStoreSettingsPage> createState() => _ShopStoreSettingsPageState();
}

class _ShopStoreSettingsPageState extends State<ShopStoreSettingsPage> {
  final TextEditingController _pickupNote = TextEditingController();
  bool _storefrontEnabled = true;
  bool _loaded = false;

  @override
  void dispose() {
    _pickupNote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await StoreSettingsService.instance.saveSettings(
      shopId: widget.shopId,
      pickupNote: _pickupNote.text,
      storefrontEnabled: _storefrontEnabled,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已儲存賣場設定')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: StoreSettingsService.instance.streamSettings(widget.shopId),
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>> snapshot,
      ) {
        final Map<String, dynamic> data =
            snapshot.data ?? const <String, dynamic>{};
        if (!_loaded && snapshot.hasData) {
          _pickupNote.text = (data['pickupNote'] ?? '').toString();
          _storefrontEnabled = data['storefrontEnabled'] != false;
          _loaded = true;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Text(
              '履約方式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('第一版僅開放店內自取，宅配欄位已預留但前台不可選。'),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('開放賣場前台'),
              subtitle: const Text('關閉後前台不顯示賣場入口與精選商品'),
              value: _storefrontEnabled,
              onChanged: widget.canManage
                  ? (bool value) => setState(() => _storefrontEnabled = value)
                  : null,
            ),
            TextField(
              controller: _pickupNote,
              enabled: widget.canManage,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '自取說明',
                hintText: '例如：請於營業時間至櫃台取貨',
              ),
            ),
            const SizedBox(height: 16),
            if (widget.canManage)
              FilledButton(onPressed: _save, child: const Text('儲存設定')),
          ],
        );
      },
    );
  }
}

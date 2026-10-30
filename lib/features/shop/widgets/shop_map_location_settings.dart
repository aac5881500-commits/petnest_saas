import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:petnest_saas/core/models/shop_map_location.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopMapLocationSettings extends StatefulWidget {
  const ShopMapLocationSettings({super.key, required this.shopId});
  final String shopId;
  @override
  State<ShopMapLocationSettings> createState() => _LocationSettingsState();
}

class _LocationSettingsState extends State<ShopMapLocationSettings> {
  final _lat = TextEditingController(), _lng = TextEditingController();
  bool _loading = true, _allowed = false, _saving = false, _confirmed = false;
  String _address = '';
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final shop = await ShopService.instance.getShop(widget.shopId);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final owner =
          uid != null &&
          (shop?['ownerUid'] == uid ||
              await ShopService.instance.getUserRoleInShop(
                    shopId: widget.shopId,
                    uid: uid,
                  ) ==
                  'owner');
      if (!mounted) return;
      final raw = shop?['mapLocation'];
      final point = ShopMapLocation.fromMap(raw);
      _address =
          '${shop?['city'] ?? ''}${shop?['district'] ?? ''}${shop?['address'] ?? ''}';
      _lat.text = point?.latitude.toString() ?? '';
      _lng.text = point?.longitude.toString() ?? '';
      _confirmed =
          point != null && raw is Map && raw['addressSnapshot'] == _address;
      setState(() {
        _allowed = owner;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '位置設定讀取失敗，請重試。';
        });
      }
    }
  }

  Future<void> _save({bool remove = false}) async {
    final point = ShopMapLocation.parse(_lat.text.trim(), _lng.text.trim());
    if (!remove && (point == null || !_confirmed)) {
      setState(() => _error = '請填寫有效座標，並勾選已確認店家位置。');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirebaseFunctions.instanceFor(
        region: 'asia-east1',
      ).httpsCallable('saveShopMapLocation').call({
        'shopId': widget.shopId,
        'expectedAddress': _address,
        'remove': remove,
        if (!remove) ...{
          'latitude': point!.latitude,
          'longitude': point.longitude,
          'confirmed': true,
        },
      });
      if (!mounted) return;
      if (remove) {
        _lat.clear();
        _lng.clear();
        _confirmed = false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(remove ? '已移除地圖位置' : '已儲存地圖位置，公開店家會顯示於地圖')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.code == 'not-found'
              ? '地圖位置服務尚未部署，請聯絡平台。'
              : e.message ?? '位置儲存失敗',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = '位置儲存失敗，請重試。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();
    if (_error != null && !_allowed) {
      return ListTile(
        title: Text(_error!),
        trailing: IconButton(
          tooltip: '重試地圖位置設定',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      );
    }
    if (!_allowed) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.pin_drop_outlined),
              title: Text('地圖找店位置'),
              subtitle: Text('僅店主可設定；店家公開且位置已確認時，才會標示在平台地圖。'),
            ),
            Text(_address.isEmpty ? '請先設定店家地址' : _address),
            const SizedBox(height: 8),
            const Text(
              '在 Google 地圖長按店址，複製緯度與經度後填入。地址變更後需重新確認位置。',
              style: TextStyle(fontSize: 12),
            ),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.https('www.google.com', '/maps/search/', {
                  'api': '1',
                  'query': _address,
                }),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('開啟地圖確認店址'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _lat,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (_) => setState(() => _confirmed = false),
              decoration: const InputDecoration(
                labelText: '緯度（-90～90）',
                hintText: '例如 25.033',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lng,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (_) => setState(() => _confirmed = false),
              decoration: const InputDecoration(
                labelText: '經度（-180～180）',
                hintText: '例如 121.565',
                border: OutlineInputBorder(),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('我已確認這是店家的實際位置'),
              value: _confirmed,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _confirmed = v == true),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _saving ? null : () => _save(),
                  child: Text(_saving ? '儲存中…' : '儲存地圖位置'),
                ),
                TextButton(
                  onPressed: _saving ? null : () => _save(remove: true),
                  child: const Text('移除地圖位置'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

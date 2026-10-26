import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';
import 'package:petnest_saas/features/shop/pages/shop_contact_platform_page.dart';

class StoreBusinessStatusCard extends StatefulWidget {
  const StoreBusinessStatusCard({
    super.key,
    required this.shopId,
    required this.canManage,
  });
  final String shopId;
  final bool canManage;
  @override
  State<StoreBusinessStatusCard> createState() =>
      _StoreBusinessStatusCardState();
}

class _StoreBusinessStatusCardState extends State<StoreBusinessStatusCard> {
  late final _shop = ShopService.instance.streamShop(widget.shopId);
  late final _settings = StoreSettingsService.instance.streamSettings(
    widget.shopId,
  );
  bool _saving = false;

  Future<void> _change(String status) async {
    if (_saving || !widget.canManage) return;
    setState(() => _saving = true);
    try {
      await StoreSettingsService.instance.mergeSettings(
        shopId: widget.shopId,
        data: {
          'businessStatus': status,
          'storefrontEnabled': status != 'preparing',
          'acceptNewOrders': status == 'open',
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已更新商城營業狀態')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('更新失敗，請確認網路與商城設定權限後重試。')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>?>(
    stream: _shop,
    builder: (context, shop) => StreamBuilder<Map<String, dynamic>>(
      stream: _settings,
      builder: (context, settings) {
        if (shop.hasError || settings.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('商城狀態讀取失敗，請稍後重新進入。'),
            ),
          );
        }
        if (!shop.hasData || !settings.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          );
        }
        return StoreBusinessControls(
          entitled: StorefrontAccess.hasEntitlement(shop.data),
          status: StorefrontAccess.businessStatus(settings.data),
          canManage: widget.canManage,
          saving: _saving,
          onChanged: _change,
          onContact: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ShopContactPlatformPage(shopId: widget.shopId),
            ),
          ),
        );
      },
    ),
  );
}

class StoreBusinessControls extends StatelessWidget {
  const StoreBusinessControls({
    super.key,
    required this.entitled,
    required this.status,
    required this.canManage,
    required this.saving,
    required this.onChanged,
    required this.onContact,
  });
  final bool entitled;
  final String status;
  final bool canManage;
  final bool saving;
  final ValueChanged<String> onChanged;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '商城服務與營業狀態',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(entitled ? '已開通・目前付費方案包含商城' : '尚未開通或方案已到期'),
          const SizedBox(height: 6),
          const Text('999 方案已包含商城，無須另外購買商城模組。'),
          if (!entitled) ...[
            const SizedBox(height: 8),
            const Text('請完成方案付款或續約，由平台確認後開通。既有訂單仍可查看與處理。'),
            if (canManage)
              TextButton.icon(
                onPressed: onContact,
                icon: const Icon(Icons.support_agent),
                label: const Text('聯絡平台開通／續約'),
              ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: status,
            key: ValueKey(status),
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '營業狀態',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'preparing',
                child: Text(
                  '準備中・暫不開放瀏覽與下單',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'open',
                child: Text(
                  '營業中・開放瀏覽與下單',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'paused',
                child: Text(
                  '暫停接單・保留商品瀏覽',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: entitled && canManage && !saving
                ? (value) {
                    if (value != null) onChanged(value);
                  }
                : null,
          ),
          if (saving)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 8),
          const Text(
            '首頁「逛逛賣場」入口可在前台外觀設定單獨顯示或隱藏。變更營業狀態不會刪除商品或既有訂單。',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

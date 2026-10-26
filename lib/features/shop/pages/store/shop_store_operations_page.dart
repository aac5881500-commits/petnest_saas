import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_business_status_card.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_list_page.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_product_form_page.dart';

/// Practical entry points; all changes still use the existing validated editors.
class ShopStoreOperationsPage extends StatelessWidget {
  const ShopStoreOperationsPage({
    super.key,
    required this.shopId,
    required this.memberData,
    required this.canProducts,
    required this.canOrders,
    required this.canSettings,
    required this.onTab,
  });

  final String shopId;
  final Map<String, dynamic>? memberData;
  final bool canProducts;
  final bool canOrders;
  final bool canSettings;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final canInventory =
        ShopService.instance.hasPermission(
          memberData,
          ShopPermissionKeys.viewInventory,
        ) ||
        ShopService.instance.hasPermission(
          memberData,
          ShopPermissionKeys.manageInventory,
        );
    void inventory() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('中央庫存')),
          body: ShopInventoryListPage(shopId: shopId, memberData: memberData),
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        StoreBusinessStatusCard(shopId: shopId, canManage: canSettings),
        Text(
          '賣場營運工作台',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text('從商品準備到交付取貨，把日常工作集中在這裡。'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (canProducts)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ShopStoreProductFormPage(shopId: shopId),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('新增商品'),
              ),
            if (canOrders)
              OutlinedButton.icon(
                onPressed: () => onTab(2),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('處理訂單'),
              ),
            if (canInventory)
              OutlinedButton.icon(
                onPressed: inventory,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('庫存與補貨'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _section(context, '開店準備', '第一次使用，依照順序完成設定。', [
          _task(
            '1. 準備中央庫存',
            '先建立品項、單位與現有數量；例如主食罐以「罐」計量。',
            Icons.inventory_2_outlined,
            canInventory ? inventory : null,
          ),
          _task(
            '2. 建立商品分類',
            '依主食、零食、清潔用品分類，方便客人找商品。',
            Icons.category_outlined,
            canProducts ? () => onTab(3) : null,
          ),
          _task(
            '3. 設定商品與售價',
            '連結庫存、上傳照片、填寫規格與售價，再決定是否上架。',
            Icons.shopping_bag_outlined,
            canProducts ? () => onTab(1) : null,
          ),
          _task(
            '4. 確認交易設定',
            '檢查賣場開關、取貨與付款設定，確認客人能完成購買。',
            Icons.settings_outlined,
            canSettings ? () => onTab(5) : null,
          ),
        ]),
        const SizedBox(height: 16),
        _section(context, '每日營運', '建議開店與交班時檢查一次。', [
          _task(
            '收款與備貨',
            '進入訂單，依付款與訂單狀態篩選；核對商品數量後再更新進度。',
            Icons.receipt_long_outlined,
            canOrders ? () => onTab(2) : null,
          ),
          _task(
            '取貨與完成',
            '用訂單編號或客人電話找單，核對實際交付品項，再完成訂單。',
            Icons.local_mall_outlined,
            canOrders ? () => onTab(2) : null,
          ),
          _task(
            '低庫存與售罄',
            '商品分頁可篩選低庫存、售罄及未連庫存；進貨請到中央庫存處理。',
            Icons.inventory_outlined,
            canProducts ? () => onTab(1) : null,
          ),
          _task(
            '活動檔期',
            '檢查活動起訖與適用商品，活動前先確認庫存能供應。',
            Icons.local_offer_outlined,
            canProducts ? () => onTab(4) : null,
          ),
        ]),
        const SizedBox(height: 16),
        _section(context, '實際使用情境', '可參考以下做法，再依店內規則調整。', [
          _example('住宿客加購', '把常用主食罐、零食建立成商品，客人自行下單；店員備貨後在交接時核對取貨。'),
          _example('一組多入商品', '例如一組 6 罐，請核對每次銷售對應的庫存扣量，避免只扣 1 罐。'),
          _example('檔期促銷', '先設定商品與庫存，再建立限時優惠；上線前核對適用範圍、折扣與活動日期。'),
          _example('取消或付款異常', '先查看訂單明細與付款紀錄，依可用操作處理；退款與庫存回補結果需各自核對。'),
        ]),
      ],
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    String subtitle,
    List<Widget> children,
  ) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(subtitle),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );

  Widget _task(
    String title,
    String description,
    IconData icon,
    VoidCallback? action,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(
      action == null ? '$description\n需要對應管理權限才能操作。' : description,
    ),
    isThreeLine: false,
    trailing: action == null
        ? const Icon(Icons.lock_outline, size: 18)
        : const Icon(Icons.chevron_right),
    onTap: action,
  );

  Widget _example(String title, String description) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(description),
      ],
    ),
  );
}

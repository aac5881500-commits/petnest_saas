import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_list_page.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_detail_page.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_form_page.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_booking_supply_settings_page.dart';

/// Inventory entry and live stock health. Counts follow the stock model's rules.
class InventoryManagementHub extends StatefulWidget {
  const InventoryManagementHub({
    super.key,
    required this.shopId,
    required this.isProfileComplete,
    this.memberData,
    this.itemsStream,
  });
  final String shopId;
  final bool isProfileComplete;
  final Map<String, dynamic>? memberData;
  final Stream<List<InventoryItemModel>>? itemsStream;
  @override
  State<InventoryManagementHub> createState() => _InventoryManagementHubState();
}

class _InventoryManagementHubState extends State<InventoryManagementHub> {
  Stream<List<InventoryItemModel>>? _items;
  bool _can(String key) =>
      ShopService.instance.hasPermission(widget.memberData, key);
  bool get _view => [
    ShopPermissionKeys.viewInventory,
    ShopPermissionKeys.manageInventory,
    ShopPermissionKeys.receiveInventory,
    ShopPermissionKeys.adjustInventory,
  ].any(_can);
  bool get _manage => _can(ShopPermissionKeys.manageInventory);
  bool get _supplies => _manage || _can(ShopPermissionKeys.viewInventory);
  void _subscribe() {
    _items = widget.isProfileComplete && _view
        ? widget.itemsStream ??
              InventoryService.instance.streamItems(widget.shopId)
        : null;
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant InventoryManagementHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId ||
        oldWidget.isProfileComplete != widget.isProfileComplete ||
        oldWidget.memberData != widget.memberData ||
        oldWidget.itemsStream != widget.itemsStream) {
      _subscribe();
    }
  }

  void _open(Widget page) => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
  void _list([InventoryStockStatus? status]) => _open(
    ShopInventoryListPage(
      shopId: widget.shopId,
      memberData: widget.memberData,
      initialStockStatus: status,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '庫存與耗材',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '掌握用品存量，安排補貨與服務耗材。',
                        style: TextStyle(color: Color(0xFF667085), height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!widget.isProfileComplete)
              _panel(const Text('請先完成店家基本資料，再開始管理庫存與耗材。')),
            if (!_view && !_supplies)
              _panel(const Text('目前沒有庫存檢視權限，請聯絡店家管理員調整。')),
            if (_items != null)
              StreamBuilder<List<InventoryItemModel>>(
                stream: _items,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '暫時無法讀取庫存摘要',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          const Text('可重新載入，或從下方進入庫存管理。'),
                          TextButton.icon(
                            onPressed: () => setState(_subscribe),
                            icon: const Icon(Icons.refresh),
                            label: const Text('重新載入'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return _panel(
                      const Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('正在讀取庫存摘要…'),
                        ],
                      ),
                    );
                  }
                  return _overview(snapshot.data!);
                },
              ),
            const SizedBox(height: 20),
            const Text(
              '管理工具',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = <Widget>[
                  if (_view)
                    _entry(
                      title: '庫存管理',
                      subtitle: '品項、進貨、出庫、盤點與異動紀錄',
                      icon: Icons.inventory_2_outlined,
                      tags: const ['存量追蹤', '補貨作業'],
                      onTap: () => _list(),
                    ),
                  if (_supplies)
                    _entry(
                      title: '住宿耗材設定',
                      subtitle: '設定服務用量，選擇是否連動庫存扣除',
                      icon: Icons.cleaning_services_outlined,
                      tags: const ['扣除規則', '庫存連動'],
                      onTap: () => _open(
                        ShopBookingSupplySettingsPage(
                          shopId: widget.shopId,
                          memberData: widget.memberData,
                        ),
                      ),
                    ),
                ];
                if (constraints.maxWidth < 720 || cards.length < 2) {
                  return Column(
                    children: [
                      for (final card in cards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: card,
                        ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards.first),
                    const SizedBox(width: 12),
                    Expanded(child: cards.last),
                  ],
                );
              },
            ),
            if (_view && widget.isProfileComplete) ...[
              const SizedBox(height: 14),
              _panel(
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '第一次使用？',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1  建立品項與單位，設定安全庫存\n2  進貨登錄實際數量\n3  綁定住宿耗材並設定每次使用量',
                      style: TextStyle(height: 1.8),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '進貨增加存量、出庫記錄領用；盤點用於校正實際存量。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _overview(List<InventoryItemModel> items) {
    final active = items.where((item) => item.enabled).toList();
    final low = active
        .where((item) => item.stockStatus == InventoryStockStatus.low)
        .toList();
    final out = active
        .where((item) => item.stockStatus == InventoryStockStatus.outOfStock)
        .toList();
    final expiring = active.where((item) => item.isExpiringSoon).toList()
      ..sort((a, b) => a.nearestExpiryDate!.compareTo(b.nearestExpiryDate!));
    final alerts = {...out, ...low, ...expiring}.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '庫存概況',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(onPressed: () => _list(), child: const Text('查看全部')),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width =
                (constraints.maxWidth -
                    (constraints.maxWidth >= 650 ? 30 : 10)) /
                (constraints.maxWidth >= 650 ? 4 : 2);
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: width,
                  child: _metric(
                    '啟用品項',
                    active.length,
                    Icons.inventory_2_outlined,
                    const Color(0xFF4F5FA8),
                    () => _list(),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _metric(
                    '低庫存',
                    low.length,
                    Icons.trending_down,
                    const Color(0xFF9A6300),
                    () => _list(InventoryStockStatus.low),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _metric(
                    '已缺貨',
                    out.length,
                    Icons.remove_shopping_cart_outlined,
                    const Color(0xFFB54747),
                    () => _list(InventoryStockStatus.outOfStock),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _metric(
                    '即期／已到期',
                    expiring.length,
                    Icons.event_outlined,
                    const Color(0xFF826339),
                    null,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '從第一個庫存品項開始',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  '建立貓砂、飼料或清潔用品，讓補貨與耗材用量有跡可循。',
                  style: TextStyle(height: 1.6),
                ),
                if (_manage)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FilledButton.icon(
                      onPressed: () =>
                          _open(ShopInventoryFormPage(shopId: widget.shopId)),
                      icon: const Icon(Icons.add),
                      label: const Text('新增庫存品項'),
                    ),
                  ),
              ],
            ),
          )
        else if (alerts.isEmpty)
          _panel(
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    active.isEmpty
                        ? '目前沒有啟用品項，可至庫存管理查看停用品項。'
                        : '目前沒有低庫存、缺貨或即期提醒。',
                  ),
                ),
              ],
            ),
          )
        else
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '優先處理',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  '先顯示缺貨與低庫存，再顯示即期品項；最多 4 筆。',
                  style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
                ),
                for (final item in alerts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text(
                      [
                        if (item.stockStatus == InventoryStockStatus.outOfStock)
                          '已缺貨',
                        if (item.stockStatus == InventoryStockStatus.low)
                          '低於安全存量',
                        if (item.isExpiringSoon) '即期／已到期',
                        '現有 ${InventoryConstants.formatQuantity(item.currentStock)} ${item.unit}',
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(
                      ShopInventoryDetailPage(
                        shopId: widget.shopId,
                        itemId: item.id,
                        memberData: widget.memberData,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _metric(
    String label,
    int count,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE4E7EC)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 10),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    ),
  );

  Widget _entry({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<String> tags,
    required VoidCallback onTap,
  }) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE4E7EC)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: widget.isProfileComplete ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.isProfileComplete ? subtitle : '請先完成基本資料',
              style: const TextStyle(color: Color(0xFF667085), height: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4FA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF56628A),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE4E7EC)),
    ),
    child: child,
  );
}

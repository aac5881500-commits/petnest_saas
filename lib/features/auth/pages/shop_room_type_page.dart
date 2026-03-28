// 檔案名稱 lib/features/auth/pages/shop_room_type_page.dart
// 🐱 房型管理頁（升級版：新增 + 列表 + 房間數量）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopRoomTypePage extends StatefulWidget {
  const ShopRoomTypePage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<ShopRoomTypePage> createState() => _ShopRoomTypePageState();
}

class _ShopRoomTypePageState extends State<ShopRoomTypePage> {
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController();
  final _priceController = TextEditingController();
  final _totalRoomsController = TextEditingController(); // 👈 新增

  bool _loading = false;

  Future<void> _createRoomType() async {
    final name = _nameController.text.trim();
    final capacity = int.tryParse(_capacityController.text) ?? 0;
    final price = int.tryParse(_priceController.text) ?? 0;
    final totalRooms = int.tryParse(_totalRoomsController.text) ?? 0;

    if (name.isEmpty || capacity <= 0 || price <= 0 || totalRooms <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請填寫完整資料')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await ShopService.instance.createRoomType(
        shopId: widget.shopId,
        name: name,
        capacity: capacity,
        price: price,
        totalRooms: totalRooms, // 👈 新增
      );

      _nameController.clear();
      _capacityController.clear();
      _priceController.clear();
      _totalRoomsController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新增成功')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('錯誤：$e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    _totalRoomsController.dispose(); // 👈 記得釋放
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('房型管理'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 新增區
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '房型名稱（例如：大房）',
                      ),
                    ),
                    TextField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '可住幾隻',
                      ),
                    ),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '每晚價格',
                      ),
                    ),

                    /// 👇 新增這個
                    TextField(
                      controller: _totalRoomsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '房間數量',
                      ),
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton(
                      onPressed: _loading ? null : _createRoomType,
                      child: const Text('新增房型'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// 房型列表
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: ShopService.instance
                    .streamRoomTypes(widget.shopId),
                builder: (context, snapshot) {
                  final list = snapshot.data ?? [];

                  if (list.isEmpty) {
                    return const Center(
                      child: Text('尚未建立房型'),
                    );
                  }

                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];

                      return Card(
                        child: ListTile(
  title: Text(item['name'] ?? ''),
  subtitle: Text(
    '可住 ${item['capacity']} 隻｜房間 ${item['totalRooms'] ?? 0} 間｜\$${item['price']} / 晚',
  ),
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('確認刪除'),
              content: const Text('確定要刪除此房型嗎？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('刪除'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            print('刪除ID: ${item['id']}');
            await ShopService.instance.deleteRoomType(
              shopId: widget.shopId,
              roomTypeId: item['id'], 
            );

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已刪除')),
            );
          }
        },
      ),
    ],
  ),
),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
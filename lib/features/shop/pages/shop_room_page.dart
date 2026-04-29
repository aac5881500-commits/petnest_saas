// 檔案名稱 lib/features/shop/pages/shop_room_page.dart
// 🏠 房間管理（完整升級版🔥）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';



class ShopRoomPage extends StatefulWidget {
  const ShopRoomPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<ShopRoomPage> createState() => _ShopRoomPageState();
}

class _ShopRoomPageState extends State<ShopRoomPage> {
  final _nameController = TextEditingController();
  String? _selectedRoomTypeId;

  /// 🔥 建立房間（含防呆）
  Future<void> _createRoom() async {
    final name = _nameController.text.trim();

    if (name.isEmpty || _selectedRoomTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請填寫完整資料')),
      );
      return;
    }

    /// 🔥 取得房型
    final roomTypes =
        await ShopService.instance.getRoomTypes(widget.shopId);

    final selectedType = roomTypes.firstWhere(
      (e) => e['id'] == _selectedRoomTypeId,
    );

    final totalRooms = selectedType['totalRooms'] ?? 0;

    /// 🔥 取得現有房間
    final rooms = await ShopService.instance.getRooms(widget.shopId);

    final sameTypeRooms = rooms
        .where((r) => r['roomTypeId'] == _selectedRoomTypeId)
        .toList();

    /// ❗ 房型數量限制
    if (sameTypeRooms.length >= totalRooms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此房型已達最大房間數')),
      );
      return;
    }

    /// ❗ 房號重複
    final isDuplicate = sameTypeRooms.any((r) => r['name'] == name);

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此房型已有相同房號')),
      );
      return;
    }

    /// ✅ 新增
    await ShopService.instance.createRoom(
      shopId: widget.shopId,
      name: name,
      roomTypeId: _selectedRoomTypeId!,
    );

    _nameController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('新增房間成功')),
    );
  }

  /// 🔥 刪除房間
  Future<void> _deleteRoom(String roomId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('確定要刪除此房間嗎？'),
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

    if (confirm != true) return;

    await ShopService.instance.deleteRoom(
      shopId: widget.shopId,
      roomId: roomId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已刪除房間')),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('房間管理')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 🔥 新增房間
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '房號（例如 A1）',
                      ),
                    ),

                    const SizedBox(height: 8),

                    /// 🔥 房型選擇
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: ShopService.instance
                          .streamRoomTypes(widget.shopId),
                      builder: (context, snapshot) {
                        final list = snapshot.data ?? [];

                        return DropdownButtonFormField<String>(
                          value: _selectedRoomTypeId,
                          items: list.map<DropdownMenuItem<String>>((item) {
                            return DropdownMenuItem<String>(
                              value: item['id'] as String,
                              child: Text(item['name'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedRoomTypeId = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: '選擇房型',
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton(
                      onPressed: _createRoom,
                      child: const Text('新增房間'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// 🔥 房間列表
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: ShopService.instance
                    .streamRooms(widget.shopId),
                builder: (context, snapshot) {
                  final list = snapshot.data ?? [];

                  if (list.isEmpty) {
                    return const Center(child: Text('尚未建立房間'));
                  }

                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];

                      return Card(
                        child: ListTile(

                          subtitle: Text(
  '${item['name'] ?? ''}（${item['roomTypeId']}）',
),

                          /// 🔥 開關
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              /// 開關
                              Switch(
                                value: item['enabled'] ?? true,
                                onChanged: (value) {
                                  ShopService.instance.updateRoomStatus(
                                    shopId: widget.shopId,
                                    roomId: item['id'],
                                    enabled: value,
                                  );
                                },
                              ),

                              /// 🔥 刪除按鈕
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _deleteRoom(item['id']);
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
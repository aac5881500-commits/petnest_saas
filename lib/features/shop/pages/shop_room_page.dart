// 檔案名稱 lib/features/shop/pages/shop_room_page.dart
// 🏠 房間管理（完整升級版🔥）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/shop_plan_service.dart';

class ShopRoomPage extends StatefulWidget {
  const ShopRoomPage({super.key, required this.shopId});

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請填寫完整資料')));
      return;
    }

    /// 🔥 取得房型
    final roomTypes = await ShopService.instance.getRoomTypes(widget.shopId);

    final selectedType = roomTypes.firstWhere(
      (e) => e['id'] == _selectedRoomTypeId,
    );

    final totalRooms = selectedType['totalRooms'] ?? 0;

    /// 🔥 取得現有房間
    final rooms = await ShopService.instance.getRooms(widget.shopId);

    final sameTypeRooms = rooms
        .where((r) => r['roomTypeId'] == _selectedRoomTypeId)
        .toList();

    final shopDoc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .get();

    final shop = shopDoc.data() ?? {};

    final limit = ShopPlanService.roomLimit(shop);

    if (rooms.length >= limit) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('免費版最多建立 $limit 間房間，升級 999 方案即可解除限制')),
      );
      return;
    }

    /// ❗ 房型數量限制
    if (sameTypeRooms.length >= totalRooms) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此房型已達最大房間數')));
      return;
    }

    /// ❗ 房號不可重複：不同房型也不能使用同一個房號
    final isDuplicate = rooms.any(
      (r) => (r['name'] ?? '').toString().trim() == name,
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此房號已存在，請使用不同房號')));
      return;
    }

    /// ✅ 新增
    await ShopService.instance.createRoom(
      shopId: widget.shopId,
      name: name,
      roomTypeId: _selectedRoomTypeId!,
    );

    _nameController.clear();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('新增房間成功')));
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已刪除房間')));
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
                      decoration: const InputDecoration(labelText: '房號（例如 A1）'),
                    ),

                    const SizedBox(height: 8),

                    /// 🔥 房型選擇
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: ShopService.instance.streamRoomTypes(
                        widget.shopId,
                      ),
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
                          decoration: const InputDecoration(labelText: '選擇房型'),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton(
                      onPressed: _createRoom,
                      child: const Text('新增房間'),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      '1. 此頁用來建立實際房間，例如 A01、A02。\n'
                      '2. 房型管理設定幾間房，這裡就需要建立幾次房間。\n'
                      '3. 每個房號不可重複，不同房型也不能使用同一個房號。\n'
                      '4. 下方開關可永久停用或恢復該房間；關閉後，前台將不會把此房間納入可預約數量。\n'
                      '5. 房間關閉後，前台不會把此房間納入可預約數量。\n'
                      '6. 若刪除房型，該房型底下建立的房間也會一併刪除；若只是某一天維修或臨時關閉，請到房務管理的日曆設定單日關閉。',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        height: 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// 🔥 房間列表
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: ShopService.instance.streamRooms(widget.shopId),
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
                          subtitle: FutureBuilder<List<Map<String, dynamic>>>(
                            future: ShopService.instance.getRoomTypes(
                              widget.shopId,
                            ),
                            builder: (context, typeSnapshot) {
                              final types = typeSnapshot.data ?? [];

                              final roomType = types.where(
                                (type) => type['id'] == item['roomTypeId'],
                              );

                              final roomTypeName = roomType.isEmpty
                                  ? '未找到房型'
                                  : roomType.first['name'] ?? '未命名房型';

                              return Text(
                                '${item['name'] ?? ''}（$roomTypeName）',
                              );
                            },
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
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
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

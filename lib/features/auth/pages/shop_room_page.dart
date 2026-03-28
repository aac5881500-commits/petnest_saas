// 檔案名稱 /features/auth/pages/shop_room_page.dart
// 🏠 房間管理

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

  Future<void> _createRoom() async {
    final name = _nameController.text.trim();

    if (name.isEmpty || _selectedRoomTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請填寫完整資料')),
      );
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('房間管理')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 新增房間
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

            /// 房間列表
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

                      return SwitchListTile(
                        title: Text(item['name'] ?? ''),
                        subtitle: Text('房型ID: ${item['roomTypeId']}'),
                        value: item['enabled'] ?? true,
                        onChanged: (value) {
                          ShopService.instance.updateRoomStatus(
                            shopId: widget.shopId,
                            roomId: item['id'],
                            enabled: value,
                          );
                        },
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
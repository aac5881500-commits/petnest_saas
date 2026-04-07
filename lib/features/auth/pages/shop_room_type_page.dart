// lib/features/auth/pages/shop_room_type_page.dart
// 🐱 房型管理頁（完整升級版🔥）

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;

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
  final _totalRoomsController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _loading = false;

  Future<void> _createRoomType() async {
    final name = _nameController.text.trim();
    final capacity = int.tryParse(_capacityController.text) ?? 0;
    final price = int.tryParse(_priceController.text) ?? 0;
    final totalRooms = int.tryParse(_totalRoomsController.text) ?? 0;
    final description = _descriptionController.text.trim();

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
        totalRooms: totalRooms,
        description: description,
      );

      _nameController.clear();
      _capacityController.clear();
      _priceController.clear();
      _totalRoomsController.clear();
      _descriptionController.clear();

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
    _totalRoomsController.dispose();
    _descriptionController.dispose();
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
            /// 🔥 新增區
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: '房型名稱'),
                    ),
                    TextField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '可住幾隻'),
                    ),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '價格'),
                    ),
                    TextField(
                      controller: _totalRoomsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '房間數量'),
                    ),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: '房型介紹'),
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

            /// 🔥 房型列表
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: ShopService.instance.streamRoomTypes(widget.shopId),
                builder: (context, snapshot) {
                  final list = snapshot.data ?? [];

                  if (list.isEmpty) {
                    return const Center(child: Text('尚未建立房型'));
                  }

                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];

                      return Card(
                        child: ListTile(
                          title: Text(item['name'] ?? ''),

                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '可住 ${item['capacity']} 隻｜房間 ${item['totalRooms']} 間｜\$${item['price']}',
                              ),

                              /// 🔥 圖片列（可刪除）
                              if ((item['images'] ?? []).isNotEmpty)
                                SizedBox(
                                  height: 60,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: item['images'].length,
                                    itemBuilder: (context, i) {
                                      final url = item['images'][i];

                                      return Stack(
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            child: Image.network(url, width: 60, height: 60),
                                          ),
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: GestureDetector(
                                              onTap: () async {
                                                await ShopService.instance.deleteRoomTypeImage(
                                                  shopId: widget.shopId,
                                                  roomTypeId: item['id'],
                                                  imageUrl: url,
                                                );
                                              },
                                              child: Container(
                                                color: Colors.black54,
                                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),

                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  _showEditDialog(item);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  await ShopService.instance.deleteRoomType(
                                    shopId: widget.shopId,
                                    roomTypeId: item['id'],
                                  );
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

  /// 🔥 編輯 + 上傳圖片（含壓縮）
  void _showEditDialog(Map<String, dynamic> item) {
    final descriptionController =
        TextEditingController(text: item['description'] ?? '');

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('編輯房型'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '房型介紹'),
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: () async {
                  final picker = ImagePicker();
                  final file = await picker.pickImage(source: ImageSource.gallery);
                  if (file == null) return;

                  /// 🔥 壓縮
                  final rawBytes = await file.readAsBytes();

                  final codec = await ui.instantiateImageCodec(
                    rawBytes,
                    targetWidth: 1280,
                  );

                  final frame = await codec.getNextFrame();

                  final byteData = await frame.image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );

                  final bytes = byteData!.buffer.asUint8List();

                  await ShopService.instance.uploadRoomTypeImage(
                    shopId: widget.shopId,
                    roomTypeId: item['id'],
                    bytes: bytes,
                  );

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('圖片上傳成功')),
                  );
                },
                child: const Text('上傳圖片'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('shops')
                    .doc(widget.shopId)
                    .collection('room_types')
                    .doc(item['id'])
                    .update({
                  'description': descriptionController.text.trim(),
                });

                Navigator.pop(context);
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
  }
}
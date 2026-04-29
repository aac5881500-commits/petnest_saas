// lib/features/shop/pages/shop_room_type_page.dart
// 🐱 房型管理頁（升級：支援小卡片🔥）

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
  final _extraPriceController = TextEditingController(); // 每隻加價
final _widthController = TextEditingController(); // 寬
final _depthController = TextEditingController(); // 深
final _heightController = TextEditingController(); // 高

  bool _loading = false;

  /// 🧩 房型特色小卡
  final List<Map<String, dynamic>> _featureOptions = [
    {'key': 'private_space', 'name': '🏡 獨立包廂', 'icon': Icons.home},
    {'key': 'daily_clean', 'name': '🧹 每日整理', 'icon': Icons.cleaning_services},
    {'key': 'camera', 'name': '📹 全日監控', 'icon': Icons.videocam},
    {'key': 'aircon', 'name': '❄️ 舒適空調', 'icon': Icons.ac_unit},
    {'key': 'private_door', 'name': '🔒 獨立房門', 'icon': Icons.lock},
    {'key': 'cat_window', 'name': '🪟 透明貓窗', 'icon': Icons.window},
    {'key': 'sky_walk', 'name': '🌉 天空步道', 'icon': Icons.architecture},
    {'key': 'scratch', 'name': '🐾 貓抓板', 'icon': Icons.pets},
    {'key': 'jump', 'name': '🪜 跳台設計', 'icon': Icons.stairs},
    {'key': 'bed', 'name': '🛏️ 舒眠睡窩', 'icon': Icons.bed},
  ];

  List<String> _selectedFeatures = [];

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

  /// 🔥 這些現在會正常了
  extraPrice: int.tryParse(_extraPriceController.text) ?? 0,
  width: int.tryParse(_widthController.text) ?? 0,
  depth: int.tryParse(_depthController.text) ?? 0,
  height: int.tryParse(_heightController.text) ?? 0,

  extraData: {
    'features': _selectedFeatures,
  },
);

      _nameController.clear();
      _capacityController.clear();
      _priceController.clear();
      _totalRoomsController.clear();
      _descriptionController.clear();
      _selectedFeatures.clear();
      _extraPriceController.clear();
_widthController.clear();
_depthController.clear();
_heightController.clear();

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
    _extraPriceController.dispose();
_widthController.dispose();
_depthController.dispose();
_heightController.dispose();
    super.dispose();
  }

  /// 🔥 小卡UI
  Widget _buildFeatureSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _featureOptions.map((item) {
        final selected = _selectedFeatures.contains(item['key']);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                _selectedFeatures.remove(item['key']);
              } else {
                _selectedFeatures.add(item['key']);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? Colors.blue : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item['icon'], size: 16, color: selected ? Colors.white : Colors.black),
                const SizedBox(width: 4),
                Text(
                  item['name'],
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 🔥 顯示用小卡
  Widget _buildFeatureTags(List features) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: features.map<Widget>((key) {
        final item = _featureOptions.firstWhere(
          (e) => e['key'] == key,
          orElse: () => {},
        );

        if (item.isEmpty) return const SizedBox();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item['icon'], size: 14),
              const SizedBox(width: 4),
              Text(item['name'], style: const TextStyle(fontSize: 11)),
            ],
          ),
        );
      }).toList(),
    );
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
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '每晚價格'),
                    ),

                    TextField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '房間最高可住'),
                    ),
                    const SizedBox(height: 12),

                    TextField(
  controller: _extraPriceController,
  keyboardType: TextInputType.number,
  decoration: const InputDecoration(
    labelText: '每隻加購價格（例：200）',
  ),
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

/// 🔥 房間尺寸（寬 深 高）
Row(
  children: [
    Expanded(
      child: TextField(
        controller: _widthController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: '寬(cm)'),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: TextField(
        controller: _depthController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: '深(cm)'),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: TextField(
        controller: _heightController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: '高(cm)'),
      ),
    ),
  ],
),

                    const SizedBox(height: 12),

                    /// 🔥 小卡選擇
                    _buildFeatureSelector(),

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
                      final features = item['features'] ?? [];

                      return Card(
                        child: ListTile(
                          title: Text(item['name'] ?? ''),

                          subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    Text(
      '每晚 \$${item['price']}',
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),

    Text(
      '可住 ${item['capacity']} 隻｜房間 ${item['totalRooms']} 間',
    ),

    if ((item['extraPrice'] ?? 0) > 0)
      Text(
        '每隻加購 +${item['extraPrice']}',
        style: const TextStyle(color: Colors.red),
      ),

    Text(
      '尺寸：${item['width']} x ${item['depth']} x ${item['height']} cm',
      style: const TextStyle(color: Colors.grey),
    ),

    const SizedBox(height: 6),

    /// 🔥 小卡
    _buildFeatureTags(features),

    /// 🔥 圖片
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
                  child: Image.network(
                    url,
                    width: 60,
                    height: 60,
                  ),
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
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
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

    /// 📷 上傳圖片（新）
    IconButton(
      icon: const Icon(Icons.add_photo_alternate, color: Colors.blue),
      onPressed: () async {

        final images = List<String>.from(item['images'] ?? []);

        /// 🔥 限制最多5張
        if (images.length >= 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('最多只能上傳5張圖片')),
          );
          return;
        }

        final picker = ImagePicker();
        final file = await picker.pickImage(source: ImageSource.gallery);
        if (file == null) return;

        final rawBytes = await file.readAsBytes();

        /// 🔥 壓縮圖片（限制大小）
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
    ),

    /// ✏️ 編輯
    IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () {
        _showEditDialog(item);
      },
    ),

    /// 🗑️ 刪除
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

  void _showEditDialog(Map<String, dynamic> item) {
    final descriptionController =
        TextEditingController(text: item['description'] ?? '');

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('編輯房型介紹'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '房型介紹'),
              ),
              const SizedBox(height: 12),
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
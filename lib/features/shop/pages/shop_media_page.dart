// lib/features/shop/pages/shop_media_page.dart
// 🔥 店家媒體設定頁（活動海報管理 完整版）

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:image/image.dart' as img;
// ❌ 已移除 image_cropper（Web會爆）

class ShopMediaPage extends StatefulWidget {
  const ShopMediaPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<ShopMediaPage> createState() => _ShopMediaPageState();
}

class _ShopMediaPageState extends State<ShopMediaPage> {
  bool _uploading = false;

  List<Map<String, dynamic>> banners = [];

  static const int _maxImageBytes = 5 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  void _loadBanners() async {
    final shop = await ShopService.instance.getShop(widget.shopId);
    final data = shop?['banners'];

    if (data != null && data is List) {
      setState(() {
        banners = data.map<Map<String, dynamic>>((e) {
          return {
            'imageUrl': e['imageUrl'] ?? '',
            'linkUrl': e['linkUrl'] ?? '',
            'isActive': e['isActive'] ?? true,
          };
        }).toList();
      });
    }
  }

  Future<void> _pickAndUploadImage(int index) async {
    final picker = ImagePicker();

    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (file == null) return;

    /// 🔥 不裁切（Web穩定版）
    final XFile finalFile = file;

    setState(() => _uploading = true);

    try {
      final Uint8List originalBytes = await finalFile.readAsBytes();

      final decoded = img.decodeImage(originalBytes);

      if (decoded == null) {
        throw Exception('圖片格式不支援（請使用 JPG / PNG）');
      }

      /// 🔥 自動縮放
      final resized = img.copyResize(
        decoded,
        width: 1200,
      );

      /// 🔥 轉 JPG
      final jpg = img.encodeJpg(resized, quality: 85);
      final bytes = Uint8List.fromList(jpg);

      /// 🔥 限制大小
      if (bytes.length > _maxImageBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('圖片需小於5MB')),
        );
        return;
      }

      /// 🔥 刪舊圖
      final oldUrl = banners[index]['imageUrl'];
      if (oldUrl != null && oldUrl.toString().isNotEmpty) {
        await ShopService.instance.deleteImageByUrl(oldUrl);
      }

      /// 🔥 上傳
      final url = await ShopService.instance.uploadShopCover(
        shopId: widget.shopId,
        bytes: bytes,
      );

      setState(() {
        banners[index]['imageUrl'] = url;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上傳失敗：$e')),
      );
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    await ShopService.instance.updateShop(
      shopId: widget.shopId,
      data: {
        'banners': banners,
      },
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('儲存成功')),
    );
  }

  Widget _buildHintCard({
    required String title,
    required String desc,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$title\n$desc',
        style: const TextStyle(height: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('活動海報管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          _buildHintCard(
            title: '海報說明',
            desc: '建議使用橫式16:9圖片（系統會自動處理比例）',
          ),

          const SizedBox(height: 16),

          ReorderableListView(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = banners.removeAt(oldIndex);
                banners.insert(newIndex, item);
              });
            },
            children: banners.asMap().entries.map((entry) {
              final index = entry.key;
              final banner = entry.value;

              return Card(
                key: ValueKey('banner_$index'),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [

                      Align(
                        alignment: Alignment.centerRight,
                        child: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle, color: Colors.grey),
                        ),
                      ),

                      banner['imageUrl'] != ''
                          ? AspectRatio(
                              aspectRatio: 16 / 9,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  banner['imageUrl'],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : const Text('尚未上傳圖片'),

                      const SizedBox(height: 6),

                      ElevatedButton(
                        onPressed: () => _pickAndUploadImage(index),
                        child: const Text('上傳圖片'),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        initialValue: banner['linkUrl'],
                        decoration: const InputDecoration(
                          labelText: '點擊連結（可空）',
                        ),
                        onChanged: (value) {
                          banner['linkUrl'] = value;
                        },
                      ),

                      SwitchListTile(
                        title: const Text('啟用'),
                        value: banner['isActive'],
                        onChanged: (value) {
                          setState(() {
                            banner['isActive'] = value;
                          });
                        },
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            final oldUrl = banners[index]['imageUrl'];

                            if (oldUrl != null && oldUrl.toString().isNotEmpty) {
                              await ShopService.instance.deleteImageByUrl(oldUrl);
                            }

                            setState(() {
                              banners.removeAt(index);
                            });
                          },
                          child: const Text('刪除'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          ElevatedButton(
            onPressed: () {
              if (banners.length >= 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('最多只能5張海報')),
                );
                return;
              }

              setState(() {
                banners.add({
                  'imageUrl': '',
                  'linkUrl': '',
                  'isActive': true,
                });
              });
            },
            child: const Text('新增海報'),
          ),

          if (_uploading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
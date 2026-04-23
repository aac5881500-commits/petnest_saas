import 'package:flutter/material.dart';

class RoomTypeDetailPage extends StatefulWidget {
  const RoomTypeDetailPage({
    super.key,
    required this.roomType,
    required this.startDate,
    required this.endDate,
  });

  final Map<String, dynamic> roomType;
  final DateTime startDate;
  final DateTime endDate;

  @override
  State<RoomTypeDetailPage> createState() => _RoomTypeDetailPageState();
}

class _RoomTypeDetailPageState extends State<RoomTypeDetailPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final images = List<String>.from(widget.roomType['images'] ?? []);

    return Scaffold(
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context, widget.roomType);
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('查看您的選項'),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 🔥 圖片區
            if (images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [

                    /// 左大圖
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 240,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(images[_currentIndex]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    /// 右小圖
                    SizedBox(
                      width: 90,
                      height: 240,
                      child: ListView.builder(
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() => _currentIndex = index);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              height: 70,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _currentIndex == index
                                      ? Colors.blue
                                      : Colors.transparent,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(images[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Center(child: Text('尚無圖片')),
              ),

            /// 🔥 房型資訊
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// 名稱
                  Text(
                    widget.roomType['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  /// 價格
                  Text(
                    'NT\$ ${widget.roomType['price']} / 晚',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 4),

                  /// 容量
                  Text(
                    '可住 ${widget.roomType['capacity']} 隻',
                    style: const TextStyle(color: Colors.grey),
                  ),

                  /// 加價
                  if ((widget.roomType['extraPrice'] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '每多一隻 +${widget.roomType['extraPrice']} 元',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  /// 🔥 小卡（主角）
                  _buildFeatureTags(widget.roomType['features'] ?? []),

                  const SizedBox(height: 20),


const SizedBox(height: 10),

Row(
  children: const [
    Icon(Icons.straighten, size: 16),
    SizedBox(width: 6),
    Text(
      '房間尺寸',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
  ],
),

                  /// 📏 尺寸
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _sizeItem('寬', widget.roomType['width']),
                        _sizeItem('深', widget.roomType['depth']),
                        _sizeItem('高', widget.roomType['height']),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// 🏠 房型介紹
                  if ((widget.roomType['description'] ?? '').toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.roomType['description'],
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// 📅 入住時間
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('入住時間'),
                        Text(
                          '${widget.startDate.month}月${widget.startDate.day}日',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('退房時間'),
                        Text(
                          '${widget.endDate.month}月${widget.endDate.day}日',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// 💰 價格
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('1晚房價'),
        Text(
          'TWD ${widget.roomType['price']}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text('含稅費與其他費用'),
      ],
    ),
  ),
),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// 尺寸
Widget _sizeItem(String label, dynamic value) {
  return Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 4),
      Text(
        '${value ?? 0} cm',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ],
  );
}

/// 小卡
Widget _buildFeatureTags(List features) {
  final featureOptions = {
    'private_space': {'name': '獨立包廂', 'icon': Icons.home},
    'daily_clean': {'name': '每日整理', 'icon': Icons.cleaning_services},
    'camera': {'name': '全日監控', 'icon': Icons.videocam},
    'aircon': {'name': '舒適空調', 'icon': Icons.ac_unit},
    'private_door': {'name': '獨立房門', 'icon': Icons.lock},
    'cat_window': {'name': '透明貓窗', 'icon': Icons.window},
    'sky_walk': {'name': '天空步道', 'icon': Icons.architecture},
    'scratch': {'name': '貓抓板', 'icon': Icons.pets},
    'jump': {'name': '跳台設計', 'icon': Icons.stairs},
    'bed': {'name': '舒眠睡窩', 'icon': Icons.bed},
  };

  return Wrap(
    spacing: 10,
    runSpacing: 10,
    children: features.map<Widget>((key) {
      final item = featureOptions[key];
      if (item == null) return const SizedBox();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
       decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: Colors.grey.shade200),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ],
),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item['icon'] as IconData, size: 18),
            const SizedBox(width: 6),
            Text(item['name'] as String),
          ],
        ),
      );
    }).toList(),
  );
}
// lib/features/platform/pages/platform_shop_list_page.dart
// 🏪 平台店家列表頁
// 功能：
// 1. 顯示所有公開店家
// 2. 點擊進入店家前台
// 3. 之後可擴充搜尋 / 篩選 / 排序

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';

class PlatformShopListPage extends StatelessWidget {
  const PlatformShopListPage({super.key});

String _businessTypeLabel(String value) {
  switch (value) {
    case 'cat_hotel':
      return '貓咪旅店';
    case 'dog_hotel':
      return '狗狗旅店';
    case 'grooming':
      return '美容';
    case 'hospital':
      return '動物醫院';
    case 'shop':
      return '寵物賣場';
    default:
      return '其他';
  }
}
String _moduleLabel(String value) {
  switch (value) {
    case 'cat_hotel':
      return '貓咪旅宿';
    case 'dog_hotel':
      return '狗狗旅宿';
    case 'grooming':
      return '寵物美容';
    case 'hospital':
      return '動物醫院';
    case 'shop':
      return '寵物賣場';
    default:
      return value;
  }
}

bool _isShopOpenNow(Map<String, dynamic> data) {
  final manualOpen = data['isOpen'] == true;
  if (!manualOpen) return false;

  final openTime = data['openTime']?.toString() ?? '';
  final closeTime = data['closeTime']?.toString() ?? '';

  if (openTime.isEmpty || closeTime.isEmpty) {
    return manualOpen;
  }

  final now = TimeOfDay.now();

  TimeOfDay? parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  final open = parseTime(openTime);
  final close = parseTime(closeTime);

  if (open == null || close == null) return manualOpen;

  final nowMinutes = now.hour * 60 + now.minute;
  final openMinutes = open.hour * 60 + open.minute;
  final closeMinutes = close.hour * 60 + close.minute;

  return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text('平台找店'),
  actions: [
    TextButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.map_outlined, size: 18),
      label: const Text('地圖'),
    ),
    TextButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.tune, size: 18),
      label: const Text('篩選'),
    ),
    const SizedBox(width: 6),
  ],
),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .where('isPublic', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('目前沒有公開店家'),
            );
          }

return Column(
  children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              size: 20,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: '搜尋店名、地區或服務',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    
    SizedBox(
  height: 42,
  child: ListView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    children: const [
      _QuickFilterChip(label: '全部', selected: true),
      SizedBox(width: 8),
      _QuickFilterChip(label: '貓咪旅宿'),
      SizedBox(width: 8),
      _QuickFilterChip(label: '寵物美容'),
      SizedBox(width: 8),
      _QuickFilterChip(label: '動物醫院'),
    ],
  ),
),

    Expanded(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: docs.length,

  gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: 0.68,
  ),

  itemBuilder: (context, index) {
    final doc = docs[index];

    final data =
        doc.data() as Map<String, dynamic>;

    final city = data['city'] ?? '';
    final district = data['district'] ?? '';
    final enabledModules = List<String>.from(
  data['enabledModules'] ?? [],
).where((item) {
  return item != 'basic_info' && item != 'reports';
}).toList();
   final platformHomeCoverUrl =
    data['platformHomeCoverUrl']?.toString() ?? '';
    final logoUrl =
    data['platformHomeLogoUrl']?.toString() ?? '';

final coverUrl = platformHomeCoverUrl.isNotEmpty
    ? platformHomeCoverUrl
    : data['coverUrl']?.toString() ?? '';

final isOpen = _isShopOpenNow(data);
final openTime = data['openTime']?.toString() ?? '';
final closeTime = data['closeTime']?.toString() ?? '';
final businessTimeText = openTime.isNotEmpty && closeTime.isNotEmpty
    ? '$openTime - $closeTime'
    : '尚未設定營業時間';
    return InkWell(
      borderRadius: BorderRadius.circular(20),

      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShopPublicPage(
              shopId: doc.id,
            ),
          ),
        );
      },

      child: Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
           Stack(
  clipBehavior: Clip.none,
  children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
    children: [
      Container(
        height: 120,
        width: double.infinity,
        color: Colors.grey.shade200,
        child: coverUrl.isNotEmpty
            ? Image.network(
                coverUrl,
                fit: BoxFit.cover,
              )
            : const Center(
                child: Icon(
                  Icons.store,
                  color: Colors.black26,
                  size: 38,
                ),
              ),
      ),

      Positioned(
        left: 12,
        top: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: isOpen
                ? Colors.green.shade50
                : Colors.red.shade50,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            isOpen ? '營業中' : '休息中',
            style: TextStyle(
              color: isOpen
                  ? Colors.green.shade700
                  : Colors.red.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ],
  ),
),
Positioned(
  left: 14,
  bottom: -18,
  child: Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.white,
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 8,
        ),
      ],
      image: logoUrl.isNotEmpty
          ? DecorationImage(
              image: NetworkImage(logoUrl),
              fit: BoxFit.cover,
            )
          : null,
    ),
    child: logoUrl.isEmpty
        ? const Icon(
            Icons.pets,
            size: 22,
            color: Colors.black38,
          )
        : null,
  ),
),
  ],
),
            const SizedBox(height: 28),

            Text(
              data['name'] ?? '未命名店家',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,

              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              '$city $district',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 6),

          Wrap(
  spacing: 6,
  runSpacing: 6,
  children: enabledModules.isEmpty
      ? [
          _ServiceChip(
            label: _businessTypeLabel(
              data['businessType']?.toString() ?? '',
            ),
          ),
        ]
      : enabledModules
          .map(
            (module) => _ServiceChip(
              label: _moduleLabel(module),
            ),
          )
          .toList(),
),
const Spacer(),

Row(
  children: [
    Icon(
      Icons.schedule,
      size: 14,
      color: Colors.grey.shade500,
    ),
    const SizedBox(width: 4),
    Expanded(
      child: Text(
        businessTimeText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ],
),
  ],
),
      ),
    );
    },
),
),
  ],
);
        },
      ),
    );
  }
}
class _ServiceChip extends StatelessWidget {
  const _ServiceChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1565C0),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.label,
    this.selected = false,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1565C0) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? const Color(0xFF1565C0) : Colors.grey.shade200,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.grey.shade700,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
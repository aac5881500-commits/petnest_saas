// lib/features/platform/pages/create_shop_page.dart
// 🏪 平台建立店家頁

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class CreateShopPage extends StatefulWidget {
  const CreateShopPage({super.key});

  @override
  State<CreateShopPage> createState() => _CreateShopPageState();
}

class _CreateShopPageState extends State<CreateShopPage> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();

  bool _loading = false;

  final Map<String, List<String>> taiwanMap = {
  '新北市': ['板橋區', '淡水區', '中和區'],
  '台北市': ['大安區', '信義區'],
  '新竹縣': ['竹北市', '新埔鎮', '湖口鄉'],
  '新竹市': ['東區', '北區', '香山區'],
  '桃園市': ['中壢區', '桃園區'],
};

  Future<void> _createShop() async {
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();
    final district = _districtController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入店名')),
      );
      return;
    }

if (city.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('請選擇城市')),
  );
  return;
}

if (district.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('請選擇區域')),
  );
  return;
}

    try {
      setState(() {
        _loading = true;
      });

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      await ShopService.instance.createShop(
  name: name,
  city: city,
  district: district,
  businessType: 'cat_hotel',
);

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('建立成功')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('建立失敗: $e')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('建立店家')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '店家名稱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
  value: _cityController.text.isEmpty ? null : _cityController.text,
  decoration: const InputDecoration(
    labelText: '縣市',
    border: OutlineInputBorder(),
  ),
  items: taiwanMap.keys.map((city) {
    return DropdownMenuItem(
      value: city,
      child: Text(city),
    );
  }).toList(),
  onChanged: (value) {
    setState(() {
      _cityController.text = value ?? '';
      _districtController.clear();
    });
  },
),
            const SizedBox(height: 20),
            const SizedBox(height: 12),

DropdownButtonFormField<String>(
  value: _districtController.text.isEmpty
      ? null
      : _districtController.text,
  decoration: const InputDecoration(
    labelText: '區域',
    border: OutlineInputBorder(),
  ),
  items: (_cityController.text.isEmpty
          ? <String>[]
          : taiwanMap[_cityController.text] ?? [])
      .map((district) {
    return DropdownMenuItem(
      value: district,
      child: Text(district),
    );
  }).toList(),
  onChanged: (value) {
    setState(() {
      _districtController.text = value ?? '';
    });
  },
),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _createShop,
                child: Text(_loading ? '建立中...' : '建立店家'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
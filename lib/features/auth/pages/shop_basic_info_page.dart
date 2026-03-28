// 檔案名稱：lib/features/auth/pages/shop_basic_info_page.dart
// 說明：店家基本資料編輯頁
//
// 功能：
// - 讀取單一店家資料
// - 編輯店名 / 類型 / 電話 / 地址 / 城市 / 地區 / LINE / 店家介紹
// - 儲存回 Firestore

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopBasicInfoPage extends StatefulWidget {
  const ShopBasicInfoPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<ShopBasicInfoPage> createState() => _ShopBasicInfoPageState();
}

class _ShopBasicInfoPageState extends State<ShopBasicInfoPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _lineUrlController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String _businessType = 'cat';

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    try {
      final shop = await ShopService.instance.getShop(widget.shopId);

      if (shop == null) {
        throw Exception('找不到店家資料');
      }

      _nameController.text = shop['name'] ?? '';
      _phoneController.text = shop['phone'] ?? '';
      _addressController.text = shop['address'] ?? '';
      _descriptionController.text = shop['description'] ?? '';
      _cityController.text = shop['city'] ?? '';
      _districtController.text = shop['district'] ?? '';
      _lineUrlController.text = shop['lineUrl'] ?? '';

      final type = shop['businessType'] ?? 'cat';
      if (['cat', 'dog', 'hospital', 'grooming'].contains(type)) {
        _businessType = type;
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入失敗：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await ShopService.instance.updateShopBasicInfo(
        shopId: widget.shopId,
        name: _nameController.text,
        businessType: _businessType,
        phone: _phoneController.text,
        address: _addressController.text,
        description: _descriptionController.text,
        city: _cityController.text,
        district: _districtController.text,
        lineUrl: _lineUrlController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('店家基本資料已儲存')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _lineUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('店家基本資料'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: _input('店名'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '請輸入店名';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _businessType,
                      decoration: _input('店家類型'),
                      items: const [
                        DropdownMenuItem(
                          value: 'cat',
                          child: Text('貓旅宿'),
                        ),
                        DropdownMenuItem(
                          value: 'dog',
                          child: Text('狗旅宿'),
                        ),
                        DropdownMenuItem(
                          value: 'hospital',
                          child: Text('動物醫院'),
                        ),
                        DropdownMenuItem(
                          value: 'grooming',
                          child: Text('美容'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _businessType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _input('聯絡電話'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cityController,
                      decoration: _input('縣市'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _districtController,
                      decoration: _input('地區 / 鄉鎮市區'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: _input('完整地址'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lineUrlController,
                      decoration: _input('LINE 連結'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: _input('店家介紹'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? '儲存中...' : '儲存'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
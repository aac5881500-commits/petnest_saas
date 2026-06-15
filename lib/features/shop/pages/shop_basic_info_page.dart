// lib/features/shop/pages/shop_basic_info_page.dart
// 👤 店家基本資料（完整版🔥）
// ✅ 縣市區域下拉
// ✅ IG / FB
// ✅ LINE 移動
// ✅ 移除介紹

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_change_request_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_request_center_page.dart';

class ShopBasicInfoPage extends StatefulWidget {
  const ShopBasicInfoPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopBasicInfoPage> createState() => _ShopBasicInfoPageState();
}

class _ShopBasicInfoPageState extends State<ShopBasicInfoPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();

  final _lineUrlController = TextEditingController();
  final _igUrlController = TextEditingController();
  final _fbUrlController = TextEditingController();

  final _businessHoursController = TextEditingController();
  final _licenseController = TextEditingController();
  final _taxIdController = TextEditingController();

  bool _showTaxId = true;
  bool _loading = true;
  bool _saving = false;

  String _businessType = 'cat';

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    final shop = await ShopService.instance.getShop(widget.shopId);

    _nameController.text = shop?['name'] ?? '';
    _phoneController.text = shop?['phone'] ?? '';
    _addressController.text = shop?['address'] ?? '';
    _cityController.text = shop?['city'] ?? '';
    _districtController.text = shop?['district'] ?? '';

    _lineUrlController.text = shop?['lineUrl'] ?? '';
    _igUrlController.text = shop?['igUrl'] ?? '';
    _fbUrlController.text = shop?['fbUrl'] ?? '';

    _licenseController.text = shop?['licenseNumber'] ?? '';
    _taxIdController.text = shop?['taxId'] ?? '';
    _showTaxId = shop?['showTaxId'] ?? true;

    final rawBusinessType = shop?['businessType']?.toString() ?? 'cat_hotel';

    _businessType = rawBusinessType == 'cat' ? 'cat_hotel' : rawBusinessType;

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    await ShopService.instance.updateShopBasicInfo(
      shopId: widget.shopId,
      name: _nameController.text,
      businessType: _businessType,
      phone: _phoneController.text,
      address: _addressController.text,
      city: _cityController.text,
      district: _districtController.text,

      lineUrl: _lineUrlController.text,
      igUrl: _igUrlController.text,
      fbUrl: _fbUrlController.text,

      licenseNumber: _licenseController.text,
      taxId: _taxIdController.text,
      showTaxId: _showTaxId,
    );

    setState(() => _saving = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已儲存')));
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  String? _validateSocialUrl({required String? value, required String type}) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return null;

    final uri = Uri.tryParse(text);

    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return '請輸入完整網址，例如 https://...';
    }

    final host = uri.host.toLowerCase();

    if (type == 'line') {
      if (host == 'line.me' ||
          host == 'www.line.me' ||
          host == 'page.line.me' ||
          host == 'lin.ee') {
        return null;
      }

      return 'LINE 連結只能使用 line.me、page.line.me 或 lin.ee';
    }

    if (type == 'ig') {
      if (host == 'instagram.com' || host == 'www.instagram.com') return null;
      return 'IG 連結只能使用 instagram.com';
    }

    if (type == 'fb') {
      if (host == 'facebook.com' ||
          host == 'www.facebook.com' ||
          host == 'fb.me') {
        return null;
      }
      return 'FB 連結只能使用 facebook.com 或 fb.me';
    }

    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _lineUrlController.dispose();
    _igUrlController.dispose();
    _fbUrlController.dispose();
    _businessHoursController.dispose();
    _licenseController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('店家基本資料')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '為保障店家與消費者權益，店名、店家類型、電話、縣市、區域、地址、特寵字號、統編等重要資料若需修改，需由平台人工審核後協助處理，以避免冒用、詐騙或資料異常情形。\n\n'
                            'LINE、IG、FB 可由店家自行更新；未來平台後台會提供對外連結快速關閉功能，避免帳號遭盜用或連結被濫用時無法即時處理。',
                            style: TextStyle(fontSize: 13, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '重要資料需透過申請修改流程處理，平台確認資料正確後才會更新正式資料。',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextFormField(
                    controller: _nameController,
                    readOnly: true,
                    decoration: _input(
                      '店名（建立後不可修改）',
                    ).copyWith(filled: true, fillColor: Colors.grey.shade100),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _businessType,
                    decoration: _input(
                      '類型（建立後不可修改）',
                    ).copyWith(filled: true, fillColor: Colors.grey.shade100),
                    items: const [
                      DropdownMenuItem(value: 'cat_hotel', child: Text('貓咪旅店')),
                      DropdownMenuItem(value: 'dog_hotel', child: Text('狗狗旅店')),
                      DropdownMenuItem(value: 'grooming', child: Text('美容功能')),
                      DropdownMenuItem(value: 'hospital', child: Text('動物醫院')),
                      DropdownMenuItem(value: 'shop', child: Text('賣場功能')),
                    ],
                    onChanged: null,
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneController,
                    readOnly: true,
                    decoration: _input(
                      '電話（需申請修改）',
                    ).copyWith(filled: true, fillColor: Colors.grey.shade100),
                  ),

                  const SizedBox(height: 16),

                  /// 🔥 縣市
                  TextFormField(
                    controller: _cityController,
                    readOnly: true,
                    decoration: _input(
                      '縣市（需申請修改）',
                    ).copyWith(filled: true, fillColor: Colors.grey.shade100),
                  ),
                  const SizedBox(height: 16),

                  /// 🔥 區域
                  TextFormField(
                    controller: _districtController,
                    readOnly: true,
                    decoration: _input(
                      '區域（需申請修改）',
                    ).copyWith(filled: true, fillColor: Colors.grey.shade100),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _addressController,
                    readOnly: true,
                    decoration: _input(
                      '地址（需申請修改）',
                    ).copyWith(filled: true, fillColor: Colors.grey.shade100),
                  ),

                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _licenseController,
                    readOnly: true,
                    decoration: _input(
                      '特寵字號（需申請修改）',
                    ).copyWith(filled: true, fillColor: Colors.grey.shade100),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _taxIdController,
                    readOnly: true,
                    decoration: _input(
                      '統編（需申請修改）',
                    ).copyWith(filled: true, fillColor: Colors.grey.shade100),
                  ),

                  SwitchListTile(
                    value: _showTaxId,
                    title: const Text('顯示統編'),
                    onChanged: (v) => setState(() => _showTaxId = v),
                  ),

                  const SizedBox(height: 16),

                  /// 🔥 LINE / IG / FB
                  TextFormField(
                    controller: _lineUrlController,
                    decoration: _input('LINE'),
                    validator: (v) =>
                        _validateSocialUrl(value: v, type: 'line'),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _igUrlController,
                    decoration: _input('IG'),
                    validator: (v) => _validateSocialUrl(value: v, type: 'ig'),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _fbUrlController,
                    decoration: _input('FB'),
                    validator: (v) => _validateSocialUrl(value: v, type: 'fb'),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '儲存中' : '儲存社群資訊'),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShopChangeRequestPage(
                            shopId: widget.shopId,
                            shopName: _nameController.text,
                            currentCity: _cityController.text,
                            currentDistrict: _districtController.text,
                            currentPhone: _phoneController.text,
                            currentAddress: _addressController.text,
                            currentLicenseNumber: _licenseController.text,
                            currentTaxId: _taxIdController.text,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text('申請修改重要資料'),
                  ),

                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ShopRequestCenterPage(shopId: widget.shopId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('查看申請紀錄'),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    '重要資料修改申請功能即將推出。\n'
                    '未來送出申請後，平台確認資料正確性後才會更新正式資料。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

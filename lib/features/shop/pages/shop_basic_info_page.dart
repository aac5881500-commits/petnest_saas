// lib/features/shop/pages/shop_basic_info_page.dart
// 👤 店家基本資料（完整版🔥）
// ✅ 縣市區域下拉
// ✅ IG / FB
// ✅ LINE 移動
// ✅ 移除介紹

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/pages/shop_change_request_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_request_center_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_verify_request_page.dart';

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
  bool _licenseVerified = false;
  bool _taxIdVerified = false;
  bool _isPublic = false;

  bool _isInitialSetup = false;

  /// 特寵字號與統編是否仍為首次設定
  bool _licenseInitialSetup = false;
  bool _taxIdInitialSetup = false;

  bool _lineInitialSetup = false;
  bool _igInitialSetup = false;
  bool _fbInitialSetup = false;
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
    _licenseVerified = shop?['licenseVerified'] == true;
    _taxIdVerified = shop?['taxIdVerified'] == true;
    _isPublic = shop?['isPublic'] == true;

    final rawBusinessType = shop?['businessType']?.toString() ?? 'cat_hotel';

    _businessType = rawBusinessType == 'cat' ? 'cat_hotel' : rawBusinessType;

    _isInitialSetup =
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty;

    /// 欄位沒有資料時，可以進行第一次設定；已有資料就鎖定
    _licenseInitialSetup = _licenseController.text.trim().isEmpty;
    _taxIdInitialSetup = _taxIdController.text.trim().isEmpty;

    _lineInitialSetup = _lineUrlController.text.trim().isEmpty;

    _igInitialSetup = _igUrlController.text.trim().isEmpty;

    _fbInitialSetup = _fbUrlController.text.trim().isEmpty;

    if (!mounted) return;

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
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

      /// 第一次儲存成功後，只要已有資料就立即改為鎖定狀態
      _licenseInitialSetup = _licenseController.text.trim().isEmpty;
      _taxIdInitialSetup = _taxIdController.text.trim().isEmpty;

      _lineInitialSetup = _lineUrlController.text.trim().isEmpty;
      _igInitialSetup = _igUrlController.text.trim().isEmpty;
      _fbInitialSetup = _fbUrlController.text.trim().isEmpty;

      _isInitialSetup =
          _phoneController.text.trim().isEmpty ||
          _addressController.text.trim().isEmpty;

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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

  void _openVerifyRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopVerifyRequestPage(
          shopId: widget.shopId,
          shopName: _nameController.text,
          currentLicenseNumber: _licenseController.text,
          currentTaxId: _taxIdController.text,
        ),
      ),
    );
  }

  Widget _verifyStatusCard() {
    final verified = _licenseVerified && _taxIdVerified && _isPublic;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openVerifyRequest,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: verified ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: verified ? Colors.green.shade200 : Colors.orange.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              verified ? Icons.verified : Icons.verified_user_outlined,
              color: verified ? Colors.green : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '店家認證狀態',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    verified ? '已完成認證，店家目前已公開於平台' : '尚未完成認證，點擊送出認證申請',
                    style: TextStyle(
                      color: verified
                          ? Colors.green.shade800
                          : Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
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
      appBar: AppBar(
        title: const Text('店家基本資料'),
        actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
      ),
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
                            '店名、電話、地址、特寵字號、統編、LINE、IG、FB 等重要公開資訊，若需修改皆需由平台審核後更新。',
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isInitialSetup
                                ? '請先完成店家基本資料設定，完成後重要資料將鎖定並改為申請修改模式。'
                                : '重要資料需透過申請修改流程處理，平台確認資料正確後才會更新正式資料。',
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
                  _verifyStatusCard(),
                  TextFormField(
                    controller: _nameController,
                    readOnly: true,
                    decoration: _input(
                      '店名（需申請修改）',
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
                    readOnly: !_isInitialSetup,
                    decoration: _input(
                      _isInitialSetup ? '電話（首次設定）' : '電話（需申請修改）',
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
                    readOnly: !_isInitialSetup,
                    decoration: _input(
                      _isInitialSetup ? '地址（首次設定）' : '地址（需申請修改）',
                    ).copyWith(filled: true, fillColor: Colors.grey.shade100),
                  ),

                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '特寵字號認證',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _licenseController,
                          readOnly: !_licenseInitialSetup,
                          decoration:
                              _input(
                                _licenseInitialSetup
                                    ? '特寵字號（首次設定）'
                                    : '特寵字號（需申請修改）',
                              ).copyWith(
                                filled: true,
                                fillColor: _licenseInitialSetup
                                    ? Colors.white
                                    : Colors.grey.shade100,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '此資料需平台確認後，店家才能在平台前台公開曝光。',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '統編認證',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _taxIdController,
                          readOnly: !_taxIdInitialSetup,
                          decoration:
                              _input(
                                _taxIdInitialSetup ? '統編（首次設定）' : '統編（需申請修改）',
                              ).copyWith(
                                filled: true,
                                fillColor: _taxIdInitialSetup
                                    ? Colors.white
                                    : Colors.grey.shade100,
                              ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _showTaxId,
                          title: const Text('前台顯示統編'),
                          onChanged: (v) => setState(() => _showTaxId = v),
                        ),
                        Text(
                          '統編可選擇是否顯示，但是否能平台公開仍需平台認證。',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// 🔥 LINE / IG / FB
                  TextFormField(
                    controller: _lineUrlController,
                    validator: (value) =>
                        _validateSocialUrl(value: value, type: 'line'),
                    readOnly: !_lineInitialSetup,
                    decoration: _input(
                      _lineInitialSetup ? 'LINE（首次設定）' : 'LINE（需申請修改）',
                    ).copyWith(filled: true, fillColor: Colors.grey.shade100),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _igUrlController,
                    validator: (value) =>
                        _validateSocialUrl(value: value, type: 'ig'),
                    readOnly: !_igInitialSetup,
                    decoration: _input(
                      _igInitialSetup ? 'IG（首次設定）' : 'IG（需申請修改）',
                    ).copyWith(filled: true, fillColor: Colors.grey.shade100),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _fbUrlController,
                    validator: (value) =>
                        _validateSocialUrl(value: value, type: 'fb'),
                    readOnly: !_fbInitialSetup,
                    decoration: _input(
                      _fbInitialSetup ? 'FB（首次設定）' : 'FB（需申請修改）',
                    ).copyWith(filled: true, fillColor: Colors.grey.shade100),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '儲存中' : '儲存顯示設定'),
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
                            currentLineUrl: _lineUrlController.text,
                            currentIgUrl: _igUrlController.text,
                            currentFbUrl: _fbUrlController.text,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text('申請修改重要資料'),
                  ),

                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShopVerifyRequestPage(
                            shopId: widget.shopId,
                            shopName: _nameController.text,
                            currentLicenseNumber: _licenseController.text,
                            currentTaxId: _taxIdController.text,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('申請認證／平台公開'),
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
                    '重要資料、特寵字號、統編與平台公開皆透過此申請流程。\n'
                    '平台審核通過後才會正式更新或開放公開。',
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

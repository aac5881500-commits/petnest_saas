import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';
// 檔案名稱：lib/features/shop/pages/shop_basic_info_page.dart
// 功能說明：店家基本資料（完整版）
// ✅ 縣市區域沿用創店資料並鎖定
// ✅ IG / FB
// ✅ LINE 移動
// ✅ 移除介紹

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/taiwan_city_data.dart';
import 'package:petnest_saas/core/legal_pet/license_lookup.dart';
import 'package:petnest_saas/core/legal_pet/shop_profile_lock.dart';
import 'package:petnest_saas/core/services/legal_pet_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/pages/shop_change_request_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_request_center_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_verify_request_page.dart';
import 'package:petnest_saas/features/shop/shop_admin_welcome.dart';
import 'package:petnest_saas/features/shop/widgets/legal_pet_license_check_card.dart';
import 'package:petnest_saas/features/shop/widgets/legal_pet_license_input.dart';
import 'package:petnest_saas/features/shop/widgets/shop_contact_setup_guide.dart';

class ShopBasicInfoPage extends StatefulWidget {
  const ShopBasicInfoPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopBasicInfoPage> createState() => _ShopBasicInfoPageState();
}

class _ShopBasicInfoPageState extends State<ShopBasicInfoPage>
    with ShopDashboardLeaveAware<ShopBasicInfoPage> {
  String? _dashboardSavedDraft;
  String get _dashboardDraft => [
    _nameController.text,
    _phoneController.text,
    _addressController.text,
    _lineUrlController.text,
    _igUrlController.text,
    _fbUrlController.text,
    _licenseController.text,
    _taxIdController.text,
    _showTaxId.toString(),
    _isPublic.toString(),
  ].map((value) => '${value.length}:$value').join();
  @override
  bool get dashboardHasUnsavedChanges =>
      !_loading && _dashboardSavedDraft != _dashboardDraft;
  @override
  bool get dashboardIsBusy => _saving || _lookingUp;

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
  String _verifyRequestStatus = '';

  bool _addressSetupCompleted = false;
  bool _phoneSetupCompleted = false;
  bool _lookingUp = false;
  LegalPetLookupResult? _lookup;
  LegalPetLookupInputs? _lookupInputs;

  /// 特寵字號與統編是否仍為首次設定
  bool _licenseInitialSetup = false;
  String _persistedLicense = '';
  bool _taxIdInitialSetup = false;

  bool _lineInitialSetup = false;
  bool _igInitialSetup = false;
  bool _fbInitialSetup = false;
  String _businessType = 'cat';
  bool _isNewShop = false;
  bool _profileChangePending = false;

  bool get _contactIncomplete =>
      !_phoneSetupCompleted || !_addressSetupCompleted;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _cityController,
      _districtController,
      _addressController,
    ]) {
      controller.addListener(_onCheckInputsChanged);
    }
    _loadShopData();
  }

  void _onCheckInputsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadShopData() async {
    final shop = await ShopService.instance.getShop(widget.shopId);
    if (!mounted) return;

    _nameController.text = shop?['name'] ?? '';
    _phoneController.text = shop?['phone'] ?? '';
    _addressController.text = shop?['address'] ?? '';
    _cityController.text = shop?['city'] ?? '';
    _districtController.text = shop?['district'] ?? '';

    _lineUrlController.text = shop?['lineUrl'] ?? '';
    _igUrlController.text = shop?['igUrl'] ?? '';
    _fbUrlController.text = shop?['fbUrl'] ?? '';

    _persistedLicense = (shop?['licenseNumber'] ?? '').toString();
    _licenseController.text = licenseInputText(_persistedLicense);
    _taxIdController.text = shop?['taxId'] ?? '';
    _showTaxId = shop?['showTaxId'] ?? true;
    _licenseVerified = shop?['licenseVerified'] == true;
    _taxIdVerified = shop?['taxIdVerified'] == true;
    _isPublic = shop?['isPublic'] == true;
    _verifyRequestStatus = await _loadVerifyRequestStatus();
    if (!mounted) return;

    _addressSetupCompleted = isAddressSetupCompleted(shop);
    _phoneSetupCompleted = isPhoneSetupCompleted(shop);
    _isNewShop = ShopAdminWelcome.isNewShop(shop ?? <String, dynamic>{});
    _profileChangePending = await _hasPendingProfileChange();
    if (!mounted) return;

    final rawBusinessType = shop?['businessType']?.toString() ?? 'cat_hotel';

    _businessType = rawBusinessType == 'cat' ? 'cat_hotel' : rawBusinessType;

    /// 欄位沒有資料時，可以進行第一次設定；已有資料就鎖定
    _licenseInitialSetup = _persistedLicense.trim().isEmpty;
    _taxIdInitialSetup = _taxIdController.text.trim().isEmpty;

    _lineInitialSetup = _lineUrlController.text.trim().isEmpty;

    _igInitialSetup = _igUrlController.text.trim().isEmpty;

    _fbInitialSetup = _fbUrlController.text.trim().isEmpty;

    if (!mounted) return;

    _dashboardSavedDraft = _dashboardDraft;
    setState(() => _loading = false);
  }

  Future<String> _loadVerifyRequestStatus() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> pending =
          await FirebaseFirestore.instance
              .collection('shop_change_requests')
              .where('shopId', isEqualTo: widget.shopId)
              .where('requestType', isEqualTo: 'fullVerify')
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();
      if (pending.docs.isNotEmpty) {
        return 'pending';
      }
      final QuerySnapshot<Map<String, dynamic>> rejected =
          await FirebaseFirestore.instance
              .collection('shop_change_requests')
              .where('shopId', isEqualTo: widget.shopId)
              .where('requestType', isEqualTo: 'fullVerify')
              .where('status', isEqualTo: 'rejected')
              .limit(1)
              .get();
      if (rejected.docs.isNotEmpty) {
        return 'rejected';
      }
    } catch (_) {}
    return '';
  }

  Future<bool> _hasPendingProfileChange() async {
    const types = <String>['phone', 'address', 'name'];
    try {
      for (final type in types) {
        final QuerySnapshot<Map<String, dynamic>> pending =
            await FirebaseFirestore.instance
                .collection('shop_change_requests')
                .where('shopId', isEqualTo: widget.shopId)
                .where('requestType', isEqualTo: type)
                .where('status', isEqualTo: 'pending')
                .limit(1)
                .get();
        if (pending.docs.isNotEmpty) return true;
      }
    } catch (_) {}
    return false;
  }

  String? _firstStepBlockReason() {
    final error = validateShopContactPhone(_phoneController.text);
    if (error != null) return error;
    if (!_locationComplete) return '目前店家所在地資料不完整，請透過既有資料修正流程處理。';
    if (_addressController.text.trim().isEmpty) return '請填寫詳細地址';
    return null;
  }

  Future<void> _saveFirstStep() {
    return _save(finishFirstStep: true);
  }

  Future<void> _openImportantNotes() async {
    const String body =
        '為保障店家與消費者權益，避免冒用、詐騙與資料異常，重要資料修改需經平台人工審核。\n\n'
        '店名、電話、縣市、區域、地址、特寵字號、統編及 LINE／Instagram／Facebook 等重要公開資訊，依現有規則申請修改。\n\n'
        '申請送出不代表正式資料已更新，平台確認後才更新。\n\n'
        '店家類型於建立後不可修改，也不能申請修改。';
    final bool compact = MediaQuery.sizeOf(context).width < 720;
    if (compact) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext context) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '重要資料修改說明',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(body, style: const TextStyle(height: 1.5, fontSize: 14)),
              ],
            ),
          );
        },
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('重要資料修改說明'),
          content: const SingleChildScrollView(
            child: Text(body, style: TextStyle(height: 1.5)),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save({bool finishFirstStep = false}) async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (finishFirstStep) {
      final String? blocked = _firstStepBlockReason();
      if (blocked != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(blocked)));
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final bool savingAddress =
          !_addressSetupCompleted && _addressController.text.trim().isNotEmpty;
      final bool savingPhone =
          !_phoneSetupCompleted && _phoneController.text.trim().isNotEmpty;
      if (savingAddress && !_locationComplete) {
        throw StateError('目前店家所在地資料不完整，請透過既有資料修正流程處理。');
      }
      if (savingPhone &&
          validateShopContactPhone(_phoneController.text) != null) {
        throw StateError(validateShopContactPhone(_phoneController.text)!);
      }
      final licenseNumber = _licenseToSave();
      // Existing shops update path: nonempty values lock phone/address.
      // A transactional read prevents overwriting concurrent initial setup.
      final ref = FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final current = snapshot.data();
        if (current == null) throw StateError('找不到店家資料');
        final patch = <String, dynamic>{
          'name': _nameController.text.trim(),
          'businessType': _businessType,
          'lineUrl': _lineUrlController.text.trim(),
          'igUrl': _igUrlController.text.trim(),
          'fbUrl': _fbUrlController.text.trim(),
          'licenseNumber': licenseNumber.trim(),
          'taxId': _taxIdController.text.trim(),
          'showTaxId': _showTaxId,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (savingAddress) {
          if (isAddressSetupCompleted(current) ||
              current['city'] != _cityController.text ||
              current['district'] != _districtController.text) {
            throw StateError('店家資料已更新，請重新載入後確認');
          }
          patch['address'] = _addressController.text.trim();
          patch['addressSetupCompleted'] = true;
        }
        if (savingPhone) {
          if (isPhoneSetupCompleted(current)) {
            throw StateError('店家資料已更新，請重新載入後確認');
          }
          patch['phone'] = _phoneController.text.trim();
          patch['phoneSetupCompleted'] = true;
        }
        // Never send city/district, even during ordinary saves.
        transaction.update(ref, patch);
      });

      /// 第一次儲存成功後，只要已有資料就立即改為鎖定狀態
      _persistedLicense = licenseNumber;
      _licenseInitialSetup = _persistedLicense.trim().isEmpty;
      _taxIdInitialSetup = _taxIdController.text.trim().isEmpty;

      _lineInitialSetup = _lineUrlController.text.trim().isEmpty;
      _igInitialSetup = _igUrlController.text.trim().isEmpty;
      _fbInitialSetup = _fbUrlController.text.trim().isEmpty;
      if (_addressController.text.trim().isNotEmpty) {
        _addressSetupCompleted = true;
      }
      if (_phoneController.text.trim().isNotEmpty) {
        _phoneSetupCompleted = true;
      }

      if (!mounted) return;

      _dashboardSavedDraft = _dashboardDraft;
      if (finishFirstStep) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('基本聯絡資訊已完成！')));
        Navigator.of(context).pop();
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存')));
    } on LegalPetException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
      MaterialPageRoute<void>(
        builder: (_) => ShopVerifyRequestPage(
          shopId: widget.shopId,
          shopName: _nameController.text,
          currentLicenseNumber: _licenseToSave(),
          currentTaxId: _taxIdController.text,
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

  void _openChangeRequest({
    String? initialRequestType,
    String? initialCity,
    String? initialDistrict,
    String? initialAddress,
    String? initialHint,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ShopChangeRequestPage(
          shopId: widget.shopId,
          shopName: _nameController.text,
          currentCity: _cityController.text,
          currentDistrict: _districtController.text,
          currentPhone: _phoneController.text,
          currentAddress: _addressController.text,
          currentLicenseNumber: _licenseToSave(),
          currentTaxId: _taxIdController.text,
          currentLineUrl: _lineUrlController.text,
          currentIgUrl: _igUrlController.text,
          currentFbUrl: _fbUrlController.text,
          initialRequestType: initialRequestType ?? 'phone',
          initialNewCity: initialCity,
          initialNewDistrict: initialDistrict,
          initialNewAddress: initialAddress,
          initialHint: initialHint,
        ),
      ),
    );
  }

  String _licenseToSave() {
    return licenseValueToStore(
      persisted: _persistedLicense,
      current: _licenseController.text,
    );
  }

  void _clearLookupResult() {
    if (_lookup == null && _lookupInputs == null) return;
    setState(() {
      _lookup = null;
      _lookupInputs = null;
    });
  }

  Future<void> _lookupLicense() async {
    final license = _licenseController.text.trim();
    if (license.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先填寫特寵字號')));
      return;
    }
    setState(() => _lookingUp = true);
    try {
      final result = await LegalPetService.instance.lookupLicense(
        shopId: widget.shopId,
        licenseNumber: license,
        city: _cityController.text,
        district: _districtController.text,
        address: _addressController.text,
      );
      _lookup = result;
      _lookupInputs = LegalPetLookupInputs(
        license: _licenseController.text,
        city: _cityController.text,
        district: _districtController.text,
        address: _addressController.text,
      );
    } on LegalPetException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  void _applyGovernmentAddress(LegalPetMatch match) {
    final parsed = match.parsedAddress;
    if (!parsed.reliable || _addressSetupCompleted) return;
    if (parsed.city != _cityController.text ||
        parsed.district != _districtController.text) {
      _requestRegisteredAddress(match);
      return;
    }
    setState(() {
      _addressController.text = parsed.detail;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已帶入表單，按儲存後才會寫入')));
  }

  void _requestRegisteredAddress(LegalPetMatch match) {
    final parsed = match.parsedAddress;
    _openChangeRequest(
      initialRequestType: 'address',
      initialCity: parsed.reliable ? parsed.city : _cityController.text,
      initialDistrict: parsed.reliable
          ? parsed.district
          : _districtController.text,
      initialAddress: parsed.reliable ? parsed.detail : match.legaladdress,
      initialHint: parsed.reliable
          ? '已預填政府登記地址，核准前不會改正式地址。'
          : '政府地址無法可靠拆成縣市與區域，原始地址已放在詳細地址，請確認後再送出。',
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required bool locked,
    required bool firstSetup,
  }) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: locked ? const Color(0xFFF4F1EC) : Colors.white,
      suffixIcon: locked
          ? const Icon(Icons.lock_outline, size: 18)
          : (firstSetup ? const Icon(Icons.edit_outlined, size: 18) : null),
      helperText: locked ? '需申請修改' : (firstSetup ? '首次設定後將鎖定' : null),
      helperMaxLines: 1,
    );
  }

  Widget _lockedField({
    required String label,
    required TextEditingController controller,
    required bool locked,
    bool firstSetup = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: locked,
      validator: validator,
      keyboardType: keyboardType,
      decoration: _fieldDecoration(
        label: label,
        locked: locked,
        firstSetup: firstSetup,
      ).copyWith(hintText: hintText),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
    Widget? footer,
    String? laterTitle,
    bool laterHeading = false,
  }) {
    final Widget card = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.brown.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ...children,
            if (footer != null) ...<Widget>[const SizedBox(height: 12), footer],
          ],
        ),
      ),
    );
    if (!_contactIncomplete || laterTitle == null) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (laterHeading) ...<Widget>[
          const Text(
            '其他資料，可以稍後再完成',
            style: TextStyle(
              color: Color(0xFF74250F),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '先完成必要資料即可繼續，其他資訊可以在旅社設定中慢慢補齊。',
            style: TextStyle(
              color: Color(0xFF796A5D),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '申請店家認證及公開前台前，仍需依平台規定補齊必要資料。',
            style: TextStyle(
              color: Color(0xFF796A5D),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          title: Text(
            laterTitle,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          subtitle: const Text('稍後設定'),
          children: <Widget>[card],
        ),
      ],
    );
  }

  Widget _twoCol({
    required bool split,
    required Widget left,
    required Widget right,
  }) {
    if (!split) {
      return Column(
        children: <Widget>[left, const SizedBox(height: 12), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return dashboardGuard(
      Scaffold(
        backgroundColor: const Color(0xFFF7F4F0),
        appBar: AppBar(
          title: const Text('店家基本資料'),
          actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double width = constraints.maxWidth;
                    final bool tablet = width >= 720;
                    final bool desktop = width >= 980;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: <Widget>[
                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: desktop ? 920 : 720,
                            ),
                            child: Column(
                              children: <Widget>[
                                if (_contactIncomplete) ..._guidedLead(tablet),
                                if (!_contactIncomplete) ...<Widget>[
                                  _introCard(),
                                  const SizedBox(height: 10),
                                  _verifyStatusRow(),
                                  const SizedBox(height: 12),
                                  _sectionCard(
                                    title: '基本資料',
                                    children: <Widget>[
                                      _twoCol(
                                        split: tablet,
                                        left: _lockedField(
                                          label: '店名',
                                          controller: _nameController,
                                          locked: true,
                                        ),
                                        right: DropdownButtonFormField<String>(
                                          initialValue: _businessType,
                                          decoration: _fieldDecoration(
                                            label: '店家類型',
                                            locked: true,
                                            firstSetup: false,
                                          ),
                                          items:
                                              const <DropdownMenuItem<String>>[
                                                DropdownMenuItem(
                                                  value: 'cat_hotel',
                                                  child: Text('貓咪旅店'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'dog_hotel',
                                                  child: Text('狗狗旅店'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'grooming',
                                                  child: Text('美容功能'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'hospital',
                                                  child: Text('動物醫院'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'shop',
                                                  child: Text('賣場功能'),
                                                ),
                                              ],
                                          onChanged: null,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _lockedField(
                                        label: '電話',
                                        controller: _phoneController,
                                        locked: _phoneSetupCompleted,
                                        firstSetup: !_phoneSetupCompleted,
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ],
                                    footer: _applyEditButton(),
                                  ),
                                  const SizedBox(height: 12),
                                  _sectionCard(
                                    title: '店址資料',
                                    children: <Widget>[
                                      _locationCard(),
                                      const SizedBox(height: 12),
                                      _lockedField(
                                        label: '地址',
                                        controller: _addressController,
                                        locked: _addressSetupCompleted,
                                        firstSetup: !_addressSetupCompleted,
                                      ),
                                    ],
                                    footer: _applyEditButton(),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                _sectionCard(
                                  title: '商業與公開資訊',
                                  laterTitle: '商業與認證資料',
                                  laterHeading: true,
                                  children: <Widget>[
                                    _twoCol(
                                      split: tablet,
                                      left: LegalPetLicenseInput(
                                        controller: _licenseController,
                                        locked: !_licenseInitialSetup,
                                        firstSetup: _licenseInitialSetup,
                                        onChanged: _clearLookupResult,
                                      ),
                                      right: _lockedField(
                                        label: '統編',
                                        controller: _taxIdController,
                                        locked: !_taxIdInitialSetup,
                                        firstSetup: _taxIdInitialSetup,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: OutlinedButton.icon(
                                        onPressed: _lookingUp
                                            ? null
                                            : _lookupLicense,
                                        icon: const Icon(
                                          Icons.fact_check_outlined,
                                        ),
                                        label: Text(
                                          _lookingUp ? '查核中' : '查核字號',
                                        ),
                                      ),
                                    ),
                                    if (_lookup != null) ...[
                                      const SizedBox(height: 8),
                                      LegalPetLicenseCheckCard(
                                        result: _lookup!,
                                        stale:
                                            _lookupInputs == null ||
                                            !_lookupInputs!.matches(
                                              LegalPetLookupInputs(
                                                license:
                                                    _licenseController.text,
                                                city: _cityController.text,
                                                district:
                                                    _districtController.text,
                                                address:
                                                    _addressController.text,
                                              ),
                                            ),
                                        addressLocked: _addressSetupCompleted,
                                        currentAddress:
                                            '${_cityController.text}${_districtController.text}${_addressController.text}',
                                        onApply: _applyGovernmentAddress,
                                        onKeep: () => setState(() {}),
                                        onRequestChange:
                                            _requestRegisteredAddress,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      '相關資料須經平台確認，公開資格依審核結果為準。',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: Colors.brown.shade600,
                                      ),
                                    ),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      value: _showTaxId,
                                      title: const Text('前台顯示統編'),
                                      onChanged: (bool v) =>
                                          setState(() => _showTaxId = v),
                                    ),
                                    Text(
                                      '統編是否公開仍以平台審核設定為準',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: Colors.brown.shade600,
                                      ),
                                    ),
                                  ],
                                  footer: _applyEditButton(),
                                ),
                                const SizedBox(height: 12),
                                _sectionCard(
                                  title: '聯絡與社群',
                                  laterTitle: '聯絡與社群',
                                  children: <Widget>[
                                    _lockedField(
                                      label: 'LINE',
                                      controller: _lineUrlController,
                                      locked: !_lineInitialSetup,
                                      firstSetup: _lineInitialSetup,
                                      validator: (String? value) =>
                                          _validateSocialUrl(
                                            value: value,
                                            type: 'line',
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    _lockedField(
                                      label: 'Instagram',
                                      controller: _igUrlController,
                                      locked: !_igInitialSetup,
                                      firstSetup: _igInitialSetup,
                                      validator: (String? value) =>
                                          _validateSocialUrl(
                                            value: value,
                                            type: 'ig',
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    _lockedField(
                                      label: 'Facebook',
                                      controller: _fbUrlController,
                                      locked: !_fbInitialSetup,
                                      firstSetup: _fbInitialSetup,
                                      validator: (String? value) =>
                                          _validateSocialUrl(
                                            value: value,
                                            type: 'fb',
                                          ),
                                    ),
                                  ],
                                  footer: _applyEditButton(),
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  key: const ValueKey(
                                    'shop-contact-setup-save',
                                  ),
                                  onPressed: _saving
                                      ? null
                                      : (_contactIncomplete
                                            ? _saveFirstStep
                                            : _save),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _contactIncomplete
                                        ? const Color(0xFFF45B14)
                                        : null,
                                    minimumSize: const Size.fromHeight(50),
                                    shape: _contactIncomplete
                                        ? const StadiumBorder()
                                        : null,
                                  ),
                                  child: Text(
                                    _saving
                                        ? '儲存中'
                                        : _contactIncomplete
                                        ? '儲存並完成第一步 →'
                                        : '儲存顯示設定',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _openVerifyRequest,
                                  icon: const Icon(
                                    Icons.verified_user_outlined,
                                  ),
                                  label: const Text('申請認證／平台公開'),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => ShopRequestCenterPage(
                                          shopId: widget.shopId,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.history),
                                  label: const Text('查看申請紀錄'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  List<Widget> _guidedLead(bool split) {
    return <Widget>[
      ShopContactSetupHeader(
        shopName: _nameController.text,
        showActivationProgress: _isNewShop,
      ),
      if (_profileChangePending) ...<Widget>[
        const SizedBox(height: 10),
        const Text(
          '已有資料修改申請正在審核，核准前不會覆蓋正式資料。',
          style: TextStyle(color: Color(0xFF796A5D), height: 1.4),
        ),
      ],
      const SizedBox(height: 12),
      _sectionCard(
        title: '第一步｜完成必要資料',
        children: <Widget>[
          const Text(
            '為了保障店家與顧客的權益，請先確認聯絡電話與營業地址。',
            style: TextStyle(color: Color(0xFF796A5D), height: 1.45),
          ),
          const SizedBox(height: 12),
          _lockedField(
            label: '1. 店家聯絡電話',
            controller: _phoneController,
            locked: _phoneSetupCompleted,
            firstSetup: !_phoneSetupCompleted,
            keyboardType: TextInputType.phone,
            validator: _phoneSetupCompleted ? null : validateShopContactPhone,
          ),
          const SizedBox(height: 12),
          _locationCard(),
          const SizedBox(height: 12),
          _lockedField(
            label: '2. 詳細地址',
            hintText: '請輸入路、街、巷、弄、門牌號碼',
            controller: _addressController,
            locked: _addressSetupCompleted,
            firstSetup: !_addressSetupCompleted,
            validator: _addressSetupCompleted
                ? null
                : (String? value) =>
                      (value ?? '').trim().isEmpty ? '請填寫詳細地址' : null,
          ),
        ],
      ),
      const SizedBox(height: 12),
      const ShopContactSafetyNote(),
      const SizedBox(height: 4),
    ];
  }

  bool get _locationComplete =>
      cityData.containsKey(_cityController.text.trim()) &&
      (cityData[_cityController.text.trim()] ?? <String>[]).contains(
        _districtController.text.trim(),
      );

  Widget _locationCard() => ShopLocationInfoCard(
    city: _cityController.text,
    district: _districtController.text,
    complete: _locationComplete,
    onRequestChange: () => _openChangeRequest(
      initialRequestType: 'address',
      initialCity: _cityController.text,
      initialDistrict: _districtController.text,
      initialAddress: _addressController.text,
    ),
  );

  Widget _introCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.brown.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '店家基本資料',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    '重要公開資料如需修改，請提出申請，由平台審核後更新。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Colors.brown.shade700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '完整說明',
                  onPressed: _openImportantNotes,
                  icon: Icon(Icons.help_outline, color: Colors.brown.shade700),
                ),
              ],
            ),
            if (_profileChangePending) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '已有資料修改申請正在審核，核准前不會覆蓋正式資料。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.brown.shade700,
                ),
              ),
            ],
            if (!_phoneSetupCompleted) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '電話仍可做首次設定，完成後需申請修改。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.brown.shade600,
                ),
              ),
            ],
            if (!_addressSetupCompleted) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '詳細地址仍可做首次設定；所在地沿用創店資料，儲存後須申請修改。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.brown.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _verifyStatusRow() {
    final bool certified = _licenseVerified && _taxIdVerified;
    String certifyText = '未認證';
    IconData icon = Icons.verified_user_outlined;
    Color iconColor = Colors.grey.shade600;
    Color background = const Color(0xFFF3F1EE);
    if (certified) {
      certifyText = '已認證';
      icon = Icons.verified;
      iconColor = const Color(0xFF2E7D4F);
      background = const Color(0xFFEAF6EC);
    } else if (_verifyRequestStatus == 'pending') {
      certifyText = '審核中';
      icon = Icons.hourglass_top_outlined;
      iconColor = const Color(0xFFC47B1A);
      background = const Color(0xFFFFF6E8);
    } else if (_verifyRequestStatus == 'rejected') {
      certifyText = '退件';
      icon = Icons.error_outline;
      iconColor = Colors.red.shade700;
      background = const Color(0xFFFDECEC);
    }
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  certifyText,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  _isPublic ? '平台公開：已公開' : '平台公開：未公開',
                  style: TextStyle(fontSize: 12, color: Colors.brown.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _applyEditButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _openChangeRequest,
        icon: const Icon(Icons.edit_note, size: 18),
        label: const Text('申請修改店家資料'),
      ),
    );
  }
}

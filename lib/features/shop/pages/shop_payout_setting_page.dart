// 檔案名稱：lib/features/shop/pages/shop_payout_setting_page.dart
// 功能說明：管理店家的銀行轉帳收款資料，並提供綠界金流資料填寫
// 🏦 收款帳戶 / 金流設定頁
// 付款方式選擇、送交平台審核與審核狀態顯示。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/services/payment_function_service.dart';
import '../../../core/widgets/shop_task_center_button.dart';

class ShopPayoutSettingPage extends StatefulWidget {
  const ShopPayoutSettingPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopPayoutSettingPage> createState() => _ShopPayoutSettingPageState();
}

class _ShopPayoutSettingPageState extends State<ShopPayoutSettingPage> {
  // 🏦 銀行轉帳設定欄位
  final TextEditingController _bankNameCtrl = TextEditingController();
  final TextEditingController _accountNameCtrl = TextEditingController();
  final TextEditingController _accountNumberCtrl = TextEditingController();

  // 💳 綠界金流設定欄位
  final TextEditingController _merchantNameCtrl = TextEditingController();
  final TextEditingController _merchantIdCtrl = TextEditingController();
  final TextEditingController _hashKeyCtrl = TextEditingController();
  final TextEditingController _hashIvCtrl = TextEditingController();

  // 🌐 綠界執行環境：test 測試、production 正式
  String _ecpayEnvironment = 'test';

  // 💰 店家申請啟用的綠界付款方式
  bool _creditCardEnabled = true;
  bool _atmEnabled = false;
  bool _cvsCodeEnabled = false;

  // 🏪 收款方式營運設定
  bool _bankTransferEnabled = true;

  bool _ecpayEnabled = false;

  bool _ecpayCreditCardEnabled = true;
  bool _ecpayAtmEnabled = false;
  bool _ecpayCvsCodeEnabled = false;

  // 📋 綠界審核狀態
  String _paymentReviewStatus = 'notSubmitted';
  String _paymentRejectionReason = '';

  // ⛔ 平台是否暫停此店家的綠界金流
  bool _platformSuspended = false;

  // ⏳ 畫面操作狀態
  bool _loading = true;
  bool _saving = false;
  bool _submittingEcpay = false;

  // 🔒 密鑰欄位顯示狀態
  bool _showHashKey = false;
  bool _showHashIv = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    // 🏦 銀行轉帳欄位
    _bankNameCtrl.dispose();
    _accountNameCtrl.dispose();
    _accountNumberCtrl.dispose();

    // 💳 綠界金流欄位
    _merchantNameCtrl.dispose();
    _merchantIdCtrl.dispose();
    _hashKeyCtrl.dispose();
    _hashIvCtrl.dispose();

    super.dispose();
  }

  /// 📥 讀取銀行帳戶與綠界公開設定
  ///
  /// HashKey 與 HashIV 屬於敏感資料，不會從 Firestore 前端讀回。
  Future<void> _loadData() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(widget.shopId)
              .get();

      final Map<String, dynamic> data = document.data() ?? <String, dynamic>{};

      // 🏦 銀行轉帳資料
      _bankNameCtrl.text = (data['bankName'] ?? '').toString();
      _accountNameCtrl.text = (data['accountName'] ?? '').toString();
      _accountNumberCtrl.text = (data['accountNumber'] ?? '').toString();

      // 💳 綠界金流公開設定
      final dynamic rawPaymentSetting = data['paymentSetting'];

      final Map<String, dynamic> paymentSetting = rawPaymentSetting is Map
          ? Map<String, dynamic>.from(rawPaymentSetting)
          : <String, dynamic>{};

      _merchantNameCtrl.text = (paymentSetting['merchantName'] ?? '')
          .toString();
      _merchantIdCtrl.text = (paymentSetting['merchantId'] ?? '').toString();

      _ecpayEnvironment = (paymentSetting['environment'] ?? 'test').toString();

      if (_ecpayEnvironment != 'test' && _ecpayEnvironment != 'production') {
        _ecpayEnvironment = 'test';
      }

      _paymentReviewStatus = (paymentSetting['reviewStatus'] ?? 'notSubmitted')
          .toString();

      _paymentRejectionReason = (paymentSetting['rejectionReason'] ?? '')
          .toString();

      _platformSuspended = paymentSetting['platformSuspended'] == true;

      final dynamic rawEnabledMethods = paymentSetting['enabledMethods'];

      final Map<String, dynamic> enabledMethods = rawEnabledMethods is Map
          ? Map<String, dynamic>.from(rawEnabledMethods)
          : <String, dynamic>{};

      _creditCardEnabled =
          enabledMethods['creditCard'] == true ||
          paymentSetting['creditCardEnabled'] == true;

      _atmEnabled =
          enabledMethods['atm'] == true || paymentSetting['atmEnabled'] == true;

      _cvsCodeEnabled =
          enabledMethods['cvsCode'] == true ||
          paymentSetting['cvsCodeEnabled'] == true;

      // 🏪 收款方式營運設定
      final dynamic rawOperationSettings = paymentSetting['operationSettings'];

      final Map<String, dynamic> operationSettings = rawOperationSettings is Map
          ? Map<String, dynamic>.from(rawOperationSettings)
          : <String, dynamic>{};

      _bankTransferEnabled = operationSettings['bankTransferEnabled'] ?? true;

      _ecpayEnabled = operationSettings['ecpayEnabled'] ?? false;

      _ecpayCreditCardEnabled = operationSettings['creditCardEnabled'] ?? true;

      _ecpayAtmEnabled = operationSettings['atmEnabled'] ?? false;

      _ecpayCvsCodeEnabled = operationSettings['cvsCodeEnabled'] ?? false;

      // 🔐 敏感資料不從前端讀取
      _hashKeyCtrl.clear();
      _hashIvCtrl.clear();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('讀取收款設定失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// 🏦 儲存銀行轉帳收款資料
  Future<void> _saveBankAccount() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .update(<String, dynamic>{
            'bankName': _bankNameCtrl.text.trim(),
            'accountName': _accountNameCtrl.text.trim(),
            'accountNumber': _accountNumberCtrl.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('銀行收款資料已儲存')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存銀行收款資料失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  /// 💾 儲存收款方式營運設定
  Future<void> _saveOperationSettings() async {
    try {
      await PaymentFunctionService.instance.updatePaymentOperationSettings(
        shopId: widget.shopId,
        bankTransferEnabled: _bankTransferEnabled,
        ecpayEnabled: _ecpayEnabled,
        creditCardEnabled: _ecpayCreditCardEnabled,
        atmEnabled: _ecpayAtmEnabled,
        cvsCodeEnabled: _ecpayCvsCodeEnabled,
      );

      if (!mounted) {
        return;
      }

      _showMessage('收款方式營運設定已儲存');
    } on PaymentFunctionException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('儲存收款方式失敗，請稍後再試。');
    }
  }

  /// 📝 驗證並送出綠界金流設定
  Future<void> _submitEcpaySetting() async {
    if (_submittingEcpay || !_canEditImportantEcpayFields) {
      return;
    }

    final String merchantName = _merchantNameCtrl.text.trim();
    final String merchantId = _merchantIdCtrl.text.trim();
    final String hashKey = _hashKeyCtrl.text.trim();
    final String hashIv = _hashIvCtrl.text.trim();

    if (merchantName.isEmpty) {
      _showMessage('請輸入綠界商店名稱。');
      return;
    }

    if (merchantId.isEmpty) {
      _showMessage('請輸入 MerchantID。');
      return;
    }

    if (hashKey.isEmpty) {
      _showMessage('請輸入 HashKey。');
      return;
    }

    if (hashIv.isEmpty) {
      _showMessage('請輸入 HashIV。');
      return;
    }

    if (!_creditCardEnabled && !_atmEnabled && !_cvsCodeEnabled) {
      _showMessage('請至少選擇一種付款方式。');
      return;
    }

    final bool confirmed = await _showSubmitConfirmation();

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _submittingEcpay = true;
    });

    try {
      await PaymentFunctionService.instance.submitEcpayPaymentSetting(
        shopId: widget.shopId,
        merchantName: merchantName,
        merchantId: merchantId,
        hashKey: hashKey,
        hashIv: hashIv,
        environment: _ecpayEnvironment,
        creditCardEnabled: _creditCardEnabled,
        atmEnabled: _atmEnabled,
        cvsCodeEnabled: _cvsCodeEnabled,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _paymentReviewStatus = 'pending';
        _paymentRejectionReason = '';
        _hashKeyCtrl.clear();
        _hashIvCtrl.clear();
        _showHashKey = false;
        _showHashIv = false;
      });

      _showMessage('綠界金流設定已送出平台審核。');
    } on PaymentFunctionException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('送出綠界金流設定失敗，請稍後再試。');
    } finally {
      if (mounted) {
        setState(() {
          _submittingEcpay = false;
        });
      }
    }
  }

  /// ✅ 送審前再次提醒店主確認敏感資料
  Future<bool> _showSubmitConfirmation() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('確認送出綠界金流審核'),
          content: const Text(
            '送出後，MerchantID、HashKey 與 HashIV 將交由平台審核。'
            '審核期間不可修改，請確認資料正確。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('確認送出'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  /// 💬 顯示操作結果
  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 🔒 審核中與已核准時，重要金流資料不可直接修改
  bool get _canEditImportantEcpayFields {
    return _paymentReviewStatus != 'pending' &&
        _paymentReviewStatus != 'approved';
  }

  /// ✅ 是否可啟用綠界營運
  bool get _canEnableEcpay {
    return _paymentReviewStatus == 'approved' && !_platformSuspended;
  }

  /// 📋 取得審核狀態顯示文字
  String get _reviewStatusText {
    switch (_paymentReviewStatus) {
      case 'pending':
        return '平台審核中';
      case 'approved':
        return '已核准';
      case 'rejected':
        return '審核未通過';
      case 'disabled':
        return '已被平台停用';
      default:
        return '尚未送審';
    }
  }

  /// 🎨 取得審核狀態顏色
  Color _reviewStatusColor(BuildContext context) {
    switch (_paymentReviewStatus) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'disabled':
        return Colors.grey;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  /// 🧾 建立審核狀態卡片
  Widget _buildReviewStatusCard() {
    final Color statusColor = _reviewStatusColor(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.fact_check_outlined, color: statusColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '目前審核狀態',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _reviewStatusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_paymentReviewStatus == 'pending') ...<Widget>[
                    const SizedBox(height: 8),
                    const Text(
                      '平台審核完成前，MerchantID、HashKey、HashIV、'
                      '環境與付款方式暫時不可修改。',
                    ),
                  ],
                  if (_paymentReviewStatus == 'approved') ...<Widget>[
                    const SizedBox(height: 8),
                    const Text('重要金流資料已鎖定。後續若需修改，必須重新提出變更申請。'),
                  ],
                  if (_paymentReviewStatus == 'rejected' &&
                      _paymentRejectionReason.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      '退件原因：${_paymentRejectionReason.trim()}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  if (_paymentReviewStatus == 'disabled') ...<Widget>[
                    const SizedBox(height: 8),
                    const Text('此店家的綠界金流已被平台停用，前台不會顯示綠界付款方式。'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 💳 收款方式設定
  Widget _buildPaymentMethodCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '收款方式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              value: true,
              title: const Text('到店付款'),
              subtitle: const Text('會員到店付款（固定啟用）'),
              onChanged: null,
            ),

            SwitchListTile(
              value: _bankTransferEnabled,
              title: const Text('銀行轉帳'),
              subtitle: const Text('會員依銀行帳戶付款'),
              onChanged: (bool value) async {
                setState(() {
                  _bankTransferEnabled = value;
                });

                await _saveOperationSettings();
              },
            ),
            if (_bankTransferEnabled) ...[
              const Divider(),

              const ListTile(
                leading: Icon(Icons.account_balance_outlined),
                title: Text(
                  '銀行收款帳戶',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('會員選擇銀行轉帳時使用此帳戶付款'),
              ),

              TextField(
                controller: _bankNameCtrl,
                decoration: const InputDecoration(
                  labelText: '銀行名稱',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _accountNameCtrl,
                decoration: const InputDecoration(
                  labelText: '戶名',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _accountNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '帳號',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveBankAccount,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? '儲存中...' : '儲存銀行帳戶'),
                ),
              ),

              const SizedBox(height: 16),
            ],

            const Divider(height: 32),

            Opacity(
              opacity: _platformSuspended ? 0.45 : 1,
              child: IgnorePointer(
                ignoring: _platformSuspended,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const ListTile(
                      leading: Icon(Icons.public),
                      title: Text(
                        '線上付款',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),

                    SwitchListTile(
                      contentPadding: const EdgeInsets.only(left: 16, right: 8),
                      value: _platformSuspended ? false : _ecpayEnabled,
                      title: const Text('啟用綠界付款'),
                      subtitle: Text(
                        _platformSuspended
                            ? '平台目前已停用此店家的綠界金流'
                            : _canEnableEcpay
                            ? '會員可使用綠界付款'
                            : '綠界尚未通過平台審核',
                      ),
                      onChanged: _canEnableEcpay
                          ? (bool value) async {
                              setState(() {
                                _ecpayEnabled = value;
                              });

                              await _saveOperationSettings();
                            }
                          : null,
                    ),

                    if (_ecpayEnabled || _platformSuspended) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: CheckboxListTile(
                          value: _platformSuspended
                              ? false
                              : _ecpayCreditCardEnabled,
                          title: const Text('信用卡'),
                          secondary: const Icon(Icons.credit_card_outlined),
                          onChanged: _canEnableEcpay
                              ? (value) {
                                  setState(() {
                                    _ecpayCreditCardEnabled = value ?? false;
                                  });
                                }
                              : null,
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: CheckboxListTile(
                          value: _platformSuspended ? false : _ecpayAtmEnabled,
                          title: const Text('ATM 虛擬帳號'),
                          secondary: const Icon(Icons.account_balance_outlined),
                          onChanged: _canEnableEcpay
                              ? (value) {
                                  setState(() {
                                    _ecpayAtmEnabled = value ?? false;
                                  });
                                }
                              : null,
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: CheckboxListTile(
                          value: _platformSuspended
                              ? false
                              : _ecpayCvsCodeEnabled,
                          title: const Text('超商代碼'),
                          secondary: const Icon(Icons.store_outlined),
                          onChanged: _canEnableEcpay
                              ? (value) {
                                  setState(() {
                                    _ecpayCvsCodeEnabled = value ?? false;
                                  });
                                }
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_platformSuspended) ...[
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.block, color: Colors.red.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '綠界金流已由平台停用',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '目前無法啟用或修改線上付款設定，如需恢復使用請聯絡平台管理員。',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!_canEnableEcpay) ...[
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '綠界尚未通過平台審核，目前無法啟用線上付款。',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 🏦 建立銀行轉帳設定分頁
  Widget _buildBankTransferTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[_buildPaymentMethodCard()],
    );
  }

  /// 💳 建立綠界金流設定分頁
  Widget _buildEcpayTab() {
    final bool editable = _canEditImportantEcpayFields;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.verified_user_outlined, color: Colors.green),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '店家可在這裡申請綠界金流。設定完成後需送交平台審核，'
                  '核准後才會在會員付款頁顯示。',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildReviewStatusCard(),

        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  '綠界商店資料',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _merchantNameCtrl,
                  enabled: editable,
                  decoration: const InputDecoration(
                    labelText: '綠界商店名稱',
                    hintText: '請輸入綠界後台顯示的商店名稱',
                    prefixIcon: Icon(Icons.storefront_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _merchantIdCtrl,
                  enabled: editable,
                  decoration: const InputDecoration(
                    labelText: 'MerchantID',
                    hintText: '請輸入綠界特店編號',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hashKeyCtrl,
                  enabled: editable,
                  obscureText: !_showHashKey,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'HashKey',
                    hintText: editable ? '請輸入綠界 HashKey' : '敏感資料已鎖定',
                    prefixIcon: const Icon(Icons.key_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _showHashKey ? '隱藏 HashKey' : '顯示 HashKey',
                      onPressed: editable
                          ? () {
                              setState(() {
                                _showHashKey = !_showHashKey;
                              });
                            }
                          : null,
                      icon: Icon(
                        _showHashKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hashIvCtrl,
                  enabled: editable,
                  obscureText: !_showHashIv,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'HashIV',
                    hintText: editable ? '請輸入綠界 HashIV' : '敏感資料已鎖定',
                    prefixIcon: const Icon(Icons.password_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _showHashIv ? '隱藏 HashIV' : '顯示 HashIV',
                      onPressed: editable
                          ? () {
                              setState(() {
                                _showHashIv = !_showHashIv;
                              });
                            }
                          : null,
                      icon: Icon(
                        _showHashIv
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'HashKey 與 HashIV 只會送往 Cloud Functions，'
                  '不會存放在 Flutter 或 shops 店家文件中。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '綠界執行環境',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                // 🌐 使用新版 RadioGroup 管理綠界環境選擇
                RadioGroup<String>(
                  groupValue: _ecpayEnvironment,
                  onChanged: (String? value) {
                    // 🔒 審核中或已核准時，不允許切換環境
                    if (!editable || value == null) {
                      return;
                    }

                    setState(() {
                      _ecpayEnvironment = value;
                    });
                  },
                  child: const Column(
                    children: <Widget>[
                      RadioListTile<String>(
                        value: 'test',
                        title: Text('測試環境'),
                        subtitle: Text('測試串接時使用，不會進行正式收款。'),
                      ),
                      RadioListTile<String>(
                        value: 'production',
                        title: Text('正式環境'),
                        subtitle: Text('正式營運收款時使用。'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (editable)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submittingEcpay ? null : _submitEcpaySetting,
              icon: _submittingEcpay
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _submittingEcpay
                    ? '送出中...'
                    : _paymentReviewStatus == 'rejected'
                    ? '修正後重新送審'
                    : '送出平台審核',
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 🏦 將收款設定分成銀行轉帳與綠界金流兩個分頁
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('收款帳戶 / 金流設定'),
          actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(icon: Icon(Icons.account_balance_outlined), text: '銀行轉帳'),
              Tab(icon: Icon(Icons.credit_card_outlined), text: '綠界金流'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[_buildBankTransferTab(), _buildEcpayTab()],
        ),
      ),
    );
  }
}

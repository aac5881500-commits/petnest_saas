// 檔案名稱：lib/features/shop/pages/shop_deposit_setting_page.dart
// 功能說明：設定訂金規則、付款期限與付款方式
// 💰 店家訂金與收款設定頁
// 備註：目前舊長住折扣暫時保留，之後確認新版優惠正常後再移除

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/shop_deposit_setting_panel.dart';

class ShopDepositSettingPage extends StatefulWidget {
  const ShopDepositSettingPage({
    super.key,
    required this.shopId,
    this.embedded = false,
  });

  final String shopId;

  /// true：嵌入 Tab 使用，不顯示自己的 Scaffold 與 AppBar
  /// false：維持原本獨立頁面顯示方式
  final bool embedded;

  @override
  State<ShopDepositSettingPage> createState() => _ShopDepositSettingPageState();
}

class _ShopDepositSettingPageState extends State<ShopDepositSettingPage> {
  bool _depositEnabled = false;

  String _depositType = 'fixed';
  int _depositValue = 1000;
  String _depositBase = 'room';

  bool _cash = true;
  bool _transfer = false;
  int _depositExpireHours = 12;

  bool _discountEnabled = false;
  String _discountBase = 'room_pet';

  final TextEditingController _depositValueCtrl = TextEditingController();

  final List<Map<String, TextEditingController>> _discountRuleCtrls = [];

  bool _loading = true;
  bool _saving = false;

  bool _savedEnabled = false;
  String _savedType = 'fixed';
  int _savedValue = 1000;
  String _savedBase = 'room';
  int _savedExpireHours = 12;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _depositValueCtrl.dispose();

    for (final Map<String, TextEditingController> item in _discountRuleCtrls) {
      item['minNights']?.dispose();
      item['discountPercent']?.dispose();
    }

    super.dispose();
  }

  Future<void> _loadData() async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('shops')
        .doc(widget.shopId)
        .get();

    final Map<String, dynamic>? data = doc.data();

    if (data != null) {
      _depositEnabled = data['depositEnabled'] ?? false;
      _depositType = data['depositType'] ?? 'fixed';
      _depositValue = data['depositValue'] ?? 1000;
      _depositValueCtrl.text = _depositValue.toString();
      _depositBase = data['depositBase'] ?? 'room';

      _cash = data['paymentMethods']?['cash'] ?? true;
      _transfer = data['paymentMethods']?['transfer'] ?? false;
      _depositExpireHours = data['depositExpireHours'] ?? 12;

      final Map<String, dynamic> discountSetting =
          data['discountSetting'] as Map<String, dynamic>? ??
          <String, dynamic>{};

      _discountEnabled = discountSetting['enabled'] ?? false;
      _discountBase = discountSetting['base'] ?? 'room_pet';

      final Object? rules = discountSetting['rules'];

      if (rules is List && rules.isNotEmpty) {
        for (final Object? item in rules) {
          if (item is! Map) {
            continue;
          }

          _discountRuleCtrls.add(<String, TextEditingController>{
            'minNights': TextEditingController(
              text: (item['minNights'] ?? '').toString(),
            ),
            'discountPercent': TextEditingController(
              text: (item['discountPercent'] ?? '').toString(),
            ),
          });
        }
      } else {
        _addDefaultDiscountRules();
      }
    } else {
      _addDefaultDiscountRules();
    }

    if (_discountRuleCtrls.isEmpty) {
      _addDefaultDiscountRules();
    }

    _captureSaved();
    setState(() => _loading = false);
  }

  void _captureSaved() {
    _savedEnabled = _depositEnabled;
    _savedType = _depositType;
    _savedValue = _depositValue;
    _savedBase = _depositBase;
    _savedExpireHours = _depositExpireHours;
  }

  bool get _dirty {
    return _depositEnabled != _savedEnabled ||
        _depositType != _savedType ||
        _depositValue != _savedValue ||
        _depositBase != _savedBase ||
        _depositExpireHours != _savedExpireHours;
  }

  void _addDefaultDiscountRules() {
    _discountRuleCtrls.addAll(<Map<String, TextEditingController>>[
      <String, TextEditingController>{
        'minNights': TextEditingController(text: '3'),
        'discountPercent': TextEditingController(text: '20'),
      },
      <String, TextEditingController>{
        'minNights': TextEditingController(text: '7'),
        'discountPercent': TextEditingController(text: '30'),
      },
    ]);
  }

  List<Map<String, int>> _buildDiscountRulesForSave() {
    final List<Map<String, int>> rules = <Map<String, int>>[];

    for (final Map<String, TextEditingController> item in _discountRuleCtrls) {
      final int minNights =
          int.tryParse(item['minNights']?.text.trim() ?? '') ?? 0;

      int discountPercent =
          int.tryParse(item['discountPercent']?.text.trim() ?? '') ?? 0;

      if (minNights <= 0) {
        continue;
      }

      if (discountPercent < 1) {
        discountPercent = 1;
      }
      if (discountPercent > 99) {
        discountPercent = 99;
      }

      rules.add(<String, int>{
        'minNights': minNights,
        'discountPercent': discountPercent,
      });
    }

    rules.sort(
      (Map<String, int> a, Map<String, int> b) =>
          a['minNights']!.compareTo(b['minNights']!),
    );

    return rules;
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (_depositType == 'percent') {
      if (_depositValue > 100) {
        _depositValue = 100;
      }
      if (_depositValue < 1) {
        _depositValue = 1;
      }
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .update(<String, dynamic>{
            'depositEnabled': _depositEnabled,
            'depositType': _depositType,
            'depositValue': _depositValue,
            'depositBase': _depositType == 'percent' ? _depositBase : 'total',
            'paymentMethods': <String, bool>{
              'cash': _cash,
              'transfer': _transfer,
            },
            'depositExpireHours': _depositExpireHours,
            'discountSetting': <String, dynamic>{
              'enabled': _discountEnabled,
              'base': _discountBase,
              'rules': _buildDiscountRulesForSave(),
            },
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) {
        return;
      }
      _captureSaved();
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('收款設定已儲存')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$error')));
    }
  }

  void _updateDepositValue(String v) {
    int value = int.tryParse(v) ?? 0;

    if (_depositType == 'percent') {
      if (value > 100) {
        value = 100;
      }
      if (value < 1) {
        value = 1;
      }
    }

    _depositValue = value;

    final String fixedText = value.toString();
    if (_depositValueCtrl.text != fixedText) {
      _depositValueCtrl.text = fixedText;
      _depositValueCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _depositValueCtrl.text.length),
      );
    }
    setState(() {});
  }

  void _changeDepositType(String value) {
    setState(() {
      _depositType = value;

      if (_depositType == 'percent') {
        if (_depositValue > 100) {
          _depositValue = 100;
          _depositValueCtrl.text = '100';
        }

        if (_depositValue < 1) {
          _depositValue = 1;
          _depositValueCtrl.text = '1';
        }

        _depositValueCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _depositValueCtrl.text.length),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      const Widget loadingView = Center(child: CircularProgressIndicator());

      if (widget.embedded) {
        return loadingView;
      }

      return const Scaffold(body: loadingView);
    }

    final Widget content = ShopDepositSettingPanel(
      depositEnabled: _depositEnabled,
      depositType: _depositType,
      depositValue: _depositValue,
      depositBase: _depositBase,
      depositExpireHours: _depositExpireHours,
      depositValueController: _depositValueCtrl,
      dirty: _dirty,
      saving: _saving,
      onToggleEnabled: (bool value) => setState(() => _depositEnabled = value),
      onExpireHours: (int value) => setState(() => _depositExpireHours = value),
      onDepositBase: (String value) => setState(() => _depositBase = value),
      onDepositType: _changeDepositType,
      onDepositValueChanged: _updateDepositValue,
      onSave: _save,
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('訂金與收款設定')),
      body: content,
    );
  }
}

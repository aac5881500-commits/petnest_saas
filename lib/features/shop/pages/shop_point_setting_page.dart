// 檔案名稱：lib/features/shop/pages/shop_point_setting_page.dart
// 功能說明：點數制度、安親發點與折抵設定；發點固定訂單完成後才入點。

import 'package:flutter/material.dart';
import '../../../core/models/daycare_settings_model.dart';
import '../../../core/models/point_setting_model.dart';
import '../../../core/services/daycare_settings_service.dart';
import '../../../core/services/point_setting_service.dart';
import '../../../core/services/shop_service.dart';

class ShopPointSettingPage extends StatefulWidget {
  const ShopPointSettingPage({
    super.key,
    required this.shopId,
    this.embedded = false,
  });

  final String shopId;
  final bool embedded;

  @override
  State<ShopPointSettingPage> createState() => _ShopPointSettingPageState();
}

class _ShopPointSettingPageState extends State<ShopPointSettingPage> {
  final PointSettingService _service = PointSettingService.instance;
  final TextEditingController _amountPerPointController =
      TextEditingController();
  final TextEditingController _pointsPerNightController =
      TextEditingController();
  final TextEditingController _minimumOrderAmountController =
      TextEditingController();
  final TextEditingController _maximumPointsController =
      TextEditingController();
  final TextEditingController _expireDaysController = TextEditingController();
  final TextEditingController _pointNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _daycareAmountPerPointController =
      TextEditingController();
  final TextEditingController _daycareMinimumController =
      TextEditingController();
  final TextEditingController _daycareMaximumController =
      TextEditingController();
  final TextEditingController _pointsPerNtdController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  bool _enabled = false;
  bool _allowPointsExchange = true;
  String _calculationType = PointSettingModel.calculationTypeAmount;
  bool _daycareEarnEnabled = false;
  bool _spendEnabled = false;
  bool _staySpendEnabled = false;
  bool _daycareSpendEnabled = false;
  bool _storeSpendEnabled = false;
  bool _basicOpen = true;
  bool _daycareOpen = true;
  bool _spendOpen = true;

  bool get _isAmountCalculation =>
      _calculationType == PointSettingModel.calculationTypeAmount;

  @override
  void dispose() {
    _amountPerPointController.dispose();
    _pointsPerNightController.dispose();
    _minimumOrderAmountController.dispose();
    _maximumPointsController.dispose();
    _expireDaysController.dispose();
    _pointNameController.dispose();
    _descriptionController.dispose();
    _daycareAmountPerPointController.dispose();
    _daycareMinimumController.dispose();
    _daycareMaximumController.dispose();
    _pointsPerNtdController.dispose();
    super.dispose();
  }

  void _applySetting(PointSettingModel setting) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _enabled = setting.enabled;
    _calculationType = setting.calculationType;
    _allowPointsExchange = setting.allowPointsExchange;
    _amountPerPointController.text = setting.amountPerPoint.toString();
    _pointsPerNightController.text = setting.pointsPerNight.toString();
    _minimumOrderAmountController.text = setting.minimumOrderAmount.toString();
    _maximumPointsController.text = setting.maximumPointsPerBooking.toString();
    _expireDaysController.text = setting.pointExpireDays.toString();
    _pointNameController.text = setting.pointName;
    _descriptionController.text = setting.description;
    _daycareEarnEnabled = setting.daycareEarnEnabled;
    _daycareSpendEnabled = setting.daycareSpendEnabled;
    _staySpendEnabled = setting.staySpendEnabled;
    _storeSpendEnabled = setting.storeSpendEnabled;
    _spendEnabled = setting.spendEnabled;
    _pointsPerNtdController.text =
        (setting.pointsPerNtd > 0 ? setting.pointsPerNtd : 1).toString();
    _daycareAmountPerPointController.text = setting.daycareAmountPerPoint
        .toString();
    _daycareMinimumController.text = setting.daycareMinimumOrderAmount
        .toString();
    _daycareMaximumController.text = setting.daycareMaximumPointsPerBooking
        .toString();
  }

  Future<void> _save() async {
    final int? amountPerPoint = int.tryParse(
      _amountPerPointController.text.trim(),
    );
    final int? pointsPerNight = int.tryParse(
      _pointsPerNightController.text.trim(),
    );
    final int? minimumOrderAmount = int.tryParse(
      _minimumOrderAmountController.text.trim(),
    );
    final int? maximumPoints = int.tryParse(
      _maximumPointsController.text.trim(),
    );
    final int? expireDays = int.tryParse(_expireDaysController.text.trim());
    final int? pointsPerNtd = int.tryParse(_pointsPerNtdController.text.trim());
    if (_isAmountCalculation &&
        (amountPerPoint == null || amountPerPoint <= 0)) {
      _showMessage('每點消費金額必須大於 0');
      return;
    }
    if (!_isAmountCalculation &&
        (pointsPerNight == null || pointsPerNight <= 0)) {
      _showMessage('每晚發放點數必須大於 0');
      return;
    }
    if (minimumOrderAmount == null || minimumOrderAmount < 0) {
      _showMessage('最低消費金額不能小於 0');
      return;
    }
    if (maximumPoints == null || maximumPoints < 0) {
      _showMessage('單筆最多點數不能小於 0');
      return;
    }
    if (expireDays == null || expireDays < 0) {
      _showMessage('點數有效天數不能小於 0');
      return;
    }
    if (pointsPerNtd == null || pointsPerNtd <= 0) {
      _showMessage('折抵比例必須大於 0');
      return;
    }
    if (_pointNameController.text.trim().isEmpty) {
      _showMessage('請輸入點數名稱');
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.savePointSetting(
        shopId: widget.shopId,
        enabled: _enabled,
        calculationType: _calculationType,
        amountPerPoint: amountPerPoint ?? 100,
        pointsPerNight: pointsPerNight ?? 1,
        minimumOrderAmount: minimumOrderAmount,
        maximumPointsPerBooking: maximumPoints,
        pointExpireDays: expireDays,
        issueAfterCompleted: true,
        allowManualAdjustment: true,
        allowPointsExchange: _allowPointsExchange,
        pointName: _pointNameController.text.trim(),
        description: _descriptionController.text.trim(),
        daycareEarnEnabled: _daycareEarnEnabled,
        daycareSpendEnabled: _daycareSpendEnabled,
        staySpendEnabled: _staySpendEnabled,
        storeSpendEnabled: _storeSpendEnabled,
        spendEnabled: _spendEnabled,
        pointsPerNtd: pointsPerNtd,
        daycareCalculationType: PointSettingModel.daycareCalculationTypeAmount,
        daycareAmountPerPoint:
            int.tryParse(_daycareAmountPerPointController.text.trim()) ?? 100,
        daycarePointsPerOrder: 0,
        daycareMinimumOrderAmount:
            int.tryParse(_daycareMinimumController.text.trim()) ?? 0,
        daycareMaximumPointsPerBooking:
            int.tryParse(_daycareMaximumController.text.trim()) ?? 0,
      );
      if (mounted) {
        _showMessage('點數設定已儲存');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('儲存失敗：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _card({
    required String title,
    required bool open,
    required ValueChanged<bool> onOpen,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: open,
        onExpansionChanged: onOpen,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = StreamBuilder<PointSettingModel>(
      stream: _service.streamPointSetting(widget.shopId),
      builder:
          (BuildContext context, AsyncSnapshot<PointSettingModel> snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('讀取點數設定失敗：${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            _applySetting(snapshot.data!);
            final double width = MediaQuery.sizeOf(context).width;
            final bool desktop = width >= 1024;
            final Widget basic = _card(
              title: '基本制度',
              open: _basicOpen,
              onOpen: (bool v) => setState(() => _basicOpen = v),
              children: <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('啟用點數制度'),
                  value: _enabled,
                  onChanged: (bool value) => setState(() => _enabled = value),
                ),
                TextField(
                  controller: _pointNameController,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: '點數名稱',
                    isDense: true,
                  ),
                ),
                TextField(
                  controller: _expireDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '點數有效天數（0 為永久）',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('住宿發點方式'),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('依消費金額'),
                  value: PointSettingModel.calculationTypeAmount,
                  groupValue: _calculationType,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _calculationType = value);
                    }
                  },
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('依住宿晚數'),
                  value: PointSettingModel.calculationTypeNight,
                  groupValue: _calculationType,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _calculationType = value);
                    }
                  },
                ),
                if (_isAmountCalculation)
                  TextField(
                    controller: _amountPerPointController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '每消費 NT\$ N 得 1 點',
                      isDense: true,
                    ),
                  )
                else
                  TextField(
                    controller: _pointsPerNightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '每晚 N 點',
                      isDense: true,
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _minimumOrderAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '住宿最低消費門檻',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _maximumPointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '住宿單筆發點上限（0 不限）',
                    isDense: true,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('允許會員兌換商品'),
                  subtitle: const Text('與商城結帳折抵分開，這是點數商城兌換商品。'),
                  value: _allowPointsExchange,
                  onChanged: (bool value) =>
                      setState(() => _allowPointsExchange = value),
                ),
                const Text(
                  '發點固定在訂單完成且無待補／待退後入帳，店主無需再選擇。',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            );
            final Widget daycare = StreamBuilder<Map<String, dynamic>?>(
              stream: ShopService.instance.streamShop(widget.shopId),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<Map<String, dynamic>?> shopSnap,
                  ) {
                    return StreamBuilder<DaycareSettingsModel>(
                      stream: DaycareSettingsService.instance.stream(
                        widget.shopId,
                      ),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<DaycareSettingsModel> daycareSnap,
                          ) {
                            final bool show =
                                _enabled &&
                                DaycareSettingsService.instance
                                    .isEnabledForShop(
                                      shop: shopSnap.data,
                                      settings:
                                          daycareSnap.data ??
                                          const DaycareSettingsModel(),
                                    );
                            if (!show) {
                              return const SizedBox.shrink();
                            }
                            return _card(
                              title: '安親發點',
                              open: _daycareOpen,
                              onOpen: (bool v) =>
                                  setState(() => _daycareOpen = v),
                              children: <Widget>[
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('安親完成後發放點數'),
                                  value: _daycareEarnEnabled,
                                  onChanged: (bool value) => setState(
                                    () => _daycareEarnEnabled = value,
                                  ),
                                ),
                                TextField(
                                  controller: _daycareAmountPerPointController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '每消費 NT\$ N 得 1 點',
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _daycareMinimumController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '安親最低消費門檻',
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _daycareMaximumController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '安親單筆發點上限（0 不限）',
                                    isDense: true,
                                  ),
                                ),
                              ],
                            );
                          },
                    );
                  },
            );
            final Widget spend = _card(
              title: '點數折抵',
              open: _spendOpen,
              onOpen: (bool v) => setState(() => _spendOpen = v),
              children: <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('啟用點數折抵'),
                  value: _spendEnabled,
                  onChanged: (bool value) =>
                      setState(() => _spendEnabled = value),
                ),
                TextField(
                  controller: _pointsPerNtdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'N 點折抵 NT\$1',
                    helperText: '例如 10 代表 10 點折抵 1 元',
                    isDense: true,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('住宿可使用點數折抵'),
                  value: _staySpendEnabled,
                  onChanged: !_spendEnabled
                      ? null
                      : (bool value) =>
                            setState(() => _staySpendEnabled = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('安親可使用點數折抵'),
                  value: _daycareSpendEnabled,
                  onChanged: !_spendEnabled
                      ? null
                      : (bool value) =>
                            setState(() => _daycareSpendEnabled = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('商城可使用點數折抵'),
                  subtitle: const Text('僅限結帳折抵，與兌換商品權限分開。'),
                  value: _storeSpendEnabled,
                  onChanged: !_spendEnabled
                      ? null
                      : (bool value) =>
                            setState(() => _storeSpendEnabled = value),
                ),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '點數制度說明',
                    isDense: true,
                  ),
                ),
              ],
            );
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (desktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: basic),
                      const SizedBox(width: 12),
                      Expanded(child: daycare),
                    ],
                  )
                else ...<Widget>[basic, daycare],
                spend,
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? '儲存中...' : '儲存點數設定'),
                ),
              ],
            );
          },
    );
    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('點數設定')),
      body: content,
    );
  }
}

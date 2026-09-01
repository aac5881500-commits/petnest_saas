// lib/features/shop/pages/shop_point_setting_page.dart
// 🪙 店家點數設定頁
// 功能：設定點數開關、發點計算方式、有效期限與兌換權限

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
  final TextEditingController _daycarePointsPerOrderController =
      TextEditingController();
  final TextEditingController _daycareMinimumController =
      TextEditingController();
  final TextEditingController _daycareMaximumController =
      TextEditingController();

  bool _initialized = false;
  bool _saving = false;

  bool _enabled = false;
  bool _issueAfterCompleted = true;
  bool _allowManualAdjustment = true;
  bool _allowPointsExchange = true;

  String _calculationType = PointSettingModel.calculationTypeAmount;
  bool _daycareEarnEnabled = false;
  bool _daycareSpendEnabled = false;
  String _daycareCalculationType =
      PointSettingModel.daycareCalculationTypeAmount;
  bool _daycareIncludeAddons = true;
  bool _daycareIncludeSurcharge = true;
  bool _daycareIncludeOvertime = true;

  bool get _isAmountCalculation =>
      _calculationType == PointSettingModel.calculationTypeAmount;

  bool get _isNightCalculation =>
      _calculationType == PointSettingModel.calculationTypeNight;

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
    _daycarePointsPerOrderController.dispose();
    _daycareMinimumController.dispose();
    _daycareMaximumController.dispose();
    super.dispose();
  }

  void _applySetting(PointSettingModel setting) {
    if (_initialized) {
      return;
    }

    _initialized = true;

    _enabled = setting.enabled;
    _calculationType = setting.calculationType;
    _issueAfterCompleted = setting.issueAfterCompleted;
    _allowManualAdjustment = setting.allowManualAdjustment;
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
    _daycareCalculationType = setting.daycareCalculationType;
    _daycareAmountPerPointController.text = setting.daycareAmountPerPoint
        .toString();
    _daycarePointsPerOrderController.text = setting.daycarePointsPerOrder
        .toString();
    _daycareMinimumController.text = setting.daycareMinimumOrderAmount
        .toString();
    _daycareMaximumController.text = setting.daycareMaximumPointsPerBooking
        .toString();
    _daycareIncludeAddons = setting.daycareIncludeAddons;
    _daycareIncludeSurcharge = setting.daycareIncludeSurcharge;
    _daycareIncludeOvertime = setting.daycareIncludeOvertime;
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

    if (_isAmountCalculation &&
        (amountPerPoint == null || amountPerPoint <= 0)) {
      _showMessage('每點消費金額必須大於 0');
      return;
    }

    if (_isNightCalculation &&
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

    if (_pointNameController.text.trim().isEmpty) {
      _showMessage('請輸入點數名稱');
      return;
    }

    setState(() {
      _saving = true;
    });

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
        issueAfterCompleted: _issueAfterCompleted,
        allowManualAdjustment: _allowManualAdjustment,
        allowPointsExchange: _allowPointsExchange,
        pointName: _pointNameController.text.trim(),
        description: _descriptionController.text.trim(),
        daycareEarnEnabled: _daycareEarnEnabled,
        daycareSpendEnabled: _daycareSpendEnabled,
        daycareCalculationType: _daycareCalculationType,
        daycareAmountPerPoint:
            int.tryParse(_daycareAmountPerPointController.text.trim()) ?? 100,
        daycarePointsPerOrder:
            int.tryParse(_daycarePointsPerOrderController.text.trim()) ?? 0,
        daycareMinimumOrderAmount:
            int.tryParse(_daycareMinimumController.text.trim()) ?? 0,
        daycareMaximumPointsPerBooking:
            int.tryParse(_daycareMaximumController.text.trim()) ?? 0,
        daycareIncludeAddons: _daycareIncludeAddons,
        daycareIncludeSurcharge: _daycareIncludeSurcharge,
        daycareIncludeOvertime: _daycareIncludeOvertime,
      );

      if (!mounted) {
        return;
      }

      _showMessage('點數設定已儲存');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('儲存失敗：$error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildDaycarePointsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(),
        const Text(
          '臨托點數設定',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          '僅 APP 會員可獲得點數。點數有效期限沿用上方全店設定。',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('臨托完成後發放點數'),
          value: _daycareEarnEnabled,
          onChanged: (bool value) =>
              setState(() => _daycareEarnEnabled = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('臨托允許點數折抵'),
          value: _daycareSpendEnabled,
          onChanged: (bool value) =>
              setState(() => _daycareSpendEnabled = value),
        ),
        const Text('點數計算方式'),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          title: const Text('依消費金額'),
          value: PointSettingModel.daycareCalculationTypeAmount,
          groupValue: _daycareCalculationType,
          onChanged: (String? value) {
            if (value == null) {
              return;
            }
            setState(() => _daycareCalculationType = value);
          },
        ),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          title: const Text('每張完成訂單固定點數'),
          value: PointSettingModel.daycareCalculationTypeFixed,
          groupValue: _daycareCalculationType,
          onChanged: (String? value) {
            if (value == null) {
              return;
            }
            setState(() => _daycareCalculationType = value);
          },
        ),
        if (_daycareCalculationType ==
            PointSettingModel.daycareCalculationTypeAmount)
          TextField(
            controller: _daycareAmountPerPointController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '每消費多少元獲得 1 點',
              border: OutlineInputBorder(),
            ),
          )
        else
          TextField(
            controller: _daycarePointsPerOrderController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '每張完成臨托訂單獲得點數',
              border: OutlineInputBorder(),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _daycareMinimumController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '最低消費金額（0 為不限制）',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _daycareMaximumController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '每張臨托訂單最多發放點數（0 為不限制）',
            border: OutlineInputBorder(),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('計算時包含加值服務'),
          value: _daycareIncludeAddons,
          onChanged: (bool value) =>
              setState(() => _daycareIncludeAddons = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('計算時包含特殊日期加價'),
          value: _daycareIncludeSurcharge,
          onChanged: (bool value) =>
              setState(() => _daycareIncludeSurcharge = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('計算時包含超時費'),
          value: _daycareIncludeOvertime,
          onChanged: (bool value) =>
              setState(() => _daycareIncludeOvertime = value),
        ),
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('啟用點數制度'),
                  subtitle: const Text('開啟後，完成訂單可依設定發放點數'),
                  value: _enabled,
                  onChanged: (bool value) {
                    setState(() {
                      _enabled = value;
                    });
                  },
                ),
                const Divider(),
                TextField(
                  controller: _pointNameController,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: '點數名稱',
                    hintText: '例如：點、毛幣',
                  ),
                ),
                const SizedBox(height: 8),
                Text('點數計算方式', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('依消費金額計算'),
                  subtitle: const Text('例如：每消費 100 元獲得 1 點'),
                  value: PointSettingModel.calculationTypeAmount,
                  groupValue: _calculationType,
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _calculationType = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('依住宿晚數計算'),
                  subtitle: const Text('例如：每住宿 1 晚獲得 5 點'),
                  value: PointSettingModel.calculationTypeNight,
                  groupValue: _calculationType,
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _calculationType = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                if (_isAmountCalculation)
                  TextField(
                    controller: _amountPerPointController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '消費多少元獲得 1 點',
                      helperText: '例如填入 100，代表每消費 100 元獲得 1 點',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (_isNightCalculation)
                  TextField(
                    controller: _pointsPerNightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '每住宿 1 晚獲得多少點',
                      helperText: '例如填入 5，住宿 3 晚會獲得 15 點',
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _minimumOrderAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '最低消費金額',
                    helperText: '訂單未達此金額不發點，填 0 代表不限制',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _maximumPointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '單筆訂單最多發放點數',
                    helperText: '填 0 代表不限制',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _expireDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '點數有效天數',
                    helperText: '填 0 代表永久有效',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('訂單完成後才發放點數'),
                  value: _issueAfterCompleted,
                  onChanged: (bool value) {
                    setState(() {
                      _issueAfterCompleted = value;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('允許後台手動調整點數'),
                  value: _allowManualAdjustment,
                  onChanged: (bool value) {
                    setState(() {
                      _allowManualAdjustment = value;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('允許會員使用點數兌換'),
                  subtitle: Text(
                    _allowPointsExchange
                        ? '會員可以在點數商城兌換商品'
                        : '兌換商品仍可先建立，但會員暫時看不到',
                  ),
                  value: _allowPointsExchange,
                  onChanged: (bool value) {
                    setState(() {
                      _allowPointsExchange = value;
                    });
                  },
                ),

                if (!_allowPointsExchange) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '目前尚未開放會員點數兌換。你仍可先建立商品，'
                            '等設定完成後再開啟兌換功能。',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                StreamBuilder<Map<String, dynamic>?>(
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
                                final bool showDaycare =
                                    _enabled &&
                                    DaycareSettingsService.instance
                                        .isEnabledForShop(
                                          shop: shopSnap.data,
                                          settings:
                                              daycareSnap.data ??
                                              const DaycareSettingsModel(),
                                        );
                                if (!showDaycare) {
                                  return const SizedBox.shrink();
                                }
                                return _buildDaycarePointsSection();
                              },
                        );
                      },
                ),

                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '點數制度說明',
                    hintText: '例如：完成住宿後發放，點數可兌換優惠券',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
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

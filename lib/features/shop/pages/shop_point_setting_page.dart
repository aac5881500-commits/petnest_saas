// lib/features/shop/pages/shop_point_setting_page.dart
// 🪙 店家點數設定頁
// 功能：設定點數開關、發點計算方式、有效期限與兌換權限

import 'package:flutter/material.dart';
import '../../../core/models/point_setting_model.dart';
import '../../../core/services/point_setting_service.dart';

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

  bool _initialized = false;
  bool _saving = false;

  bool _enabled = false;
  bool _issueAfterCompleted = true;
  bool _allowManualAdjustment = true;
  bool _allowPointsExchange = true;

  String _calculationType = PointSettingModel.calculationTypeAmount;

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

// 檔案名稱：lib/features/shop/pages/shop_business_info_page.dart
// 功能說明：店家營業資訊設定頁（含時間選擇 + 服務類型）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopBusinessInfoPage extends StatefulWidget {
  const ShopBusinessInfoPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopBusinessInfoPage> createState() => _ShopBusinessInfoPageState();
}

class _ShopBusinessInfoPageState extends State<ShopBusinessInfoPage> {
  bool _isOpen = true;
  bool _isPublic = false;
  bool _licenseVerified = false;
  bool _taxIdVerified = false;

  List<String> _serviceTypes = [];

  final _businessHoursController = TextEditingController();

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _businessHoursController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final shop = await ShopService.instance.getShop(widget.shopId);

    if (shop != null) {
      _isOpen = shop['isOpen'] ?? true;
      _isPublic = shop['isPublic'] ?? false;
      _licenseVerified = shop['licenseVerified'] == true;
      _taxIdVerified = shop['taxIdVerified'] == true;

      if (!_licenseVerified || !_taxIdVerified) {
        _isPublic = false;
      }
      _businessHoursController.text = shop['businessHours'] ?? '';
      final openTime = shop['openTime']?.toString() ?? '';
      final closeTime = shop['closeTime']?.toString() ?? '';

      _startTime = _parseTimeOfDay(openTime);
      _endTime = _parseTimeOfDay(closeTime);

      _serviceTypes = List<String>.from(shop['serviceTypes'] ?? []);
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  // 🔥 選開始時間
  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 10, minute: 0),
    );

    if (picked != null) {
      setState(() {
        _startTime = picked;
        _updateBusinessHoursText();
      });
    }
  }

  // 🔥 選結束時間
  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 20, minute: 0),
    );

    if (picked != null) {
      setState(() {
        _endTime = picked;
        _updateBusinessHoursText();
      });
    }
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    if (value.isEmpty || !value.contains(':')) return null;

    final parts = value.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23) return null;
    if (minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  // 🔥 更新文字
  void _updateBusinessHoursText() {
    if (_startTime != null && _endTime != null) {
      final start =
          '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
      final end =
          '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}';

      _businessHoursController.text = '$start - $end';
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    await ShopService.instance.updateBusinessInfo(
      shopId: widget.shopId,
      isOpen: _isOpen,
      businessHours: _businessHoursController.text,
      openTime: _startTime == null
          ? ''
          : '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
      closeTime: _endTime == null
          ? ''
          : '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
      isPublic: _isPublic,
      serviceTypes: _serviceTypes,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已儲存')));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('營業資訊')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            /// 營業開關
            SwitchListTile(
              title: const Text('目前營業中'),
              value: _isOpen,
              onChanged: (v) => setState(() => _isOpen = v),
            ),

            const SizedBox(height: 16),

            /// 🔥 時間選擇器
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickStartTime,
                    child: Text(
                      _startTime == null
                          ? '開始時間'
                          : '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickEndTime,
                    child: Text(
                      _endTime == null
                          ? '結束時間'
                          : '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// 顯示時間文字
            TextField(
              controller: _businessHoursController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: '營業時間',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            /// 公開開關
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (!_licenseVerified || !_taxIdVerified)
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (!_licenseVerified || !_taxIdVerified)
                      ? Colors.red.shade200
                      : Colors.green.shade200,
                ),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('是否公開顯示'),
                subtitle: Text(
                  (!_licenseVerified || !_taxIdVerified)
                      ? '特寵字號與統編需平台認證通過後，才能公開在平台找店。'
                      : '認證已通過，可公開顯示在平台找店。',
                ),
                value: _isPublic,
                onChanged: (!_licenseVerified || !_taxIdVerified)
                    ? null
                    : (v) => setState(() => _isPublic = v),
              ),
            ),

            const SizedBox(height: 24),

            /// 儲存
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '儲存中...' : '儲存'),
            ),
          ],
        ),
      ),
    );
  }
}

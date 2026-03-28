// 檔案名稱：lib/features/auth/pages/shop_business_info_page.dart
// 說明：店家營業資訊設定頁（含時間選擇 + 服務類型）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopBusinessInfoPage extends StatefulWidget {
  const ShopBusinessInfoPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<ShopBusinessInfoPage> createState() =>
      _ShopBusinessInfoPageState();
}

class _ShopBusinessInfoPageState
    extends State<ShopBusinessInfoPage> {
  bool _isOpen = true;
  bool _isPublic = false;

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

  Future<void> _load() async {
    final shop =
        await ShopService.instance.getShop(widget.shopId);

    if (shop != null) {
      _isOpen = shop['isOpen'] ?? true;
      _isPublic = shop['isPublic'] ?? false;
      _businessHoursController.text =
          shop['businessHours'] ?? '';

      _serviceTypes =
          List<String>.from(shop['serviceTypes'] ?? []);
    }

    setState(() {
      _loading = false;
    });
  }

  // 🔥 選開始時間
  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _startTime ?? const TimeOfDay(hour: 10, minute: 0),
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
      initialTime:
          _endTime ?? const TimeOfDay(hour: 20, minute: 0),
    );

    if (picked != null) {
      setState(() {
        _endTime = picked;
        _updateBusinessHoursText();
      });
    }
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
      isPublic: _isPublic,
      serviceTypes: _serviceTypes, // 🔥 重點
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已儲存')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('營業資訊'),
      ),
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

            /// 🔥 服務類型
            const Text(
              '提供服務',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            CheckboxListTile(
              title: const Text('住宿'),
              value: _serviceTypes.contains('overnight'),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _serviceTypes.add('overnight');
                  } else {
                    _serviceTypes.remove('overnight');
                  }
                });
              },
            ),

            CheckboxListTile(
              title: const Text('日托'),
              value: _serviceTypes.contains('daycare'),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _serviceTypes.add('daycare');
                  } else {
                    _serviceTypes.remove('daycare');
                  }
                });
              },
            ),

            const SizedBox(height: 16),

            /// 公開開關
            SwitchListTile(
              title: const Text('是否公開顯示'),
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
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
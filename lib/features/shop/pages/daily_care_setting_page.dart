// lib/features/shop/pages/daily_care_setting_page.dart
// 🐾 每日照護紀錄設定頁
// 功能：讓店主設定是否啟用每日照護紀錄、每天填寫次數、
// 要填寫的照護欄位、照片功能與退房後下載期限。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/services/daily_care_setting_service.dart';

class DailyCareSettingPage extends StatefulWidget {
  const DailyCareSettingPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<DailyCareSettingPage> createState() => _DailyCareSettingPageState();
}

class _DailyCareSettingPageState extends State<DailyCareSettingPage> {
  bool _loading = true;
  bool _saving = false;

  bool _enabled = false;
  int _sessionCount = 2;
  bool _photoEnabled = true;
  int _downloadHours = 24;

  Set<String> _enabledFields = <String>{};

  List<DailyCareCustomField> _customFields = <DailyCareCustomField>[];

  static const List<_CareFieldOption> _fieldOptions = <_CareFieldOption>[
    _CareFieldOption(
      key: 'water',
      label: '飲水',
      icon: Icons.water_drop_outlined,
    ),
    _CareFieldOption(
      key: 'dryFood',
      label: '飼料',
      icon: Icons.restaurant_outlined,
    ),
    _CareFieldOption(
      key: 'wetFood',
      label: '罐頭',
      icon: Icons.soup_kitchen_outlined,
    ),
    _CareFieldOption(key: 'snack', label: '零食', icon: Icons.cookie_outlined),
    _CareFieldOption(
      key: 'stool',
      label: '大便',
      icon: Icons.check_circle_outline,
    ),
    _CareFieldOption(
      key: 'urine',
      label: '尿尿',
      icon: Icons.check_circle_outline,
    ),
    _CareFieldOption(
      key: 'wandToy',
      label: '逗貓棒',
      icon: Icons.sports_esports_outlined,
    ),
    _CareFieldOption(key: 'scratchBoard', label: '貓抓板', icon: Icons.texture),
    _CareFieldOption(
      key: 'jumpPlatform',
      label: '貓跳台',
      icon: Icons.stairs_outlined,
    ),
    _CareFieldOption(
      key: 'toyBall',
      label: '玩具球',
      icon: Icons.sports_soccer_outlined,
    ),
    _CareFieldOption(key: 'catHouse', label: '貓屋', icon: Icons.home_outlined),
    _CareFieldOption(key: 'catnip', label: '貓薄荷', icon: Icons.eco_outlined),
    _CareFieldOption(
      key: 'silverVine',
      label: '木天蓼',
      icon: Icons.local_florist_outlined,
    ),
    _CareFieldOption(key: 'catGrass', label: '貓草', icon: Icons.grass_outlined),
    _CareFieldOption(
      key: 'generalNote',
      label: '整房概況',
      icon: Icons.notes_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final DailyCareSettingModel setting = await DailyCareSettingService
          .instance
          .getSetting(widget.shopId);

      if (!mounted) return;

      setState(() {
        _enabled = setting.enabled;
        _sessionCount = setting.sessionCount;
        _photoEnabled = setting.photoEnabled;
        _downloadHours = setting.downloadHoursAfterCheckout;
        _enabledFields = setting.enabledFields.toSet();
        _customFields = List<DailyCareCustomField>.from(setting.customFields);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('讀取設定失敗：$e')));
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    if (_enabled && _enabledFields.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請至少選擇一個照護紀錄欄位')));
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final DailyCareSettingModel setting = DailyCareSettingModel(
        enabled: _enabled,
        sessionCount: _sessionCount,
        enabledFields: _enabledFields.toList(),
        customFields: _customFields,
        photoEnabled: _photoEnabled,
        downloadHoursAfterCheckout: _downloadHours,
      );

      await DailyCareSettingService.instance.saveSetting(
        shopId: widget.shopId,
        setting: setting,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('每日照護紀錄設定已儲存')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _showAddCustomFieldDialog(String category) async {
    final TextEditingController nameController = TextEditingController();

    String inputType = 'yesNo';

    final DailyCareCustomField? result = await showDialog<DailyCareCustomField>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('新增自訂照護項目'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '項目名稱',
                      hintText: '例如：吃藥、梳毛、精神狀況',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: inputType,
                    decoration: const InputDecoration(
                      labelText: '填寫方式',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'yesNo', child: Text('有 / 無')),
                      DropdownMenuItem(
                        value: 'amount',
                        child: Text('無 / 少 / 一般 / 多'),
                      ),
                      DropdownMenuItem(
                        value: 'condition',
                        child: Text('正常 / 偏少 / 偏多 / 異常'),
                      ),
                      DropdownMenuItem(value: 'text', child: Text('自由文字')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) return;

                      setDialogState(() {
                        inputType = value;
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final String name = nameController.text.trim();

                    if (name.isEmpty) {
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      DailyCareCustomField(
                        id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
                        label: name,
                        category: category,
                        inputType: inputType,
                      ),
                    );
                  },
                  child: const Text('新增'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();

    if (result == null || !mounted) return;

    setState(() {
      _customFields.add(result);
    });
  }

  String _inputTypeLabel(String inputType) {
    switch (inputType) {
      case 'amount':
        return '無 / 少 / 一般 / 多';
      case 'condition':
        return '正常 / 偏少 / 偏多 / 異常';
      case 'text':
        return '自由文字';
      case 'yesNo':
      default:
        return '有 / 無';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(title: const Text('每日照護紀錄設定')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _buildMainSwitchCard(),

                const SizedBox(height: 16),

                IgnorePointer(
                  ignoring: !_enabled,
                  child: Opacity(
                    opacity: _enabled ? 1 : 0.45,
                    child: Column(
                      children: <Widget>[
                        _buildSessionCard(),

                        const SizedBox(height: 16),

                        _buildFieldsCard(),

                        const SizedBox(height: 16),

                        _buildPhotoCard(),

                        const SizedBox(height: 16),

                        _buildDownloadCard(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? '儲存中...' : '儲存設定'),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildMainSwitchCard() {
    return _SettingCard(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          '啟用每日照護紀錄',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('開啟後，入住中的房間才會在房務管理出現照護紀錄填寫入口。'),
        ),
        value: _enabled,
        onChanged: (bool value) {
          setState(() {
            _enabled = value;
          });
        },
      ),
    );
  }

  Widget _buildSessionCard() {
    return _SettingCard(
      title: '每天填寫次數',
      subtitle: '每個房間每天填寫一份或多份紀錄，不需要每隻貓各填一份。',
      child: SegmentedButton<int>(
        segments: const <ButtonSegment<int>>[
          ButtonSegment<int>(value: 1, label: Text('1 次')),
          ButtonSegment<int>(value: 2, label: Text('2 次')),
          ButtonSegment<int>(value: 3, label: Text('3 次')),
        ],
        selected: <int>{_sessionCount},
        onSelectionChanged: (Set<int> values) {
          if (values.isEmpty) return;

          setState(() {
            _sessionCount = values.first;
          });
        },
      ),
    );
  }

  Widget _buildFieldCategory({
    required String title,
    required String category,
    required IconData icon,
    required List<_CareFieldOption> builtInFields,
  }) {
    final List<DailyCareCustomField> customFields = _customFields
        .where((DailyCareCustomField field) => field.category == category)
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: const Color(0xFF3D6F9F)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  _showAddCustomFieldDialog(category);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增'),
              ),
            ],
          ),

          for (final _CareFieldOption option in builtInFields)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: Icon(option.icon, size: 20),
              title: Text(option.label),
              value: _enabledFields.contains(option.key),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _enabledFields.add(option.key);
                  } else {
                    _enabledFields.remove(option.key);
                  }
                });
              },
            ),

          for (final DailyCareCustomField field in customFields)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.extension_outlined, size: 20),
              title: Text(field.label),
              subtitle: Text(_inputTypeLabel(field.inputType)),
              trailing: IconButton(
                tooltip: '刪除自訂項目',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _customFields.removeWhere(
                      (DailyCareCustomField item) => item.id == field.id,
                    );
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldsCard() {
    return _SettingCard(
      title: '照護紀錄欄位',
      subtitle: '溫度與濕度為固定紀錄；其他項目可依店家流程自行勾選或新增。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 固定紀錄
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.thermostat_outlined),
                  title: Text('室內溫度'),
                  trailing: Text(
                    '必填',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.water_drop_outlined),
                  title: Text('室內濕度'),
                  trailing: Text(
                    '必填',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          _buildFieldCategory(
            title: '飲食與飲水',
            category: 'food',
            icon: Icons.restaurant_outlined,
            builtInFields: _fieldOptions
                .where(
                  (_CareFieldOption item) => <String>[
                    'water',
                    'dryFood',
                    'wetFood',
                    'snack',
                  ].contains(item.key),
                )
                .toList(),
          ),

          _buildFieldCategory(
            title: '大小便狀況',
            category: 'toilet',
            icon: Icons.health_and_safety_outlined,
            builtInFields: _fieldOptions
                .where(
                  (_CareFieldOption item) =>
                      <String>['stool', 'urine'].contains(item.key),
                )
                .toList(),
          ),

          _buildFieldCategory(
            title: '活動與玩樂',
            category: 'activity',
            icon: Icons.sports_esports_outlined,
            builtInFields: _fieldOptions
                .where(
                  (_CareFieldOption item) => <String>[
                    'wandToy',
                    'scratchBoard',
                    'jumpPlatform',
                    'toyBall',
                    'catHouse',
                  ].contains(item.key),
                )
                .toList(),
          ),

          _buildFieldCategory(
            title: '放鬆與用品',
            category: 'relax',
            icon: Icons.eco_outlined,
            builtInFields: _fieldOptions
                .where(
                  (_CareFieldOption item) => <String>[
                    'catnip',
                    'silverVine',
                    'catGrass',
                  ].contains(item.key),
                )
                .toList(),
          ),

          _buildFieldCategory(
            title: '文字紀錄',
            category: 'other',
            icon: Icons.notes_outlined,
            builtInFields: _fieldOptions
                .where((_CareFieldOption item) => item.key == 'generalNote')
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard() {
    return _SettingCard(
      title: '照護照片',
      subtitle: '照片會使用壓縮預覽圖顯示，下載版會控制尺寸以降低儲存與流量成本。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('啟用照護照片'),
            value: _photoEnabled,
            onChanged: (bool value) {
              setState(() {
                _photoEnabled = value;
              });
            },
          ),
          const Divider(),
          const Text(
            '照片數量限制由平台統一控制，店家無法自行增加上限。',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard() {
    return _SettingCard(
      title: '退房後下載期限',
      subtitle: '退房後客戶可在期限內下載住宿紀錄與照片；到期後照片將關閉並進入自動清除流程。',
      child: DropdownButtonFormField<int>(
        initialValue: _downloadHours,
        decoration: const InputDecoration(
          labelText: '下載期限',
          border: OutlineInputBorder(),
        ),
        items: const <DropdownMenuItem<int>>[
          DropdownMenuItem<int>(value: 12, child: Text('12 小時')),
          DropdownMenuItem<int>(value: 24, child: Text('24 小時')),
          DropdownMenuItem<int>(value: 48, child: Text('48 小時')),
          DropdownMenuItem<int>(value: 72, child: Text('72 小時')),
        ],
        onChanged: (int? value) {
          if (value == null) return;

          setState(() {
            _downloadHours = value;
          });
        },
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.child, this.title, this.subtitle});

  final Widget child;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(
              title!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 5),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _CareFieldOption {
  const _CareFieldOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

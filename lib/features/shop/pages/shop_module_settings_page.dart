//lib/features/shop/pages/shop_module_settings_page.dart
//模組開關頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_modules.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopModuleSettingsPage extends StatefulWidget {
  const ShopModuleSettingsPage({
    super.key,
    required this.shopId,
    required this.currentUserRole,
  });

  final String shopId;
  final String? currentUserRole;

  @override
  State<ShopModuleSettingsPage> createState() =>
      _ShopModuleSettingsPageState();
}

class _ShopModuleSettingsPageState extends State<ShopModuleSettingsPage> {
  bool _saving = false;
  List<String> _selectedModules = [];

  bool get _canEdit =>
      widget.currentUserRole == ShopRoles.owner ||
      widget.currentUserRole == ShopRoles.manager;

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    final shop = await ShopService.instance.getShop(widget.shopId);

    if (shop == null) return;

    final modules =
        ShopService.instance.normalizeEnabledModules(shop['enabledModules']);

    if (!mounted) return;
    setState(() {
      _selectedModules = modules;
    });
  }

  String _label(String module) {
    switch (module) {
      case ShopModules.basicInfo:
        return '基本資訊';
      case ShopModules.catHotel:
        return '貓咪旅店';
      case ShopModules.dogHotel:
        return '狗狗旅店';
      case ShopModules.grooming:
        return '美容功能';
      case ShopModules.hospital:
        return '動物醫院';
      case ShopModules.store:
        return '賣場功能';
      case ShopModules.reports:
        return '表格統計';
      default:
        return module;
    }
  }

  String _subtitle(String module) {
    switch (module) {
      case ShopModules.basicInfo:
        return '店家資料、營業資訊、媒體設定、前台預覽';
      case ShopModules.catHotel:
        return '目前先接預約管理，之後可擴充房型與附加服務';
      case ShopModules.dogHotel:
        return '先保留模板，未來可接狗狗住宿 / 安親';
      case ShopModules.grooming:
        return '先保留模板，未來可接美容預約與價目表';
      case ShopModules.hospital:
        return '先保留模板，未來可接門診與醫師排班';
      case ShopModules.store:
        return '先保留模板，未來可接商品與訂單';
      case ShopModules.reports:
        return '統計與報表入口，部分內容可再鎖 owner';
      default:
        return '';
    }
  }

  bool _isLockedAlwaysOn(String module) {
    return module == ShopModules.basicInfo || module == ShopModules.reports;
  }

  void _toggleModule(String module, bool value) {
    if (_isLockedAlwaysOn(module)) return;

    setState(() {
      if (value) {
        if (!_selectedModules.contains(module)) {
          _selectedModules.add(module);
        }
      } else {
        _selectedModules.remove(module);
      }
    });
  }

  Future<void> _save() async {
    if (!_canEdit) return;

    setState(() {
      _saving = true;
    });

    try {
      final finalModules = <String>[
        ..._selectedModules,
      ];

      if (!finalModules.contains(ShopModules.basicInfo)) {
        finalModules.add(ShopModules.basicInfo);
      }
      if (!finalModules.contains(ShopModules.reports)) {
        finalModules.add(ShopModules.reports);
      }

      await ShopService.instance.updateEnabledModules(
        shopId: widget.shopId,
        enabledModules: finalModules,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('模組設定已儲存')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleModules = ShopModules.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('模組設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '可先保留未來模組位置，不一定全部顯示。\n'
              '基本資訊、表格統計先固定保留；其他模組可依方案或需求開關。',
            ),
          ),
          const SizedBox(height: 16),
          ...visibleModules.map((module) {
            final locked = _isLockedAlwaysOn(module);
            final checked = _selectedModules.contains(module) || locked;

            return Card(
              child: CheckboxListTile(
                value: checked,
                onChanged: (!_canEdit || locked)
                    ? null
                    : (v) => _toggleModule(module, v ?? false),
                title: Text(_label(module)),
                subtitle: Text(
                  locked
                      ? '${_subtitle(module)}\n此模組目前固定保留'
                      : _subtitle(module),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            );
          }),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: (_saving || !_canEdit) ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_canEdit ? '儲存模組設定' : '你沒有修改權限'),
          ),
        ],
      ),
    );
  }
}
// 檔案名稱：lib/features/platform/pages/platform_sales_rep_manage_page.dart
// 功能說明：建立、編輯與停用平台業務。停用保留歷史。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_commercial_service.dart';

class PlatformSalesRepManagePage extends StatefulWidget {
  const PlatformSalesRepManagePage({super.key});

  @override
  State<PlatformSalesRepManagePage> createState() =>
      _PlatformSalesRepManagePageState();
}

class _PlatformSalesRepManagePageState extends State<PlatformSalesRepManagePage> {
  List<Map<String, dynamic>> _reps = const [];
  String? _selectedId;
  bool _loading = true;
  String? _error;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final reps = await ShopCommercialService.instance.listSalesReps();
      if (!mounted) return;
      setState(() {
        _reps = reps;
        _loading = false;
      });
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
        _permissionDenied = error.permissionDenied;
      });
    }
  }

  Future<void> _edit([Map<String, dynamic>? current]) async {
    final name = TextEditingController(text: '${current?['displayName'] ?? ''}');
    final uid = TextEditingController(text: '${current?['platformUid'] ?? ''}');
    final phone = TextEditingController(text: '${current?['phone'] ?? ''}');
    final email = TextEditingController(text: '${current?['email'] ?? ''}');
    final note = TextEditingController(text: '${current?['note'] ?? ''}');
    var enabled = current?['enabled'] != false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(current == null ? '新增業務' : '編輯業務'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: '姓名／顯示名稱'),
                    ),
                    TextField(
                      controller: uid,
                      decoration: const InputDecoration(
                        labelText: '綁定平台帳號（可空白）',
                      ),
                    ),
                    TextField(
                      controller: phone,
                      decoration: const InputDecoration(labelText: '電話'),
                    ),
                    TextField(
                      controller: email,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextField(
                      controller: note,
                      decoration: const InputDecoration(labelText: '備註'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('啟用'),
                      value: enabled,
                      onChanged: (value) => setLocal(() => enabled = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved != true) {
      name.dispose();
      uid.dispose();
      phone.dispose();
      email.dispose();
      note.dispose();
      return;
    }
    try {
      await ShopCommercialService.instance.saveSalesRep({
        if (current != null) 'repId': current['repId'],
        'displayName': name.text.trim(),
        'platformUid': uid.text.trim(),
        'phone': phone.text.trim(),
        'email': email.text.trim(),
        'note': note.text.trim(),
        'enabled': enabled,
      });
      await _load();
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
    name.dispose();
    uid.dispose();
    phone.dispose();
    email.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _reps.cast<Map<String, dynamic>?>().firstWhere(
      (rep) => rep?['repId'] == _selectedId,
      orElse: () => null,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('業務管理')),
      floatingActionButton: _permissionDenied
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('新增業務'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _permissionDenied
          ? const Center(child: Text('沒有查看或管理業務的權限'))
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('重試')),
                ],
              ),
            )
          : _reps.isEmpty
          ? const Center(child: Text('目前沒有業務資料'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final list = ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reps.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final rep = _reps[index];
                    final enabled = rep['enabled'] == true;
                    return Card(
                      child: ListTile(
                        selected: rep['repId'] == _selectedId,
                        title: Text('${rep['displayName'] ?? ''}'),
                        subtitle: Text(enabled ? '啟用中' : '已停用，歷史仍保留'),
                        onTap: () => setState(() {
                          _selectedId = '${rep['repId']}';
                        }),
                      ),
                    );
                  },
                );
                final detail = selected == null
                    ? const Center(child: Text('請選擇一位業務'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            '${selected['displayName'] ?? ''}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text('電話：${selected['phone'] ?? '未填'}'),
                          Text('Email：${selected['email'] ?? '未填'}'),
                          Text(
                            (selected['platformUid'] ?? '').toString().isEmpty
                                ? '尚未綁定登入帳號'
                                : '已綁定平台帳號',
                          ),
                          Text('備註：${selected['note'] ?? ''}'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => _edit(selected),
                            child: const Text('編輯'),
                          ),
                        ],
                      );
                if (constraints.maxWidth < 800) {
                  return list;
                }
                return Row(
                  children: [
                    SizedBox(width: 320, child: list),
                    const VerticalDivider(width: 1),
                    Expanded(child: detail),
                  ],
                );
              },
            ),
    );
  }
}

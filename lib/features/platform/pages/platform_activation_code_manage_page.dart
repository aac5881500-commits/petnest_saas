// 檔案名稱：lib/features/platform/pages/platform_activation_code_manage_page.dart
// 功能說明：建立激活碼、查看使用次數、查看啟用狀態
// 🎟️ 平台激活碼管理頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:petnest_saas/core/services/platform_activation_code_service.dart';

class PlatformActivationCodeManagePage extends StatefulWidget {
  const PlatformActivationCodeManagePage({super.key});

  @override
  State<PlatformActivationCodeManagePage> createState() =>
      _PlatformActivationCodeManagePageState();
}

class _PlatformActivationCodeManagePageState
    extends State<PlatformActivationCodeManagePage> {
  final _codeController = TextEditingController();

  final _maxUsesController = TextEditingController(text: '1');

  final _freeDaysController = TextEditingController(text: '30');

  final _searchController = TextEditingController();

  String _searchKeyword = '';
  String _selectedModule = 'cat_hotel';

  @override
  void dispose() {
    _codeController.dispose();
    _maxUsesController.dispose();
    _freeDaysController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCreateDialog() async {
    _codeController.clear();
    _selectedModule = 'cat_hotel';
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('建立激活碼'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: '激活碼',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _selectedModule,
                  decoration: const InputDecoration(
                    labelText: '開通模板',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cat_hotel', child: Text('貓咪旅館')),
                    DropdownMenuItem(value: 'dog_hotel', child: Text('狗狗旅館')),
                    DropdownMenuItem(value: 'grooming', child: Text('寵物美容')),
                    DropdownMenuItem(value: 'hospital', child: Text('動物醫院')),
                    DropdownMenuItem(value: 'store', child: Text('寵物商城')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedModule = value ?? 'cat_hotel';
                    });
                  },
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: _maxUsesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '可使用次數',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: _freeDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '免費天數',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = _codeController.text.trim();

                if (code.isEmpty) {
                  return;
                }

                try {
                  await PlatformActivationCodeService.instance.createCode(
                    code: code,
                    module: _selectedModule,
                    maxUses: int.tryParse(_maxUsesController.text) ?? 1,
                    freeDays: int.tryParse(_freeDaysController.text) ?? 30,
                  );

                  if (!mounted) return;

                  Navigator.pop(context);

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('激活碼建立成功')));
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('建立失敗：$e')));
                }
              },
              child: const Text('建立'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showUsageLogs(String codeId) async {
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('使用紀錄'),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('activation_codes')
                  .doc(codeId)
                  .collection('usage_logs')
                  .orderBy('usedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Text('目前沒有使用紀錄');
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    return ListTile(
                      title: Text(data['shopName']?.toString() ?? '未命名店家'),
                      subtitle: Text(data['usedByEmail']?.toString() ?? ''),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      appBar: AppBar(title: const Text('激活碼管理')),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('新增激活碼'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜尋激活碼...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchKeyword = value.trim().toLowerCase();
                });
              },
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('activation_codes')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final code = data['code']?.toString().toLowerCase() ?? '';

                  return code.contains(_searchKeyword);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('目前沒有激活碼'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];

                    final data = doc.data() as Map<String, dynamic>;

                    final code = data['code'] ?? '';

                    final usedCount = data['usedCount'] ?? 0;

                    final maxUses = data['maxUses'] ?? 0;

                    final enabled = data['enabled'] == true;

                    final isUsedUp = maxUses > 0 && usedCount >= maxUses;

                    final freeDays = data['freeDays'] ?? 0;

                    final plan = data['plan'] ?? '';

                    final module = data['module'] ?? '';

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    code,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),

                                IconButton(
                                  tooltip: '複製激活碼',
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: code),
                                    );

                                    if (!mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('已複製激活碼')),
                                    );
                                  },
                                  icon: const Icon(Icons.copy),
                                ),

                                IconButton(
                                  tooltip: '分享激活碼',
                                  onPressed: () {
                                    Share.share('PetNest SaaS 創店激活碼：$code');
                                  },
                                  icon: const Icon(Icons.share),
                                ),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUsedUp
                                        ? Colors.orange.withValues(alpha: 0.1)
                                        : enabled
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    isUsedUp
                                        ? '已用完'
                                        : enabled
                                        ? '啟用中'
                                        : '已停用',
                                    style: TextStyle(
                                      color: isUsedUp
                                          ? Colors.orange
                                          : enabled
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _InfoPill(label: '方案：$plan'),
                                _InfoPill(label: '模板：$module'),
                                _InfoPill(label: '免費：$freeDays 天'),
                                _InfoPill(label: '使用：$usedCount / $maxUses'),
                              ],
                            ),

                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  _showUsageLogs(doc.id);
                                },
                                icon: const Icon(Icons.history, size: 18),
                                label: const Text('查看使用紀錄'),
                              ),
                            ),

                            const SizedBox(height: 8),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await PlatformActivationCodeService.instance
                                      .updateCodeEnabled(
                                        codeId: doc.id,
                                        enabled: !enabled,
                                      );
                                },
                                icon: Icon(
                                  enabled
                                      ? Icons.block
                                      : Icons.check_circle_outline,
                                  size: 18,
                                ),
                                label: Text(enabled ? '停用激活碼' : '啟用激活碼'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

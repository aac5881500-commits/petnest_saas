// lib/features/auth/pages/shop_policy_logs_page.dart
// 📊 條款同意紀錄（後台 + 搜尋 + 排序 + 美化時間）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopPolicyLogsPage extends StatefulWidget {
  const ShopPolicyLogsPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<ShopPolicyLogsPage> createState() =>
      _ShopPolicyLogsPageState();
}

class _ShopPolicyLogsPageState
    extends State<ShopPolicyLogsPage> {
  bool _loading = true;

  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];

  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ShopService.instance
        .getPolicyAcceptances(widget.shopId);

    /// 🔥 排序（最新在上）
    data.sort((a, b) {
      final aTime = a['acceptedAt'];
      final bTime = b['acceptedAt'];

      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    setState(() {
      _logs = data;
      _filteredLogs = data;
      _loading = false;
    });
  }

  /// 🔍 搜尋
  void _onSearch(String value) {
    _search = value;

    final lower = value.toLowerCase();

    setState(() {
      _filteredLogs = _logs.where((item) {
        final email =
            (item['email'] ?? '').toString().toLowerCase();
        final userId =
            (item['userId'] ?? '').toString().toLowerCase();

        return email.contains(lower) ||
            userId.contains(lower);
      }).toList();
    });
  }

  /// 🕒 時間格式
  String _formatTime(dynamic ts) {
    if (ts == null) return '-';
    final dt = ts.toDate();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('條款同意紀錄'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                /// 🔍 搜尋框
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '搜尋 email 或會員ID',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _onSearch,
                  ),
                ),

                /// 📋 列表
                Expanded(
                  child: _filteredLogs.isEmpty
                      ? const Center(child: Text('沒有符合資料'))
                      : ListView.builder(
                          itemCount: _filteredLogs.length,
                          itemBuilder: (context, index) {
                            final item = _filteredLogs[index];

                            final email = item['email'];
                            final userId = item['userId'];

                            final displayUser =
                                (email != null &&
                                        email.toString().isNotEmpty)
                                    ? email
                                    : userId;

                            return Card(
                              margin: const EdgeInsets.all(8),
                              child: ListTile(
                                title: FutureBuilder<Map<String, dynamic>?>(
  future: ShopService.instance.getUserProfile(userId),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
  return Text('會員：載入中...');
}
    final data = snapshot.data ?? <String, dynamic>{};

final name =
    data['displayName']?.toString() ??
    data['name']?.toString() ??
    data['customerName']?.toString() ??
    '';
final email = data['email']?.toString() ?? '';
final phone = data['phone']?.toString() ?? '';
    final display =
        (name != null && name.toString().isNotEmpty)
            ? '$name（${email ?? ''}）'
            : (email ?? userId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('會員：$display'),
        if (phone != null && phone.toString().isNotEmpty)
          Text('電話：$phone'),
      ],
    );
  },
),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                            '版本：v${item['acceptedVersion']}'),
                                        const SizedBox(width: 8),

                                        /// 🔥 最新標籤
                                        if (index == 0 &&
                                            _search.isEmpty)
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              '最新',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                        '時間：${_formatTime(item['acceptedAt'])}'),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
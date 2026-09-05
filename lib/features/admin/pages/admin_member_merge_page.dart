// 檔案名稱：lib/features/admin/pages/admin_member_merge_page.dart
// 功能說明：掃描同電話的手動會員與店家會員，後續提供合併訂單功能
// 🔀 後台會員合併管理頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/member_merge_service.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_detail_page.dart';

class AdminMemberMergePage extends StatefulWidget {
  const AdminMemberMergePage({super.key, required this.shopId});

  final String shopId;

  @override
  State<AdminMemberMergePage> createState() => _AdminMemberMergePageState();
}

class _AdminMemberMergePageState extends State<AdminMemberMergePage> {
  late Future<List<MemberMergeCandidate>> _future;
  bool _isMerging = false;

  @override
  void initState() {
    super.initState();
    _future = MemberMergeService.instance.findCandidates(shopId: widget.shopId);
  }

  void _reload() {
    setState(() {
      _future = MemberMergeService.instance.findCandidates(
        shopId: widget.shopId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('會員合併管理')),
      backgroundColor: Colors.grey.shade100,
      body: FutureBuilder<List<MemberMergeCandidate>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('合併名單讀取失敗：${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final candidates = snapshot.data!;

          if (candidates.isEmpty) {
            return const Center(child: Text('目前沒有可合併的同電話會員'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: candidates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = candidates[index];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '電話：${item.phone}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _mergeInfoBox(
                              title: '手動會員',
                              name: item.manualName,
                              bookingCount: item.manualBookingCount,
                              petCount: item.manualPetCount,
                              color: Colors.purple,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.arrow_forward,
                              color: Colors.grey,
                            ),
                          ),
                          Expanded(
                            child: _mergeInfoBox(
                              title: '店家會員',
                              name: item.appName,
                              bookingCount: item.appBookingCount,
                              petCount: item.appPetCount,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminMemberDetailPage(
                                  shopId: widget.shopId,
                                  userId: item.manualUserId,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility),
                          label: const Text('查看手動會員'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: const Text('確認合併訂單？'),
                                  content: Text(
                                    '將把「${item.manualName}」的訂單歸屬轉移到「${item.appName}」。\n\n'
                                    '此操作只會修改訂單 userId。\n'
                                    '不會修改訂單原始姓名、電話、金額、寵物資料。\n'
                                    '不會合併寵物資料。\n'
                                    '不會異動評價資料。\n\n'
                                    '完成後，手動會員會標記為已合併。',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      child: const Text('取消'),
                                    ),
                                    FilledButton(
                                      onPressed: _isMerging
                                          ? null
                                          : () async {
                                              Navigator.pop(dialogContext);

                                              setState(() {
                                                _isMerging = true;
                                              });

                                              try {
                                                final count =
                                                    await MemberMergeService
                                                        .instance
                                                        .mergeManualToApp(
                                                          shopId: widget.shopId,
                                                          manualUserId:
                                                              item.manualUserId,
                                                          appUserId:
                                                              item.appUserId,
                                                        );

                                                if (!context.mounted) return;

                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      '已合併 $count 筆訂單，手動會員已標記為已合併',
                                                    ),
                                                  ),
                                                );

                                                _reload();
                                              } catch (e) {
                                                if (!context.mounted) return;

                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text('合併失敗：$e'),
                                                  ),
                                                );
                                              } finally {
                                                if (context.mounted) {
                                                  setState(() {
                                                    _isMerging = false;
                                                  });
                                                }
                                              }
                                            },
                                      child: const Text('確認合併訂單'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          icon: const Icon(Icons.merge_type),
                          label: const Text('合併訂單'),
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
    );
  }

  Widget _mergeInfoBox({
    required String title,
    required String name,
    required int bookingCount,
    required int petCount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text('訂單：$bookingCount 筆'),
          Text('寵物：$petCount 隻'),
        ],
      ),
    );
  }
}

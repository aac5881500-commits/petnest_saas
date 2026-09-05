// 檔案名稱：lib/features/platform/pages/platform_review_manage_page.dart
// 功能說明：查看所有店家的會員評價與店家回覆
// ⭐ 平台後台：全平台評價管理

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/features/booking/widgets/review_card.dart';

class PlatformReviewManagePage extends StatefulWidget {
  const PlatformReviewManagePage({super.key});

  @override
  State<PlatformReviewManagePage> createState() =>
      _PlatformReviewManagePageState();
}

class _PlatformReviewManagePageState extends State<PlatformReviewManagePage> {
  String _statusFilter = 'all';
  final TextEditingController _shopKeywordController = TextEditingController();

  String _shopKeyword = '';
  int? _ratingFilter;
  bool _sortNewestFirst = true;

  @override
  void dispose() {
    _shopKeywordController.dispose();
    super.dispose();
  }

  Future<void> _hideReview(BuildContext context, ReviewModel review) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('隱藏評價'),
        content: const Text('確定要隱藏這則評價嗎？隱藏後前台不應再顯示。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定隱藏'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await FirebaseFirestore.instance
        .collection('reviews')
        .doc(review.reviewId)
        .update({
          'status': 'hidden',
          'updatedAt': FieldValue.serverTimestamp(),
        });

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已隱藏評價')));
  }

  Future<void> _restoreReview(BuildContext context, ReviewModel review) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('還原評價'),
        content: const Text('確定要讓這則評價重新顯示嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定還原'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await FirebaseFirestore.instance
        .collection('reviews')
        .doc(review.reviewId)
        .update({
          'status': 'visible',
          'updatedAt': FieldValue.serverTimestamp(),
        });

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已還原評價')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('評價管理')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            (_statusFilter == 'all'
                    ? FirebaseFirestore.instance.collection('reviews')
                    : FirebaseFirestore.instance
                          .collection('reviews')
                          .where('status', isEqualTo: _statusFilter))
                .orderBy('createdAt', descending: _sortNewestFirst)
                .limit(100)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('讀取評價失敗：${snapshot.error}'),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('目前沒有評價'));
          }

          final reviews = docs.map(ReviewModel.fromDoc).toList();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _shopKeywordController,
                      decoration: InputDecoration(
                        hintText: '搜尋店家名稱',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _shopKeyword = value.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('全部'),
                          selected: _statusFilter == 'all',
                          onSelected: (_) {
                            setState(() {
                              _statusFilter = 'all';
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('顯示中'),
                          selected: _statusFilter == 'visible',
                          onSelected: (_) {
                            setState(() {
                              _statusFilter = 'visible';
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('已隱藏'),
                          selected: _statusFilter == 'hidden',
                          onSelected: (_) {
                            setState(() {
                              _statusFilter = 'hidden';
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('全部星數'),
                          selected: _ratingFilter == null,
                          onSelected: (_) {
                            setState(() {
                              _ratingFilter = null;
                            });
                          },
                        ),
                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('最新優先'),
                              selected: _sortNewestFirst,
                              onSelected: (_) {
                                setState(() {
                                  _sortNewestFirst = true;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('最舊優先'),
                              selected: !_sortNewestFirst,
                              onSelected: (_) {
                                setState(() {
                                  _sortNewestFirst = false;
                                });
                              },
                            ),
                          ],
                        ),
                        for (final rating in [5, 4, 3, 2, 1])
                          ChoiceChip(
                            label: Text('$rating 星'),
                            selected: _ratingFilter == rating,
                            onSelected: (_) {
                              setState(() {
                                _ratingFilter = rating;
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                );
              }

              final review = reviews[index - 1];

              if (_ratingFilter != null && review.rating != _ratingFilter) {
                return const SizedBox.shrink();
              }

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('shops')
                    .doc(review.shopId)
                    .get(),
                builder: (context, shopSnapshot) {
                  final shopData = shopSnapshot.data?.data();
                  final shopName = (shopData?['name'] ?? '未知店家').toString();

                  if (_shopKeyword.isNotEmpty &&
                      !shopName.contains(_shopKeyword)) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                shopName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              review.status,
                              style: TextStyle(
                                fontSize: 12,
                                color: review.status == 'visible'
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ReviewCard(review: review),
                        const SizedBox(height: 8),
                        review.status == 'visible'
                            ? OutlinedButton.icon(
                                onPressed: () => _hideReview(context, review),
                                icon: const Icon(Icons.visibility_off),
                                label: const Text('隱藏評價'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: () =>
                                    _restoreReview(context, review),
                                icon: const Icon(Icons.visibility),
                                label: const Text('還原評價'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                ),
                              ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

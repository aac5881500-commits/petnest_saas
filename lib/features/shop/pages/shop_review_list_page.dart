// lib/features/shop/pages/shop_review_list_page.dart
// ⭐ 店家前台：完整評價列表頁
// 功能：顯示單一店家的 visible 評價、平均星數、星數分布、星數篩選與評價列表

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/features/booking/widgets/review_card.dart';

class ShopReviewListPage extends StatefulWidget {
  const ShopReviewListPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopReviewListPage> createState() => _ShopReviewListPageState();
}

class _ShopReviewListPageState extends State<ShopReviewListPage> {
  int? _ratingFilter;
  bool _sortNewestFirst = true;
  bool _onlyWithImages = false;
  bool _onlyWithReply = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF7),
      appBar: AppBar(
        title: const Text('顧客評價'),
        backgroundColor: const Color(0xFFFFFCF7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('shopId', isEqualTo: widget.shopId)
            .where('status', isEqualTo: 'visible')
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

          final reviews = snapshot.data!.docs.map(ReviewModel.fromDoc).toList();

          reviews.sort((a, b) {
            final aTime = a.createdAt;
            final bTime = b.createdAt;

            if (aTime == null || bTime == null) return 0;

            return _sortNewestFirst
                ? bTime.compareTo(aTime)
                : aTime.compareTo(bTime);
          });

          if (reviews.isEmpty) {
            return const Center(child: Text('目前尚無評價'));
          }

          double total = 0;

          int star5 = 0;
          int star4 = 0;
          int star3 = 0;
          int star2 = 0;
          int star1 = 0;

          for (final review in reviews) {
            total += review.rating.toDouble();

            switch (review.rating) {
              case 5:
                star5++;
                break;
              case 4:
                star4++;
                break;
              case 3:
                star3++;
                break;
              case 2:
                star2++;
                break;
              case 1:
                star1++;
                break;
            }
          }

          final average = total / reviews.length;

          final filteredReviews = reviews.where((review) {
            if (_ratingFilter != null && review.rating != _ratingFilter) {
              return false;
            }

            if (_onlyWithImages && review.imageUrls.isEmpty) {
              return false;
            }

            if (_onlyWithReply && !review.hasReply) {
              return false;
            }

            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF0E0CC)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            average.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF3A2A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.star,
                                size: 14,
                                color: Color(0xFFFFB300),
                              ),
                              Icon(
                                Icons.star,
                                size: 14,
                                color: Color(0xFFFFB300),
                              ),
                              Icon(
                                Icons.star,
                                size: 14,
                                color: Color(0xFFFFB300),
                              ),
                              Icon(
                                Icons.star,
                                size: 14,
                                color: Color(0xFFFFB300),
                              ),
                              Icon(
                                Icons.star,
                                size: 14,
                                color: Color(0xFFFFB300),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${reviews.length} 則評價',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _starDistributionRow(
                            star: 5,
                            count: star5,
                            total: reviews.length,
                          ),
                          _starDistributionRow(
                            star: 4,
                            count: star4,
                            total: reviews.length,
                          ),
                          _starDistributionRow(
                            star: 3,
                            count: star3,
                            total: reviews.length,
                          ),
                          _starDistributionRow(
                            star: 2,
                            count: star2,
                            total: reviews.length,
                          ),
                          _starDistributionRow(
                            star: 1,
                            count: star1,
                            total: reviews.length,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: _ratingFilter == null,
                    onSelected: (_) {
                      setState(() {
                        _ratingFilter = null;
                      });
                    },
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

              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('有圖片'),
                    selected: _onlyWithImages,
                    onSelected: (selected) {
                      setState(() {
                        _onlyWithImages = selected;
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('有店家回覆'),
                    selected: _onlyWithReply,
                    onSelected: (selected) {
                      setState(() {
                        _onlyWithReply = selected;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (filteredReviews.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('目前沒有符合篩選條件的評價')),
                )
              else
                ...filteredReviews.map((review) => ReviewCard(review: review)),
            ],
          );
        },
      ),
    );
  }

  Widget _starDistributionRow({
    required int star,
    required int count,
    required int total,
  }) {
    final percent = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$star★',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 7,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: const Color(0xFFFFF1DD),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

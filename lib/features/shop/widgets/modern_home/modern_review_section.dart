// 檔案名稱：lib/features/shop/widgets/modern_home/modern_review_section.dart
// 功能說明：讀取店家公開評價，顯示緊湊型橫向評價卡片與全部評價入口
// ⭐ 新版首頁顧客評價區塊

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/features/shop/pages/shop_review_list_page.dart';

class ModernReviewSection extends StatelessWidget {
  const ModernReviewSection({
    super.key,
    required this.shopId,
    required this.primaryColor,
    required this.darkTextColor,
    required this.secondaryTextColor,
    required this.cardColor,
    required this.borderColor,
    required this.theme,
  });

  final String shopId;
  final Color primaryColor;
  final Color darkTextColor;
  final Color secondaryTextColor;
  final Color cardColor;
  final Color borderColor;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.star_rounded, size: 16, color: primaryColor),
            const SizedBox(width: 6),
            Text(
              '顧客評價',
              style: TextStyle(
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: darkTextColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('reviews')
              .where('shopId', isEqualTo: shopId)
              .where('status', isEqualTo: 'visible')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 112,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            if (snapshot.hasError) {
              return _buildMessageCard(message: '評價資料讀取失敗');
            }

            final reviews =
                snapshot.data?.docs
                    .map(ReviewModel.fromDoc)
                    .where((review) => review.isVisible)
                    .toList() ??
                <ReviewModel>[];

            reviews.sort((a, b) {
              final aTime = a.createdAt;
              final bTime = b.createdAt;

              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;

              return bTime.compareTo(aTime);
            });

            if (reviews.isEmpty) {
              return _buildMessageCard(message: '目前尚無顧客評價');
            }

            /// 首頁最多顯示最新 5 則評價
            final previewReviews = reviews.take(5).toList();

            return LayoutBuilder(
              builder: (context, constraints) {
                const allReviewsCardWidth = 78.0;
                const separatorWidth = 8.0;

                /// 只有一則評價時，自動把評價卡加寬，
                /// 讓評價卡與「全部評價」卡盡量填滿畫面。
                final singleReviewAvailableWidth =
                    constraints.maxWidth - allReviewsCardWidth - separatorWidth;

                final reviewCardWidth = previewReviews.length == 1
                    ? singleReviewAvailableWidth.clamp(205.0, 280.0).toDouble()
                    : 205.0;

                return SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: previewReviews.length + 1,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: separatorWidth),
                    itemBuilder: (context, index) {
                      if (index == previewReviews.length) {
                        return _buildAllReviewsCard(context);
                      }

                      return _buildReviewCard(
                        previewReviews[index],
                        width: reviewCardWidth,
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMessageCard({required String message}) {
    return Container(
      height: 100,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 11, color: secondaryTextColor),
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review, {required double width}) {
    final customerName = review.customerName.trim().isEmpty
        ? '匿名顧客'
        : review.customerName.trim();

    final content = review.content.trim().isEmpty
        ? '顧客留下了星級評價'
        : review.content.trim();

    final rating = review.rating.clamp(1, 5);

    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (int index = 0; index < 5; index++)
                Icon(
                  index < rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 13,
                  color: const Color(0xFFFFB300),
                ),

              const Spacer(),

              Text(
                '${review.rating}.0',
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: darkTextColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: darkTextColor,
            ),
          ),

          const Spacer(),

          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  customerName.characters.first,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllReviewsCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ShopReviewListPage(shopId: shopId, theme: theme),
          ),
        );
      },
      child: Container(
        width: 78,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '>>',
              style: TextStyle(
                fontSize: 18,
                height: 1,
                fontWeight: FontWeight.w800,
                color: primaryColor,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              '全部評價',
              style: TextStyle(
                fontSize: 9,
                height: 1,
                fontWeight: FontWeight.w700,
                color: darkTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

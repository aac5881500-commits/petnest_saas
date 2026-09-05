// 檔案名稱：lib/features/booking/pages/my_reviews_page.dart
// 功能說明：顯示會員跨店所有評價，並可修改自己的評價內容與照片
// ⭐ 會員中心：我的評價

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/booking/pages/my_bookings_page.dart';
import 'package:petnest_saas/features/member/widgets/member_empty_state.dart';
import 'package:petnest_saas/features/member/widgets/member_page_scaffold.dart';
import 'package:petnest_saas/features/member/widgets/member_review_card.dart';
import 'package:petnest_saas/features/member/widgets/member_summary_card.dart';
import 'package:petnest_saas/features/member/widgets/member_ui_tokens.dart';

class MyReviewsPage extends StatelessWidget {
  const MyReviewsPage({super.key, this.shopId = ''});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return ShopFrontendThemeScope(
      shopId: shopId,
      builder: (BuildContext context) {
        return _MyReviewsBody(shopId: shopId);
      },
    );
  }
}

class _MyReviewsBody extends StatefulWidget {
  const _MyReviewsBody({required this.shopId});

  final String shopId;

  @override
  State<_MyReviewsBody> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<_MyReviewsBody> {
  final Map<String, String> _shopNames = <String, String>{};
  bool _loadingShops = false;

  Future<void> _ensureShopNames(Iterable<String> shopIds) async {
    final List<String> missing = shopIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty && !_shopNames.containsKey(id))
        .toSet()
        .toList();
    if (missing.isEmpty || _loadingShops) {
      return;
    }
    _loadingShops = true;
    try {
      final List<DocumentSnapshot<Map<String, dynamic>>> docs =
          await Future.wait(
            missing.map(
              (String id) =>
                  FirebaseFirestore.instance.collection('shops').doc(id).get(),
            ),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        for (int i = 0; i < missing.length; i++) {
          final Map<String, dynamic>? data = docs[i].data();
          final String name = (data?['name'] ?? '店家').toString();
          _shopNames[missing[i]] = name.trim().isEmpty ? '店家' : name.trim();
        }
      });
    } catch (error) {
      MemberUi.logError(error);
    } finally {
      _loadingShops = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const MemberPageScaffold(
        title: '我的評價',
        body: MemberEmptyState(
          icon: Icons.lock_outline,
          title: '請先登入',
          message: '登入後即可查看評價。',
        ),
      );
    }

    return MemberPageScaffold(
      title: '我的評價',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'visible')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            MemberUi.logError(snapshot.error!);
            return MemberErrorState(
              message: MemberUi.friendlyError(snapshot.error!),
            );
          }

          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return MemberEmptyState(
              icon: Icons.rate_review_outlined,
              title: '還沒有評價',
              message: '完成住宿或安親後，就能分享這次的體驗。',
              actionLabel: '查看我的訂單',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const MyBookingsPage(),
                  ),
                );
              },
            );
          }

          final reviews = docs.map(ReviewModel.fromDoc).toList();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureShopNames(
              reviews.map((ReviewModel review) => review.shopId),
            );
          });

          final int count = reviews.length;
          final double avg =
              reviews.fold<int>(0, (int sum, ReviewModel r) => sum + r.rating) /
              count;

          return MemberUi.constrain(
            ListView.builder(
              padding: const EdgeInsets.all(MemberUi.pagePadding),
              itemCount: reviews.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: MemberUi.cardGap),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: MemberSummaryCard(
                            icon: Icons.rate_review_outlined,
                            label: '總評價數',
                            value: '$count',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MemberSummaryCard(
                            icon: Icons.star_outline,
                            label: '平均評分',
                            value: avg.toStringAsFixed(1),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final review = reviews[index - 1];
                final Map<String, dynamic> raw = docs[index - 1].data();
                return MemberReviewCard(
                  review: review,
                  raw: raw,
                  shopName: _shopNames[review.shopId] ?? '店家',
                );
              },
            ),
          );
        },
      ),
    );
  }
}

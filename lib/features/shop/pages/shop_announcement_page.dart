// 檔案名稱：lib/features/shop/pages/shop_announcement_page.dart
// 功能說明：客戶端最新公告：店家公告與目前啟用優惠活動雙分頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/booking/widgets/customer_active_campaigns_section.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_detail_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_entry_page.dart';
import 'package:petnest_saas/features/shop/widgets/announcement/shop_announcement_card.dart';

enum ShopAnnouncementSection { notices, campaigns }

class ShopAnnouncementPage extends StatelessWidget {
  const ShopAnnouncementPage({
    super.key,
    required this.shopId,
    this.theme = HomeThemeModel.classicDefault,
    this.initialSection = ShopAnnouncementSection.notices,
    this.returnToBookingOnReserve = false,
    this.bookingSnapshot,
    this.memberJoinedAt,
    this.isFirstBooking = false,
    this.memberCampaignUsedNights = const <String, int>{},
  });

  final String shopId;
  final HomeThemeModel theme;
  final ShopAnnouncementSection initialSection;
  final bool returnToBookingOnReserve;
  final CustomerCampaignBookingSnapshot? bookingSnapshot;
  final DateTime? memberJoinedAt;
  final bool isFirstBooking;
  final Map<String, int> memberCampaignUsedNights;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialSection == ShopAnnouncementSection.campaigns ? 1 : 0,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        appBar: AppBar(
          backgroundColor: theme.cardColor,
          foregroundColor: theme.textColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            '最新公告',
            style: TextStyle(
              color: theme.textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: TabBar(
            labelColor: theme.primaryColor,
            unselectedLabelColor: theme.textColor.withValues(alpha: 0.55),
            indicatorColor: theme.primaryColor,
            tabs: const <Widget>[
              Tab(text: '店家公告'),
              Tab(text: '優惠活動'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _AnnouncementList(shopId: shopId, theme: theme),
            CustomerActiveCampaignsSection(
              shopId: shopId,
              theme: theme,
              showBookButton: true,
              bookingSnapshot: bookingSnapshot,
              memberJoinedAt: memberJoinedAt,
              isFirstBooking: isFirstBooking,
              memberCampaignUsedNights: memberCampaignUsedNights,
              onBookNow: () {
                if (returnToBookingOnReserve &&
                    Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ShopBookingEntryPage(shopId: shopId, theme: theme),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementList extends StatelessWidget {
  const _AnnouncementList({required this.shopId, required this.theme});

  final String shopId;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .snapshots(),
      builder: (context, shopSnapshot) {
        if (!shopSnapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: theme.primaryColor),
          );
        }

        final shopData = shopSnapshot.data!.data() as Map<String, dynamic>?;

        final showAnnouncementSection =
            shopData?['showAnnouncementSection'] != false;

        if (!showAnnouncementSection) {
          return Center(
            child: Text(
              '此功能尚未開放',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.65)),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('shops')
              .doc(shopId)
              .collection('announcements')
              .where('isPublished', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  '公告暫時無法載入，請稍後再試',
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.65),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(color: theme.primaryColor),
              );
            }

            final docs = snapshot.data!.docs.toList();

            docs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;

              final aTime = aData['createdAt'];
              final bTime = bData['createdAt'];

              if (aTime is! Timestamp || bTime is! Timestamp) return 0;

              return bTime.compareTo(aTime);
            });

            if (docs.isEmpty) {
              return Center(
                child: Text(
                  '目前尚無公告',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.textColor.withValues(alpha: 0.65),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShopAnnouncementDetailPage(
                          data: data,
                          theme: theme,
                        ),
                      ),
                    );
                  },
                  child: ShopAnnouncementCard(data: data, theme: theme),
                );
              },
            );
          },
        );
      },
    );
  }
}

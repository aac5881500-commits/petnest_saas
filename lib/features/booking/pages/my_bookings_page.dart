// lib/features/booking/pages/my_bookings_page.dart
// 📄 我的訂單頁
//
// 功能：
// - 顯示目前登入會員的所有訂單
// - 訂單卡片顯示房號 / 日期 / 寵物數 / 中文狀態 / 總金額
// - 點擊訂單卡片可直接進入訂單詳細頁
// - 狀態不顯示英文，統一轉成客戶看得懂的中文

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';
import 'package:petnest_saas/features/member/widgets/member_booking_card.dart';
import 'package:petnest_saas/features/member/widgets/member_empty_state.dart';
import 'package:petnest_saas/features/member/widgets/member_filter_chips.dart';
import 'package:petnest_saas/features/member/widgets/member_list_helpers.dart';
import 'package:petnest_saas/features/member/widgets/member_page_scaffold.dart';
import 'package:petnest_saas/features/member/widgets/member_ui_tokens.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_entry_page.dart';

class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({super.key, this.returnShopId});

  final String? returnShopId;

  @override
  Widget build(BuildContext context) {
    return ShopFrontendThemeScope(
      shopId: returnShopId ?? '',
      builder: (BuildContext context) {
        return _MyBookingsBody(returnShopId: returnShopId);
      },
    );
  }
}

class _MyBookingsBody extends StatefulWidget {
  const _MyBookingsBody({this.returnShopId});

  final String? returnShopId;

  @override
  State<_MyBookingsBody> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<_MyBookingsBody> {
  int _limit = 5;
  bool _checkingHistoryMergedNotice = false;
  bool _historyNoticeCheckedOnce = false;
  String _filter = MemberBookingFilters.all;

  Future<void> _checkHistoryMergedNotice({
    required String shopId,
    required String userId,
  }) async {
    if (_checkingHistoryMergedNotice || _historyNoticeCheckedOnce) return;

    _checkingHistoryMergedNotice = true;
    _historyNoticeCheckedOnce = true;

    try {
      final memberRef = FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
          .doc(userId);

      final memberDoc = await memberRef.get();

      if (!memberDoc.exists) return;

      final memberData = memberDoc.data() ?? {};

      final shouldShow = memberData['historyMergedNoticeShown'] == false;
      final count = memberData['historyMergedBookingCount'] ?? 0;

      if (!shouldShow || count <= 0) return;
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('已同步歷史訂單'),
            content: Text(
              '已同步 $count 筆歷史住宿紀錄。\n\n'
              '這些訂單是在您使用 PetNest App 前，由店家協助建立，'
              '因此已同步到您的會員中心。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('我知道了'),
              ),
            ],
          );
        },
      );

      await memberRef.update({
        'historyMergedNoticeShown': true,
        'historyMergedNoticeShownAt': FieldValue.serverTimestamp(),
      });
    } finally {
      _checkingHistoryMergedNotice = false;
    }
  }

  void _goBook() {
    final String shopId = widget.returnShopId?.trim() ?? '';
    if (shopId.isEmpty) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ShopBookingEntryPage(
          shopId: shopId,
          theme: ShopFrontendTheme.of(context).home,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const MemberPageScaffold(
        title: '我的訂單',
        body: MemberEmptyState(
          icon: Icons.lock_outline,
          title: '請先登入',
          message: '登入後即可查看訂單。',
        ),
      );
    }

    return MemberPageScaffold(
      title: '我的訂單',
      body: StreamBuilder<QuerySnapshot>(
        stream: () {
          Query<Map<String, dynamic>> query = FirebaseFirestore.instance
              .collection('bookings')
              .where('userId', isEqualTo: user.uid);

          final String currentShopId = widget.returnShopId?.trim() ?? '';

          if (currentShopId.isNotEmpty) {
            query = query.where('shopId', isEqualTo: currentShopId);
          }

          return query
              .orderBy('createdAt', descending: true)
              .limit(30)
              .snapshots();
        }(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            MemberUi.logError(snapshot.error!);
            return MemberErrorState(
              message: MemberUi.friendlyError(snapshot.error!),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            final String shopId = widget.returnShopId?.trim() ?? '';
            return MemberEmptyState(
              icon: Icons.receipt_long_outlined,
              title: '目前沒有訂單',
              message: '完成預約後，住宿與安親訂單會顯示在這裡。',
              actionLabel: shopId.isEmpty ? null : '前往預約',
              onAction: shopId.isEmpty ? null : _goBook,
            );
          }

          final docs = snapshot.data!.docs.toList();

          final firstData = docs.first.data() as Map<String, dynamic>;
          final firstShopId = (firstData['shopId'] ?? '').toString();

          if (firstShopId.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkHistoryMergedNotice(shopId: firstShopId, userId: user.uid);
            });
          }

          final List<QueryDocumentSnapshot> filtered = docs.where((doc) {
            final Map<String, dynamic> data =
                doc.data() as Map<String, dynamic>;
            final String status = (data['status'] ?? '').toString();
            return MemberBookingFilters.matches(_filter, status);
          }).toList();

          final visibleDocs = filtered.take(_limit).toList();
          final bool hasMore = visibleDocs.length < filtered.length;

          if (filtered.isEmpty) {
            return MemberUi.constrain(
              ListView(
                padding: const EdgeInsets.all(MemberUi.pagePadding),
                children: <Widget>[
                  _filterBar(docs),
                  MemberEmptyState(
                    icon: Icons.filter_list_outlined,
                    title: '這個分類目前沒有訂單',
                    message: '試試切換其他狀態查看。',
                  ),
                ],
              ),
            );
          }

          return MemberUi.constrain(
            ListView.builder(
              padding: const EdgeInsets.all(MemberUi.pagePadding),
              itemCount: visibleDocs.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _filterBar(docs),
                  );
                }
                if (index == visibleDocs.length + 1) {
                  if (hasMore) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _limit += 10;
                          });
                        },
                        child: const Text('載入更多訂單'),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24, top: 4),
                    child: Text(
                      '已顯示全部訂單',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: MemberUi.captionSize,
                        color: MemberUi.of(context).muted,
                      ),
                    ),
                  );
                }
                final data =
                    visibleDocs[index - 1].data() as Map<String, dynamic>;
                final BookingDetailViewData view =
                    BookingDetailViewData.fromBooking(
                      data: data,
                      docId: visibleDocs[index - 1].id,
                    );
                return MemberBookingCard(view: view);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _filterBar(List<QueryDocumentSnapshot> docs) {
    int countFor(String filter) {
      return docs.where((doc) {
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return MemberBookingFilters.matches(
          filter,
          (data['status'] ?? '').toString(),
        );
      }).length;
    }

    return MemberFilterChips(
      selectedId: _filter,
      onSelected: (String id) {
        setState(() {
          _filter = id;
          _limit = 5;
        });
      },
      options: <MemberFilterOption>[
        MemberFilterOption(
          id: MemberBookingFilters.all,
          label: '全部',
          count: docs.length,
        ),
        MemberFilterOption(
          id: MemberBookingFilters.active,
          label: '進行中',
          count: countFor(MemberBookingFilters.active),
        ),
        MemberFilterOption(
          id: MemberBookingFilters.completed,
          label: '已完成',
          count: countFor(MemberBookingFilters.completed),
        ),
        MemberFilterOption(
          id: MemberBookingFilters.cancelled,
          label: '已取消',
          count: countFor(MemberBookingFilters.cancelled),
        ),
      ],
    );
  }
}

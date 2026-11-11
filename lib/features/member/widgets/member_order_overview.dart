import 'package:petnest_saas/features/member/widgets/member_order_room_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/inspection_owner_context.dart';
import 'package:petnest_saas/features/booking/pages/booking_detail_page.dart';
import 'package:petnest_saas/features/booking/pages/my_bookings_page.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

class MemberOrderPreview {
  const MemberOrderPreview({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;
  BookingDetailViewData get view =>
      BookingDetailViewData.fromBooking(data: data, docId: id);
}

/// Latest personal order across shops; owner inspection stays within its shop.
class MemberOrderOverviewHost extends StatefulWidget {
  const MemberOrderOverviewHost({
    super.key,
    required this.shopId,
    required this.userId,
    required this.theme,
    this.compact = false,
    this.hideWhenEmpty = false,
    this.ordersStream,
    this.onOpenOrders,
    this.onOpenLatest,
  });
  final String shopId, userId;
  final HomeThemeModel theme;
  final bool compact, hideWhenEmpty;
  final Stream<MemberOrderPreview?>? ordersStream;
  final VoidCallback? onOpenOrders;
  final ValueChanged<MemberOrderPreview>? onOpenLatest;
  @override
  State<MemberOrderOverviewHost> createState() =>
      _MemberOrderOverviewHostState();
}

class _MemberOrderOverviewHostState extends State<MemberOrderOverviewHost> {
  late Stream<MemberOrderPreview?> stream;
  String get shop => InspectionOwnerContext.active
      ? InspectionOwnerContext.shopId
      : widget.shopId.trim();
  String get uid => InspectionOwnerContext.readUid(widget.userId);
  @override
  void initState() {
    super.initState();
    subscribe();
  }

  @override
  void didUpdateWidget(covariant MemberOrderOverviewHost old) {
    super.didUpdateWidget(old);
    if (old.shopId != widget.shopId ||
        old.userId != widget.userId ||
        old.ordersStream != widget.ordersStream) {
      subscribe();
    }
  }

  void subscribe() {
    if (widget.ordersStream != null) {
      stream = widget.ordersStream!;
      return;
    }
    if (uid.isEmpty) {
      stream = Stream.value(null);
      return;
    }
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: uid);
    if (InspectionOwnerContext.active && shop.isNotEmpty) {
      query = query.where('shopId', isEqualTo: shop);
    }
    stream = query
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map(
          (s) => s.docs.isEmpty
              ? null
              : MemberOrderPreview(
                  id: s.docs.first.id,
                  data: s.docs.first.data(),
                ),
        );
  }

  void openOrders() {
    if (widget.onOpenOrders != null) {
      widget.onOpenOrders!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MyBookingsPage(returnShopId: shop),
      ),
    );
  }

  void openLatest(MemberOrderPreview p) {
    if (widget.onOpenLatest != null) {
      widget.onOpenLatest!(p);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BookingDetailPage(data: p.data, docId: p.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<MemberOrderPreview?>(
    key: ValueKey('order-overview-$shop-$uid'),
    stream: stream,
    builder: (context, s) {
      final preview = s.hasError ? null : s.data;
      if (widget.hideWhenEmpty && preview == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: widget.compact
            ? const EdgeInsets.only(bottom: 10)
            : EdgeInsets.zero,
        child: MemberOrderOverview(
          theme: widget.theme,
          view: preview?.view,
          compact: widget.compact,
          loading: s.connectionState == ConnectionState.waiting && !s.hasData,
          failed: s.hasError,
          onOpenOrders: openOrders,
          onOpenLatest: preview == null ? null : () => openLatest(preview),
        ),
      );
    },
  );
}

/// View-only order entry: reuses existing order labels and never recalculates payments.
class MemberOrderOverview extends StatelessWidget {
  const MemberOrderOverview({
    super.key,
    required this.theme,
    required this.onOpenOrders,
    this.view,
    this.onOpenLatest,
    this.compact = false,
    this.loading = false,
    this.failed = false,
  });
  final HomeThemeModel theme;
  final BookingDetailViewData? view;
  final VoidCallback onOpenOrders;
  final VoidCallback? onOpenLatest;
  final bool compact, loading, failed;
  @override
  Widget build(BuildContext context) {
    final soft = Color.alphaBlend(
      theme.primaryColor.withValues(alpha: 0.18),
      theme.cardColor,
    );
    final muted = theme.textColor.withValues(alpha: 0.65);
    Widget icon() => Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        Icons.receipt_long_rounded,
        color: theme.primaryColor,
        size: 24,
      ),
    );
    final title = Text(
      '我的訂單',
      style: TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w900,
        color: theme.textColor,
      ),
    );
    return Material(
      key: ValueKey(compact ? 'home-order-shortcut' : 'member-order-overview'),
      color: soft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpenOrders,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  icon(),
                  const SizedBox(width: 12),
                  Expanded(child: title),
                  Text(
                    '全部訂單',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.primaryColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: theme.cardBorderColor.withValues(alpha: 0.6),
          ),
          InkWell(
            onTap: onOpenLatest ?? onOpenOrders,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (view != null) ...[
                    MemberOrderRoomImage(data: view!.raw),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      key: view == null
                          ? null
                          : const ValueKey('latest-member-order'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (view != null) ...[
                          Text(
                            view!.shopName.trim().isEmpty
                                ? '店家名稱未提供'
                                : view!.shopName,
                            key: const ValueKey('latest-order-shop-name'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            view!.roomAssignmentLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '最近成立',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: soft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  view!.statusTitle,
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${view!.serviceLabel} · #${view!.bookingCode}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (view!.dateRangeLabel.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              view!.dateRangeLabel,
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                          if (view!.petNames.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              view!.petNames,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ] else
                          Text(
                            loading
                                ? '正在取得最近一筆訂單…'
                                : failed
                                ? '可由全部訂單查看付款與入住進度'
                                : '付款與入住進度，都在這裡查看',
                            style: TextStyle(
                              color: muted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          view == null ? '查看我的訂單' : '查看這筆訂單',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: theme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

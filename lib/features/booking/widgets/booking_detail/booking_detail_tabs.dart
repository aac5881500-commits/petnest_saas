import 'package:flutter/material.dart';
import 'booking_detail_ui.dart';
import 'booking_detail_view_data.dart';

enum BookingDetailTab {
  overview('總覽', Icons.dashboard_outlined),
  guests('入住資料', Icons.pets_outlined),
  services('服務與用藥', Icons.event_note_outlined),
  payment('費用與付款', Icons.receipt_long_outlined);

  const BookingDetailTab(this.label, this.icon);
  final IconData icon;
  final String label;
}

class BookingDetailTabs extends StatelessWidget {
  const BookingDetailTabs({
    super.key,
    required this.controller,
    required this.overview,
    required this.guests,
    required this.services,
    required this.payment,
    this.overviewController,
    this.view,
    this.brand,
  });
  final TabController controller;
  final Widget overview, guests, services, payment;
  final ScrollController? overviewController;
  final BookingDetailViewData? view;
  final Widget? brand;

  Widget _identity(BuildContext context) {
    final theme = BookingDetailUi.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?brand,
          if (view case final booking?)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.background,
                border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: booking.status == 'cancelled'
                          ? theme.dangerSoft
                          : theme.iconSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      booking.statusTitle,
                      style: TextStyle(
                        color: booking.status == 'cancelled'
                            ? theme.danger
                            : theme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (booking.dateRangeLabel.isNotEmpty)
                    Text(
                      booking.dateRangeLabel,
                      style: TextStyle(fontSize: 12, color: theme.text),
                    ),
                  if (booking.roomName.isNotEmpty)
                    Text(
                      '房間 ${booking.roomName}',
                      style: TextStyle(fontSize: 12, color: theme.muted),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _navigation(BuildContext context) {
    final theme = BookingDetailUi.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final scrollTabs = MediaQuery.sizeOf(context).width < 350 * scale;
    final milk = BookingDetailUi.isMilkTea(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Container(
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(4),
        child: TabBar(
          controller: controller,
          isScrollable: scrollTabs,
          tabAlignment: scrollTabs ? TabAlignment.start : TabAlignment.fill,
          indicator: BoxDecoration(
            color: theme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: theme.muted,
          labelPadding: EdgeInsets.symmetric(horizontal: scrollTabs ? 10 : 2),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: [
            for (final tab in BookingDetailTab.values)
              Tab(
                height: 40 * scale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!milk) ...[
                      Icon(tab.icon, size: 16),
                      const SizedBox(height: 3),
                    ],
                    Text(tab.label, maxLines: 1),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(Widget page, bool mobile) => Padding(
    padding: EdgeInsets.fromLTRB(mobile ? 16 : 28, 16, mobile ? 16 : 28, 32),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: page,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = BookingDetailUi.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final pages = [overview, guests, services, payment];
    final navigation = _navigation(context);
    final navHeight = 40 * MediaQuery.textScalerOf(context).scale(1) + 18;
    Widget pageStack() => ListenableBuilder(
      listenable: controller,
      builder: (context, child) => IndexedStack(
        index: controller.index,
        children: [
          for (final tab in BookingDetailTab.values)
            ExcludeFocus(
              excluding: tab.index != controller.index,
              child: mobile
                  ? CustomScrollView(
                      key: PageStorageKey(tab),
                      controller: tab == BookingDetailTab.overview
                          ? overviewController
                          : null,
                      primary: false,
                      slivers: [
                        SliverToBoxAdapter(child: _identity(context)),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _PinnedBookingTabs(
                            height: navHeight,
                            color: theme.card,
                            child: navigation,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _content(pages[tab.index], true),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      key: PageStorageKey(tab),
                      controller: tab == BookingDetailTab.overview
                          ? overviewController
                          : null,
                      primary: false,
                      child: _content(pages[tab.index], false),
                    ),
            ),
        ],
      ),
    );
    return SafeArea(
      top: false,
      child: mobile
          ? pageStack()
          : Column(
              children: [
                Material(
                  color: theme.card,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [_identity(context), navigation],
                      ),
                    ),
                  ),
                ),
                Expanded(child: pageStack()),
              ],
            ),
    );
  }
}

class _PinnedBookingTabs extends SliverPersistentHeaderDelegate {
  _PinnedBookingTabs({
    required this.height,
    required this.color,
    required this.child,
  });
  final double height;
  final Color color;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: color,
    child: SizedBox.expand(child: child),
  );
  @override
  bool shouldRebuild(_PinnedBookingTabs oldDelegate) =>
      height != oldDelegate.height ||
      color != oldDelegate.color ||
      child != oldDelegate.child;
}

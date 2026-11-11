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
  });

  final TabController controller;
  final Widget overview;
  final Widget guests;
  final Widget services;
  final Widget payment;
  final ScrollController? overviewController;
  final BookingDetailViewData? view;

  @override
  Widget build(BuildContext context) {
    final theme = BookingDetailUi.of(context);
    final pages = [overview, guests, services, payment];
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Material(
            color: theme.card,
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scrollTabs =
                        constraints.maxWidth <
                        350 * MediaQuery.textScalerOf(context).scale(1);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (view case final booking?)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
                              child: Row(
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: theme.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Icon(
                                        booking.isDaycare
                                            ? Icons.wb_sunny_outlined
                                            : Icons.nights_stay_outlined,
                                        size: 18,
                                        color: theme.text,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          booking.statusTitle,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: booking.status == 'cancelled'
                                                ? theme.danger
                                                : theme.text,
                                          ),
                                        ),
                                        if (booking.dateRangeLabel.isNotEmpty)
                                          Text(
                                            booking.dateRangeLabel,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.muted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              color: theme.background,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: TabBar(
                              controller: controller,
                              isScrollable: scrollTabs,
                              tabAlignment: scrollTabs
                                  ? TabAlignment.start
                                  : TabAlignment.fill,
                              indicator: BoxDecoration(
                                color: Color.alphaBlend(
                                  theme.primary.withValues(alpha: 0.14),
                                  theme.card,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelColor: theme.text,
                              unselectedLabelColor: theme.muted,
                              labelPadding: EdgeInsets.symmetric(
                                horizontal: scrollTabs ? 10 : 2,
                              ),
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                              tabs: [
                                for (final tab in BookingDetailTab.values)
                                  Tab(
                                    height:
                                        48 *
                                        MediaQuery.textScalerOf(
                                          context,
                                        ).scale(1),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(tab.icon, size: 16),
                                        const SizedBox(height: 3),
                                        Text(tab.label, maxLines: 1),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, child) => IndexedStack(
                index: controller.index,
                children: [
                  for (final tab in BookingDetailTab.values)
                    ExcludeFocus(
                      excluding: tab.index != controller.index,
                      child: SingleChildScrollView(
                        key: PageStorageKey(tab),
                        controller: tab == BookingDetailTab.overview
                            ? overviewController
                            : null,
                        primary: false,
                        padding: EdgeInsets.fromLTRB(
                          MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
                          20,
                          MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
                          32,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1040),
                            child: pages[tab.index],
                          ),
                        ),
                      ),
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

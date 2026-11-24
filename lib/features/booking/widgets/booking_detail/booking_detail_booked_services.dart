import 'package:flutter/material.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

import 'booking_detail_explanations.dart';
import 'booking_detail_ui.dart';
import 'booking_detail_view_data.dart';

class BookingDetailBookedServices extends StatelessWidget {
  const BookingDetailBookedServices({super.key, required this.view});
  final BookingDetailViewData view;

  @override
  Widget build(BuildContext context) {
    final addons = SafeParse.parseMapList(view.raw['addons']);
    final theme = BookingDetailUi.of(context);
    return BookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BookingDetailSectionTitle('本次預約的加購服務'),
          const SizedBox(height: 12),
          if (addons.isEmpty) const Text('這筆訂單沒有加購服務紀錄。'),
          for (final addon in addons) ...[
            Builder(
              builder: (context) {
                final name = SafeParse.parseString(addon['name']).trim();
                final details = addonExplanation(
                  addon,
                  view.pets,
                  schedules: true,
                  includePetSchedule: false,
                );
                final schedules = addonPetSchedules(addon, view.pets);
                final count = SafeParse.parseMoney(
                  addon['count'] ?? addon['quantity'] ?? 1,
                );
                final amount = SafeParse.parseMoney(
                  addon['total'] ??
                      addon['amount'] ??
                      SafeParse.parseMoney(addon['price']) * count,
                );
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    key: PageStorageKey((
                      'booked-addon',
                      view.docId,
                      addons.indexOf(addon),
                    )),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      name.isEmpty ? '加購服務' : name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                      ),
                    ),
                    subtitle: Text(
                      'NT\$ $amount',
                      style: TextStyle(color: theme.muted, fontSize: 13),
                    ),
                    children: [
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          details,
                          style: TextStyle(color: theme.text, height: 1.65),
                        ),
                      ],
                      for (final schedule in schedules) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.card,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.pets_outlined,
                                    size: 15,
                                    color: theme.text,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      schedule.name,
                                      style: TextStyle(
                                        color: theme.text,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              for (final time in schedule.times)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    left: 23,
                                  ),
                                  child: Text(
                                    time,
                                    style: TextStyle(
                                      color: theme.muted,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

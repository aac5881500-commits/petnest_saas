import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:flutter/material.dart';
import 'booking_editorial_design.dart';
import 'booking_appearance_scope.dart';

class BookingEditorialArrival extends StatelessWidget {
  const BookingEditorialArrival({
    super.key,
    required this.shopName,
    required this.coverUrl,
    required this.dateSection,
    required this.petsSection,
    required this.campaign,
    required this.dateLabel,
    required this.hasDates,
    required this.petCount,
  });
  final String shopName, coverUrl, dateLabel;
  final Widget dateSection, petsSection, campaign;
  final bool hasDates;
  final int petCount;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          height: 210,
          child: Stack(
            fit: StackFit.expand,
            children: [
              BookingAppearanceScope.of(context).heroImage.isEmpty ||
                      BookingAppearanceScope.of(
                        context,
                      ).heroImage.startsWith('assets/')
                  ? Image.asset(
                      BookingAppearanceScope.of(
                            context,
                          ).heroImage.startsWith('assets/')
                          ? BookingAppearanceScope.of(context).heroImage
                          : BookingPageAppearance.defaultHero,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      BookingAppearanceScope.of(context).heroImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stack) => Image.asset(
                        BookingAppearanceScope.of(
                              context,
                            ).heroImage.startsWith('assets/')
                            ? BookingAppearanceScope.of(context).heroImage
                            : BookingPageAppearance.defaultHero,
                        fit: BoxFit.cover,
                      ),
                    ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'A LITTLE GETAWAY',
                      style: TextStyle(
                        color: Colors.white,
                        letterSpacing: 1.5,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '讓牠，也放個假。',
                      style: BookingEditorial.title(
                        22,
                      ).copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      shopName,
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      BookingEditorial.heading('選擇住宿日期', subtitle: '先選入住與退房日期，再安排入住貓咪。'),
      dateSection,
      Divider(
        color: BookingEditorial.theme(context).cardBorderColor,
        height: 24,
      ),
      petsSection,
      if (hasDates) ...[
        const SizedBox(height: 10),
        BookingEditorial.trip('$dateLabel · $petCount 隻'),
      ],
      BookingEditorialReminder(
        title: BookingAppearanceScope.of(context).reminderTitle,
        note: BookingAppearanceScope.of(context).note,
      ),
      campaign,
    ],
  );
}

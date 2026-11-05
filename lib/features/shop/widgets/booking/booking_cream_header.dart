import 'package:flutter/material.dart';
import 'booking_editorial_design.dart';

class BookingCreamHeader extends StatelessWidget {
  const BookingCreamHeader({
    super.key,
    required this.shopName,
    required this.step,
    this.title = '貓咪旅宿預約',
    this.subtitle = '讓貓咪在旅途中，也有安心的家',
  });
  final String shopName, title, subtitle;
  final int step;
  @override
  Widget build(BuildContext context) {
    final t = BookingEditorial.theme(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: BookingEditorial.tint(context),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    shopName,
                    style: BookingEditorial.title(23, context),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: t.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$step / 3',
                    style: BookingEditorial.body(12, context),
                  ),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: step == 1 ? 2.7 : 3.8,
            child: Image.asset(
              'assets/images/booking_cream_hero_v1.png',
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: BookingEditorial.title(step == 1 ? 28 : 25, context),
                ),
                const SizedBox(height: 5),
                Text(subtitle, style: BookingEditorial.body(13, context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

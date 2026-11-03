import 'package:flutter/material.dart';
import 'booking_arrival_preview.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';

class BookingQuickTemplateCard extends StatelessWidget {
  const BookingQuickTemplateCard({
    super.key,
    required this.style,
    required this.selected,
    required this.onApply,
    this.compact = false,
  });
  final String style;
  final bool selected, compact;
  final VoidCallback? onApply;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFF0F8FF) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected ? const Color(0xFF4E9BD1) : const Color(0xFFE0E6EB),
        width: selected ? 2 : 1,
      ),
    ),
    child: InkWell(
      onTap: onApply,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: compact ? 64 : 94,
                child: style == 'cream'
                    ? Image.asset(
                        'assets/images/booking_cream_hero_v1.png',
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : style == 'house'
                    ? Container(
                        color: const Color(0xFFDDEEF9),
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: Container(
                            width: 120,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF8EF),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(34),
                                bottom: Radius.circular(6),
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.home_outlined,
                                  color: Color(0xFF6AA1C7),
                                  size: 22,
                                ),
                                SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.pets,
                                      size: 13,
                                      color: Color(0xFF9CB8CE),
                                    ),
                                    SizedBox(width: 18),
                                    Icon(
                                      Icons.pets,
                                      size: 13,
                                      color: Color(0xFF9CB8CE),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.fill,
                        child: SizedBox(
                          width: 180,
                          child: BookingLayoutThumbnail(style: style),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    BookingPageAppearance.styles[style]!,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 14 : 15,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF4E9BD1),
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                BookingPageAppearance.descriptions[style]!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF63707B),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: onApply,
              child: Text(selected ? '已選用' : '選用模板', maxLines: 1),
            ),
          ],
        ),
      ),
    ),
  );
}

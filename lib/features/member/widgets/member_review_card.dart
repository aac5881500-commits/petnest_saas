// 會員評價卡：單層卡片，不嵌套 ReviewCard。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/booking/pages/booking_review_page.dart';
import 'package:petnest_saas/features/booking/widgets/review_rating_stars.dart';
import 'package:petnest_saas/features/member/widgets/member_section_card.dart';
import 'package:petnest_saas/features/member/widgets/member_status_chip.dart';
import 'package:petnest_saas/features/member/widgets/member_ui_tokens.dart';

class MemberReviewCard extends StatelessWidget {
  const MemberReviewCard({
    super.key,
    required this.review,
    required this.raw,
    required this.shopName,
  });

  final ReviewModel review;
  final Map<String, dynamic> raw;
  final String shopName;

  @override
  Widget build(BuildContext context) {
    final bool isDaycare = BookingKind.isDaycare(raw);
    final String stayLabel = isDaycare ? '安親評價' : '住宿評價';
    final String dateRange = _dateRange();
    final String duration = _durationLabel(isDaycare);

    return MemberSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  shopName.trim().isEmpty ? '店家' : shopName.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: MemberUi.cardTitleSize,
                    fontWeight: FontWeight.w700,
                    color: MemberUi.of(context).text,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_horiz, color: MemberUi.of(context).muted),
                onSelected: (String value) {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => BookingReviewPage(
                          bookingId: review.bookingId,
                          review: review,
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (BuildContext context) {
                  return const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'edit', child: Text('修改評價')),
                  ];
                },
              ),
            ],
          ),
          Row(
            children: <Widget>[
              ReviewRatingStars(value: review.rating, size: 16),
              const SizedBox(width: 6),
              Text(
                '${review.rating}.0',
                style: TextStyle(
                  fontSize: MemberUi.bodySize,
                  fontWeight: FontWeight.w700,
                  color: MemberUi.of(context).text,
                ),
              ),
              const Spacer(),
              Text(
                _createdText(),
                style: TextStyle(
                  fontSize: MemberUi.captionSize,
                  color: MemberUi.of(context).muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              MemberStatusChip(label: stayLabel, tone: MemberChipTone.primary),
              if (review.roomTypeName.trim().isNotEmpty)
                _infoChip(context, review.roomTypeName.trim()),
              if (dateRange.isNotEmpty) _infoChip(context, dateRange),
              if (duration.isNotEmpty) _infoChip(context, duration),
            ],
          ),
          if (review.content.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              review.content.trim(),
              style: TextStyle(
                fontSize: MemberUi.bodySize,
                height: 1.5,
                color: MemberUi.of(context).text,
              ),
            ),
          ],
          if (review.imageUrls.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.imageUrls.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int index) {
                  final String url = review.imageUrls[index];
                  return GestureDetector(
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (
                                    BuildContext context,
                                    Object error,
                                    StackTrace? stackTrace,
                                  ) {
                                    return const SizedBox(
                                      height: 120,
                                      child: Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                    );
                                  },
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        url,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (
                              BuildContext context,
                              Object error,
                              StackTrace? stackTrace,
                            ) {
                              return Container(
                                width: 80,
                                height: 80,
                                color: MemberUi.of(context).iconSoft,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: MemberUi.of(context).muted,
                                ),
                              );
                            },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _createdText() {
    final DateTime? date = review.createdAt?.toDate();
    if (date == null) {
      return '';
    }
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _dateRange() {
    final DateTime? start = review.startDate?.toDate();
    final DateTime? end = review.endDate?.toDate();
    if (start == null) {
      return '';
    }
    final String startText =
        '${start.month.toString().padLeft(2, '0')}/${start.day.toString().padLeft(2, '0')}';
    if (end == null) {
      return startText;
    }
    return '$startText ～ ${end.month.toString().padLeft(2, '0')}/${end.day.toString().padLeft(2, '0')}';
  }

  String _durationLabel(bool isDaycare) {
    if (isDaycare) {
      final DateTime? start = review.startDate?.toDate();
      final DateTime? end = review.endDate?.toDate();
      if (start == null || end == null) {
        return '';
      }
      final int days =
          DateTime(
            end.year,
            end.month,
            end.day,
          ).difference(DateTime(start.year, start.month, start.day)).inDays +
          1;
      return '${days < 1 ? 1 : days} 天';
    }
    final int nights = SafeParse.parseMoney(raw['nights']);
    if (nights > 0) {
      return '$nights 晚';
    }
    if (review.nights > 0) {
      return '${review.nights} 晚';
    }
    return '';
  }

  Widget _infoChip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDE6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: MemberUi.of(context).muted),
      ),
    );
  }
}

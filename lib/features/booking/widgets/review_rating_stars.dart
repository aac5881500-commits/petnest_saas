// lib/features/booking/widgets/review_rating_stars.dart
// ⭐ 評價星星元件
// 功能：顯示或選擇 1~5 顆星，可用於評價表單與評價列表

import 'package:flutter/material.dart';

class ReviewRatingStars extends StatelessWidget {
  const ReviewRatingStars({
    super.key,
    required this.value,
    this.size = 24,
    this.editable = false,
    this.onChanged,
  });

  final int value;
  final double size;
  final bool editable;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final selected = starValue <= value;

        return InkWell(
          onTap: editable ? () => onChanged?.call(starValue) : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              selected ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: size,
            ),
          ),
        );
      }),
    );
  }
}

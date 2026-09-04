// lib/features/shop/widgets/media/fixed_image_spec_hint.dart
// 固定版型圖片上傳區說明文字。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';

class FixedImageSpecHint extends StatelessWidget {
  const FixedImageSpecHint({super.key, required this.spec});

  final FixedImageSpec spec;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        spec.hintText,
        style: TextStyle(
          fontSize: 12,
          height: 1.35,
          color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
        ),
      ),
    );
  }
}

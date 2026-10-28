import 'package:flutter/material.dart';

/// A clearly named destination, distinct from returning within a shop module.
class ShopPlatformHomeButton extends StatelessWidget {
  const ShopPlatformHomeButton({
    super.key,
    required this.onPressed,
    this.compact = false,
  });
  final VoidCallback onPressed;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        tooltip: '回平台首頁',
        onPressed: onPressed,
        icon: const Icon(Icons.home_outlined),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.home_outlined),
        label: const Text('回平台首頁'),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Keeps preview sheets and barriers inside the preview, independently of admin navigation.
class HomePreviewNavigator extends StatelessWidget {
  const HomePreviewNavigator({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: Navigator(
      pages: [
        MaterialPage<void>(
          key: const ValueKey('home-preview-local-route'),
          child: child,
        ),
      ],
      onDidRemovePage: (_) {},
    ),
  );
}

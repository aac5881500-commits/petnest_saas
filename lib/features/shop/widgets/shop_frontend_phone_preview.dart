// 檔案名稱：lib/features/shop/widgets/shop_frontend_phone_preview.dart
// 功能說明：Dashboard 內嵌正式前台的 430×932 等比例手機框，不含假狀態列。

import 'dart:math' as math;

import 'package:flutter/material.dart';

class ShopFrontendPhoneSize {
  const ShopFrontendPhoneSize({
    required this.id,
    required this.label,
    required this.size,
  });

  final String id;
  final String label;
  final Size size;

  static const ShopFrontendPhoneSize large = ShopFrontendPhoneSize(
    id: 'large',
    label: '大手機',
    size: Size(430, 932),
  );

  static const ShopFrontendPhoneSize live = large;
}

class ShopFrontendPhoneFrame extends StatelessWidget {
  const ShopFrontendPhoneFrame({
    super.key,
    required this.logicalSize,
    required this.child,
    this.onScrollMetrics,
  });

  static const Size liveLogicalSize = Size(430, 932);

  final Size logicalSize;
  final Widget child;
  final ValueChanged<ScrollMetrics>? onScrollMetrics;

  static double scaleFor({
    required double availableWidth,
    required double availableHeight,
    Size logicalSize = liveLogicalSize,
  }) {
    if (logicalSize.height <= 0 || logicalSize.width <= 0) {
      return 1;
    }
    return math.min(
      1,
      math.min(
        availableHeight / logicalSize.height,
        availableWidth / logicalSize.width,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size logical = logicalSize;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double scale = scaleFor(
          availableWidth: constraints.maxWidth,
          availableHeight: constraints.maxHeight,
          logicalSize: logical,
        );
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: logical.width * scale,
            height: logical.height * scale,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: logical.width,
                height: logical.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFD7DEE8)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: logical,
                        padding: EdgeInsets.zero,
                        viewPadding: EdgeInsets.zero,
                        viewInsets: EdgeInsets.zero,
                        textScaler: const TextScaler.linear(1.0),
                      ),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification notification) {
                          if (notification.metrics.axis != Axis.vertical) {
                            return false;
                          }
                          onScrollMetrics?.call(notification.metrics);
                          return false;
                        },
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

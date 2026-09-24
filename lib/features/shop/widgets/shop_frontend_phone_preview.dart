// 檔案名稱：lib/features/shop/widgets/shop_frontend_phone_preview.dart
// 功能說明：以固定手機寬度渲染前台後再等比例縮小，避免左欄把版面重排。

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
    size: Size(ShopFrontendPhoneFrame.liveLogicalWidth, 844),
  );

  static const ShopFrontendPhoneSize live = large;
}

class ShopFrontendPhoneFrame extends StatelessWidget {
  const ShopFrontendPhoneFrame({
    super.key,
    required this.child,
    this.logicalWidth = liveLogicalWidth,
    this.scaleToFit = true,
    this.onScrollMetrics,
  });

  /// 與直接開啟客戶前台時的手機版寬度對齊。
  static const double liveLogicalWidth = 500;

  static const Size liveLogicalSize = Size(liveLogicalWidth, 844);

  final double logicalWidth;
  final bool scaleToFit;
  final Widget child;
  final ValueChanged<ScrollMetrics>? onScrollMetrics;

  static double scaleFor({
    required double availableWidth,
    required double availableHeight,
    Size logicalSize = liveLogicalSize,
  }) {
    if (logicalSize.width <= 0) {
      return 1;
    }
    return math.min(1, availableWidth / logicalSize.width);
  }

  Widget _wrapMedia({
    required BuildContext context,
    required Size canvas,
    required Widget child,
  }) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: canvas,
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
    );
  }

  Widget _canvasShell({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7DEE8)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : logicalWidth;
        final double availH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : liveLogicalSize.height;
        if (!scaleToFit) {
          final double canvasW = math.min(logicalWidth, availW);
          final Size canvas = Size(canvasW, availH);
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: canvasW,
              height: availH,
              child: _canvasShell(
                child: _wrapMedia(
                  context: context,
                  canvas: canvas,
                  child: child,
                ),
              ),
            ),
          );
        }

        final double scale = math.min(1, availW / logicalWidth);
        final double displayW = logicalWidth * scale;
        final double canvasH = scale <= 0 ? availH : availH / scale;
        final Size canvas = Size(logicalWidth, canvasH);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: displayW,
            height: availH,
            child: ClipRect(
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: logicalWidth,
                  maxWidth: logicalWidth,
                  minHeight: canvasH,
                  maxHeight: canvasH,
                  child: SizedBox(
                    width: logicalWidth,
                    height: canvasH,
                    child: _canvasShell(
                      child: _wrapMedia(
                        context: context,
                        canvas: canvas,
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

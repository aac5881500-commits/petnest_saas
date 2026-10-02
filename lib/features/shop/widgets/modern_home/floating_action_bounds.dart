import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 店家選單與聯絡店家共用的浮動安全範圍。
class FloatingActionBounds {
  const FloatingActionBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  static const double edge = 12;
  static const double safeBottomGap = 16;
  static const double peerGap = 12;
  static const double dragSlop = 8;

  static FloatingActionBounds resolve({
    required Size size,
    required EdgeInsets padding,
    required double headerHeight,
    required bool showBottomBar,
    required double bottomBarHeight,
    required Size buttonSize,
  }) {
    final double minX = edge;
    final double rawMaxX = size.width - buttonSize.width - edge;
    final double maxX = rawMaxX < minX ? minX : rawMaxX;
    final double minY = padding.top + headerHeight + edge;
    final double occupiedBottom = showBottomBar
        ? bottomBarHeight + edge
        : padding.bottom + safeBottomGap;
    final double rawMaxY = size.height - occupiedBottom - buttonSize.height;
    final double maxY = rawMaxY < minY ? minY : rawMaxY;
    return FloatingActionBounds(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
    );
  }

  Offset clampPoint(Offset topLeft) {
    return Offset(_clamp(topLeft.dx, minX, maxX), _clamp(topLeft.dy, minY, maxY));
  }

  double normX(double x) {
    final double span = maxX - minX;
    if (span <= 0) {
      return 0;
    }
    return _clamp((x - minX) / span, 0, 1);
  }

  double normY(double y) {
    final double span = maxY - minY;
    if (span <= 0) {
      return 0;
    }
    return _clamp((y - minY) / span, 0, 1);
  }

  double denormX(double nx) => minX + (maxX - minX) * _clamp(nx, 0, 1);

  double denormY(double ny) => minY + (maxY - minY) * _clamp(ny, 0, 1);

  /// 放開後吸附左或右緣，垂直位置保留，並與另一顆按鈕保持間距。
  Offset placeOnRelease(
    Offset topLeft,
    Size button, {
    Rect? peer,
    bool preferLeft = true,
  }) {
    final Offset clamped = clampPoint(topLeft);
    final double center = clamped.dx + button.width / 2;
    final double mid = (minX + maxX) / 2;
    double x = center <= mid ? minX : maxX;
    double y = clamped.dy;
    if (peer != null && _tooClose(Rect.fromLTWH(x, y, button.width, button.height), peer)) {
      x = preferLeft ? minX : maxX;
      Rect mine = Rect.fromLTWH(x, y, button.width, button.height);
      if (_tooClose(mine, peer)) {
        final double above = peer.top - peerGap - button.height;
        final double below = peer.bottom + peerGap;
        if (above >= minY) {
          y = above;
        } else if (below <= maxY) {
          y = below;
        }
        y = _clamp(y, minY, maxY);
        mine = Rect.fromLTWH(x, y, button.width, button.height);
        if (_tooClose(mine, peer) && preferLeft && maxX > minX) {
          x = maxX;
        } else if (_tooClose(mine, peer) && !preferLeft && maxX > minX) {
          x = minX;
        }
      }
    }
    return Offset(_clamp(x, minX, maxX), _clamp(y, minY, maxY));
  }

  bool _tooClose(Rect mine, Rect peer) {
    return mine.overlaps(peer.inflate(peerGap));
  }

  static double _clamp(double value, double min, double max) {
    if (max < min) {
      return min;
    }
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }
}

/// 各使用者、各店家的店家選單位置。存在本機，不寫入店家外觀。
class ShopMenuPositionStore {
  static String keyFor(String shopId, String userId) {
    return 'frontend_shop_menu_pos_${shopId}_$userId';
  }

  static Future<Offset?> load(String shopId, String userId) async {
    if (shopId.isEmpty || userId.isEmpty) {
      return null;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String key = keyFor(shopId, userId);
      final double? x = prefs.getDouble('${key}_x');
      final double? y = prefs.getDouble('${key}_y');
      if (x == null || y == null) {
        return null;
      }
      return Offset(x, y);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String shopId, String userId, double nx, double ny) async {
    if (shopId.isEmpty || userId.isEmpty) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String key = keyFor(shopId, userId);
      await prefs.setDouble('${key}_x', nx);
      await prefs.setDouble('${key}_y', ny);
    } catch (_) {
      return;
    }
  }
}

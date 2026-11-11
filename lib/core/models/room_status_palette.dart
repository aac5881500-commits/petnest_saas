import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../presentation/room_status_presentation.dart';

/// Shop-specific display preferences only. Keys never change booking/room state.
@immutable
class RoomStatusPalette {
  const RoomStatusPalette._(this._colors);
  static const defaults = RoomStatusPalette._({});
  final Map<String, int> _colors;
  static const defaultColors = <String, int>{
    'available': 0xFF2E7D32,
    'occupied': 0xFFC62828,
    'daycare': 0xFF5E35B1,
    'checked_in': 0xFF1565C0,
    'completed': 0xFF00695C,
    'checkout_cleaning': 0xFF827717,
    'cleaning': 0xFFEF6C00,
    'closed': 0xFF6D4C41,
    'maintenance': 0xFF424242,
    'disabled': 0xFF607D8B,
    'history': 0xFFBDBDBD,
  };
  static const labels = <String, String>{
    'available': '空房',
    'occupied': '住宿',
    'daycare': '安親',
    'checked_in': '入住中',
    'completed': '退房／完成',
    'checkout_cleaning': '待清潔',
    'cleaning': '清潔中',
    'closed': '今日關閉',
    'maintenance': '維修中',
    'disabled': '未啟用',
    'history': '歷史日期',
  };
  static String canonicalKey(String key) =>
      key == 'daycare_checked_in' ? 'daycare' : key;
  Color color(String key) {
    final resolved = canonicalKey(key);
    return Color(
      _colors[resolved] ??
          defaultColors[resolved] ??
          defaultColors['available']!,
    );
  }

  String hex(String key) =>
      '#${(color(key).toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  factory RoomStatusPalette.fromMap(Object? raw) {
    if (raw is! Map) return defaults;
    final colors = <String, int>{};
    for (final key in defaultColors.keys) {
      final value = raw[key];
      int? parsed;
      if (value is int && value >= 0 && value <= 0xFFFFFFFF) parsed = value;
      if (value is String &&
          RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(value.trim())) {
        parsed = int.tryParse(value.trim().replaceFirst('#', ''), radix: 16);
      }
      if (parsed != null) colors[key] = 0xFF000000 | (parsed & 0xFFFFFF);
    }
    return RoomStatusPalette._(Map.unmodifiable(colors));
  }
  RoomStatusPalette withColor(String key, Color value) {
    final resolved = canonicalKey(key);
    if (!defaultColors.containsKey(resolved)) return this;
    return RoomStatusPalette._(
      Map.unmodifiable({
        ..._colors,
        resolved: 0xFF000000 | (value.toARGB32() & 0xFFFFFF),
      }),
    );
  }

  RoomStatusPalette reset(String key) {
    final colors = Map<String, int>.from(_colors)..remove(canonicalKey(key));
    return RoomStatusPalette._(Map.unmodifiable(colors));
  }

  Map<String, dynamic> toMap() => {
    for (final key in defaultColors.keys) key: hex(key),
  };
  RoomStatusPresentation apply(RoomStatusPresentation original) {
    final resolved = color(original.value);
    return RoomStatusPresentation(
      value: original.value,
      label: original.label,
      icon: original.icon,
      color: resolved,
      background: resolved.withValues(alpha: .12),
      border: resolved.withValues(alpha: .35),
    );
  }

  List<RoomStatusPresentation> legendItems() =>
      RoomStatusPresentation.legendItems().map(apply).toList();
  @override
  bool operator ==(Object other) =>
      other is RoomStatusPalette && mapEquals(toMap(), other.toMap());
  @override
  int get hashCode =>
      Object.hashAll(defaultColors.keys.map((key) => color(key).toARGB32()));
}

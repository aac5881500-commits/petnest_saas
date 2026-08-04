// lib/core/models/home_text_style_model.dart
// 🎨 首頁共用文字樣式 Model
// 功能：統一管理 Classic、Modern 首頁可自訂文字的大小、顏色、粗體、陰影與對齊方式

import 'package:flutter/material.dart';

class HomeTextStyleModel {
  const HomeTextStyleModel({
    required this.fontSize,
    required this.colorValue,
    required this.isBold,
    required this.hasShadow,
    required this.alignment,
  });

  final double fontSize;
  final int colorValue;
  final bool isBold;
  final bool hasShadow;
  final String alignment;

  Color get color => Color(colorValue);

  FontWeight get fontWeight {
    return isBold ? FontWeight.bold : FontWeight.normal;
  }

  TextAlign get textAlign {
    switch (alignment) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
      default:
        return TextAlign.center;
    }
  }

  List<Shadow>? get shadows {
    if (!hasShadow) {
      return null;
    }

    return const <Shadow>[
      Shadow(blurRadius: 6, offset: Offset(0, 2), color: Color(0x99000000)),
    ];
  }

  TextStyle toTextStyle({String? fontFamily, double? defaultHeight}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: defaultHeight,
      color: color,
      fontWeight: fontWeight,
      shadows: shadows,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'fontSize': fontSize,
      'color': colorValue,
      'isBold': isBold,
      'hasShadow': hasShadow,
      'alignment': alignment,
    };
  }

  factory HomeTextStyleModel.fromMap(
    dynamic rawData, {
    required HomeTextStyleModel fallback,
  }) {
    if (rawData is! Map) {
      return fallback;
    }

    final map = Map<String, dynamic>.from(rawData);

    return HomeTextStyleModel(
      fontSize: _readDouble(map['fontSize'], fallback.fontSize),
      colorValue: _readColorValue(map['color'], fallback.colorValue),
      isBold: map['isBold'] is bool ? map['isBold'] as bool : fallback.isBold,
      hasShadow: map['hasShadow'] is bool
          ? map['hasShadow'] as bool
          : fallback.hasShadow,
      alignment: _readAlignment(map['alignment'], fallback.alignment),
    );
  }

  HomeTextStyleModel copyWith({
    double? fontSize,
    int? colorValue,
    bool? isBold,
    bool? hasShadow,
    String? alignment,
  }) {
    return HomeTextStyleModel(
      fontSize: fontSize ?? this.fontSize,
      colorValue: colorValue ?? this.colorValue,
      isBold: isBold ?? this.isBold,
      hasShadow: hasShadow ?? this.hasShadow,
      alignment: alignment ?? this.alignment,
    );
  }

  static double _readDouble(dynamic value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _readColorValue(dynamic value, int fallback) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String _readAlignment(dynamic value, String fallback) {
    final alignment = value?.toString();

    if (alignment == 'left' || alignment == 'center' || alignment == 'right') {
      return alignment!;
    }

    return fallback;
  }
}

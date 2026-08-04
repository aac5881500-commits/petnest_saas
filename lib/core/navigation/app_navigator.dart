// lib/core/navigation/app_navigator.dart
// 🧭 App 全域導航管理
// 功能：提供全域 NavigatorKey，讓推播通知可在沒有 BuildContext 時導向頁面

import 'package:flutter/material.dart';

class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static NavigatorState? get state {
    return key.currentState;
  }

  static BuildContext? get context {
    return key.currentContext;
  }
}

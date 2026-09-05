// 檔案名稱：lib/core/navigation/app_navigator.dart
// 功能說明：提供全域 NavigatorKey，讓推播通知可在沒有 BuildContext 時導向頁面
// 🧭 App 全域導航管理

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

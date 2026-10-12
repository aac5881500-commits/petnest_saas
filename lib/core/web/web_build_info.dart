// 檔案名稱：lib/core/web/web_build_info.dart
// 功能說明：描述一次 Web 部署的版本，以及和本機程式比對後的結果。

import 'dart:convert';

class WebBuildInfo {
  const WebBuildInfo({required this.buildId, required this.builtAt});

  final String buildId;
  final String builtAt;
}

enum WebUpdatePhase {
  idle,
  checking,
  current,
  updateAvailable,
  failed,
  development,
}

/// 只接受含有部署識別碼的內容。Flutter 內建的 pubspec 版號檔不算新版本。
WebBuildInfo? parseWebBuildInfo(String body) {
  try {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final Object? buildId = decoded['buildId'];
    final Object? builtAt = decoded['builtAt'];
    if (buildId is! String || buildId.isEmpty) return null;
    return WebBuildInfo(
      buildId: buildId,
      builtAt: builtAt is String ? builtAt : '',
    );
  } catch (_) {
    return null;
  }
}

bool tracksWebDeployment(String buildId) {
  return buildId.isNotEmpty && buildId != 'dev';
}

String webUpdatePhaseLabel(WebUpdatePhase phase) {
  switch (phase) {
    case WebUpdatePhase.idle:
      return '尚未檢查';
    case WebUpdatePhase.checking:
      return '正在檢查更新';
    case WebUpdatePhase.current:
      return '已是最新版本';
    case WebUpdatePhase.updateAvailable:
      return '發現新版本';
    case WebUpdatePhase.failed:
      return '檢查失敗，請稍後再試';
    case WebUpdatePhase.development:
      return '這是本機開發版本，不會和正式網站比較';
  }
}

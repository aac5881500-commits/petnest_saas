// 檔案名稱：lib/core/legal_pet/directory_load_gate.dart
// 功能說明：業者名單的查詢序號、版本判斷與同步標題。

const int requiredDirectoryApiVersion = 3;

const String staleDirectoryBackendMessage =
    '後端版本尚未更新，請部署業者資料庫相關 Functions';

class DirectoryLoadGate {
  int _latest = 0;

  int issue() => ++_latest;

  bool isCurrent(int id) => id == _latest;
}

class DirectoryResponseDecision {
  const DirectoryResponseDecision({
    required this.acceptItems,
    required this.stale,
  });

  final bool acceptItems;
  final bool stale;
}

DirectoryResponseDecision decideDirectoryResponse({
  required int apiVersion,
  required bool constrained,
}) {
  if (apiVersion >= requiredDirectoryApiVersion) {
    return const DirectoryResponseDecision(acceptItems: true, stale: false);
  }
  return DirectoryResponseDecision(acceptItems: !constrained, stale: true);
}

String directorySyncHeadline({
  required String phase,
  required String successText,
  required bool hasItems,
}) {
  final success = successText.isEmpty ? '' : '最後成功同步：$successText';
  if (phase == 'running') {
    return success.isEmpty ? '同步中' : '$success　同步中';
  }
  if (phase == 'failed') {
    return success.isEmpty ? '同步失敗' : '$success　同步失敗';
  }
  if (phase == 'success') {
    return success.isEmpty ? '政府資料已同步' : success;
  }
  if (hasItems || success.isNotEmpty) {
    return success.isEmpty ? '政府資料已載入' : success;
  }
  if (phase == 'never') return '尚未同步政府資料';
  return '同步狀態無法確認';
}

class DirectoryListController {
  final DirectoryLoadGate gate = DirectoryLoadGate();
  int pageIndex = 0;
  List<String> cursors = [''];
  String? selectedId;
  bool loading = false;

  int issue() => gate.issue();

  bool isCurrent(int id) => gate.isCurrent(id);

  void beginRequest({required bool resetPage}) {
    loading = true;
    if (!resetPage) return;
    pageIndex = 0;
    cursors = [''];
    selectedId = null;
  }
}

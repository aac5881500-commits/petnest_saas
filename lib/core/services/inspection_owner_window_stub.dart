Future<void> openInspectionOwnerWindow({
  required Future<Map<String, dynamic>> Function(String) authorize,
  required Future<void> Function(String) onTouch,
  required void Function(Object) onFailure,
  required bool Function() isAlive,
}) async {
  throw UnsupportedError('完整唯讀後台請使用瀏覽器開啟');
}

void closeInspectionOwnerWindow() {}

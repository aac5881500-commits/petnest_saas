/// Translate transport failures without presenting bare SDK codes as a message.
String inspectionErrorMessage(String code, String? message) {
  if (code == 'internal' || code == 'unknown') {
    return '查核服務目前無法連線。請平台確認 inspectShop 已部署於 asia-east1，並檢查後端紀錄。';
  }
  if (code == 'not-found') return '查核驗證服務尚未啟用，請平台更新部署 inspectShop。';
  final value = message?.trim() ?? '';
  if (value.isNotEmpty &&
      value.toLowerCase() != code.toLowerCase() &&
      RegExp(r'[\u4e00-\u9fff]').hasMatch(value)) {
    return value;
  }
  return switch (code) {
    'permission-denied' => '只有 APP 最高權限帳號可使用唯讀查核。',
    'unauthenticated' => '查核授權已失效，請重新取得驗證碼。',
    'resource-exhausted' => '驗證碼申請次數過多，請稍後再試。',
    'unavailable' => '查核或寄信服務暫時無法使用，請稍後再試。',
    'deadline-exceeded' => '查核服務回應逾時，請稍後再試。',
    _ => '查核服務暫時無法完成操作，請稍後再試。',
  };
}

// 檔案名稱：lib/core/models/policy_confirmation_status.dart
// 功能說明：用最新已發布版本與使用者已確認版本即時比對，不寫入會員資料

enum PolicyConfirmationState {
  /// 目前沒有已發布版本。
  noPublished,

  /// 沒有同意紀錄。
  notAccepted,

  /// 已確認的版本低於最新已發布版本。
  needsUpdate,

  /// 已確認版本等於最新已發布版本。
  current,
}

int parsePolicyConfirmationVersion(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString().trim() ?? '') ?? 0;
}

PolicyConfirmationState resolvePolicyConfirmation({
  required int? publishedVersion,
  required int? acceptedVersion,
}) {
  final int published = publishedVersion ?? 0;
  final int accepted = acceptedVersion ?? 0;
  if (published <= 0) return PolicyConfirmationState.noPublished;
  if (accepted <= 0) return PolicyConfirmationState.notAccepted;
  if (accepted == published) return PolicyConfirmationState.current;
  return PolicyConfirmationState.needsUpdate;
}

String policyConfirmationLabel(PolicyConfirmationState state) {
  switch (state) {
    case PolicyConfirmationState.noPublished:
      return '目前沒有已發布平台條款';
    case PolicyConfirmationState.notAccepted:
      return '尚未確認';
    case PolicyConfirmationState.needsUpdate:
      return '待確認更新';
    case PolicyConfirmationState.current:
      return '已確認最新版';
  }
}

String policyVersionLabel(int version) {
  if (version <= 0) return '尚未確認';
  return 'v$version';
}

/// 已發布版本文件 ID。草稿不使用這個 ID，避免覆寫歷史版本。
String platformPolicyVersionDocId(int version) => 'v$version';

int nextPlatformPolicyVersion(int publishedVersion) {
  if (publishedVersion < 0) return 1;
  return publishedVersion + 1;
}

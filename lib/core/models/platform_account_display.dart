// 檔案名稱：lib/core/models/platform_account_display.dart
// 功能說明：依既有欄位決定可顯示的姓名、Email，以及業務身分錯誤文案。

class PlatformAccountDisplay {
  const PlatformAccountDisplay({required this.name, required this.email});

  final String name;
  final String email;

  static const String unset = '尚未設定';

  static PlatformAccountDisplay resolve({
    String? platformName,
    String? platformDisplayName,
    String? authDisplayName,
    String? profileName,
    String? authEmail,
    String? platformEmail,
    String? profileEmail,
    required String uid,
  }) {
    return PlatformAccountDisplay(
      name: _first(<String?>[
        platformName,
        platformDisplayName,
        authDisplayName,
        profileName,
      ]),
      email: _email(<String?>[
        authEmail,
        platformEmail,
        profileEmail,
      ], uid),
    );
  }

  static String describeSalesFailure({
    required String code,
    required String message,
    bool permissionDenied = false,
    bool notFound = false,
  }) {
    if (permissionDenied || code == 'permission-denied') {
      return '沒有查看或設定業務身分的權限。';
    }
    if (notFound || code == 'not-found') {
      return '業務身分服務尚未更新。需要部署 getSalesIdentity 與 setSalesIdentity。';
    }
    final String normalized = message.trim().toLowerCase();
    final bool opaque = code == 'internal' ||
        code == 'unavailable' ||
        code == 'unknown' ||
        normalized == 'internal' ||
        normalized == 'internal error' ||
        normalized.isEmpty;
    if (opaque) {
      return '無法讀取業務資料。業務身分服務尚未部署或呼叫失敗，需要部署 getSalesIdentity 與 setSalesIdentity。請稍後重試。';
    }
    if (_containsHan(message)) return message.trim();
    return '無法讀取業務資料，請重試。';
  }

  static String _first(List<String?> values) {
    for (final String? value in values) {
      final String text = (value ?? '').trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _email(List<String?> values, String uid) {
    for (final String? value in values) {
      final String text = (value ?? '').trim();
      if (text.isEmpty || text == uid || !text.contains('@')) continue;
      return text;
    }
    return '';
  }

  static bool _containsHan(String value) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(value);
  }
}

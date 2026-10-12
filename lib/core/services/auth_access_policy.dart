// 檔案名稱：lib/core/services/auth_access_policy.dart
// 功能說明：登入准入、信箱驗證、錯誤中文與會員欄位保護。不讀 Firestore 自訂驗證旗標。

import 'package:firebase_auth/firebase_auth.dart';

class AuthAccessPolicy {
  AuthAccessPolicy._();

  static const String passwordProvider = 'password';
  static const String googleProvider = 'google.com';
  static const String appleProvider = 'apple.com';
  static const Duration resendCooldown = Duration(seconds: 60);

  static const String resetSentMessage =
      '如果此電子郵件已註冊 PetNest，我們會寄送密碼重設連結，請查看收件匣或垃圾郵件。';
  static const String resetExpiredHint = '如果重設連結已過期或已使用，請重新輸入電子郵件再寄一次。';
  static const String emailNotVerifiedYet = '尚未完成電子郵件驗證，請先查看信箱。';
  static const String appleCredentialMessage =
      'Apple 登入驗證失敗，請稍後重試；若持續發生，請聯絡平台客服。';

  /// 只有「僅 Email／密碼、且 Firebase emailVerified 為 false」才要擋。
  /// 已連結 Google 或 Apple 的帳號不走寄信驗證。
  static bool mustVerifyEmail({
    required bool emailVerified,
    required Iterable<String> providerIds,
  }) {
    final Set<String> ids = providerIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
    if (ids.contains(googleProvider) || ids.contains(appleProvider)) {
      return false;
    }
    if (!ids.contains(passwordProvider)) {
      return false;
    }
    return !emailVerified;
  }

  static String? emailIssue(String raw) {
    final String email = raw.trim();
    if (email.isEmpty) {
      return '請輸入電子郵件。';
    }
    final bool ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!ok) {
      return '電子郵件格式不正確，請重新確認。';
    }
    return null;
  }

  static String? passwordIssue(String raw) {
    if (raw.trim().isEmpty) {
      return '請輸入密碼。';
    }
    return null;
  }

  static bool isCancelledCode(String code) {
    switch (code) {
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'canceled':
      case 'web-context-cancelled':
      case 'user-cancelled':
        return true;
      default:
        return false;
    }
  }

  /// 取消登入回傳 null，呼叫端不要顯示錯誤卡片。
  /// [appleSignIn] 只影響 Apple 流程的 invalid-credential，不改 Email／密碼文案。
  static String? messageFor(Object error, {bool appleSignIn = false}) {
    if (error is! FirebaseAuthException) {
      return '暫時無法完成操作，請稍後再試。';
    }
    if (isCancelledCode(error.code)) {
      return null;
    }
    switch (error.code) {
      case 'invalid-email':
        return '電子郵件格式不正確，請重新確認。';
      case 'invalid-credential':
        if (appleSignIn) {
          return appleCredentialMessage;
        }
        return '電子郵件或密碼不正確，請重新輸入。';
      case 'wrong-password':
      case 'user-not-found':
        return '電子郵件或密碼不正確，請重新輸入。';
      case 'email-already-in-use':
        return '此電子郵件已被使用，請直接登入或重設密碼。';
      case 'weak-password':
        return '密碼安全性不足，請設定更安全的密碼。';
      case 'user-disabled':
        return '此帳號目前無法使用，請聯絡客服。';
      case 'too-many-requests':
        return '嘗試次數過多，請稍後再試。';
      case 'network-request-failed':
        return '網路連線異常，請確認網路後重試。';
      case 'email-not-verified':
        return '請先完成電子郵件驗證，再登入 PetNest。';
      case 'popup-blocked':
        return '瀏覽器阻擋登入視窗，請允許彈出視窗後重試。';
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return '此電子郵件已使用其他登入方式註冊，請改用原本的方式登入。';
      case 'expired-action-code':
      case 'invalid-action-code':
        return '重設連結已過期或已使用，請重新申請密碼重設信。';
      case 'operation-not-allowed':
        return '此登入方式目前尚未開放，請稍後再試。';
      default:
        return '暫時無法完成操作，請稍後再試。';
    }
  }

  static Duration? resendWait({
    required DateTime? lastSent,
    required DateTime now,
    Duration cooldown = resendCooldown,
  }) {
    if (lastSent == null) {
      return null;
    }
    final Duration elapsed = now.difference(lastSent);
    if (elapsed >= cooldown) {
      return null;
    }
    final Duration left = cooldown - elapsed;
    if (left.inSeconds <= 0 && left.inMilliseconds <= 0) {
      return null;
    }
    return left;
  }

  /// 第二次登入沒有姓名或 Email 時，不寫入空白覆蓋既有資料。
  static Map<String, String> identityPatch({
    required String? email,
    required String? displayName,
  }) {
    final Map<String, String> patch = <String, String>{};
    final String mail = (email ?? '').trim();
    if (mail.isNotEmpty) {
      patch['email'] = mail;
    }
    final String name = (displayName ?? '').trim();
    if (name.isNotEmpty) {
      patch['displayName'] = name;
    }
    return patch;
  }

  static bool shouldCreateMemberRecord(bool exists) => !exists;

  /// Debug 用。去掉 Token、授權碼與過長內容，不回傳原始憑證。
  static String redactedAuthMessage(String? raw) {
    var text = (raw ?? '').trim();
    if (text.isEmpty) {
      return '';
    }
    text = text.replaceAllMapped(
      RegExp(
        r'(id_token|access_token|refresh_token|authorizationCode|idToken|code)=[^&\s]+',
        caseSensitive: false,
      ),
      (Match match) => '${match.group(1)}=[redacted]',
    );
    text = text.replaceAll(RegExp(r'ya29\.[A-Za-z0-9._\-]+'), '[redacted]');
    text = text.replaceAll(
      RegExp(r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+'),
      '[redacted]',
    );
    if (text.length > 180) {
      text = text.substring(0, 180);
    }
    return text;
  }

  /// Web 使用 Firebase OAuth popup；iOS／Android 使用原生 Provider。
  static bool useApplePopup({required bool isWeb}) => isWeb;
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/auth_access_policy.dart';

void main() {
  const String password = AuthAccessPolicy.passwordProvider;
  const String google = AuthAccessPolicy.googleProvider;
  const String apple = AuthAccessPolicy.appleProvider;

  group('EMAIL', () {
    test('EMAIL-1 未驗證的 Email 密碼帳號不得進入首頁', () {
      expect(
        AuthAccessPolicy.mustVerifyEmail(
          emailVerified: false,
          providerIds: <String>[password],
        ),
        isTrue,
      );
    });

    test('EMAIL-2 驗證完成後可以進入首頁', () {
      expect(
        AuthAccessPolicy.mustVerifyEmail(
          emailVerified: true,
          providerIds: <String>[password],
        ),
        isFalse,
      );
    });

    test('EMAIL-3 EMAIL-4 重新開啟或重新整理仍以 emailVerified 判斷', () {
      expect(
        AuthAccessPolicy.mustVerifyEmail(
          emailVerified: false,
          providerIds: <String>[password],
        ),
        isTrue,
      );
    });

    test('EMAIL-5 舊 Email 帳號未驗證仍可走補驗證，不因缺少其他 provider 放行', () {
      expect(
        AuthAccessPolicy.mustVerifyEmail(
          emailVerified: false,
          providerIds: <String>[password],
        ),
        isTrue,
      );
    });

    test('EMAIL-6 登入補資料不包含角色、電話、寵物', () {
      final Map<String, String> patch = AuthAccessPolicy.identityPatch(
        email: 'owner@petnest.app',
        displayName: '店主',
      );
      expect(patch.keys, <String>['email', 'displayName']);
      expect(patch.containsKey('role'), isFalse);
      expect(patch.containsKey('phone'), isFalse);
      expect(patch.containsKey('pets'), isFalse);
    });
  });

  group('APPLE', () {
    test('APPLE-1 首次登入才建立會員', () {
      expect(AuthAccessPolicy.shouldCreateMemberRecord(false), isTrue);
    });

    test('APPLE-2 再次登入不重複建立會員', () {
      expect(AuthAccessPolicy.shouldCreateMemberRecord(true), isFalse);
    });

    test('APPLE-3 隱藏 Email 格式可接受', () {
      expect(
        AuthAccessPolicy.emailIssue('abc123@privaterelay.appleid.com'),
        isNull,
      );
    });

    test('APPLE-4 第二次沒有姓名時不清空原本姓名', () {
      expect(
        AuthAccessPolicy.identityPatch(email: 'a@b.co', displayName: ''),
        <String, String>{'email': 'a@b.co'},
      );
      expect(
        AuthAccessPolicy.identityPatch(email: '  ', displayName: '  '),
        isEmpty,
      );
    });

    test('Apple invalid-credential 不顯示密碼錯誤', () {
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'invalid-credential'),
          appleSignIn: true,
        ),
        AuthAccessPolicy.appleCredentialMessage,
      );
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'popup-closed-by-user'),
          appleSignIn: true,
        ),
        isNull,
      );
    });

    test('Apple 隱藏信箱不依 Email 合併既有會員', () {
      expect(AuthAccessPolicy.shouldCreateMemberRecord(true), isFalse);
      expect(
        AuthAccessPolicy.identityPatch(
          email: 'hide@privaterelay.appleid.com',
          displayName: '',
        ).containsKey('uid'),
        isFalse,
      );
    });

    test('除錯訊息會遮蔽 Token 與授權碼', () {
      const String raw =
          'Invalid OAuth response id_token=eyJabc.def.ghi access_token=ya29.secret code=authcode';
      final String redacted = AuthAccessPolicy.redactedAuthMessage(raw);
      expect(redacted, isNot(contains('ya29.secret')));
      expect(redacted, isNot(contains('eyJabc')));
      expect(redacted, isNot(contains('authcode')));
      expect(redacted, contains('id_token=[redacted]'));
    });

    test('APPLE-5 取消登入不產生錯誤文案', () {
      expect(AuthAccessPolicy.isCancelledCode('popup-closed-by-user'), isTrue);
      expect(AuthAccessPolicy.isCancelledCode('canceled'), isTrue);
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'popup-closed-by-user'),
        ),
        isNull,
      );
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'cancelled-popup-request'),
        ),
        isNull,
      );
    });

    test('APPLE-6 Web 用 popup，其他平台用原生 Provider', () {
      expect(AuthAccessPolicy.useApplePopup(isWeb: true), isTrue);
      expect(AuthAccessPolicy.useApplePopup(isWeb: false), isFalse);
    });

    test('Apple 與 Google 不走 Email 驗證信流程', () {
      expect(
        AuthAccessPolicy.mustVerifyEmail(
          emailVerified: false,
          providerIds: <String>[apple],
        ),
        isFalse,
      );
      expect(
        AuthAccessPolicy.mustVerifyEmail(
          emailVerified: false,
          providerIds: <String>[google],
        ),
        isFalse,
      );
      expect(
        AuthAccessPolicy.mustVerifyEmail(
          emailVerified: false,
          providerIds: <String>[password, apple],
        ),
        isFalse,
      );
    });
  });

  group('PASSWORD', () {
    test('PASSWORD-1 成功文案不透露信箱是否已註冊', () {
      expect(AuthAccessPolicy.resetSentMessage, contains('如果此電子郵件已註冊'));
      expect(AuthAccessPolicy.resetSentMessage, isNot(contains('找不到')));
    });

    test('PASSWORD-2 Email 格式錯誤顯示中文', () {
      expect(AuthAccessPolicy.emailIssue(''), '請輸入電子郵件。');
      expect(AuthAccessPolicy.emailIssue('not-an-email'), '電子郵件格式不正確，請重新確認。');
    });

    test('PASSWORD-3 重新寄送有冷卻', () {
      final DateTime now = DateTime(2026, 10, 8, 12);
      expect(AuthAccessPolicy.resendWait(lastSent: null, now: now), isNull);
      expect(
        AuthAccessPolicy.resendWait(
          lastSent: now.subtract(const Duration(seconds: 10)),
          now: now,
        ),
        const Duration(seconds: 50),
      );
      expect(
        AuthAccessPolicy.resendWait(
          lastSent: now.subtract(const Duration(seconds: 60)),
          now: now,
        ),
        isNull,
      );
    });

    test('PASSWORD-4 連結過期提供重新申請', () {
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'expired-action-code'),
        ),
        '重設連結已過期或已使用，請重新申請密碼重設信。',
      );
      expect(AuthAccessPolicy.resetExpiredHint, contains('重新輸入電子郵件'));
    });
  });

  group('ERROR', () {
    test('ERROR-1 invalid-email', () {
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'invalid-email'),
        ),
        '電子郵件格式不正確，請重新確認。',
      );
    });

    test('ERROR-2 invalid-credential 與 wrong-password、user-not-found', () {
      const String expected = '電子郵件或密碼不正確，請重新輸入。';
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'invalid-credential'),
        ),
        expected,
      );
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'wrong-password'),
        ),
        expected,
      );
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'user-not-found'),
        ),
        expected,
      );
    });

    test('ERROR-3 too-many-requests', () {
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'too-many-requests'),
        ),
        '嘗試次數過多，請稍後再試。',
      );
    });

    test('ERROR-4 network-request-failed', () {
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        '網路連線異常，請確認網路後重試。',
      );
    });

    test('ERROR-5 未知錯誤不顯示 Firebase 原文', () {
      final String? message = AuthAccessPolicy.messageFor(
        FirebaseAuthException(
          code: 'internal-error',
          message: 'The email address is badly formatted.',
        ),
      );
      expect(message, '暫時無法完成操作，請稍後再試。');
      expect(message, isNot(contains('firebase')));
      expect(message, isNot(contains('badly formatted')));
      expect(
        AuthAccessPolicy.messageFor(Exception('secret-token')),
        '暫時無法完成操作，請稍後再試。',
      );
    });

    test('其餘指定錯誤碼', () {
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'email-already-in-use'),
        ),
        '此電子郵件已被使用，請直接登入或重設密碼。',
      );
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'weak-password'),
        ),
        '密碼安全性不足，請設定更安全的密碼。',
      );
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'user-disabled'),
        ),
        '此帳號目前無法使用，請聯絡客服。',
      );
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'email-not-verified'),
        ),
        '請先完成電子郵件驗證，再登入 PetNest。',
      );
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(code: 'popup-blocked'),
        ),
        '瀏覽器阻擋登入視窗，請允許彈出視窗後重試。',
      );
      expect(
        AuthAccessPolicy.messageFor(
          FirebaseAuthException(
            code: 'account-exists-with-different-credential',
          ),
        ),
        contains('請改用原本的方式登入'),
      );
    });
  });

  group('REGRESSION', () {
    test('REGRESSION-1 Google 登入不要求寄信驗證', () {
      expect(
        AuthAccessPolicy.mustVerifyEmail(
          emailVerified: false,
          providerIds: <String>[google],
        ),
        isFalse,
      );
    });

    test('REGRESSION-2 已驗證 Email 登入可進入', () {
      expect(
        AuthAccessPolicy.mustVerifyEmail(
          emailVerified: true,
          providerIds: <String>[password],
        ),
        isFalse,
      );
      expect(AuthAccessPolicy.passwordIssue('secret'), isNull);
    });

    test('REGRESSION-3 空白姓名與空白 Email 不覆蓋會員資料', () {
      expect(
        AuthAccessPolicy.identityPatch(email: null, displayName: null),
        isEmpty,
      );
    });

    test('REGRESSION-4 補資料欄位不含店家角色', () {
      final Map<String, String> patch = AuthAccessPolicy.identityPatch(
        email: 'staff@petnest.app',
        displayName: '員工',
      );
      expect(patch.containsKey('role'), isFalse);
      expect(patch.containsKey('shopId'), isFalse);
    });
  });
}

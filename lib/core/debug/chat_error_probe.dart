// 檔案名稱：lib/core/debug/chat_error_probe.dart
// 功能說明：開發用：聊天 converted Future 定位。不要在 production 依賴這些開關。

class ChatErrorProbe {
  ChatErrorProbe._();

  /// 二分：聊天頁是否綁 messages stream。
  static const bool bindMessages = true;

  /// 二分：聊天頁是否綁 thread stream。空室改走 watchThreadIfMessagesExist。
  static const bool bindThread = true;

  /// 二分：聊天頁是否 mark read。
  static const bool bindMarkRead = true;

  /// 二分：FloatingContactButton 未讀 stream。
  static const bool bindFloatingUnread = true;

  /// 二分：會員中心店家訊息未讀 stream。
  static const bool bindMemberUnread = true;

  /// 二分：未登入也可開聊天頁 header。正式路徑關閉。
  static const bool allowAnonymousHeader = false;

  static void dump(String source, Object error, StackTrace stack) {
    print('========== $source ==========');
    print('runtimeType=${error.runtimeType}');
    print(error);
    print(stack);
    try {
      final dynamic boxed = error;
      print('boxed.error=${boxed.error}');
      print('boxed.stack=${boxed.stack}');
      print('boxed.message=${boxed.message}');
      print('boxed.code=${boxed.code}');
      print('boxed.name=${boxed.name}');
      final Object? inner = boxed.error;
      if (inner != null) {
        print('inner.runtimeType=${inner.runtimeType}');
        print(inner);
        try {
          final dynamic innerDyn = inner;
          print('inner.error=${innerDyn.error}');
          print('inner.stack=${innerDyn.stack}');
          print('inner.message=${innerDyn.message}');
          print('inner.code=${innerDyn.code}');
        } catch (_) {}
      }
    } catch (e, st) {
      print('$source boxed unwrap failed');
      print(e);
      print(st);
    }
    print('========== /$source ==========');
  }
}

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShopSharingService {
  static final instance = ShopSharingService();
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-east1');

  Future<Map<String, dynamic>> manage(
    String shopId, {
    String action = 'get',
    String searchCode = '',
  }) async {
    final result = await _functions.httpsCallable('manageShopSharing').call({
      'shopId': shopId,
      'action': action,
      'searchCode': searchCode,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>?> resolve(String code) async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    final result = await _functions.httpsCallable('resolveShopSharing').call({
      'code': code,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> _ensureUser() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  Future<String?> currentShop() async {
    await _ensureUser();
    final prefs = await SharedPreferences.getInstance();
    final result = await _functions.httpsCallable('customerShopBinding').call({
      'action': 'get',
      'legacyShopId': prefs.getString('last_customer_shop_id'),
    });
    final id = (result.data as Map)['shopId'] as String?;
    if (id != null) {
      if (prefs.getString('last_customer_shop_id') != id) {
        await prefs.remove('last_customer_shop_code');
      }
      await prefs.setString('last_customer_shop_id', id);
    }
    return id;
  }

  Future<void> selectPublicShop(String shopId) async {
    await _ensureUser();
    await _functions.httpsCallable('customerShopBinding').call({
      'action': 'selectPublic',
      'shopId': shopId,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_customer_shop_id', shopId);
    await prefs.remove('last_customer_shop_code');
  }

  Future<String?> prepareMemberLogin() async {
    if (FirebaseAuth.instance.currentUser?.isAnonymous != true) return null;
    final shop = await currentShop();
    if (shop == null) return null;
    final result = await _functions
        .httpsCallable('transferCustomerShopBinding')
        .call({'action': 'issue'});
    return (result.data as Map)['ticket'] as String?;
  }

  Future<void> completeMemberLogin(String? ticket) async {
    if (ticket == null) return;
    final result = await _functions
        .httpsCallable('transferCustomerShopBinding')
        .call({'action': 'claim', 'ticket': ticket});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'last_customer_shop_id',
      (result.data as Map)['shopId'] as String,
    );
    await prefs.remove('last_customer_shop_code');
  }

  static String errorMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'internal':
      case 'not-found':
      case 'unimplemented':
        return '店家分享服務目前無法使用，請確認後端服務已部署並可正常連線，再按「重新讀取」。';
      case 'unavailable':
      case 'deadline-exceeded':
        return '暫時無法連線至店家分享服務，請稍後重試。';
      case 'unauthenticated':
        return '登入狀態已失效，請重新登入後再試。';
      case 'permission-denied':
        return '你目前沒有管理店家分享設定的權限，請由店主或有營業資訊權限的人員操作。';
      default:
        final message = error.message?.trim();
        if (message != null &&
            message.isNotEmpty &&
            message != error.code &&
            !RegExp(r'^[A-Za-z_ -]+$').hasMatch(message)) {
          return message;
        }
        return '無法更新店家分享設定，請稍後重試。';
    }
  }

  static String shareLink(String token) {
    const configured = String.fromEnvironment(
      'SHOP_SHARE_ORIGIN',
      defaultValue: 'https://petnest-saas.web.app',
    );
    final host = Uri.base.host;
    final local =
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host.endsWith('.localhost');
    final origin =
        kIsWeb &&
            !local &&
            (Uri.base.scheme == 'https' || Uri.base.scheme == 'http')
        ? Uri.base.origin
        : configured;
    return '$origin/s/$token';
  }

  static String? parse(String input) {
    final text = input.trim();
    final uri = Uri.tryParse(text);
    if (uri != null &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 's') {
      return parse(uri.pathSegments[1]);
    }
    if (RegExp(r'^[a-f0-9]{48}$').hasMatch(text)) return text;
    final code = text.toUpperCase();
    if (RegExp(r'^[A-Z0-9][A-Z0-9_-]{7,31}$').hasMatch(code) &&
        !RegExp(r'^SHOP\d+$').hasMatch(code)) {
      return code;
    }
    return null;
  }
}

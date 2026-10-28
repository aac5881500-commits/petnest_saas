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

  static String shareLink(String token) {
    const configured = String.fromEnvironment(
      'SHOP_SHARE_ORIGIN',
      defaultValue: 'https://petnest.tw',
    );
    final origin = kIsWeb ? Uri.base.origin : configured;
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

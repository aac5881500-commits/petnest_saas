// 檔案名稱：lib/core/services/operator_stamp.dart
// 功能說明：店員操作紀錄寫入欄位：保留 UID 供內部追蹤，畫面用 email

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OperatorStamp {
  OperatorStamp._();

  static Map<String, dynamic> fields({String role = ''}) {
    final User? user = FirebaseAuth.instance.currentUser;
    return <String, dynamic>{
      'operatorUid': user?.uid ?? '',
      'operatorEmail': (user?.email ?? '').trim(),
      'operatorDisplayName': (user?.displayName ?? '').trim(),
      'operatorRole': role,
      'operatedAt': FieldValue.serverTimestamp(),
    };
  }
}

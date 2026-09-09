// 檔案名稱：lib/core/services/operator_display.dart
// 功能說明：操作人畫面顯示：email 優先，舊資料對 shop member，絕不顯示 UID

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OperatorDisplay {
  OperatorDisplay._();

  static const String removedStaff = '已移除店員';
  static const String systemOperator = '系統操作';

  static String fromLog(
    Map<String, dynamic> log, {
    Map<String, dynamic>? member,
    bool preferSystemIfNoUid = false,
  }) {
    final String email = (log['operatorEmail'] ?? '').toString().trim();
    if (email.isNotEmpty) {
      return email;
    }
    final String displayName =
        (log['operatorDisplayName'] ?? log['operatorName'] ?? '')
            .toString()
            .trim();
    final String uid = (log['operatorUid'] ?? '').toString().trim();
    if (uid.isEmpty) {
      if (preferSystemIfNoUid ||
          (log['operatorRole'] ?? '').toString() == 'system' ||
          (log['cancelBy'] ?? '').toString() == 'system') {
        return systemOperator;
      }
      return systemOperator;
    }
    final String memberEmail = (member?['email'] ?? '').toString().trim();
    if (memberEmail.isNotEmpty) {
      return memberEmail;
    }
    if (displayName.isNotEmpty && !_looksLikeUid(displayName)) {
      return displayName;
    }
    return removedStaff;
  }

  static bool _looksLikeUid(String value) {
    if (value.length < 20) {
      return false;
    }
    return RegExp(r'^[A-Za-z0-9]{20,}$').hasMatch(value);
  }
}

class OperatorActorLabel extends StatelessWidget {
  const OperatorActorLabel({
    super.key,
    required this.shopId,
    required this.log,
    this.style,
    this.prefix = '',
  });

  final String shopId;
  final Map<String, dynamic> log;
  final TextStyle? style;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final String email = (log['operatorEmail'] ?? '').toString().trim();
    if (email.isNotEmpty) {
      return Text('$prefix$email', style: style);
    }
    final String uid = (log['operatorUid'] ?? '').toString().trim();
    if (uid.isEmpty || shopId.isEmpty) {
      return Text('$prefix${OperatorDisplay.fromLog(log)}', style: style);
    }
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
          .doc(uid)
          .get(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData &&
                !snapshot.hasError) {
              return Text(
                '$prefix${OperatorDisplay.fromLog(log)}',
                style: style,
              );
            }
            Map<String, dynamic>? member;
            if (snapshot.hasData && snapshot.data!.exists) {
              member = snapshot.data!.data();
            }
            return Text(
              '$prefix${OperatorDisplay.fromLog(log, member: member)}',
              style: style,
            );
          },
    );
  }
}

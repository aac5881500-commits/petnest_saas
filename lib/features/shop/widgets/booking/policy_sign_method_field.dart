// lib/features/shop/widgets/booking/policy_sign_method_field.dart
// 📜 店員代客／轉住宿時記錄條款簽署方式，不可只存 agreed: true

import 'package:flutter/material.dart';

class PolicySignMethods {
  PolicySignMethods._();

  static const String memberOnline = 'member_online';
  static const String staffWitness = 'staff_witness';
  static const String paper = 'paper';

  static String label(String value) {
    switch (value) {
      case memberOnline:
        return '會員已於線上簽署';
      case staffWitness:
        return '店員現場見證簽署';
      case paper:
        return '現場紙本簽署';
      default:
        return '尚未選擇';
    }
  }
}

class PolicySignMethodField extends StatelessWidget {
  const PolicySignMethodField({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = '條款簽署方式',
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: title,
        border: const OutlineInputBorder(),
      ),
      items: const <DropdownMenuItem<String>>[
        DropdownMenuItem<String>(
          value: PolicySignMethods.memberOnline,
          child: Text('會員已於線上簽署'),
        ),
        DropdownMenuItem<String>(
          value: PolicySignMethods.staffWitness,
          child: Text('店員現場見證簽署'),
        ),
        DropdownMenuItem<String>(
          value: PolicySignMethods.paper,
          child: Text('現場紙本簽署'),
        ),
      ],
      onChanged: (String? selected) {
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }
}

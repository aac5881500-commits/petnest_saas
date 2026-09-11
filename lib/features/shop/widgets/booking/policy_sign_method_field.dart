// 檔案名稱：lib/features/shop/widgets/booking/policy_sign_method_field.dart
// 功能說明：店員代客／轉住宿時記錄條款簽署方式，不可只存 agreed: true

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

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
    this.serviceLabel = '條款',
    this.showError = false,
    this.theme,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final String title;
  final String serviceLabel;
  final bool showError;
  final HomeThemeModel? theme;

  String get _errorText => '請先選擇$serviceLabel確認方式，才能繼續下一步。';

  @override
  Widget build(BuildContext context) {
    final Color border = showError
        ? Colors.red.shade400
        : (theme?.cardBorderColor ?? Theme.of(context).dividerColor);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme?.cardColor ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: showError ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '條款確認',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme?.textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '必填',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(value ?? 'unset'),
            initialValue: value,
            decoration: InputDecoration(
              labelText: title,
              border: const OutlineInputBorder(),
              errorText: showError ? _errorText : null,
              errorMaxLines: 2,
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
          ),
        ],
      ),
    );
  }
}

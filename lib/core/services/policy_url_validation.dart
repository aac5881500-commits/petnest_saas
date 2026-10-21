import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/shop_policy_history.dart';

class PolicyTextField {
  const PolicyTextField(this.key, this.name, this.text, {this.enabled = true});
  final String key, name, text;
  final bool enabled;
}

class PolicyUrlIssue {
  const PolicyUrlIssue(
    this.key,
    this.name,
    this.fragment,
    this.start,
    this.end,
  );
  final String key, name, fragment;

  /// UTF-16 offsets into the unchanged editor text.
  final int start, end;
  String get excerpt =>
      fragment.length > 80 ? '${fragment.substring(0, 80)}…' : fragment;
}

class PolicyUrlValidationException implements Exception {
  const PolicyUrlValidationException(this.issues);
  final List<PolicyUrlIssue> issues;
  @override
  String toString() =>
      '條款含有網址，請移除後再發布（${issues.map((e) => e.name).toSet().join('、')}）';
}

class PolicyUrlValidation {
  static const message = '此處不可放置網址，請移除後再發布。官網或社群連結請至店家專用設定欄位填寫。';
  // Width conversion preserves each UTF-16 offset. Original text is never rewritten.
  static String _normalize(String value) => String.fromCharCodes(
    value.codeUnits.map(
      (c) => c >= 0xff01 && c <= 0xff5e
          ? c - 0xfee0
          : c == 0x3002
          ? 46
          : c == 0x3000
          ? 32
          : c,
    ),
  );
  static final _email = RegExp(
    r'''[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9.-]+\.[a-z]{2,}''',
    caseSensitive: false,
  );
  static final _url = RegExp(
    r'''(?<![a-z0-9_])(?:[a-z][a-z0-9+.-]*://|(?:mailto|tel|sms|intent):)[^\s<>"'()[\]{}]+|(?<![a-z0-9_@.-])(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}(?::[0-9]{1,5})?(?:[/?#][^\s<>"'()[\]{}]*)?''',
    caseSensitive: false,
  );
  static List<PolicyUrlIssue> inspect(Iterable<PolicyTextField> fields) {
    final issues = <PolicyUrlIssue>[];
    for (final field in fields.where((f) => f.enabled)) {
      final normalized = _normalize(field.text);
      final emails = _email.allMatches(normalized).toList();
      for (final match in _url.allMatches(normalized)) {
        if (emails.any((e) => match.start >= e.start && match.start < e.end)) {
          continue;
        }
        var end = match.end;
        while (end > match.start &&
            RegExp(r'[.,;:!?，。；：！？、]').hasMatch(normalized[end - 1])) {
          end--;
        }
        if (end > match.start) {
          issues.add(
            PolicyUrlIssue(
              field.key,
              field.name,
              field.text.substring(match.start, end),
              match.start,
              end,
            ),
          );
        }
      }
    }
    return issues;
  }

  static void requireValid(Iterable<PolicyTextField> fields) {
    final issues = inspect(fields);
    if (issues.isNotEmpty) throw PolicyUrlValidationException(issues);
  }

  /// Input must already be filtered with filterPolicyForService.
  static List<PolicyTextField> policyFields(
    Map<String, dynamic> filtered,
    String service,
  ) {
    final sections = Map<String, dynamic>.from(filtered['sections'] ?? {});
    final enabled = Map<String, dynamic>.from(filtered['enabled'] ?? {});
    final fields = <PolicyTextField>[
      for (final entry in sections.entries)
        PolicyTextField(
          entry.key,
          ShopPolicyHistory.sectionLabel(entry.key, service),
          entry.value.toString(),
          enabled: enabled[entry.key] != false,
        ),
    ];
    for (final page in ['customPoliciesPage1', 'customPoliciesPage2']) {
      final raw = filtered[page];
      if (raw is! List) continue;
      for (var i = 0; i < raw.length; i++) {
        final item = raw[i];
        final prefix = '$page.$i';
        final label = '自訂條款 ${page.endsWith('1') ? '第1頁' : '第2頁'}第${i + 1}項';
        if (item is Map) {
          if (item['enabled'] == false ||
              !PolicyApplicableService.appliesTo(
                PolicyApplicableService.parse(item['applicableServices']),
                service,
              )) {
            continue;
          }
          for (final part in ['title', 'text', 'content']) {
            if (item[part] != null) {
              fields.add(
                PolicyTextField(
                  '$prefix.$part',
                  '$label${part == 'title' ? '標題' : '內容'}',
                  item[part].toString(),
                ),
              );
            }
          }
        } else if (item is String) {
          fields.add(PolicyTextField(prefix, label, item));
        }
      }
    }
    return fields;
  }

  static List<PolicyTextField> refundFields({
    required String title,
    required String description,
    required String body,
    required bool enabled,
  }) => [
    PolicyTextField('refundTitle', '退款條款標題', title, enabled: enabled),
    PolicyTextField(
      'refundDescription',
      '退款條款說明',
      description,
      enabled: enabled,
    ),
    PolicyTextField('refundBody', '退款條款正文', body, enabled: enabled),
  ];
}

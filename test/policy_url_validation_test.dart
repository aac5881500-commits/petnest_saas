import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/policy_url_validation.dart';

void main() {
  List<PolicyUrlIssue> issues(String value) =>
      PolicyUrlValidation.inspect([PolicyTextField('notice', '入住須知', value)]);
  test(
    'recognizes explicit, bare, embedded, other-scheme and fullwidth links',
    () {
      for (final value in [
        'https://example.com/path',
        'http://example.com',
        'www.example.com',
        'example.com/path',
        '[官網](https://example.com/path)',
        '<a href="https://example.com">連結</a>',
        'ftp://files.example.com/a',
        'line://ti/p/example',
        'mailto:owner@example.com',
        'ｈｔｔｐｓ：／／ｅｘａｍｐｌｅ．ｃｏｍ／ｐａｔｈ',
        'ｗｗｗ．ｅｘａｍｐｌｅ．ｃｏｍ',
      ]) {
        expect(issues(value), isNotEmpty, reason: value);
      }
    },
  );
  test(
    'does not reject plain email, phone, dates, times, money or versions',
    () {
      for (final value in [
        'owner@example.com',
        'owner@www.example.com',
        'ｏｗｎｅｒ＠ｅｘａｍｐｌｅ．ｃｏｍ',
        '02-2345-6789',
        '0912-345-678',
        '2026.10.21',
        '2026/10/21',
        '10:30–19:00',
        'NT\$1,200.50',
        '3.14159',
        'v1.2.3',
        '【注意事項】請用外出籠',
      ]) {
        expect(issues(value), isEmpty, reason: value);
      }
    },
  );
  test(
    'returns original fragments and UTF16 selection offsets without rewriting',
    () {
      const text = '🐈 請移除 ｈｔｔｐｓ：／／ｅｘａｍｐｌｅ．ｃｏｍ／ａ。';
      final issue = issues(text).single;
      expect(text.substring(issue.start, issue.end), issue.fragment);
      expect(issue.fragment, 'ｈｔｔｐｓ：／／ｅｘａｍｐｌｅ．ｃｏｍ／ａ');
      expect(issue.key, 'notice');
    },
  );
  test('disabled fields excluded; active custom title and text included', () {
    final fields = PolicyUrlValidation.policyFields({
      'sections': {'checkinNotice': 'example.com'},
      'enabled': {'checkinNotice': false},
      'customPoliciesPage1': [
        {
          'title': 'www.example.com',
          'text': 'line://example',
          'applicableServices': ['accommodation'],
        },
        {'text': 'https://disabled.example.com', 'enabled': false},
        {
          'text': 'https://daycare.example.com',
          'applicableServices': ['daycare'],
        },
      ],
    }, 'accommodation');
    expect(PolicyUrlValidation.inspect(fields).length, 2);
    expect(
      () => PolicyUrlValidation.requireValid(fields),
      throwsA(isA<PolicyUrlValidationException>()),
    );
    expect(
      PolicyUrlValidation.inspect(
        PolicyUrlValidation.refundFields(
          title: 'example.com',
          description: '',
          body: '',
          enabled: false,
        ),
      ),
      isEmpty,
    );
  });
}

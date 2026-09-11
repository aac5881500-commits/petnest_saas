// 檔案名稱：lib/core/services/member_search_fields.dart
// 功能說明：會員搜尋正規化欄位。前綴陣列長度可控，避免過大索引。

class MemberSearchFields {
  MemberSearchFields._();

  static const int maxNamePrefixLength = 8;
  static const int maxPhoneSuffixes = 6;

  static String normalizeName(String raw) {
    return raw.trim().toLowerCase();
  }

  static String digitsOnly(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String normalizeEmail(String raw) {
    return raw.trim().toLowerCase();
  }

  static List<String> namePrefixes(String name) {
    final String normalized = normalizeName(name);
    if (normalized.isEmpty) {
      return const <String>[];
    }
    final List<String> prefixes = <String>[];
    final int end = normalized.length < maxNamePrefixLength
        ? normalized.length
        : maxNamePrefixLength;
    for (int i = 1; i <= end; i++) {
      prefixes.add(normalized.substring(0, i));
    }
    return prefixes;
  }

  static List<String> phoneSuffixes(String phone) {
    final String digits = digitsOnly(phone);
    if (digits.isEmpty) {
      return const <String>[];
    }
    final List<String> suffixes = <String>[];
    final int maxLen = digits.length < 8 ? digits.length : 8;
    for (int i = 4; i <= maxLen && suffixes.length < maxPhoneSuffixes; i++) {
      suffixes.add(digits.substring(digits.length - i));
    }
    return suffixes;
  }

  static Map<String, dynamic> fromMember({
    required String name,
    required String phone,
    required String email,
    String status = '',
    String source = 'app',
    bool blacklisted = false,
    bool isBlocked = false,
    List<dynamic>? tags,
  }) {
    final String digits = digitsOnly(phone);
    final List<String> tagList = tags == null
        ? const <String>[]
        : tags.map((dynamic e) => e.toString()).toList();
    final bool archived = status == 'archived';
    final bool merged = status == 'merged';
    return <String, dynamic>{
      'nameNormalized': normalizeName(name),
      'namePrefixes': namePrefixes(name),
      'phoneDigits': digits,
      'phoneLast4': digits.length >= 4
          ? digits.substring(digits.length - 4)
          : digits,
      'phoneLast5': digits.length >= 5
          ? digits.substring(digits.length - 5)
          : digits,
      'phoneSuffixes': phoneSuffixes(phone),
      'emailNormalized': normalizeEmail(email),
      'isArchived': archived,
      'isMerged': merged,
      'isBlacklisted': blacklisted || isBlocked,
      'isVip': tagList.contains('vip'),
      'memberSource': source.trim().isEmpty ? 'app' : source.trim(),
    };
  }
}

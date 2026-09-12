// 檔案名稱：lib/core/utils/natural_sort.dart
// 功能說明：房號／房型自然排序，讓 A2 排在 A10 之前。

class NaturalSort {
  NaturalSort._();

  static int compare(String a, String b) {
    final List<Object> left = _parts(a.trim());
    final List<Object> right = _parts(b.trim());
    final int length = left.length < right.length ? left.length : right.length;
    for (int i = 0; i < length; i++) {
      final Object l = left[i];
      final Object r = right[i];
      if (l is int && r is int) {
        final int n = l.compareTo(r);
        if (n != 0) {
          return n;
        }
      } else {
        final int n = l.toString().toLowerCase().compareTo(
          r.toString().toLowerCase(),
        );
        if (n != 0) {
          return n;
        }
      }
    }
    return left.length.compareTo(right.length);
  }

  static List<Object> _parts(String input) {
    final List<Object> out = <Object>[];
    final RegExp exp = RegExp(r'(\d+)|(\D+)');
    for (final RegExpMatch match in exp.allMatches(input)) {
      final String digits = match.group(1) ?? '';
      if (digits.isNotEmpty) {
        out.add(int.tryParse(digits) ?? 0);
      } else {
        out.add(match.group(2) ?? '');
      }
    }
    return out;
  }
}

int naturalCompare(String a, String b) => NaturalSort.compare(a, b);

/// 房號自然排序：忽略空白與大小寫；相同時用穩定第二鍵。
int compareRoomCodes(String a, String b, {String tieA = '', String tieB = ''}) {
  final int primary = NaturalSort.compare(a, b);
  if (primary != 0) {
    return primary;
  }
  return tieA.trim().toLowerCase().compareTo(tieB.trim().toLowerCase());
}

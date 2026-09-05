// 檔案名稱：lib/core/utils/natural_sort.dart
// 功能說明：將 A1、A2、A10 等文字依照人類閱讀順序排序
// 🔢 自然排序工具

int naturalCompare(String first, String second) {
  final firstParts = _splitNaturalParts(first);
  final secondParts = _splitNaturalParts(second);

  final compareLength = firstParts.length < secondParts.length
      ? firstParts.length
      : secondParts.length;

  for (var index = 0; index < compareLength; index++) {
    final firstPart = firstParts[index];
    final secondPart = secondParts[index];

    final firstNumber = int.tryParse(firstPart);
    final secondNumber = int.tryParse(secondPart);

    int result;

    if (firstNumber != null && secondNumber != null) {
      result = firstNumber.compareTo(secondNumber);

      // 數字相同時，A01 排在 A001 前面，維持穩定順序
      if (result == 0) {
        result = firstPart.length.compareTo(secondPart.length);
      }
    } else {
      result = firstPart.toLowerCase().compareTo(secondPart.toLowerCase());
    }

    if (result != 0) {
      return result;
    }
  }

  return firstParts.length.compareTo(secondParts.length);
}

List<String> _splitNaturalParts(String value) {
  return RegExp(r'\d+|\D+')
      .allMatches(value.trim())
      .map((match) => match.group(0) ?? '')
      .where((part) => part.isNotEmpty)
      .toList();
}

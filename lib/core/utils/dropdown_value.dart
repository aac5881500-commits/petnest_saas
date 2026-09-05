// 檔案名稱：lib/core/utils/dropdown_value.dart
// 功能說明：Dropdown 選取值防護，避免 Firestore 資料不在 items 內時整頁崩潰。

String? dropdownValueIfAllowed(String? value, Iterable<String> items) {
  final String text = (value ?? '').trim();
  if (text.isEmpty) {
    return null;
  }
  for (final String item in items) {
    if (item == text) {
      return text;
    }
  }
  return null;
}

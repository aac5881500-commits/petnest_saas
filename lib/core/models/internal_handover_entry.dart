import '../utils/safe_parse.dart';

const internalHandoverCategories = [
  '住宿交代',
  '餵藥交代',
  '飲食交代',
  '健康觀察',
  '接送交代',
  '清潔與環境',
  '其他事項',
];

/// Entries reuse the private revision history; text remains human readable.
class InternalHandoverEntry {
  const InternalHandoverEntry({
    required this.id,
    required this.category,
    required this.content,
    required this.author,
    required this.revision,
    this.createdAt,
  });
  final String id, category, content, author;
  final int revision;
  final DateTime? createdAt;

  factory InternalHandoverEntry.fromMap(String id, Map<String, dynamic> data) {
    final text = '${data['text'] ?? ''}';
    String category = '原有交接';
    String content = text;
    for (final value in internalHandoverCategories) {
      final prefix = '【$value】\n';
      if (text.startsWith(prefix)) {
        category = value;
        content = text.substring(prefix.length);
        break;
      }
    }
    return InternalHandoverEntry(
      id: id,
      category: category,
      content: content,
      author: '${data['updatedByEmail'] ?? ''}'.trim(),
      revision: (data['revision'] as num?)?.toInt() ?? 0,
      createdAt: SafeParse.parseDate(data['updatedAt']),
    );
  }

  static String encode(String category, String content) {
    if (!internalHandoverCategories.contains(category)) {
      throw ArgumentError('請選擇交接分類');
    }
    final clean = content.trim();
    if (clean.isEmpty) throw ArgumentError('請填寫交接內容');
    if (clean.length > 3000) throw ArgumentError('每筆交接最多 3000 字');
    return '【$category】\n$clean';
  }
}

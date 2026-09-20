// 檔案名稱：lib/features/shop/widgets/room/room_quick_create_logic.dart
// 功能說明：快速建房名稱產生、分隔解析與重複略過，不含 Firestore 寫入。

class RoomQuickCreatePlan {
  const RoomQuickCreatePlan({
    required this.requested,
    required this.toCreate,
    required this.skippedExisting,
    required this.skippedInBatch,
    required this.remaining,
    required this.exceedsRemaining,
  });

  final List<String> requested;
  final List<String> toCreate;
  final List<String> skippedExisting;
  final List<String> skippedInBatch;
  final int remaining;
  final bool exceedsRemaining;
}

class RoomQuickCreateLogic {
  RoomQuickCreateLogic._();

  static List<String> sequentialNames({
    required String prefix,
    required int start,
    required int count,
    required int digitCount,
  }) {
    if (start <= 0 || count <= 0) {
      return const <String>[];
    }
    final int digits = digitCount.clamp(1, 3);
    return List<String>.generate(count, (int index) {
      final int number = start + index;
      return '$prefix${number.toString().padLeft(digits, '0')}';
    });
  }

  static List<String> parseCustomNames(String raw) {
    return raw
        .split(RegExp(r'[\s,，、]+'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  static RoomQuickCreatePlan plan({
    required List<String> names,
    required Set<String> existingNames,
    required int remaining,
  }) {
    final List<String> requested = <String>[];
    final List<String> toCreate = <String>[];
    final List<String> skippedExisting = <String>[];
    final List<String> skippedInBatch = <String>[];
    final Set<String> seen = <String>{};

    for (final String raw in names) {
      final String name = raw.trim();
      if (name.isEmpty) {
        continue;
      }
      requested.add(name);
      if (existingNames.contains(name)) {
        if (!skippedExisting.contains(name)) {
          skippedExisting.add(name);
        }
        continue;
      }
      if (seen.contains(name)) {
        if (!skippedInBatch.contains(name)) {
          skippedInBatch.add(name);
        }
        continue;
      }
      seen.add(name);
      toCreate.add(name);
    }

    final int safeRemaining = remaining < 0 ? 0 : remaining;
    return RoomQuickCreatePlan(
      requested: requested,
      toCreate: toCreate,
      skippedExisting: skippedExisting,
      skippedInBatch: skippedInBatch,
      remaining: safeRemaining,
      exceedsRemaining: toCreate.length > safeRemaining,
    );
  }
}

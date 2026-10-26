/// Legacy FAQ records may have missing or malformed ranks. Keep their fallback
/// ordering consistent between the management list and the customer page.
num shopFaqSortOrder(Object? raw) {
  final value = raw is num ? raw : num.tryParse(raw?.toString() ?? '');
  return value != null && value.isFinite ? value : 999;
}

int compareShopFaqOrder({
  required String firstId,
  required Object? firstOrder,
  required String secondId,
  required Object? secondOrder,
}) {
  final comparison = shopFaqSortOrder(
    firstOrder,
  ).compareTo(shopFaqSortOrder(secondOrder));
  return comparison != 0 ? comparison : firstId.compareTo(secondId);
}

/// Use the greatest existing rank, not the number of records: deleting a FAQ
/// must never cause the next FAQ to reuse another item's rank.
num nextShopFaqSortOrder(Iterable<Object?> existing) {
  num greatest = 0;
  for (final raw in existing) {
    final order = shopFaqSortOrder(raw);
    if (order > greatest) greatest = order;
  }
  return greatest + 1;
}

/// Normalize ranks after a move so legacy duplicate ranks can also be moved.
/// The caller writes the changed ranks in a single atomic batch.
Map<String, int> movedShopFaqRanks(List<String> ids, int from, int to) {
  if (from < 0 || from >= ids.length || to < 0 || to >= ids.length) {
    throw RangeError('FAQ move is outside the current list');
  }
  final reordered = [...ids];
  final moving = reordered.removeAt(from);
  reordered.insert(to, moving);
  return {
    for (var index = 0; index < reordered.length; index++)
      reordered[index]: index + 1,
  };
}

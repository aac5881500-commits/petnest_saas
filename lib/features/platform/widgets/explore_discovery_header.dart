import 'package:flutter/material.dart';

/// Search and filters share one responsive surface; callbacks only update the
/// existing discovery query or navigate to the current member/map actions.
class ExploreDiscoveryHeader extends StatelessWidget {
  const ExploreDiscoveryHeader({
    super.key,
    required this.search,
    required this.categories,
    required this.category,
    required this.openOnly,
    required this.onSearch,
    required this.onCategory,
    required this.onOpenOnly,
    required this.onReset,
    required this.onMap,
    required this.onMember,
    this.onBack,
  });
  final TextEditingController search;
  final List<String> categories;
  final String category;
  final bool openOnly;
  final VoidCallback onSearch, onReset, onMap, onMember;
  final VoidCallback? onBack;
  final ValueChanged<String> onCategory;
  final ValueChanged<bool> onOpenOnly;
  bool get filtered =>
      search.text.trim().isNotEmpty || category != '全部' || openOnly;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxWidth < 600;
        return Container(
          padding: EdgeInsets.all(compact ? 12 : 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [colors.surfaceContainerHigh, colors.surfaceContainer]
                  : const [Color(0xFFEAF4F1), Color(0xFFF9F4E8)],
            ),
            borderRadius: BorderRadius.circular(compact ? 18 : 22),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (compact)
                    IconButton(
                      tooltip: '我的 PetNest／會員選單',
                      onPressed: onMember,
                      icon: const Icon(Icons.menu_rounded),
                    ),
                  if (onBack != null && !compact)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        tooltip: '返回',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                  const Icon(Icons.pets, color: Color(0xFFBD762E), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PetNest · 探索好店',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (compact && onBack != null)
                    IconButton(
                      tooltip: '返回',
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back, size: 20),
                    ),
                  if (compact)
                    IconButton(
                      tooltip: '依店家地址看地圖',
                      onPressed: onMap,
                      icon: const Icon(Icons.map_outlined),
                    ),
                  if (!compact)
                    IconButton(
                      tooltip: '我的 PetNest／會員選單',
                      onPressed: onMember,
                      icon: const Icon(Icons.person_outline),
                    ),
                ],
              ),
              SizedBox(height: compact ? 2 : 14),
              Text(
                compact ? '為毛孩找到合適的店' : '為毛孩，找一間合適的好店',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: compact ? 21 : 30,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 6),
                Text(
                  '從旅宿、美容到日常照護，依地區與服務慢慢挑選。',
                  style: TextStyle(color: colors.onSurfaceVariant, height: 1.6),
                ),
              ],
              SizedBox(height: compact ? 8 : 20),
              TextField(
                controller: search,
                onChanged: (_) => onSearch(),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  onSearch();
                  FocusScope.of(context).unfocus();
                },
                decoration: InputDecoration(
                  hintText: '搜尋店名、地區或服務',
                  hintMaxLines: 2,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除搜尋',
                          onPressed: () {
                            search.clear();
                            onSearch();
                          },
                          icon: const Icon(Icons.close, size: 20),
                        ),
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                ),
              ),
              if (compact) ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final separate =
                        constraints.maxWidth < 290 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.2;
                    final categorySelect = InputDecorator(
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: categories.contains(category)
                              ? category
                              : null,
                          hint: const Text('選擇服務'),
                          items: [
                            for (final label in categories)
                              DropdownMenuItem(
                                value: label,
                                child: Text(label == '全部' ? '全部服務' : label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) onCategory(value);
                          },
                        ),
                      ),
                    );
                    final openFilter = FilterChip(
                      label: const Text('營業中'),
                      selected: openOnly,
                      onSelected: onOpenOnly,
                      avatar: const Icon(Icons.schedule, size: 17),
                    );
                    return separate
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              categorySelect,
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: openFilter,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: categorySelect),
                              const SizedBox(width: 10),
                              openFilter,
                            ],
                          );
                  },
                ),
                if (filtered)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onReset,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('清除全部條件'),
                    ),
                  ),
              ] else ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final label in categories)
                      ChoiceChip(
                        label: Text(label),
                        selected: category == label,
                        onSelected: (_) => onCategory(label),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text('只看營業中'),
                      avatar: const Icon(Icons.schedule, size: 17),
                      selected: openOnly,
                      onSelected: onOpenOnly,
                    ),
                    TextButton.icon(
                      onPressed: onMap,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('依店家地址看地圖'),
                    ),
                    if (filtered)
                      TextButton(
                        onPressed: onReset,
                        child: const Text('清除全部條件'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class ExploreResultsHeading extends StatelessWidget {
  const ExploreResultsHeading({
    super.key,
    required this.count,
    required this.total,
    required this.filtered,
  });
  final int count, total;
  final bool filtered;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 8,
    children: [
      Text(
        filtered ? '符合條件的店家' : '探索更多店家',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      Text(
        filtered ? '找到 $count 間 · 共 $total 間公開店家' : '$count 間公開店家',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
    ],
  );
}

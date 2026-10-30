import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

/// Shared themed picker for every member pet profile selection.
class PetCatalogField extends StatelessWidget {
  const PetCatalogField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.decoration,
    this.multiple = false,
    this.requiredValue = false,
    this.enabled = true,
    this.allowCustom = true,
    this.searchable,
    this.optionLabels = const {},
    this.theme = HomeThemeModel.modernDefault,
    this.exclusiveValues = const {},
    this.hint = '選填，可搜尋或自行填寫',
  });
  final String label, value, hint;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final bool multiple, requiredValue, enabled, allowCustom;
  final bool? searchable;
  final Map<String, String> optionLabels;
  final HomeThemeModel theme;
  final Set<String> exclusiveValues;
  String display(String v) => optionLabels[v] ?? v;
  @override
  Widget build(BuildContext context) => FormField<String>(
    autovalidateMode: AutovalidateMode.onUserInteraction,
    key: ValueKey('catalog-$label-$value'),
    initialValue: value,
    validator: (v) =>
        requiredValue && (v ?? '').trim().isEmpty ? '請選擇$label' : null,
    builder: (field) => Semantics(
      button: true,
      enabled: enabled,
      label: '$label，${value.isEmpty ? '尚未選擇' : display(value)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: !enabled
            ? null
            : () async {
                final result = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: theme.cardColor,
                  constraints: const BoxConstraints(maxWidth: 600),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  builder: (_) => _PetOptionSheet(
                    label: label,
                    value: value,
                    options: options,
                    multiple: multiple,
                    requiredValue: requiredValue,
                    exclusiveValues: exclusiveValues,
                    allowCustom: allowCustom,
                    searchable: searchable ?? options.length > 6,
                    optionLabels: optionLabels,
                    theme: theme,
                  ),
                );
                if (result != null && field.mounted) {
                  field.didChange(result);
                  onChanged(result);
                }
              },
        child: InputDecorator(
          isEmpty: value.isEmpty,
          decoration: decoration.copyWith(
            enabled: enabled,
            errorText: field.errorText,
            suffixIcon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: enabled
                  ? theme.primaryColor
                  : theme.textColor.withValues(alpha: 0.3),
            ),
          ),
          child: value.isEmpty
              ? Text(
                  hint,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textColor.withValues(alpha: 0.5),
                  ),
                )
              : multiple
              ? Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final v in value.split('、').take(3))
                      _ValueTag(text: display(v), theme: theme),
                    if (value.split('、').length > 3)
                      _ValueTag(
                        text: '+${value.split('、').length - 3} 項',
                        theme: theme,
                      ),
                  ],
                )
              : Text(
                  display(value),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    ),
  );
}

class _ValueTag extends StatelessWidget {
  const _ValueTag({required this.text, required this.theme});
  final String text;
  final HomeThemeModel theme;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: theme.primaryColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, color: theme.textColor),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class _PetOptionSheet extends StatefulWidget {
  const _PetOptionSheet({
    required this.label,
    required this.value,
    required this.options,
    required this.multiple,
    required this.requiredValue,
    required this.exclusiveValues,
    required this.allowCustom,
    required this.searchable,
    required this.optionLabels,
    required this.theme,
  });
  final String label, value;
  final List<String> options;
  final bool multiple, requiredValue, allowCustom, searchable;
  final Set<String> exclusiveValues;
  final Map<String, String> optionLabels;
  final HomeThemeModel theme;
  @override
  State<_PetOptionSheet> createState() => _PetOptionSheetState();
}

class _PetOptionSheetState extends State<_PetOptionSheet> {
  late final TextEditingController custom;
  final search = TextEditingController();
  final optionsController = ScrollController();
  final selected = <String>{};
  final customKey = GlobalKey();
  bool other = false;
  String query = '';
  String? error;
  String display(String v) => widget.optionLabels[v] ?? v;
  Color get accent => widget.theme.primaryColor;
  Color get ink => widget.theme.textColor;
  Color get muted => ink.withValues(alpha: 0.6);
  Color get soft =>
      Color.alphaBlend(accent.withValues(alpha: 0.06), widget.theme.cardColor);
  IconData get icon => switch (widget.label) {
    '品種' || '寵物種類' => Icons.pets_rounded,
    '疫苗類型' => Icons.vaccines_outlined,
    '醫療狀況' => Icons.health_and_safety_outlined,
    '性別' => Icons.wc_rounded,
    '年齡' => Icons.cake_outlined,
    '結紮狀況' => Icons.verified_user_outlined,
    '貓砂種類' => Icons.inventory_2_outlined,
    '散步需求' => Icons.directions_walk_rounded,
    _ => Icons.tune_rounded,
  };
  @override
  void initState() {
    super.initState();
    final parts = widget.multiple ? widget.value.split('、') : [widget.value];
    selected.addAll(parts.where(widget.options.contains));
    final unknown = parts
        .where((v) => v.trim().isNotEmpty && !widget.options.contains(v))
        .join('、');
    other = widget.allowCustom && unknown.isNotEmpty;
    custom = TextEditingController(text: unknown);
  }

  @override
  void dispose() {
    optionsController.dispose();
    search.dispose();
    custom.dispose();
    super.dispose();
  }

  void toggle(String v, bool checked) {
    setState(() {
      if (!checked) {
        selected.remove(v);
        return;
      }
      if (!widget.multiple || widget.exclusiveValues.contains(v)) {
        selected.clear();
        other = false;
      } else {
        selected.removeAll(widget.exclusiveValues);
      }
      selected.add(v);
      error = null;
    });
  }

  void toggleOther() {
    setState(() {
      other = !other;
      if (other) {
        if (!widget.multiple) {
          selected.clear();
        } else {
          selected.removeAll(widget.exclusiveValues);
        }
      }
      error = null;
    });
    if (other) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && customKey.currentContext != null) {
          Scrollable.ensureVisible(
            customKey.currentContext!,
            duration: const Duration(milliseconds: 180),
            alignment: 0.6,
          );
        }
      });
    }
  }

  void confirm() {
    if (other && custom.text.trim().isEmpty) {
      setState(() => error = '請填寫其他內容');
      return;
    }
    final values = [
      for (final o in widget.options)
        if (selected.contains(o)) o,
      if (other && custom.text.trim().isNotEmpty) custom.text.trim(),
    ];
    if (widget.requiredValue && values.isEmpty) {
      setState(() => error = '請選擇${widget.label}');
      return;
    }
    Navigator.pop(context, values.join('、'));
  }

  InputDecoration input(
    String hint, {
    IconData? prefix,
    String? label,
  }) => InputDecoration(
    hintText: hint,
    labelText: label,
    filled: true,
    fillColor: soft,
    hintStyle: TextStyle(color: muted, fontSize: 14),
    prefixIcon: prefix == null ? null : Icon(prefix, color: muted, size: 21),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color: accent.withValues(alpha: 0.18)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color: accent.withValues(alpha: 0.18)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color: accent, width: 1.5),
    ),
  );
  Widget choice(
    String title,
    bool active,
    VoidCallback tap, {
    String? subtitle,
    IconData? leading,
  }) => Semantics(
    checked: active,
    inMutuallyExclusiveGroup: !widget.multiple,
    button: true,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: active ? soft : widget.theme.cardColor,
        border: Border.all(
          color: active ? accent : ink.withValues(alpha: 0.10),
          width: active ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  if (leading != null) ...[
                    Icon(leading, size: 20, color: active ? accent : muted),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: ink,
                            fontSize: 14,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    widget.multiple
                        ? (active
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded)
                        : (active
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded),
                    size: 23,
                    color: active ? accent : ink.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final compact =
        widget.options.length <= 6 && !widget.searchable && !widget.allowCustom;
    final filtered = widget.options
        .where((v) => display(v).toLowerCase().contains(query))
        .toList();
    final count = selected.length + (other ? 1 : 0);
    final selectedText = [
      for (final v in widget.options)
        if (selected.contains(v)) display(v),
      if (other) custom.text.trim().isEmpty ? '其他' : custom.text.trim(),
    ];
    final maxHeight = math.min(
      compact ? 430.0 : 780.0,
      MediaQuery.sizeOf(context).height * 0.88,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: EdgeInsets.only(top: 10, bottom: keyboard ? 10 : 20),
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 14, keyboard ? 10 : 16),
              child: Row(
                children: [
                  Container(
                    width: keyboard ? 38 : 46,
                    height: keyboard ? 38 : 46,
                    decoration: BoxDecoration(
                      color: soft,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '選擇${widget.label}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        if (!keyboard) const SizedBox(height: 3),
                        if (!keyboard)
                          Text(
                            widget.multiple ? '可複選符合的項目，再按確認儲存' : '選擇一個最符合的項目',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: '關閉選單',
                    style: IconButton.styleFrom(
                      backgroundColor: ink.withValues(alpha: 0.04),
                    ),
                    icon: Icon(Icons.close_rounded, color: muted, size: 20),
                  ),
                ],
              ),
            ),
            if (widget.searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  key: const ValueKey('pet-menu-search'),
                  controller: search,
                  style: TextStyle(color: ink, fontSize: 14),
                  decoration:
                      input(
                        '搜尋${widget.label}',
                        prefix: Icons.search_rounded,
                      ).copyWith(
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '清除搜尋',
                                onPressed: () {
                                  search.clear();
                                  setState(() => query = '');
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                      ),
                  onChanged: (v) =>
                      setState(() => query = v.trim().toLowerCase()),
                ),
              ),
            if (count > 0 && !keyboard && !compact)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text('已選 ', style: TextStyle(fontSize: 12, color: muted)),
                      for (final v in selectedText)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _ValueTag(text: v, theme: widget.theme),
                        ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: Row(
                children: [
                  Text(
                    query.isEmpty ? '全部選項' : '搜尋結果',
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filtered.length} 項',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final columns = compact && box.maxWidth >= 340 ? 2 : 1;
                  final width =
                      (box.maxWidth - 40 - (columns - 1) * 10) / columns;
                  return Scrollbar(
                    controller: optionsController,
                    child: ListView(
                      controller: optionsController,
                      key: const ValueKey('pet-menu-options'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      children: [
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 34,
                                  color: muted,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '找不到符合的選項',
                                  style: TextStyle(
                                    color: ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.allowCustom
                                      ? '換個關鍵字，或選「其他」自行填寫'
                                      : '試試其他關鍵字',
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 9,
                          children: [
                            for (final o in filtered)
                              SizedBox(
                                width: width,
                                child: choice(
                                  display(o),
                                  selected.contains(o),
                                  () => toggle(o, !selected.contains(o)),
                                ),
                              ),
                          ],
                        ),
                        if (widget.allowCustom) ...[
                          const SizedBox(height: 14),
                          choice(
                            '其他（自行填寫）',
                            other,
                            toggleOther,
                            leading: Icons.edit_note_rounded,
                            subtitle: '清單沒有適合的選項？在這裡補充',
                          ),
                          if (other)
                            Padding(
                              key: customKey,
                              padding: const EdgeInsets.only(top: 12),
                              child: TextField(
                                controller: custom,
                                maxLength: 500,
                                minLines: 1,
                                maxLines: 3,
                                style: TextStyle(color: ink, fontSize: 14),
                                decoration: input(
                                  '請填寫${widget.label}',
                                  label: '其他${widget.label}',
                                ).copyWith(errorText: error),
                                onChanged: (_) {
                                  setState(() => error = null);
                                },
                              ),
                            ),
                        ],
                        if (error != null && !other)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: widget.theme.cardColor,
                border: Border(
                  top: BorderSide(color: ink.withValues(alpha: 0.07)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            count == 0 ? '尚未選擇' : '已選擇 $count 項',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                          const Spacer(),
                          if (!widget.requiredValue)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  selected.clear();
                                  other = false;
                                  error = null;
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: muted,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('不填寫／清除'),
                            ),
                          if (widget.requiredValue)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                '必填項目',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: confirm,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 20),
                          label: const Text(
                            '確認選擇',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 檔案名稱：lib/features/shop/widgets/booking/daycare_addon_selector.dart
// 功能說明：安親加購 UI 對齊住宿分類卡；計價規則不變

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/daycare_addon_catalog.dart';
import 'package:petnest_saas/core/services/daycare_addon_line.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/features/shop/widgets/booking/addon_item_card.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';

class DaycareAddonSelector extends StatelessWidget {
  const DaycareAddonSelector({
    super.key,
    required this.addons,
    required this.selectedAddonIds,
    required this.selectedPetIds,
    required this.pets,
    required this.addonPetIds,
    required this.addonSlotKeys,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
    required this.onToggleAddon,
    required this.onTogglePet,
    required this.onToggleSlot,
    this.theme = HomeThemeModel.classicDefault,
    this.addonSubtotal = 0,
    this.estimateTotal = 0,
    this.showFeeSummary = false,
    this.errorAddonIds = const <String>{},
    this.addonKeys,
  });

  final List<Map<String, dynamic>> addons;
  final Set<String> selectedAddonIds;
  final Iterable<String> selectedPetIds;
  final List<Map<String, dynamic>> pets;
  final Map<String, Set<String>> addonPetIds;
  final Map<String, Set<String>> addonSlotKeys;
  final DateTime scheduledStartAt;
  final DateTime scheduledEndAt;
  final ValueChanged<String> onToggleAddon;
  final void Function(String addonId, String petId) onTogglePet;
  final void Function(String addonId, String slotKey) onToggleSlot;
  final HomeThemeModel theme;
  final int addonSubtotal;
  final int estimateTotal;
  final bool showFeeSummary;
  final Set<String> errorAddonIds;
  final Map<String, GlobalKey>? addonKeys;

  String _petId(Map<String, dynamic> pet) {
    return (pet['petId'] ?? pet['id'] ?? '').toString();
  }

  String _petName(Map<String, dynamic> pet) {
    final String name = (pet['name'] ?? pet['petName'] ?? '').toString().trim();
    final String id = _petId(pet);
    return name.isEmpty ? id : name;
  }

  String? _petPhoto(Map<String, dynamic> pet) {
    final String url = (pet['photoUrl'] ?? pet['imageUrl'] ?? '')
        .toString()
        .trim();
    return url.isEmpty ? null : url;
  }

  @override
  Widget build(BuildContext context) {
    if (addons.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<Widget> sections = <Widget>[];
    for (final Map<String, String> group in DaycareAddonCatalog.groups) {
      final String key = group['key'] ?? '';
      final List<Map<String, dynamic>> items = addons
          .where(
            (Map<String, dynamic> addon) =>
                DaycareAddonLine.groupKeyOf(addon) == key,
          )
          .toList();
      if (items.isEmpty) {
        continue;
      }
      final int selectedCount = items
          .where(
            (Map<String, dynamic> addon) =>
                selectedAddonIds.contains((addon['id'] ?? '').toString()),
          )
          .length;
      sections.add(
        _DaycareAddonCategoryCard(
          theme: theme,
          title: group['label'] ?? key,
          selectedCount: selectedCount,
          children: items.map(_item).toList(),
        ),
      );
    }
    if (showFeeSummary) {
      sections.add(
        BookingThemedCard(
          theme: theme,
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '已選 ${selectedAddonIds.length} 項服務',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                  Text(
                    '加購 ${ShopReportFormat.money(addonSubtotal)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '預估總額 ${ShopReportFormat.money(estimateTotal)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Widget _item(Map<String, dynamic> addon) {
    final String id = (addon['id'] ?? '').toString();
    final bool selected = selectedAddonIds.contains(id);
    final String group = DaycareAddonLine.groupKeyOf(addon);
    final int price = (addon['price'] as num?)?.toInt() ?? 0;
    final Set<String> petsForAddon = addonPetIds[id] ?? <String>{};
    final Set<String> slotsForAddon = addonSlotKeys[id] ?? <String>{};
    final String desc =
        (addon['desc'] ?? addon['description'] ?? addon['note'] ?? '')
            .toString()
            .trim();
    final String chargeHint = DaycareAddonCatalog.chargeLabel(addon);
    String? subtotalText;
    if (selected && group == DaycareAddonLine.groupCustom) {
      subtotalText =
          '${DaycarePlanModel.moneyLabel(price)} × ${petsForAddon.length} 隻 = '
          '${DaycarePlanModel.moneyLabel(price * petsForAddon.length)}';
    }
    if (selected && group == DaycareAddonLine.groupDailyTimed) {
      final int qty = petsForAddon.length * slotsForAddon.length;
      subtotalText =
          '${DaycarePlanModel.moneyLabel(price)} × ${petsForAddon.length} 隻 × '
          '${slotsForAddon.length} 個時段 = ${DaycarePlanModel.moneyLabel(price * qty)}';
    }
    final bool error = errorAddonIds.contains(id);

    return KeyedSubtree(
      key: addonKeys?[id],
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: error ? const EdgeInsets.all(8) : EdgeInsets.zero,
        decoration: error
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade400, width: 1.5),
                color: Colors.red.shade50,
              )
            : null,
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: () => onToggleAddon(id),
          borderRadius: BorderRadius.circular(10),
          child: AddonItemCard(
            item: <String, dynamic>{
              'name': DaycareAddonCatalog.displayName(addon),
              'desc': desc.isEmpty ? chargeHint : desc,
              'price': price,
            },
            isSelected: selected,
          ),
        ),
        if (selected &&
            (group == DaycareAddonLine.groupCustom ||
                group == DaycareAddonLine.groupDailyTimed))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.primaryColor.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '選擇服務寵物',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilterChip(
                      label: const Text('全部寵物'),
                      selected:
                          selectedPetIds.isNotEmpty &&
                          selectedPetIds.every(petsForAddon.contains) &&
                          petsForAddon.length == selectedPetIds.length,
                      onSelected: (_) {
                        for (final String petId in selectedPetIds) {
                          if (!petsForAddon.contains(petId)) {
                            onTogglePet(id, petId);
                          }
                        }
                        for (final String petId in petsForAddon.toList()) {
                          if (!selectedPetIds.contains(petId)) {
                            onTogglePet(id, petId);
                          }
                        }
                      },
                    ),
                    ...pets
                        .where(
                          (Map<String, dynamic> pet) =>
                              selectedPetIds.contains(_petId(pet)),
                        )
                        .map((Map<String, dynamic> pet) {
                          final String petId = _petId(pet);
                          final String? photo = _petPhoto(pet);
                          return FilterChip(
                            avatar: CircleAvatar(
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: photo != null
                                  ? NetworkImage(photo)
                                  : null,
                              child: photo == null
                                  ? const Icon(Icons.pets, size: 16)
                                  : null,
                            ),
                            label: Text(_petName(pet)),
                            selected: petsForAddon.contains(petId),
                            onSelected: (_) => onTogglePet(id, petId),
                          );
                        }),
                  ],
                ),
                if (group == DaycareAddonLine.groupDailyTimed) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    '選擇時段',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '僅顯示完整落在送達～接回時間內的時段',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textColor.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        DaycareAddonLine.slotsFullyInside(
                          timeSlots: (addon['timeSlots'] is List)
                              ? (addon['timeSlots'] as List)
                                    .whereType<Map>()
                                    .map(
                                      (Map<dynamic, dynamic> item) =>
                                          Map<String, dynamic>.from(item),
                                    )
                                    .toList()
                              : const <Map<String, dynamic>>[],
                          scheduledStartAt: scheduledStartAt,
                          scheduledEndAt: scheduledEndAt,
                        ).map((Map<String, dynamic> slot) {
                          final String key =
                              ((slot['id'] ?? '').toString().trim().isNotEmpty
                                      ? slot['id']
                                      : slot['label'])
                                  .toString();
                          final String label = (slot['label'] ?? key)
                              .toString();
                          final bool slotOn =
                              slotsForAddon.contains(key) ||
                              slotsForAddon.contains(label);
                          return FilterChip(
                            label: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 2,
                              ),
                              child: Text(label),
                            ),
                            selected: slotOn,
                            onSelected: (_) => onToggleSlot(id, key),
                          );
                        }).toList(),
                  ),
                ],
                if (subtotalText != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    subtotalText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (error)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              '請選擇要使用此服務的寵物',
              style: TextStyle(
                color: Color(0xFFC62828),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
      ],
    ),
      ),
    );
  }
}

class _DaycareAddonCategoryCard extends StatelessWidget {
  const _DaycareAddonCategoryCard({
    required this.theme,
    required this.title,
    required this.children,
    this.selectedCount = 0,
  });

  final HomeThemeModel theme;
  final String title;
  final int selectedCount;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedCount > 0
              ? const Color(0xFF2E8B47)
              : theme.cardBorderColor,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('daycare_addon_category_$title'),
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
              ),
              if (selectedCount > 0)
                Text(
                  '已選 $selectedCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E8B47),
                  ),
                ),
            ],
          ),
          children: children,
        ),
      ),
    );
  }
}

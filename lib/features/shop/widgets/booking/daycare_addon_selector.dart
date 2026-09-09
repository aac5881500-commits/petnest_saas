// 檔案名稱：lib/features/shop/widgets/booking/daycare_addon_selector.dart
// 功能說明：安親前台／後台加購：客製選寵物、分時段選寵物與時段

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/services/daycare_addon_catalog.dart';
import 'package:petnest_saas/core/services/daycare_addon_line.dart';

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

  String _petId(Map<String, dynamic> pet) {
    return (pet['petId'] ?? pet['id'] ?? '').toString();
  }

  String _petName(Map<String, dynamic> pet) {
    final String name = (pet['name'] ?? pet['petName'] ?? '').toString().trim();
    final String id = _petId(pet);
    return name.isEmpty ? id : name;
  }

  @override
  Widget build(BuildContext context) {
    if (addons.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: addons.map(_item).toList(),
    );
  }

  Widget _item(Map<String, dynamic> addon) {
    final String id = (addon['id'] ?? '').toString();
    final bool selected = selectedAddonIds.contains(id);
    final String group = DaycareAddonLine.groupKeyOf(addon);
    final int price = (addon['price'] as num?)?.toInt() ?? 0;
    final Set<String> petsForAddon = addonPetIds[id] ?? <String>{};
    final Set<String> slotsForAddon = addonSlotKeys[id] ?? <String>{};
    String amountHint = DaycareAddonCatalog.chargeLabel(addon);
    if (selected && group == DaycareAddonLine.groupCustom) {
      amountHint =
          '${DaycarePlanModel.moneyLabel(price)} × ${petsForAddon.length} 隻 = '
          '${DaycarePlanModel.moneyLabel(price * petsForAddon.length)}';
    }
    if (selected && group == DaycareAddonLine.groupDailyTimed) {
      final int qty = petsForAddon.length * slotsForAddon.length;
      amountHint =
          '${DaycarePlanModel.moneyLabel(price)} × ${petsForAddon.length} 隻 × '
          '${slotsForAddon.length} 時段 = ${DaycarePlanModel.moneyLabel(price * qty)}';
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CheckboxListTile(
              value: selected,
              title: Text(DaycareAddonCatalog.displayName(addon)),
              subtitle: Text(
                '${DaycarePlanModel.moneyLabel(price)}　$amountHint',
              ),
              onChanged: (_) => onToggleAddon(id),
            ),
            if (selected &&
                (group == DaycareAddonLine.groupCustom ||
                    group == DaycareAddonLine.groupDailyTimed))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '選擇寵物',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
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
                              return FilterChip(
                                label: Text(_petName(pet)),
                                selected: petsForAddon.contains(petId),
                                onSelected: (_) => onTogglePet(id, petId),
                              );
                            }),
                      ],
                    ),
                    if (group == DaycareAddonLine.groupDailyTimed) ...<Widget>[
                      const SizedBox(height: 10),
                      const Text(
                        '選擇時段（需完整落在送達～接回時間內）',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            DaycareAddonLine.slotsFullyInside(
                              timeSlots: (addon['timeSlots'] is List)
                                  ? (addon['timeSlots'] as List)
                                        .whereType<Map>()
                                        .map(
                                          (Map item) =>
                                              Map<String, dynamic>.from(item),
                                        )
                                        .toList()
                                  : const <Map<String, dynamic>>[],
                              scheduledStartAt: scheduledStartAt,
                              scheduledEndAt: scheduledEndAt,
                            ).map((Map<String, dynamic> slot) {
                              final String key =
                                  ((slot['id'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty
                                          ? slot['id']
                                          : slot['label'])
                                      .toString();
                              final String label = (slot['label'] ?? key)
                                  .toString();
                              return FilterChip(
                                label: Text(label),
                                selected:
                                    slotsForAddon.contains(key) ||
                                    slotsForAddon.contains(label),
                                onSelected: (_) => onToggleSlot(id, key),
                              );
                            }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

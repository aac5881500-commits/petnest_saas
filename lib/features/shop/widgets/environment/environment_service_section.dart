// 檔案：lib/features/shop/widgets/environment/environment_service_section.dart
// 功能：設備與服務分類、獨立版型及展開收合，預覽與前台共用。
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'package:petnest_saas/core/models/environment_presentation.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/data/environment_facility_options.dart';
import 'environment_care_item.dart';

class EnvironmentServiceSection extends StatefulWidget {
  const EnvironmentServiceSection({
    super.key,
    required this.presentation,
    required this.items,
    required this.theme,
    required this.style,
    required this.iconOf,
    required this.imageBuilder,
  });
  final EnvironmentPresentation presentation;
  final List<Map<String, dynamic>> items;
  final HomeThemeModel theme;
  final EnvironmentIntroStyle style;
  final IconData Function(String) iconOf;
  final Widget Function({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit,
  })
  imageBuilder;
  @override
  State<EnvironmentServiceSection> createState() =>
      _EnvironmentServiceSectionState();
}

class _EnvironmentServiceSectionState extends State<EnvironmentServiceSection> {
  bool _allEquipment = false;
  bool _allServices = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.presentation;
    final equipment = widget.items
        .where((m) => !p.hiddenFacilityKeys.contains(m['key']))
        .map((m) => {...m, 'category': environmentFacilityCategory(m)})
        .toList();
    final order = p.facilityOrder;
    equipment.sort((a, b) {
      final ai = order.indexOf(a['key'] as String),
          bi = order.indexOf(b['key'] as String);
      return (ai < 0
              ? order.length +
                    widget.items.indexWhere((m) => m['key'] == a['key'])
              : ai)
          .compareTo(
            bi < 0
                ? order.length +
                      widget.items.indexWhere((m) => m['key'] == b['key'])
                : bi,
          );
    });
    final fixedServices = equipment
        .where((m) => m['category'] == 'service')
        .toList();
    equipment.removeWhere((m) => m['category'] == 'service');
    final services = [
      ...fixedServices,
      ...p.services
          .where((s) => s.visible)
          .map(
            (s) => {
              ...s.toMap(),
              'title': s.title,
              'description': s.description,
              'imageUrl': s.imageUrl,
              'icon': widget.iconOf(s.icon),
              'category': s.category,
              'tag': s.tag,
            },
          ),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.style.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (equipment.isNotEmpty)
            ..._group(
              '安心設備',
              equipment,
              p.equipmentLayout,
              _allEquipment,
              () => setState(() => _allEquipment = !_allEquipment),
            ),
          if (services.isNotEmpty)
            ..._group(
              '貼心服務',
              services,
              p.serviceLayout,
              _allServices,
              () => setState(() => _allServices = !_allServices),
            ),
        ],
      ),
    );
  }

  List<Widget> _group(
    String title,
    List<Map<String, dynamic>> items,
    String layout,
    bool expanded,
    VoidCallback toggle,
  ) {
    final visible = expanded ? items : items.take(6).toList();
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: widget.style.sectionTitleSize,
            color: widget.theme.textColor,
          ),
        ),
      ),
      for (final category in EnvironmentPresentation.categories.entries)
        if (visible.any((m) => m['category'] == category.key)) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              category.value,
              style: TextStyle(
                color: widget.theme.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final minWidth = layout == 'icon' ? 96.0 : 156.0;
              final cols = layout == 'list'
                  ? 1
                  : math.max(
                      1,
                      math.min(
                        layout == 'icon' ? 6 : 4,
                        ((constraints.maxWidth + 10) /
                                ((widget.style.fontSize == 'large'
                                            ? minWidth * 1.2
                                            : minWidth) *
                                        textScale +
                                    10))
                            .floor(),
                      ),
                    );
              final rows = visible
                  .where((m) => m['category'] == category.key)
                  .toList();
              return Column(
                children: [
                  for (var start = 0; start < rows.length; start += cols)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(
                          cols,
                          (index) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: index == cols - 1 ? 0 : 10,
                              ),
                              child: start + index >= rows.length
                                  ? const SizedBox.shrink()
                                  : _card(rows[start + index], layout),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      if (items.length > 6)
        TextButton(
          onPressed: toggle,
          child: Text(expanded ? '收合' : '查看全部（${items.length}）'),
        ),
    ];
  }

  Widget _card(Map<String, dynamic> item, String layout) {
    final title = (item['title'] ?? '').toString();
    final description = (item['description'] ?? '').toString();
    final tag = const {
      'included': '包含服務',
      'contact': '需另洽',
      'paid': '另計費',
    }[item['tag']];
    return EnvironmentCareItem(
      icon: item['icon'] is IconData ? item['icon'] as IconData : Icons.pets,
      title: title,
      subtitle: description,
      theme: widget.theme,
      layout: layout,
      tag: tag,
      imageUrl: (item['imageUrl'] ?? '').toString(),
      imageBuilder: widget.imageBuilder,
      titleSize: widget.style.careTitleSize,
      subtitleSize: widget.style.careDescriptionSize,
      radius: widget.presentation.preset == 'minimal'
          ? 6
          : widget.style.cardRadius,
    );
  }
}

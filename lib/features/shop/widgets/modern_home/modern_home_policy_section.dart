import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_entry_card.dart';

/// 新版首頁入住須知。正式前台與外觀預覽共用。
class ModernHomePolicySection extends StatelessWidget {
  const ModernHomePolicySection({
    super.key,
    required this.theme,
    required this.setting,
    required this.snapshot,
    required this.phase,
    required this.onOpen,
  });

  final HomeThemeModel theme;
  final HomePolicySectionSetting setting;
  final HomePolicySnapshot snapshot;
  final HomeInfoSectionPhase phase;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (phase == HomeInfoSectionPhase.hidden) {
      return const SizedBox.shrink();
    }
    if (phase == HomeInfoSectionPhase.loading) {
      return _skeleton();
    }
    if (phase == HomeInfoSectionPhase.unavailable ||
        phase == HomeInfoSectionPhase.empty) {
      return ModernHomePolicySection(
        theme: theme,
        setting: setting,
        snapshot: const HomePolicySnapshot(
          version: 1,
          coverageLabel: '住宿與安親',
          titles: <String>['示意：入住時間', '示意：接送規定', '示意：疫苗證明'],
          stayTitles: <String>['示意：入住時間'],
          daycareTitles: <String>['示意：接送規定'],
        ),
        phase: HomeInfoSectionPhase.ready,
        onOpen: onOpen,
      );
    }
    if (!snapshot.hasContent) {
      return _empty();
    }
    return switch (HomePolicyLayouts.migrate(setting.layout)) {
      HomePolicyLayouts.singleLine => _entry(wide: true),
      HomePolicyLayouts.summary => _summary(),
      HomePolicyLayouts.serviceSplit => _split(),
      _ => _entry(wide: false),
    };
  }

  String get _primaryService {
    if (snapshot.hasStay || !snapshot.hasDaycare) {
      return PolicyApplicableService.accommodation;
    }
    return PolicyApplicableService.daycare;
  }

  Widget _entry({required bool wide}) {
    return ModernHomeEntryCard(
      cardKey: const Key('home-policy-card'),
      theme: theme,
      title: setting.entryTitle,
      subtitle: setting.entrySubtitle,
      showSubtitle: true,
      cardSize: wide ? 'wide' : 'small',
      surface: 'filled',
      icon: Icons.description_outlined,
      onTap: () => onOpen(_primaryService),
    );
  }

  Widget _split() {
    final List<_PolicyDoor> doors = <_PolicyDoor>[
      if (snapshot.hasStay)
        const _PolicyDoor(
          serviceType: PolicyApplicableService.accommodation,
          title: '住宿入住須知',
        ),
      if (snapshot.hasDaycare)
        const _PolicyDoor(
          serviceType: PolicyApplicableService.daycare,
          title: '安親服務須知',
        ),
    ];
    if (doors.isEmpty) {
      return _entry(wide: true);
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked = doors.length > 1 && constraints.maxWidth < 280;
        if (doors.length == 1 || stacked) {
          return Column(
            children: <Widget>[
              for (int index = 0; index < doors.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(height: 8),
                _door(doors[index]),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: _door(doors[0])),
            const SizedBox(width: 8),
            Expanded(child: _door(doors[1])),
          ],
        );
      },
    );
  }

  Widget _door(_PolicyDoor door) {
    return ModernHomeEntryCard(
      cardKey: Key('home-policy-${door.serviceType}'),
      theme: theme,
      title: door.title,
      subtitle: setting.entrySubtitle,
      showSubtitle: true,
      cardSize: 'wide',
      surface: 'filled',
      icon: Icons.description_outlined,
      onTap: () => onOpen(door.serviceType),
    );
  }

  Widget _summary() {
    final int count = HomePolicySectionSetting.migrateSummaryCount(
      setting.summaryItemCount,
    );
    final List<String> titles = snapshot.titles.take(count).toList();
    return _shell(
      child: InkWell(
        key: const Key('home-policy-card'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => onOpen(_primaryService),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                setting.entryTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  if (setting.showVersion) _chip('v${snapshot.version}'),
                  if (setting.showCoverage && snapshot.coverageLabel.isNotEmpty)
                    _chip(snapshot.coverageLabel),
                ],
              ),
              const SizedBox(height: 8),
              for (final String title in titles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.circle, size: 6, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: theme.textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('home-policy-open'),
                  onPressed: () => onOpen(_primaryService),
                  child: const Text('查看完整入住須知'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    final String layout = HomePolicyLayouts.migrate(setting.layout);
    if (layout == HomePolicyLayouts.summary) {
      return _shell(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            kHomePolicyEmptyMessage,
            key: const Key('home-policy-card'),
            style: TextStyle(color: theme.secondaryTextColor, height: 1.35),
          ),
        ),
      );
    }
    return ModernHomeEntryCard(
      cardKey: const Key('home-policy-card'),
      theme: theme,
      title: setting.entryTitle,
      subtitle: kHomePolicyEmptyMessage,
      showSubtitle: true,
      cardSize: layout == HomePolicyLayouts.singleLine ? 'wide' : 'small',
      surface: 'filled',
      icon: Icons.description_outlined,
      onTap: () => onOpen(_primaryService),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: theme.primaryColor,
        ),
      ),
    );
  }

  Widget _skeleton() {
    final double height = switch (HomePolicyLayouts.migrate(setting.layout)) {
      HomePolicyLayouts.singleLine => kModernHomeWideCardHeight,
      HomePolicyLayouts.summary => 148,
      _ => kModernHomeSmallCardHeight,
    };
    return SizedBox(
      key: const Key('home-policy-skeleton'),
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.cardColor.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _shell({required Widget child}) {
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.cardBorderColor),
        ),
        child: child,
      ),
    );
  }
}

class _PolicyDoor {
  const _PolicyDoor({required this.serviceType, required this.title});

  final String serviceType;
  final String title;
}

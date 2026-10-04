import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_entry_card.dart';

/// 新版首頁常見問題。正式前台與外觀預覽共用。
class ModernHomeFaqSection extends StatelessWidget {
  const ModernHomeFaqSection({
    super.key,
    required this.theme,
    required this.setting,
    required this.items,
    required this.phase,
    required this.onOpen,
  });

  final HomeThemeModel theme;
  final HomeFaqSectionSetting setting;
  final List<HomeFaqItem> items;
  final HomeInfoSectionPhase phase;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (phase == HomeInfoSectionPhase.hidden) {
      return const SizedBox.shrink();
    }
    if (phase == HomeInfoSectionPhase.loading) {
      return _skeleton();
    }
    final bool empty =
        phase == HomeInfoSectionPhase.unavailable ||
        phase == HomeInfoSectionPhase.empty ||
        items.isEmpty;
    final List<HomeFaqItem> source = empty ? _samples : items;
    return switch (HomeFaqLayouts.migrate(setting.layout)) {
      HomeFaqLayouts.singleLine => _entry(source, wide: true, empty: empty),
      HomeFaqLayouts.preview => _FaqPreview(
        theme: theme,
        setting: setting,
        items: source,
        empty: empty,
        onOpen: onOpen,
      ),
      HomeFaqLayouts.horizontalCards => _horizontal(source, empty),
      HomeFaqLayouts.twoColumnCards => _columns(source, empty),
      _ => _entry(source, wide: false, empty: empty),
    };
  }

  List<HomeFaqItem> get _samples {
    return const <HomeFaqItem>[
      HomeFaqItem(
        id: 'sample-1',
        question: '示意問題：入住前需要準備什麼？',
        answer: kHomeFaqEmptyMessage,
        sortOrder: 1,
      ),
      HomeFaqItem(
        id: 'sample-2',
        question: '示意問題：可以臨時取消嗎？',
        answer: kHomeFaqEmptyMessage,
        sortOrder: 2,
      ),
    ];
  }

  Widget _entry(
    List<HomeFaqItem> source, {
    required bool wide,
    required bool empty,
  }) {
    final String subtitle = empty
        ? kHomeFaqEmptyMessage
        : setting.showQuestionCount
        ? '共 ${source.length} 個常見問題'
        : setting.entrySubtitle;
    return ModernHomeEntryCard(
      cardKey: const Key('home-faq-card'),
      theme: theme,
      title: setting.entryTitle,
      subtitle: subtitle,
      showSubtitle: true,
      cardSize: wide ? 'wide' : 'small',
      surface: 'filled',
      icon: Icons.help_outline_rounded,
      onTap: onOpen,
    );
  }

  Widget _horizontal(List<HomeFaqItem> source, bool empty) {
    final int count = HomeFaqSectionSetting.migratePreviewCount(
      setting.previewCount,
    );
    final List<HomeFaqItem> visible = source.take(count).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          setting.entryTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: theme.textColor,
          ),
        ),
        if (empty)
          Text(
            kHomeFaqEmptyMessage,
            style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
          ),
        const SizedBox(height: 8),
        SizedBox(
          key: const Key('home-faq-card'),
          height: setting.showAnswerPreview ? 108 : 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visible.length + (setting.showViewAll ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              if (index >= visible.length) {
                return _allCard(width: 96);
              }
              return _questionCard(visible[index], index, width: 168);
            },
          ),
        ),
      ],
    );
  }

  Widget _columns(List<HomeFaqItem> source, bool empty) {
    final int count = HomeFaqSectionSetting.migratePreviewCount(
      setting.previewCount,
    );
    final List<HomeFaqItem> visible = source.take(count).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          setting.entryTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: theme.textColor,
          ),
        ),
        if (empty)
          Text(
            kHomeFaqEmptyMessage,
            style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
          ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double gap = 8;
            final bool stacked = constraints.maxWidth < 180;
            final double cardWidth = stacked
                ? constraints.maxWidth
                : (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (int index = 0; index < visible.length; index++)
                  SizedBox(
                    width: cardWidth,
                    child: _questionCard(visible[index], index),
                  ),
              ],
            );
          },
        ),
        if (setting.showViewAll)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('home-faq-see-all'),
              onPressed: onOpen,
              child: const Text('查看全部常見問題'),
            ),
          ),
      ],
    );
  }

  Widget _questionCard(HomeFaqItem item, int index, {double? width}) {
    return SizedBox(
      width: width,
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.cardBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _leading(index),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.question,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (setting.showAnswerPreview)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      item.answer.isEmpty ? '尚未填寫回答' : item.answer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.secondaryTextColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leading(int index) {
    if (HomeFaqLeadingStyles.migrate(setting.leadingStyle) ==
        HomeFaqLeadingStyles.number) {
      return Text(
        '${index + 1}',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: theme.primaryColor,
        ),
      );
    }
    return Icon(
      Icons.help_outline_rounded,
      size: 18,
      color: theme.primaryColor,
    );
  }

  Widget _allCard({required double width}) {
    return SizedBox(
      width: width,
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const Key('home-faq-see-all'),
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.cardBorderColor),
            ),
            child: Text(
              '查看全部',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeleton() {
    final double height = switch (HomeFaqLayouts.migrate(setting.layout)) {
      HomeFaqLayouts.singleLine => kModernHomeWideCardHeight,
      HomeFaqLayouts.preview => 148,
      _ => kModernHomeSmallCardHeight,
    };
    return SizedBox(
      key: const Key('home-faq-skeleton'),
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
}

class _FaqPreview extends StatefulWidget {
  const _FaqPreview({
    required this.theme,
    required this.setting,
    required this.items,
    required this.empty,
    required this.onOpen,
  });

  final HomeThemeModel theme;
  final HomeFaqSectionSetting setting;
  final List<HomeFaqItem> items;
  final bool empty;
  final VoidCallback onOpen;

  @override
  State<_FaqPreview> createState() => _FaqPreviewState();
}

class _FaqPreviewState extends State<_FaqPreview> {
  String? _openId;

  @override
  Widget build(BuildContext context) {
    final int count = HomeFaqSectionSetting.migratePreviewCount(
      widget.setting.previewCount,
    );
    final List<HomeFaqItem> visible = widget.items.take(count).toList();
    return Material(
      key: const Key('home-faq-card'),
      color: widget.theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.theme.cardBorderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.setting.entryTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: widget.theme.textColor,
                ),
              ),
              if (widget.empty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    kHomeFaqEmptyMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.theme.secondaryTextColor,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              for (int index = 0; index < visible.length; index++)
                _row(visible[index], index),
              if (widget.setting.showViewAll)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('home-faq-see-all'),
                    onPressed: widget.onOpen,
                    child: const Text('查看全部常見問題'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(HomeFaqItem item, int index) {
    final bool open = _openId == item.id;
    return Column(
      children: <Widget>[
        InkWell(
          key: Key('home-faq-item-${item.id}'),
          onTap: () {
            setState(() {
              _openId = open ? null : item.id;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: <Widget>[
                widget.setting.leadingStyle == HomeFaqLeadingStyles.number
                    ? Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: widget.theme.primaryColor,
                        ),
                      )
                    : Icon(
                        Icons.help_outline_rounded,
                        size: 18,
                        color: widget.theme.primaryColor,
                      ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: widget.theme.textColor,
                    ),
                  ),
                ),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  color: widget.theme.secondaryTextColor,
                ),
              ],
            ),
          ),
        ),
        if (open)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 72),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 26, bottom: 8),
              child: Text(
                item.answer.isEmpty ? '尚未填寫回答' : item.answer,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: widget.theme.secondaryTextColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

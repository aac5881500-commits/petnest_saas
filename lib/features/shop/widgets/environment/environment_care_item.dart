// 檔案名稱：lib/features/shop/widgets/environment/environment_care_item.dart
// 功能說明：環境介紹安心照護小卡
// 顯示照護設備：Icon、標題、簡短說明

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class EnvironmentCareItem extends StatelessWidget {
  const EnvironmentCareItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.theme = HomeThemeModel.classicDefault,
    this.titleSize = 13,
    this.subtitleSize = 11,
    this.iconSize = 23,
    this.padding = 10,
    this.avatarRadius = 21,
    this.radius = 18,
    this.layout = 'legacy',
    this.tag,
    this.imageUrl = '',
    this.imageBuilder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final HomeThemeModel theme;
  final double titleSize;
  final double subtitleSize;
  final double iconSize;
  final double padding;
  final double avatarRadius;
  final double radius;
  final String layout;
  final String? tag;
  final String imageUrl;
  final Widget Function({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit,
  })?
  imageBuilder;

  @override
  Widget build(BuildContext context) {
    if (layout != 'legacy') return _modernCard(context);
    return InkWell(
      onTap: () => _showDetails(context),
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: theme.cardBorderColor),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: theme.primaryColor.withValues(alpha: 0.12),
              child: Icon(icon, color: theme.primaryColor, size: iconSize),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                height: 1.2,
                color: theme.textColor,
              ),
            ),
            if (subtitle.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: subtitleSize,
                  height: 1.3,
                  color: theme.textColor.withValues(alpha: 0.68),
                ),
              ),
            ],
            if (tag != null) ...[
              const SizedBox(height: 8),
              Text(
                tag!,
                style: TextStyle(
                  fontSize: subtitleSize,
                  color: theme.textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text([if (subtitle.isNotEmpty) subtitle, ?tag].join('\n')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _modernCard(BuildContext context) {
    final avatar = Icon(icon, size: iconSize, color: theme.primaryColor);
    final text = Column(
      crossAxisAlignment: layout == 'icon'
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: layout == 'icon' ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        if (layout != 'icon' && subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: subtitleSize,
              height: 1.45,
              color: theme.textColor,
            ),
          ),
        ],
        if (layout != 'icon' && tag != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tag!,
              style: TextStyle(fontSize: subtitleSize, color: theme.textColor),
            ),
          ),
        ],
      ],
    );
    return InkWell(
      onTap: layout == 'icon' ? () => _showDetails(context) : null,
      child: Container(
        constraints: BoxConstraints(
          minHeight: layout == 'icon'
              ? 88
              : layout == 'square'
              ? 140
              : 64,
        ),
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: theme.cardBorderColor),
        ),
        child: layout == 'list'
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(child: text),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (layout == 'photo' &&
                      imageUrl.isNotEmpty &&
                      imageBuilder != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(radius / 2),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: imageBuilder!(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Align(
                      alignment: layout == 'icon'
                          ? Alignment.center
                          : Alignment.centerLeft,
                      child: avatar,
                    ),
                    const SizedBox(height: 8),
                  ],
                  text,
                ],
              ),
      ),
    );
  }
}

// 舊資料保持原有卡片外觀，也能在項目較多時展開／收合。
class EnvironmentLegacyCareGrid extends StatefulWidget {
  const EnvironmentLegacyCareGrid({
    super.key,
    required this.items,
    required this.theme,
    required this.style,
  });
  final List<Map<String, dynamic>> items;
  final HomeThemeModel theme;
  final EnvironmentIntroStyle style;
  @override
  State<EnvironmentLegacyCareGrid> createState() =>
      _EnvironmentLegacyCareGridState();
}

class _EnvironmentLegacyCareGridState extends State<EnvironmentLegacyCareGrid> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final items = _expanded ? widget.items : widget.items.take(6).toList();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: style.pagePadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = style.careColumns(constraints.maxWidth);
          final width =
              (constraints.maxWidth - style.careSpacing * (cols - 1)) / cols;
          return Column(
            children: [
              Wrap(
                spacing: style.careSpacing,
                runSpacing: style.careSpacing,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: width,
                      child: EnvironmentCareItem(
                        icon: item['icon'] is IconData
                            ? item['icon'] as IconData
                            : Icons.pets,
                        title: (item['title'] ?? '').toString(),
                        subtitle: (item['description'] ?? '').toString(),
                        theme: widget.theme,
                        titleSize: style.careTitleSize,
                        subtitleSize: style.careDescriptionSize,
                        iconSize: style.careIconSize,
                        padding: style.carePadding,
                        avatarRadius: style.careAvatarRadius,
                        radius: style.cardRadius - 2,
                      ),
                    ),
                ],
              ),
              if (widget.items.length > 6)
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? '收合' : '查看全部（${widget.items.length}）',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

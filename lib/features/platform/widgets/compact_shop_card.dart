// 檔案名稱：lib/features/platform/widgets/compact_shop_card.dart
// 功能說明：探索頁的輕量店家卡。封面獨立，店名與營業資訊排在背景上。

import 'package:flutter/material.dart';

class CompactShopCard extends StatefulWidget {
  const CompactShopCard({
    super.key,
    required this.name,
    required this.meta,
    required this.services,
    required this.imageUrl,
    required this.logoUrl,
    required this.isOpen,
    required this.onTap,
    required this.onFavorite,
    this.hours = '',
    this.roomy = false,
  });

  final String name;
  final Widget meta;
  final String services;
  final String imageUrl;
  final String logoUrl;
  final bool isOpen;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final String hours;
  final bool roomy;

  @override
  State<CompactShopCard> createState() => _CompactShopCardState();
}

class _CompactShopCardState extends State<CompactShopCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool roomy = widget.roomy;
    final double nameSize = roomy ? 16 : 14.5;
    final double serviceSize = roomy ? 12 : 11;
    final double hoursSize = roomy ? 12 : 11;
    final bool hasLogo = widget.logoUrl.trim().isNotEmpty;
    final String hours = widget.hours.trim();
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colors.shadow.withValues(
                      alpha: _hover ? 0.16 : 0.06,
                    ),
                    blurRadius: _hover ? 12 : 6,
                    offset: Offset(0, _hover ? 4 : 2),
                  ),
                ],
              ),
              child: AspectRatio(
                aspectRatio: roomy ? 1.72 : 1.65,
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          ColoredBox(
                            color: const Color(0xFFF3EBE3),
                            child: widget.imageUrl.trim().isEmpty
                                ? Icon(
                                    Icons.storefront_outlined,
                                    size: 22,
                                    color: colors.onSurfaceVariant,
                                  )
                                : Image.network(
                                    widget.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.storefront_outlined,
                                      size: 22,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                          const Positioned(
                            right: 8,
                            bottom: 6,
                            child: Icon(
                              Icons.pets,
                              size: 28,
                              color: Color(0x1AFFFFFF),
                            ),
                          ),
                          Positioned(
                            left: 6,
                            top: 6,
                            child: _StatusBadge(isOpen: widget.isOpen),
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: _FavoriteButton(
                              onPressed: widget.onFavorite,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasLogo)
                      Positioned(
                        left: 8,
                        bottom: -8,
                        child: _ShopBadge(url: widget.logoUrl),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: hasLogo ? 12 : 6),
            Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: nameSize,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(height: roomy ? 18 : 16, child: widget.meta),
            const SizedBox(height: 2),
            Text(
              widget.services,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: serviceSize,
                height: 1.2,
                color: colors.onSurfaceVariant,
              ),
            ),
            if (hours.isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                hours,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: hoursSize,
                  height: 1.15,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            Icons.favorite_border,
            size: 16,
            color: Color(0xFF8C4A55),
          ),
        ),
      ),
    );
  }
}

class _ShopBadge extends StatelessWidget {
  const _ShopBadge({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.network(
          url,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final Color background = isOpen
        ? const Color(0xFFE5F4EA)
        : const Color(0xFFF6E6E4);
    final Color foreground = isOpen
        ? const Color(0xFF2F7D4A)
        : const Color(0xFF8A5A56);
    return Container(
      height: 22,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOpen ? '營業中' : '休息中',
        maxLines: 1,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

String compactServiceLine(List<String> labels) {
  final List<String> clean = labels
      .map((String item) => _shortService(item.trim()))
      .where((String item) => item.isNotEmpty)
      .toList();
  if (clean.isEmpty) {
    return '服務詳見店家';
  }
  if (clean.length <= 3) {
    return clean.join(' · ');
  }
  return '${clean.take(3).join(' · ')} +${clean.length - 3}';
}

String _shortService(String label) {
  switch (label) {
    case '貓咪旅宿':
      return '貓旅';
    case '狗狗旅宿':
      return '狗旅';
    case '寵物美容':
      return '美容';
    case '動物醫院':
      return '醫院';
    case '寵物賣場':
      return '賣場';
    default:
      return label;
  }
}

// 功能：介紹頁設備自然增高，保留主題圖示與文字，不影響預約選房共用卡。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'room_intro_facts.dart';

class RoomIntroFeatures extends StatelessWidget {
  const RoomIntroFeatures({super.key, required this.room, required this.theme});
  final Map<String, dynamic> room;
  final HomeThemeModel theme;
  @override
  Widget build(BuildContext context) {
    final facts = RoomIntroFacts(room);
    return LayoutBuilder(
      builder: (context, c) {
        final columns =
            c.maxWidth >= 280 && MediaQuery.textScalerOf(context).scale(1) < 1.4
            ? 2
            : 1;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final feature in facts.featureItems)
              SizedBox(
                width: (c.maxWidth - (columns - 1) * 10) / columns,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 64),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.cardBorderColor),
                  ),
                  child: Row(
                    children: [
                      if ('${feature['emoji'] ?? ''}'.isNotEmpty)
                        Text(
                          '${feature['emoji']}',
                          style: const TextStyle(fontSize: 22),
                        )
                      else
                        Icon(
                          feature['icon'] as IconData? ?? Icons.pets_outlined,
                          color: theme.primaryColor,
                          size: 22,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${feature['name']}',
                          style: TextStyle(color: theme.textColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

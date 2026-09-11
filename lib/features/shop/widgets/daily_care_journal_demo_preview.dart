// 檔案名稱：lib/features/shop/widgets/daily_care_journal_demo_preview.dart
// 功能說明：日誌外觀預覽，共用顧客端背景與卡片渲染，使用固定示範資料。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/widgets/daily_care_card_surface.dart';

class DailyCareJournalDemoPreview extends StatelessWidget {
  const DailyCareJournalDemoPreview({
    super.key,
    required this.setting,
    this.pageImage,
    this.cardImage,
  });

  final DailyCareSettingModel setting;
  final ImageProvider? pageImage;
  final ImageProvider? cardImage;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DailyCareJournalPageBackground(
              setting: setting,
              imageOverride: pageImage,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 28, 14, 14),
              child: Column(
                children: <Widget>[
                  const Text(
                    '每日照護日誌',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text('示範房間 A01 · 入住中', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                  DailyCareCardSurface(
                    setting: setting,
                    imageOverride: cardImage,
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '早晨照護',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 6),
                        Text('飲水 一般　飼料 有吃'),
                        SizedBox(height: 8),
                        Text(
                          '今天精神很好，有好好吃飯喝水。',
                          style: TextStyle(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

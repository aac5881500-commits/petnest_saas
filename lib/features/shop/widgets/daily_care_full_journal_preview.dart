// 檔案名稱：lib/features/shop/widgets/daily_care_full_journal_preview.dart
// 功能說明：設定頁完整顧客日誌預覽，共用正式卡片與背景元件，使用示範資料。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_report_mode.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/widgets/daily_care_card_surface.dart';

class DailyCareFullJournalPreview extends StatelessWidget {
  const DailyCareFullJournalPreview({
    super.key,
    required this.setting,
    required this.isDaycare,
    required this.sessionLabels,
    required this.sessionIndex,
    this.shopName = '示範店家',
    this.shopLogoUrl = '',
    this.offerName = '示範房間',
    this.dateLabel = '2026/09/10',
    this.showPhotos = true,
    this.previewScale = 1,
    this.pageImage,
    this.cardImage,
  });

  final DailyCareSettingModel setting;
  final bool isDaycare;
  final List<String> sessionLabels;
  final int sessionIndex;
  final String shopName;
  final String shopLogoUrl;
  final String offerName;
  final String dateLabel;
  final bool showPhotos;
  final double previewScale;
  final ImageProvider? pageImage;
  final ImageProvider? cardImage;

  @override
  Widget build(BuildContext context) {
    final String title = isDaycare ? '本次安親回報' : '每日照護日誌';
    final String sessionName = sessionIndex < sessionLabels.length
        ? sessionLabels[sessionIndex]
        : '第 ${sessionIndex + 1} 次照護';
    final Color textColor = _color(setting.textColorKey, const Color(0xFF3A2A20));
    final Color accent = _color(setting.accentColorKey, const Color(0xFF8B5A2B));
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: const Color(0xFFEDE7E0),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 390 * previewScale,
            height: 720 * previewScale,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                DailyCareJournalPageBackground(
                  setting: setting,
                  imageOverride: pageImage,
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                  children: <Widget>[
                    _header(
                      title: title,
                      textColor: textColor,
                      accent: accent,
                    ),
                    const SizedBox(height: 10),
                    DailyCareCardSurface(
                      setting: setting,
                      imageOverride: cardImage,
                      padding: EdgeInsets.all(setting.cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            offerName,
                            style: TextStyle(
                              fontSize: setting.titleFontSize - 2,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '示範寵物 小米 · $dateLabel · $sessionName',
                            style: TextStyle(
                              fontSize: setting.bodyFontSize,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '已填寫  10:32',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: setting.cardGap),
                    DailyCareCardSurface(
                      setting: setting,
                      imageOverride: cardImage,
                      padding: EdgeInsets.all(setting.cardPadding),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '溫度 26°C',
                              style: TextStyle(
                                fontSize: setting.bodyFontSize,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '濕度 58%',
                              style: TextStyle(
                                fontSize: setting.bodyFontSize,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ..._categoryCards(textColor, accent, cardImage),
                    SizedBox(height: setting.cardGap),
                    DailyCareCardSurface(
                      setting: setting,
                      imageOverride: cardImage,
                      longText: true,
                      padding: EdgeInsets.all(setting.cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '文字備註',
                            style: TextStyle(
                              fontSize: setting.bodyFontSize,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '今天精神很好，有好好吃飯喝水。（示範值）',
                            style: TextStyle(
                              fontSize: setting.bodyFontSize,
                              height: 1.4,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: setting.cardGap),
                    DailyCareCardSurface(
                      setting: setting,
                      imageOverride: cardImage,
                      padding: EdgeInsets.all(setting.cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '照護照片',
                            style: TextStyle(
                              fontSize: setting.bodyFontSize,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _photoRow(showPhotos),
                          const SizedBox(height: 6),
                          Text(
                            DailyCareReportMode.photoShareNote,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: textColor.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header({
    required String title,
    required Color textColor,
    required Color accent,
  }) {
    final bool showLogo = setting.logoVisible && shopLogoUrl.trim().isNotEmpty;
    final Widget titleBlock = Column(
      crossAxisAlignment: setting.logoAlign == 'center'
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          shopName,
          style: TextStyle(
            fontSize: setting.titleFontSize,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: setting.bodyFontSize,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ],
    );
    if (!showLogo) {
      return titleBlock;
    }
    final Widget logo = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        shopLogoUrl,
        width: setting.logoSize,
        height: setting.logoSize,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
    if (setting.logoAlign == 'center') {
      return Column(
        children: <Widget>[
          logo,
          const SizedBox(height: 8),
          titleBlock,
        ],
      );
    }
    return Row(
      children: <Widget>[
        logo,
        const SizedBox(width: 10),
        Expanded(child: titleBlock),
      ],
    );
  }

  List<Widget> _categoryCards(
    Color textColor,
    Color accent,
    ImageProvider? cardImage,
  ) {
    final List<_PreviewGroup> groups = <_PreviewGroup>[
      _PreviewGroup('飲食', Icons.restaurant_outlined, const <String>[
        'dryFood',
        'wetFood',
        'snack',
      ], const <String>['有吃', '少許', '無']),
      _PreviewGroup('飲水', Icons.water_drop_outlined, const <String>[
        'water',
      ], const <String>['一般']),
      _PreviewGroup('大小便', Icons.check_circle_outline, const <String>[
        'stool',
        'urine',
      ], const <String>['正常', '正常']),
      _PreviewGroup('活動', Icons.sports_esports_outlined, const <String>[
        'wandToy',
        'scratchBoard',
        'jumpPlatform',
        'toyBall',
      ], const <String>['有', '有', '無', '有']),
    ];
    final List<Widget> out = <Widget>[];
    for (final _PreviewGroup group in groups) {
      final List<MapEntry<String, String>> items = <MapEntry<String, String>>[];
      for (int i = 0; i < group.keys.length; i++) {
        if (setting.enabledFields.contains(group.keys[i])) {
          items.add(MapEntry<String, String>(group.keys[i], group.values[i]));
        }
      }
      if (items.isEmpty) {
        continue;
      }
      out.add(SizedBox(height: setting.cardGap));
      out.add(
        DailyCareCardSurface(
          setting: setting,
          imageOverride: cardImage,
          padding: EdgeInsets.all(setting.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    group.icon,
                    size: setting.iconSize,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    group.title,
                    style: TextStyle(
                      fontSize: setting.bodyFontSize,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final MapEntry<String, String> item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_label(item.key)}  ${item.value}',
                    style: TextStyle(
                      fontSize: setting.bodyFontSize,
                      color: textColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    for (final DailyCareCustomField field in setting.customFields) {
      out.add(SizedBox(height: setting.cardGap));
      out.add(
        DailyCareCardSurface(
          setting: setting,
          imageOverride: cardImage,
          padding: EdgeInsets.all(setting.cardPadding),
          child: Text(
            '${field.label}  ${_customDemo(field.inputType)}',
            style: TextStyle(
              fontSize: setting.bodyFontSize,
              color: textColor,
            ),
          ),
        ),
      );
    }
    return out;
  }

  Widget _photoRow(bool withPhotos) {
    if (!withPhotos) {
      return Text(
        '本場未附照片（示範：0 張）',
        style: TextStyle(fontSize: setting.bodyFontSize),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(3, (int index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(setting.photoRadius),
          child: Container(
            width: 96,
            height: 96,
            color: const Color(0xFFE8DCCF),
            alignment: Alignment.center,
            child: Text(
              '示範圖 ${index + 1}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }),
    );
  }

  String _label(String key) {
    const Map<String, String> labels = <String, String>{
      'water': '飲水',
      'dryFood': '飼料',
      'wetFood': '罐頭',
      'snack': '零食',
      'stool': '大便',
      'urine': '尿尿',
      'wandToy': '逗貓棒',
      'scratchBoard': '貓抓板',
      'jumpPlatform': '貓跳台',
      'toyBall': '玩具球',
    };
    return labels[key] ?? key;
  }

  String _customDemo(String inputType) {
    switch (inputType) {
      case 'amount':
        return '一般';
      case 'condition':
        return '正常';
      case 'text':
        return '示範文字';
      default:
        return '有';
    }
  }

  Color _color(String key, Color fallback) {
    switch (key) {
      case 'brown':
        return const Color(0xFF8B5A2B);
      case 'blue':
        return const Color(0xFF3D6F9F);
      case 'green':
        return const Color(0xFF2E8B47);
      case 'ink':
        return const Color(0xFF3A2A20);
      default:
        return fallback;
    }
  }
}

class _PreviewGroup {
  const _PreviewGroup(this.title, this.icon, this.keys, this.values);
  final String title;
  final IconData icon;
  final List<String> keys;
  final List<String> values;
}

class DailyCarePreviewSession {
  const DailyCarePreviewSession();

  static List<String> labelsFor(
    DailyCareSettingModel setting, {
    required bool isDaycare,
    String offerId = '',
  }) {
    final String mode = isDaycare
        ? setting.daycareReportMode
        : setting.stayReportMode;
    if (mode == DailyCareReportMode.paidAddon) {
      return (isDaycare ? setting.daycarePaidPlan : setting.stayPaidPlan)
          .resolvedLabels();
    }
    if (mode == DailyCareReportMode.includedByOffer) {
      final quota = isDaycare
          ? setting.daycareOfferQuotas[offerId]
          : setting.stayOfferQuotas[offerId];
      if (quota == null || !quota.configured) {
        return const <String>['尚未設定此房型／方案場次'];
      }
      return quota.resolvedLabels();
    }
    return isDaycare
        ? setting.resolvedDaycareSessionLabelsForCount(setting.daycareSessionCount)
        : setting.resolvedStaySessionLabelsForCount(setting.sessionCount);
  }
}

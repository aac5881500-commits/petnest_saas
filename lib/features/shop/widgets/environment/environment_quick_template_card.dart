import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_quick_layout.dart';
import 'package:petnest_saas/core/models/environment_presentation.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'package:petnest_saas/core/models/environment_image_frame_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import '../../pages/shop_environment_page.dart';
import 'environment_intro_view.dart';
import 'environment_draft_preview.dart';

class EnvironmentQuickTemplateCard extends StatelessWidget {
  const EnvironmentQuickTemplateCard({
    super.key,
    required this.theme,
    required this.onApply,
    this.busy = false,
  });
  final HomeThemeModel theme;
  final ValueChanged<bool> onApply;
  final bool busy;
  Widget _content({bool fullContent = false, ScrollController? scroll}) {
    final data = EnvironmentQuickLayout.sampleIntro();
    final presentation = EnvironmentQuickLayout.presentation(
      EnvironmentPresentation(),
    ).copyWith({'customServices': EnvironmentQuickLayout.sampleServices()});
    return EnvironmentIntroView(
      style: const EnvironmentIntroStyle(),
      theme: theme,
      presentation: presentation,
      fullContent: fullContent,
      scrollController: scroll,
      heroTitle: data['heroTitle'] as String,
      heroSubtitle: data['heroSubtitle'] as String,
      heroImageUrl: data['heroImageUrl'] as String,
      heroFrame: const EnvironmentImageFrameSetting(
        slot: EnvironmentImageSlot.hero,
      ),
      bannerTitle: data['bannerTitle'] as String,
      bannerImageUrl: data['bannerImageUrl'] as String,
      bannerFrame: const EnvironmentImageFrameSetting(
        slot: EnvironmentImageSlot.middleBanner,
      ),
      features: List<Map<String, dynamic>>.from(data['features'] as List),
      galleryImages: (data['galleryImages'] as List)
          .map((item) => item['imageUrl'] as String)
          .toList(),
      careItems: const [],
      bottomNote: data['bottomNote'] as String,
      imageBuilder: environmentIntroNetworkImage,
      featureIconOf: environmentIntroIcon,
    );
  }

  void _open(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 1100,
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 16),
                const Expanded(child: Text('溫暖旅宿｜完整效果示意')),
                IconButton(
                  tooltip: '關閉範本預覽',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: EnvironmentDraftPreview(
                notice: '範例照片與文字皆可修改，套用到草稿後按儲存才更新正式內容。',
                contentBuilder: (scroll) => _content(scroll: scroll),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _example(BuildContext context, bool phone) => Column(
    children: [
      Text(
        phone ? '手機完整排版' : '電腦完整排版',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      InkWell(
        key: ValueKey(
          phone ? 'environment-template-phone' : 'environment-template-desktop',
        ),
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 310,
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xfff5f5f5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffe1e4ea)),
          ),
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: phone ? 390 : 1240,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(phone ? 390 : 1240, 1000),
                      textScaler: TextScaler.noScaling,
                    ),
                    child: _content(fullContent: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      const Text('點擊放大查看', style: TextStyle(fontSize: 12)),
    ],
  );
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 20),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '快速排版｜溫暖旅宿',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text('先看整頁效果，再換上自己的照片與文字。手機優先，電腦自動適配。'),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) => c.maxWidth >= 520
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _example(context, false)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _example(context, true)),
                    ],
                  )
                : Column(
                    children: [
                      _example(context, true),
                      const SizedBox(height: 16),
                      _example(context, false),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          const Text(
            '套用包含這份排版、示意照片與文字，之後可自行修改。照片非店家實景，其他店家資料不變。',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _open(context),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('放大查看範本'),
              ),
              FilledButton.icon(
                key: const ValueKey('environment-apply-warm-template'),
                onPressed: busy ? null : () => onApply(true),
                icon: const Icon(Icons.dashboard_customize_outlined),
                label: const Text('套用完整範本（含照片與文字）'),
              ),
              TextButton(
                onPressed: busy ? null : () => onApply(false),
                child: const Text('只套排版，保留目前內容'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '到「封面與文案」「環境特色」「設備與服務」編輯內容；細部設定集中於「進階外觀」。',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

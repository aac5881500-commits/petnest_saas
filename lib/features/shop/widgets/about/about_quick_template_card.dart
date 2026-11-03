// 功能：完整手機／桌機範本展示；排版套用與示意內容分離，不寫入正式資料。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:petnest_saas/core/models/about_page_template.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import '../environment/environment_draft_preview.dart';
import 'about_intro_view.dart';

class AboutQuickTemplateCard extends StatelessWidget {
  const AboutQuickTemplateCard({
    super.key,
    required this.setting,
    required this.theme,
    required this.shop,
    required this.onApply,
  });
  final AboutPageSetting setting;
  final HomeThemeModel theme;
  final Map<String, dynamic> shop;
  final ValueChanged<bool> onApply;
  AboutPageSetting get example =>
      AboutPageTemplate.complete(AboutPageSetting());

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
                const Expanded(child: Text('日光簡約｜完整效果示意')),
                IconButton(
                  tooltip: '關閉範本預覽',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: EnvironmentDraftPreview(
                notice: '範本含示意照片與文字，可整份套用後逐項替換成店家內容。',
                contentBuilder: (scroll) => AboutIntroView(
                  shop: AboutPageTemplate.previewShop(shop),
                  setting: example,
                  theme: theme,
                  preview: true,
                  scrollController: scroll,
                ),
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
                    child: AboutIntroView(
                      shop: AboutPageTemplate.previewShop(shop),
                      setting: example,
                      theme: theme,
                      preview: true,
                      fullContent: true,
                    ),
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
            '快速排版｜日光簡約',
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
            '套用包含這份排版、示意照片與文字，之後可自行修改。照片非店家實景，店家資訊仍使用自己的資料。',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('放大查看範本'),
                onPressed: () => _open(context),
              ),
              FilledButton.icon(
                key: const ValueKey('about-apply-daylight-template'),
                onPressed: () => onApply(true),
                icon: const Icon(Icons.dashboard_customize_outlined),
                label: const Text('套用完整範本（含照片與文字）'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '接著到「封面與介紹」「理念與團隊」「品牌故事」編輯內容；儲存後才更新正式頁。',
            style: TextStyle(fontSize: 12),
          ),
          if (setting.toMap()['quickTemplate'] == 'daylight-v1')
            const Text(
              '目前已使用日光簡約排版',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    ),
  );
}

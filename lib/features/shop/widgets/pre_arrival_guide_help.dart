import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';

/// Example content stays local until the shop explicitly adds and saves it.
PreArrivalGuideModel preArrivalExample({
  required String shopId,
  bool isDaycare = false,
}) {
  final title = isDaycare ? '安親前準備示範' : '入住前準備示範';
  return PreArrivalGuideModel(
    shopId: shopId,
    serviceType: isDaycare
        ? PreArrivalGuideServiceType.daycare
        : PreArrivalGuideServiceType.accommodation,
    title: title,
    blocks: [
      const PreArrivalGuideBlock(
        id: 'intro',
        type: PreArrivalGuideBlockType.text,
        text: '歡迎貓咪來玩！請依下方清單整理物品。這份內容是示範，請店家依實際服務調整。',
      ),
      const PreArrivalGuideBlock(
        id: 'essentials',
        type: PreArrivalGuideBlockType.heading,
        text: '出發前，先準備這些物品',
        sortOrder: 1,
      ),
      PreArrivalGuideBlock(
        id: 'food',
        type: PreArrivalGuideBlockType.checklist,
        text: isDaycare ? '當日需要的日常飼料，標示貓咪姓名與份量' : '住宿期間足量的日常飼料，分裝並標示貓咪姓名與份量',
        sortOrder: 2,
      ),
      const PreArrivalGuideBlock(
        id: 'carrier',
        type: PreArrivalGuideBlockType.checklist,
        text: '安全的外出籠或提籠',
        sortOrder: 3,
      ),
      const PreArrivalGuideBlock(
        id: 'comfort',
        type: PreArrivalGuideBlockType.checklist,
        text: '經店家確認可攜帶的熟悉毛毯或安撫物',
        sortOrder: 4,
      ),
      const PreArrivalGuideBlock(
        id: 'special',
        type: PreArrivalGuideBlockType.heading,
        text: '有特殊需求的貓咪',
        sortOrder: 5,
      ),
      const PreArrivalGuideBlock(
        id: 'contact',
        type: PreArrivalGuideBlockType.text,
        text: '若有用藥或特殊照顧需求，請提前與店家確認可提供的服務，再依雙方確認的方式準備物品與說明。',
        sortOrder: 6,
      ),
      const PreArrivalGuideBlock(
        id: 'notes',
        type: PreArrivalGuideBlockType.checklist,
        text: '如有特殊需求，已與店家確認並備妥相關說明',
        sortOrder: 7,
      ),
    ],
  );
}

/// Append with fresh IDs and normalized order, retaining the shop's own draft.
PreArrivalGuideModel appendPreArrivalExample(
  PreArrivalGuideModel guide, {
  required String idPrefix,
}) {
  final example = preArrivalExample(
    shopId: guide.shopId,
    isDaycare: guide.serviceType == PreArrivalGuideServiceType.daycare,
  );
  final blocks = [
    ...guide.blocks,
    for (final block in example.blocks)
      block.copyWith(id: '$idPrefix-${block.id}'),
  ];
  return guide.copyWith(
    blocks: [
      for (var i = 0; i < blocks.length; i++) blocks[i].copyWith(sortOrder: i),
    ],
  );
}

class PreArrivalGuideHelpCard extends StatelessWidget {
  const PreArrivalGuideHelpCard({
    super.key,
    required this.onDemo,
    required this.onAddExample,
    this.inherit = false,
    this.isDaycare = false,
  });
  final VoidCallback onDemo;
  final VoidCallback onAddExample;
  final bool inherit;
  final bool isDaycare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '告訴客戶：來之前要準備什麼？',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '把${isDaycare ? '安親' : '入住'}前要帶的物品與注意事項整理成一頁，讓客戶從訂單詳情查看並逐項勾選。',
            ),
            const SizedBox(height: 12),
            const Text(
              '① 寫準備清單　→　② 看客戶畫面　→　③ 儲存並提供',
              style: TextStyle(fontWeight: FontWeight.w600, height: 1.5),
            ),
            if (inherit) ...[
              const SizedBox(height: 10),
              const Text('目前沿用住宿內容：請到「住宿」分頁修改；關閉沿用後才可編輯安親專用內容。'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onDemo,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('看示範・可試勾'),
                ),
                if (!inherit)
                  TextButton.icon(
                    onPressed: onAddExample,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('加入示範到草稿'),
                  ),
              ],
            ),
            const Text(
              '示範不會自動儲存或啟用；請先改成符合店內實際服務的內容。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('不確定怎麼填？看操作說明', style: TextStyle(fontSize: 14)),
              children: const [
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '加一項物品：例如「攜帶外出籠」，客戶可以勾選。\n'
                    '一次加多項：每行一項，一次加入多個物品。\n'
                    '快速模板：帶入分段標題、用途說明及物品；換模板會替換上一份模板，手動新增內容保留。\n'
                    '加段落標題：例如「必帶物品」「特殊需求」，將內容分段。\n'
                    '加補充說明：填寫份量、標示方式、聯繫提醒。\n'
                    '圖片：示意分裝方式，並可加上圖片說明。\n'
                    '上下箭頭：調整段落順序；垃圾桶：刪除該段。\n\n'
                    '客戶勾選進度保留在同一裝置，供個人整理使用，店家不會收到完成回報。此頁的準備說明與入住條款分開設定。',
                    style: TextStyle(height: 1.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

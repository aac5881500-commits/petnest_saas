import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';

/// One shared list of blocks; changing a skin never clones customer content.
class PreArrivalCatalogItem {
  const PreArrivalCatalogItem(
    this.id,
    this.section,
    this.text, {
    this.checkable = true,
  });
  final String id, section, text;
  final bool checkable;
}

const preArrivalCatalog = [
  PreArrivalCatalogItem('food', '必須攜帶', '足量的日常飼料與罐頭，標示姓名及每餐份量'),
  PreArrivalCatalogItem('carrier', '必須攜帶', '安全且能確實關好的外出籠'),
  PreArrivalCatalogItem('vaccine', '必須攜帶', '依店家要求提供疫苗紀錄'),
  PreArrivalCatalogItem('parasite', '必須攜帶', '依店家要求提供驅蟲紀錄'),
  PreArrivalCatalogItem('blanket', '視需要攜帶', '經店家確認可攜帶的熟悉毛毯或玩具'),
  PreArrivalCatalogItem('medicine', '視需要攜帶', '用藥需求已與店家確認，備妥原標示藥品與照護說明'),
  PreArrivalCatalogItem(
    'litter',
    '店家提供',
    '店內提供貓砂與砂盆；特殊砂種請先聯繫確認',
    checkable: false,
  ),
  PreArrivalCatalogItem('bowl', '店家提供', '店內提供餐碗與飲水用品', checkable: false),
  PreArrivalCatalogItem(
    'time',
    '到店前提醒',
    '請依約定時間接送，時間變動請提前通知',
    checkable: false,
  ),
  PreArrivalCatalogItem(
    'contact',
    '到店前提醒',
    '特殊照護、飲食與行為需求請提前聯繫店家',
    checkable: false,
  ),
  PreArrivalCatalogItem('food-portions', '必須攜帶', '依餐次分裝餐食，標示姓名、日期與份量'),
  PreArrivalCatalogItem('handover-contacts', '必須攜帶', '提供可聯繫的飼主與緊急聯絡人資料'),
  PreArrivalCatalogItem('cold-food', '視需要攜帶', '冷藏或冷凍餐食已與店家確認保存及加熱方式'),
  PreArrivalCatalogItem('allergy-note', '視需要攜帶', '提供食物過敏、不能吃的食物與飲食習慣說明'),
  PreArrivalCatalogItem('supplements', '視需要攜帶', '保健品請保留原標示，並提供份量與餵食方式'),
  PreArrivalCatalogItem('own-litter', '視需要攜帶', '如需自備慣用貓砂，請先確認可用種類及數量'),
  PreArrivalCatalogItem('own-bowl', '視需要攜帶', '如需使用自備餐碗或飲水器，請先確認可否攜帶'),
  PreArrivalCatalogItem('bedding', '視需要攜帶', '經店家確認可攜帶的睡墊或小窩，請標示姓名'),
  PreArrivalCatalogItem('carrier-pad', '視需要攜帶', '視需求準備外出籠內的乾淨墊布與備用墊材'),
  PreArrivalCatalogItem('snacks', '視需要攜帶', '自備零食請告知每日可提供的份量與限制'),
  PreArrivalCatalogItem(
    'clinic-contact',
    '到店前提醒',
    '提供平時就診動物醫院與緊急就醫聯絡資料',
    checkable: false,
  ),
  PreArrivalCatalogItem(
    'pickup-person',
    '到店前提醒',
    '確認接送人姓名與聯絡方式；委託他人接回請提前告知',
    checkable: false,
  ),
  PreArrivalCatalogItem(
    'belongings-list',
    '到店前提醒',
    '自備物品標示姓名，並與店家核對交接及歸還清單',
    checkable: false,
  ),
  PreArrivalCatalogItem(
    'health-change',
    '到店前提醒',
    '近期健康、食慾或用藥若有變化，請提前告知店家評估',
    checkable: false,
  ),
  PreArrivalCatalogItem(
    'long-stay-supply',
    '到店前提醒',
    '長住請事先確認餐食與用品不足時的補給方式',
    checkable: false,
  ),
];

PreArrivalGuideModel togglePreArrivalCatalog(
  PreArrivalGuideModel guide,
  PreArrivalCatalogItem item,
  bool selected,
) {
  final id = 'catalog-${item.id}';
  final blocks = [...guide.blocks];
  if (selected && !blocks.any((b) => b.id == id)) {
    // Reuse an existing named section, including a manually created one.
    var heading = blocks.indexWhere(
      (b) => b.type == 'heading' && b.text.trim() == item.section,
    );
    if (heading < 0) {
      blocks.add(
        PreArrivalGuideBlock(
          id: 'catalog-section-${item.section}',
          type: 'heading',
          text: item.section,
        ),
      );
      heading = blocks.length - 1;
    }
    var insertion = heading + 1;
    while (insertion < blocks.length && blocks[insertion].type != 'heading') {
      insertion++;
    }
    blocks.insert(
      insertion,
      PreArrivalGuideBlock(
        id: id,
        type: item.checkable ? 'checklist' : 'text',
        text: item.text,
      ),
    );
  } else if (!selected) {
    blocks.removeWhere((b) => b.id == id);
    for (var i = blocks.length - 1; i >= 0; i--) {
      if (blocks[i].id.startsWith('catalog-section-') &&
          (i == blocks.length - 1 || blocks[i + 1].type == 'heading')) {
        blocks.removeAt(i);
      }
    }
  }
  return guide.copyWith(
    blocks: [
      for (var i = 0; i < blocks.length; i++) blocks[i].copyWith(sortOrder: i),
    ],
  );
}

class PreArrivalStylePicker extends StatelessWidget {
  const PreArrivalStylePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '選擇客戶看到的外觀',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      const Text('三款共用下方內容；切換外觀不會清除項目或修改的文字。'),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in const [
              (
                'packing',
                'D 行李打包卡',
                '暖橘卡片・分類打包',
                Color(0xFFB65C32),
                Icons.luggage_outlined,
              ),
              (
                'timeline',
                'E 出發時間軸',
                '淡紫步驟・順序準備',
                Color(0xFF7860A6),
                Icons.route_outlined,
              ),
              (
                'minimal',
                'F 日系留白',
                '米白細線・安靜閱讀',
                Color(0xFF926C5C),
                Icons.spa_outlined,
              ),
              (
                'classic',
                '原版',
                '保留原有的物品卡片',
                Color(0xFF537C6B),
                Icons.checklist_outlined,
              ),
            ])
              SizedBox(
                width: box.maxWidth < 500
                    ? (box.maxWidth - 12) / 2
                    : (box.maxWidth - 36) / 4,
                child: Semantics(
                  selected: value == entry.$1,
                  child: Material(
                    color: entry.$4.withValues(alpha: .06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: value == entry.$1
                            ? entry.$4
                            : entry.$4.withValues(alpha: .2),
                        width: value == entry.$1 ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('guide-style-${entry.$1}'),
                      onTap: () => onChanged(entry.$1),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(entry.$5, color: entry.$4, size: 30),
                            const SizedBox(height: 10),
                            Text(
                              entry.$2,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: entry.$4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.$3,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Icon(
                              value == entry.$1
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: entry.$4,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class PreArrivalCatalogPicker extends StatelessWidget {
  const PreArrivalCatalogPicker({
    super.key,
    required this.guide,
    required this.onChanged,
  });
  final PreArrivalGuideModel guide;
  final ValueChanged<PreArrivalGuideModel> onChanged;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: ValueKey('pre-arrival-more-${guide.serviceType}'),
      initiallyExpanded: false,
      leading: const Icon(Icons.checklist_rounded),
      title: const Text(
        '更多選擇',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '常用準備項目 · 已選 ${preArrivalCatalog.where((item) => guide.blocks.any((b) => b.id == 'catalog-${item.id}')).length}／${preArrivalCatalog.length} 項',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const SizedBox(height: 6),
        const Text('店主勾選＝顯示此項目，所有外觀同步。加入後可在下方修改文字；取消勾選會移除此項目。店家提供的用品請依實際服務勾選。'),
        for (final section in const ['必須攜帶', '視需要攜帶', '店家提供', '到店前提醒']) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              section,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final item in preArrivalCatalog.where(
            (i) => i.section == section,
          ))
            CheckboxListTile(
              key: ValueKey('catalog-picker-${item.id}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(item.text),
              value: guide.blocks.any((b) => b.id == 'catalog-${item.id}'),
              onChanged: (selected) => onChanged(
                togglePreArrivalCatalog(guide, item, selected == true),
              ),
            ),
        ],
      ],
    ),
  );
}

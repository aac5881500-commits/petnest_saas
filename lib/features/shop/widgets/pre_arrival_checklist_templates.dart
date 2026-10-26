import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:flutter/material.dart';

class PreArrivalChecklistTemplate {
  const PreArrivalChecklistTemplate(
    this.id,
    this.name,
    this.description,
    this.items,
  );
  final String id;
  final String name;
  final String description;
  final List<String> items;
}

// Synthesized from public cat-hotel arrival guides, reviewed 2026-10-26:
// https://www.parkcat-hotel.com.tw/product/入住須知/
// https://www.thecathotel.tw/reservation
// https://www.iamcataholic.com/qa/
// https://meowzillaaa.com/page/notice
// https://sunalley6.wixsite.com/cathotel/notice
// Requirements vary by shop. These are editable reminders, not medical rules.
const preArrivalChecklistTemplates = <PreArrivalChecklistTemplate>[
  PreArrivalChecklistTemplate('basic', '基本住宿', '先準備餐食、外出籠與交接資料。', [
    '住宿期間足量的日常飼料或罐頭，標示貓咪姓名與每餐份量',
    '安全且能確實關好的外出籠或提籠',
    '依店家要求提供疫苗及相關健康紀錄',
    '確認入住時間、接送人與緊急聯絡方式',
  ]),
  PreArrivalChecklistTemplate('food', '餐食分裝', '適合有固定餐量、濕食或個別飲食習慣的貓咪。', [
    '平時習慣的飼料、罐頭或經店家確認可存放的餐食',
    '每份餐食標示貓咪姓名、日期、餐次與份量',
    '提供每日餵食時間及飲食習慣說明',
    '如有需冷藏或冷凍的食物，已與店家確認保存方式',
    '如有食物過敏或不能吃的食物，已事先告知店家',
  ]),
  PreArrivalChecklistTemplate('comfort', '安心小物', '先確認旅館可收哪些物品，再帶熟悉的小東西。', [
    '經店家確認可攜帶的熟悉毛毯、睡墊或小窩',
    '經店家確認安全且可攜帶的慣用玩具',
    '所有自備物品標示貓咪姓名，方便交接與歸還',
    '已告知貓咪怕生情況、互動偏好及不喜歡的接觸方式',
  ]),
  PreArrivalChecklistTemplate('records', '健康資料', '準備旅館需要確認的資料，期限依各店規定。', [
    '依店家要求提供疫苗紀錄或預防針手冊照片',
    '依店家要求提供近期驅蟲紀錄',
    '如有近期就醫、健康變化或特殊狀況，已提前告知店家',
    '提供飼主、緊急聯絡人及平時就診動物醫院的聯絡方式',
  ]),
  PreArrivalChecklistTemplate('special', '特殊需求', '先確認店家能承接，再交接物品與既有說明。', [
    '已提前與店家確認特殊照顧需求及可提供的服務',
    '如需交接藥品，已確認店家可協助，並備妥原標示及既有用藥說明',
    '如有特殊飲食，已提供餐食與份量說明並確認保存方式',
    '已提供需要留意的日常狀況及緊急聯絡方式',
  ]),
  PreArrivalChecklistTemplate('multi', '多貓同行', '逐隻標示物品，交代飲食與相處習慣。', [
    '每隻貓咪的餐食及物品分開標示姓名',
    '分別提供每隻貓咪的餵食份量與特殊需求',
    '已告知貓咪之間的相處情況，並與店家確認同住或分房安排',
    '已確認每隻貓咪的安全運送方式及外出籠安排',
  ]),
  PreArrivalChecklistTemplate('long', '長住補給', '依住宿天數確認餐食、用品與補給方式。', [
    '依住宿天數備妥足量的日常餐食，並與店家確認預備量',
    '確認自備用品的數量、保存期限與存放方式',
    '如需自備慣用貓砂，已先確認店家可使用的種類與數量',
    '已與店家確認餐食或用品不足時的聯絡及補給方式',
    '提供住宿期間可聯繫的緊急聯絡人',
  ]),
  PreArrivalChecklistTemplate('daycare', '當日安親', '以當日餐食、安全接送與交接重點為主。', [
    '當日需要的餐食，標示貓咪姓名與份量',
    '安全且能確實關好的外出籠或提籠',
    '依店家要求提供相關健康資料',
    '確認送達與接回時間，以及接送人的聯絡方式',
    '已告知當日需要留意的飲食、個性或特殊需求',
  ]),
  PreArrivalChecklistTemplate('departure', '出發前確認', '把容易遺漏的聯繫與交接事項再看一次。', [
    '再次確認入住日期、到店時間與旅館地址',
    '檢查外出籠門扣是否確實關好',
    '確認餐食、物品及店家要求的資料都已備妥',
    '確認緊急聯絡方式可正常使用',
    '接送時間或貓咪狀況若有變動，已先通知店家',
  ]),
];

class PreArrivalTemplateDraft {
  const PreArrivalTemplateDraft({
    this.title = '',
    this.description = '',
    required this.text,
  });
  final String title;
  final String description;
  final String text;
}

/// Replace only the previous quick-template blocks, retaining manual content.
PreArrivalGuideModel applyPreArrivalTemplate(
  PreArrivalGuideModel guide,
  PreArrivalTemplateDraft draft, {
  required String revision,
}) {
  const prefix = 'quick-template-';
  final previous = guide.blocks.indexWhere((b) => b.id.startsWith(prefix));
  final retained = guide.blocks.where((b) => !b.id.startsWith(prefix)).toList();
  final insertion = previous < 0
      ? retained.length
      : guide.blocks
            .take(previous)
            .where((b) => !b.id.startsWith(prefix))
            .length;
  final lines = draft.text
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();
  final section = <PreArrivalGuideBlock>[
    if (draft.title.trim().isNotEmpty)
      PreArrivalGuideBlock(
        id: '$prefix$revision-heading',
        type: PreArrivalGuideBlockType.heading,
        text: draft.title.trim(),
      ),
    if (draft.description.trim().isNotEmpty)
      PreArrivalGuideBlock(
        id: '$prefix$revision-description',
        type: PreArrivalGuideBlockType.text,
        text: draft.description.trim(),
      ),
    for (var i = 0; i < lines.length; i++)
      PreArrivalGuideBlock(
        id: '$prefix$revision-item-$i',
        type: PreArrivalGuideBlockType.checklist,
        text: lines[i],
      ),
  ];
  retained.insertAll(insertion, section);
  return guide.copyWith(
    blocks: [
      for (var i = 0; i < retained.length; i++)
        retained[i].copyWith(sortOrder: i),
    ],
  );
}

class PreArrivalChecklistTemplateDialog extends StatefulWidget {
  const PreArrivalChecklistTemplateDialog({
    super.key,
    this.isDaycare = false,
    this.useTemplate = true,
  });
  final bool isDaycare;
  final bool useTemplate;
  @override
  State<PreArrivalChecklistTemplateDialog> createState() =>
      _PreArrivalChecklistTemplateDialogState();
}

class _PreArrivalChecklistTemplateDialogState
    extends State<PreArrivalChecklistTemplateDialog> {
  late PreArrivalChecklistTemplate _selected;
  late final TextEditingController _text;
  late final TextEditingController _title;
  late final TextEditingController _description;
  final Map<String, PreArrivalTemplateDraft> _drafts = {};
  @override
  void initState() {
    super.initState();
    _selected = preArrivalChecklistTemplates.firstWhere(
      (t) => t.id == (widget.isDaycare ? 'daycare' : 'basic'),
    );
    _text = TextEditingController(
      text: widget.useTemplate ? _selected.items.join('\n') : '',
    );
    _title = TextEditingController(text: _selected.name);
    _description = TextEditingController(text: _selected.description);
  }

  @override
  void dispose() {
    _text.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.useTemplate ? '選擇快速模板' : '一次加入多項物品'),
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.useTemplate) ...[
              DropdownButtonFormField<String>(
                initialValue: _selected.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '準備哪一類內容？',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final t in preArrivalChecklistTemplates)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.name}（${t.items.length} 項）'),
                    ),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  _drafts[_selected.id] = PreArrivalTemplateDraft(
                    title: _title.text,
                    description: _description.text,
                    text: _text.text,
                  );
                  setState(() {
                    _selected = preArrivalChecklistTemplates.firstWhere(
                      (t) => t.id == id,
                    );
                    _text.text =
                        _drafts[id]?.text ?? _selected.items.join('\n');
                    _title.text = _drafts[id]?.title ?? _selected.name;
                    _description.text =
                        _drafts[id]?.description ?? _selected.description;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: '分段標題（客戶會看到）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '這一段的用途／說明',
                  hintText: '告訴客戶為什麼要準備、該怎麼準備',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              widget.useTemplate
                  ? '標題、說明與每行一項的物品都可修改。套用後也能在下方逐段編輯。\n換模板會替換上次模板及其修改，不會重複堆疊；手動新增的段落保留。'
                  : '每行一項，會接在原有內容後方。',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: 5,
              maxLines: 9,
              decoration: const InputDecoration(
                labelText: '要加入的物品與提醒',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.useTemplate) ...[
              const SizedBox(height: 12),
              const Text(
                '依貓旅館公開入住須知整理；健康資料、物品及照護服務請依本店實際規定調整。',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          PreArrivalTemplateDraft(
            title: _title.text,
            description: _description.text,
            text: _text.text,
          ),
        ),
        child: Text(widget.useTemplate ? '套用分段模板' : '加入清單'),
      ),
    ],
  );
}

// 檔案名稱：lib/features/shop/pages/daily_care_addon_manage_page.dart
// 功能說明：管理寵物寫真與照護回報專用加購，不放入一般加值清單。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daily_care_addon_plan.dart';
import 'package:petnest_saas/core/services/daily_care_addon_service.dart';

class DailyCareAddonManagePage extends StatefulWidget {
  const DailyCareAddonManagePage({super.key, required this.shopId});

  final String shopId;

  @override
  State<DailyCareAddonManagePage> createState() =>
      _DailyCareAddonManagePageState();
}

class _DailyCareAddonManagePageState extends State<DailyCareAddonManagePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('寵物寫真與照護回報方案')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        label: const Text('新增方案'),
        icon: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<DailyCareAddonPlan>>(
        stream: DailyCareAddonService.instance.streamPlans(widget.shopId),
        builder: (BuildContext context, AsyncSnapshot<List<DailyCareAddonPlan>> snap) {
          final List<DailyCareAddonPlan> plans =
              snap.data ?? const <DailyCareAddonPlan>[];
          if (plans.isEmpty) {
            return const Center(child: Text('尚未建立照護加購方案。顧客端不會預先勾選付費項目。'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final DailyCareAddonPlan plan = plans[index];
              return ListTile(
                tileColor: Colors.white,
                title: Text(plan.name),
                subtitle: Text(
                  '${plan.enabled ? '啟用' : '停用'}｜住宿每晚 ${plan.stayPricePerNight}｜安親每筆 ${plan.daycarePricePerVisit}\n'
                  '增加 ${plan.extraReports} 次回報、${plan.extraPhotos} 張照片',
                ),
                isThreeLine: true,
                onTap: () => _edit(plan),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(DailyCareAddonPlan? existing) async {
    final TextEditingController name = TextEditingController(
      text: existing?.name ?? '寵物寫真與照護回報',
    );
    final TextEditingController desc = TextEditingController(
      text: existing?.description ?? '',
    );
    final TextEditingController stayPrice = TextEditingController(
      text: '${existing?.stayPricePerNight ?? 0}',
    );
    final TextEditingController daycarePrice = TextEditingController(
      text: '${existing?.daycarePricePerVisit ?? 0}',
    );
    int reports = existing?.extraReports ?? 1;
    int photos = existing?.extraPhotos ?? 3;
    bool enabled = existing?.enabled ?? true;
    bool stay = existing?.applyStay ?? true;
    bool daycare = existing?.applyDaycare ?? true;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setSt) {
            return AlertDialog(
              title: Text(existing == null ? '新增方案' : '編輯方案'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(controller: name, decoration: const InputDecoration(labelText: '名稱')),
                    TextField(controller: desc, decoration: const InputDecoration(labelText: '說明')),
                    SwitchListTile(
                      title: const Text('啟用'),
                      value: enabled,
                      onChanged: (bool value) => setSt(() => enabled = value),
                    ),
                    CheckboxListTile(
                      title: const Text('適用住宿（按晚）'),
                      value: stay,
                      onChanged: (bool? value) => setSt(() => stay = value ?? true),
                    ),
                    CheckboxListTile(
                      title: const Text('適用安親（按筆）'),
                      value: daycare,
                      onChanged: (bool? value) => setSt(() => daycare = value ?? true),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: reports,
                      decoration: const InputDecoration(labelText: '增加回報次數'),
                      items: const <DropdownMenuItem<int>>[
                        DropdownMenuItem<int>(value: 0, child: Text('0')),
                        DropdownMenuItem<int>(value: 1, child: Text('1')),
                        DropdownMenuItem<int>(value: 2, child: Text('2')),
                        DropdownMenuItem<int>(value: 3, child: Text('3')),
                      ],
                      onChanged: (int? value) => setSt(() => reports = value ?? 1),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: photos,
                      decoration: const InputDecoration(labelText: '增加照片張數'),
                      items: List<DropdownMenuItem<int>>.generate(
                        7,
                        (int i) => DropdownMenuItem<int>(value: i, child: Text('$i')),
                      ),
                      onChanged: (int? value) => setSt(() => photos = value ?? 3),
                    ),
                    TextField(
                      controller: stayPrice,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '住宿價格（每晚）'),
                    ),
                    TextField(
                      controller: daycarePrice,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '安親價格（每筆）'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    await DailyCareAddonService.instance.savePlan(
                      shopId: widget.shopId,
                      plan: DailyCareAddonPlan(
                        id: existing?.id ?? '',
                        name: name.text.trim(),
                        description: desc.text.trim(),
                        enabled: enabled,
                        applyStay: stay,
                        applyDaycare: daycare,
                        extraReports: reports,
                        extraPhotos: photos,
                        stayPricePerNight: int.tryParse(stayPrice.text) ?? 0,
                        daycarePricePerVisit: int.tryParse(daycarePrice.text) ?? 0,
                      ),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('確認儲存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'care_actual_time_field.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_medication_task.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';
import 'package:image/image.dart' as imaging;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';

const medicationTypes = <String, String>{
  'oral': '口服藥',
  'eye': '點眼藥',
  'ear': '點耳藥',
  'topical': '擦藥',
  'spray': '噴藥',
  'supplement': '保健品',
};
const medicationModes = <String, String>{
  'free': '免費',
  'visit': '按次收費',
  'day': '按日收費',
  'quote': '評估後報價',
};
const medicationStates = <String, String>{
  'pending_shop': '待店家確認',
  'pending_customer': '待客人確認',
  'confirmed': '雙方已確認',
  'declined': '店家無法提供',
  'cancelled': '已取消協助',
};
const medicationResults = <String, String>{
  'pending': '待執行',
  'done': '已完成',
  'partial': '部分完成，待確認',
  'failed': '未成功',
  'skipped': '未執行',
  'mixed': '已拌食，待確認食用',
};
Map<String, dynamic> medMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> medList(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];
String medPetId(Map<String, dynamic> p) => '${p['petId'] ?? p['id'] ?? ''}';
String medDate(Object? v) {
  final d = v is Timestamp ? v.toDate() : DateTime.tryParse('$v');
  return d == null
      ? '待確認'
      : DateFormat(
          'MM/dd HH:mm',
        ).format(d.toUtc().add(const Duration(hours: 8)));
}

String medIso(DateTime d) =>
    '${DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(d)}+08:00';
String _medPriceUnit(Object? mode) => switch (mode) {
  'visit' => '次',
  'day' => '日',
  'night' => '晚',
  _ => '',
};

String _medCountRule(Map<String, dynamic> setting) {
  final split = setting['splitTypes'] == true;
  return switch (setting['mode']) {
    'visit' =>
      split
          ? '每隻貓依照護期間安排的時間計次，同一時間的不同用藥類型各算一次。'
          : '每隻貓依照護期間安排的時間計次，同一時間有多項用藥也只算一次。',
    'day' => [
      switch (setting['dayRule']) {
        'stay_days' => '只算有計費服務的住宿日，退房日的用藥併入最後一個住宿日。',
        'all_dates' => '按交接期間的日曆日計費，首尾日都算。',
        _ => '按有計費服務的日曆日計費。',
      },
      split ? '同一隻貓每天按用藥類型分開收費，同類型多次不加價。' : '同一隻貓一天餵多次也只收一天。',
    ].join(),
    'night' => '依交接期間的跨夜數計費，同日最低一晚。${split ? '不同用藥類型分開收費。' : ''}',
    _ => '',
  };
}

String medRule(Map<String, dynamic> setting, {bool includeFeeWaivers = true}) {
  final mode = setting['mode'];
  if (mode == 'free') return '免費，服務安排仍須雙方確認。';
  final times = setting['includedTimes'] as num? ?? 0;
  final pills = setting['includedPills'] as num? ?? 0;
  final unit = _medPriceUnit(mode);
  return [
    if (unit.isEmpty)
      '評估後報價，雙方確認後生效。'
    else ...[
      "${mode == 'night' ? '按晚收費（既有規則）' : medicationModes[mode]}：每隻貓每$unit ${setting['price'] ?? 0} 元。",
      _medCountRule(setting),
    ],
    if (includeFeeWaivers && setting['mixFree'] == true) '可拌食者免費。',
    if (includeFeeWaivers && setting['successOnly'] == true) '未成功的服務不計費。',
    if (times > 0) '每日含 $times 次，超過另報價。',
    if (pills > 0) '每次含 $pills 顆，超過另報價。',
  ].join(' ');
}

class _MedicationWaiverNotices extends StatelessWidget {
  const _MedicationWaiverNotices(this.setting);

  final Map<String, dynamic> setting;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (setting['mixFree'] == true)
          ListTile(
            tileColor: colors.primaryContainer,
            textColor: colors.onPrimaryContainer,
            leading: Icon(
              Icons.restaurant_outlined,
              color: colors.onPrimaryContainer,
            ),
            title: const Text(
              '可拌食者免費',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('依原用藥指示可拌入食物時，該項用藥協助免費。'),
          ),
        if (setting['mixFree'] == true && setting['successOnly'] == true)
          const SizedBox(height: 8),
        if (setting['successOnly'] == true)
          ListTile(
            tileColor: colors.tertiaryContainer,
            textColor: colors.onTertiaryContainer,
            leading: Icon(
              Icons.receipt_long_outlined,
              color: colors.onTertiaryContainer,
            ),
            title: const Text(
              '未成功不計費',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('請記錄每次執行結果，退房時會依結果核算用藥費。'),
          ),
      ],
    );
  }
}

Future<Map<String, dynamic>> medCall(
  String name,
  Map<String, dynamic> data,
) async {
  final result = await FirebaseFunctions.instanceFor(
    region: 'asia-east1',
  ).httpsCallable(name).call(data);
  return medMap(result.data);
}

String medicationErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    if (['internal', 'unavailable', 'not-found'].contains(error.code)) {
      return '用藥服務暫時無法使用，這次操作未完成，請稍後再試。';
    }
    if (error.code == 'unauthenticated') return '登入已逾時，請重新登入後再儲存。';
    if (error.code == 'permission-denied') return '目前帳號沒有操作用藥協助的權限，請由店主確認權限。';
    if (error.code == 'deadline-exceeded') return '連線逾時，請重新讀取設定確認是否已儲存，再重試。';
    return error.message ?? '操作未完成，請稍後再試。';
  }
  return '$error';
}

void medError(BuildContext context, Object e) {
  final text = medicationErrorMessage(e);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Future<DateTime?> medPickDateTime(
  BuildContext context,
  DateTime initial,
  DateTime first,
  DateTime last,
) async {
  final day = await showDatePicker(
    context: context,
    initialDate: initial.isBefore(first)
        ? first
        : initial.isAfter(last)
        ? last
        : initial,
    firstDate: DateUtils.dateOnly(first),
    lastDate: DateUtils.dateOnly(last),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  return time == null
      ? null
      : DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

Widget medCard(String title, List<Widget> children) => Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  ),
);
Widget medInput(
  TextEditingController c,
  String label, {
  bool required = false,
  bool number = false,
  int lines = 1,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: TextFormField(
    controller: c,
    maxLines: lines,
    keyboardType: number ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    validator: (v) => required && (v ?? '').trim().isEmpty ? '請填寫$label' : null,
  ),
);

class MedicationSettingsPage extends StatefulWidget {
  const MedicationSettingsPage({
    super.key,
    required this.shopId,
    this.embedded = false,
    this.loadSetting,
    this.saveSetting,
  });
  final String shopId;
  final bool embedded;
  final Future<Map<String, dynamic>> Function()? loadSetting;
  final Future<void> Function(Map<String, dynamic>)? saveSetting;
  @override
  MedicationSettingsPageState createState() => MedicationSettingsPageState();
}

class MedicationSettingsPageState extends State<MedicationSettingsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final form = GlobalKey<FormState>();
  final price = TextEditingController(),
      note = TextEditingController(),
      times = TextEditingController(),
      pills = TextEditingController();
  Map<String, dynamic> setting = {};
  Set<String> types = {};
  List<Map<String, dynamic>> windows = [];
  bool loading = true, saving = false, dirty = false;
  Object? error;
  bool _confirmingLeave = false;
  bool get hasUnsavedChanges => dirty;
  bool get isSaving => saving;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final raw = widget.loadSetting != null
          ? await widget.loadSetting!()
          : medMap(
              (await FirebaseFirestore.instance
                      .collection('shops')
                      .doc(widget.shopId)
                      .get())
                  .data()?['medicationSetting'],
            );
      if (!mounted) return;
      setting = {
        'enabled': false,
        'mode': 'quote',
        'price': 0,
        'mixFree': false,
        'successOnly': false,
        'splitTypes': false,
        'dayRule': 'service_dates',
        'paymentTiming': 'checkout',
        ...raw,
      };
      types = (setting['types'] as List? ?? []).map((e) => '$e').toSet();
      windows = medList(setting['windows']);
      if (windows.isEmpty) {
        windows = [
          {'start': '09:00', 'end': '21:00'},
        ];
      }
      if (setting['mode'] == 'night') setting['mode'] = 'day';
      setting['dayRule'] = 'service_dates';
      price.text = '${setting['price'] ?? 0}';
      note.text = '${setting['note'] ?? ''}';
      times.text = '${setting['includedTimes'] ?? 0}';
      pills.text = '${setting['includedPills'] ?? 0}';
    } catch (e) {
      error = e;
    }
    if (mounted) setState(() => loading = false);
  }

  void change(VoidCallback fn) => setState(() {
    fn();
    dirty = true;
  });
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final amount = ['free', 'quote'].contains(setting['mode'])
        ? 0
        : int.tryParse(price.text);
    if (amount == null || amount < 0 || amount > 100000) {
      medError(context, '請輸入 0～100000 的整數金額');
      return;
    }
    if (setting['enabled'] == true && types.isEmpty) {
      medError(context, '請至少選擇一項可提供的服務');
      return;
    }
    for (final window in windows) {
      if ('${window['start']}'.compareTo('${window['end']}') >= 0) {
        medError(context, '照護結束時間須晚於開始時間');
        return;
      }
    }
    if ((int.tryParse(times.text) ?? -1) < 0 ||
        (int.tryParse(times.text) ?? 25) > 24 ||
        (int.tryParse(pills.text) ?? -1) < 0 ||
        (int.tryParse(pills.text) ?? 101) > 100) {
      medError(context, '每日次數請填 0～24，包含顆數請填 0～100 的整數');
      return;
    }
    setState(() => saving = true);
    try {
      final next = {
        ...setting,
        'types': types.toList(),
        'price': amount,
        'note': note.text.trim(),
        'windows': windows,
        'includedTimes': int.tryParse(times.text) ?? -1,
        'includedPills': int.tryParse(pills.text) ?? -1,
      };
      if (widget.saveSetting != null) {
        await widget.saveSetting!(next);
      } else {
        await medCall('saveMedicationSetting', {
          'shopId': widget.shopId,
          'setting': next,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() => dirty = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('用藥協助設定已儲存')));
      }
    } catch (e) {
      if (mounted) medError(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [price, note, times, pills]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scaffold = Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('用藥協助設定')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: TextButton(onPressed: load, child: const Text('讀取失敗，重試')),
            )
          : _settingsForm(),
      bottomNavigationBar: loading || error != null ? null : _saveFooter(),
    );
    // The enclosing add-on route checks both drafts and owns the back prompt.
    if (widget.embedded) return scaffold;
    return PopScope(
      canPop: !dirty && !saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !dirty || saving || _confirmingLeave) return;
        final route = ModalRoute.of(context);
        _confirmingLeave = true;
        try {
          final leave = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('設定尚未儲存'),
              content: const Text('要放棄這次變更並離開嗎？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('繼續編輯'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('放棄變更'),
                ),
              ],
            ),
          );
          if (leave == true && context.mounted && route?.isCurrent == true) {
            Navigator.of(context).pop(result);
          }
        } finally {
          _confirmingLeave = false;
        }
      },
      child: scaffold,
    );
  }

  Widget _settingsForm() => AbsorbPointer(
    absorbing: saving,
    child: Form(
      key: form,
      onChanged: () => setState(() => dirty = true),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: _settingsColumns(
                  wide: constraints.maxWidth >= 900,
                  sections: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _section('1', '開放服務', '選擇客人可以在預約時提出的用藥類型。', [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            '提供用藥協助',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            setting['enabled'] == true
                                ? '客人可在預約時提出需求，雙方確認後才執行。'
                                : '目前未開放，客人預約時不會出現填寫欄位。',
                          ),
                          value: setting['enabled'] == true,
                          onChanged: (value) =>
                              change(() => setting['enabled'] = value),
                        ),
                        if (setting['enabled'] == true) ...[
                          const Divider(height: 28),
                          Text(
                            '接受的服務 · 已選 ${types.length} 項',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, box) => Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: medicationTypes.entries.map((entry) {
                                final selected = types.contains(entry.key);
                                final color = Theme.of(
                                  context,
                                ).colorScheme.primary;
                                return SizedBox(
                                  width:
                                      (box.maxWidth -
                                          (box.maxWidth >= 700 ? 20 : 10)) /
                                      (box.maxWidth >= 700 ? 3 : 2),
                                  child: Material(
                                    color: selected
                                        ? color.withValues(alpha: .07)
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: selected
                                            ? color.withValues(alpha: .6)
                                            : const Color(0xFFE1E5ED),
                                      ),
                                    ),
                                    child: CheckboxListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      title: Text(
                                        entry.value,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      value: selected,
                                      onChanged: (value) => change(() {
                                        value == true
                                            ? types.add(entry.key)
                                            : types.remove(entry.key);
                                      }),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ]),
                      if (setting['enabled'] == true) ...[
                        _section('2', '可安排時間', '預約時供客人選擇的照護時段。', [
                          for (var i = 0; i < windows.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _timeButton(i, 'start', '開始時間'),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text('至'),
                                  ),
                                  Expanded(
                                    child: _timeButton(i, 'end', '結束時間'),
                                  ),
                                  if (windows.length > 1)
                                    IconButton(
                                      tooltip: '刪除此時段',
                                      onPressed: () =>
                                          change(() => windows.removeAt(i)),
                                      icon: const Icon(Icons.close, size: 20),
                                    ),
                                ],
                              ),
                            ),
                          if (windows.length < 4)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => change(
                                  () => windows.add({
                                    'start': '09:00',
                                    'end': '21:00',
                                  }),
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('新增照護時段'),
                              ),
                            ),
                          const SizedBox(height: 8),
                          medInput(note, '給客人的服務說明（選填）', lines: 3),
                        ]),
                        _section('3', '收費與結算', '設定計價單位、收款時機與費用調整。', [
                          LayoutBuilder(
                            builder: (context, box) => Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: medicationModes.entries.map((entry) {
                                final selected = setting['mode'] == entry.key;
                                final color = Theme.of(
                                  context,
                                ).colorScheme.primary;
                                const descriptions = {
                                  'free': '提供服務，不另收費',
                                  'visit': '每隻貓按用藥時間計次',
                                  'day': '每隻貓按用藥的住宿日計費',
                                  'quote': '看過需求後再報價',
                                };
                                return SizedBox(
                                  width: (box.maxWidth - 10) / 2,
                                  child: Material(
                                    color: selected
                                        ? color.withValues(alpha: .07)
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: selected
                                            ? color
                                            : const Color(0xFFE1E5ED),
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => change(
                                        () => setting['mode'] = entry.key,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  selected
                                                      ? Icons
                                                            .radio_button_checked
                                                      : Icons.radio_button_off,
                                                  size: 19,
                                                  color: selected
                                                      ? color
                                                      : Colors.grey,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    entry.value,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              descriptions[entry.key]!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF667085),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!['free', 'quote'].contains(setting['mode'])) ...[
                            medInput(
                              price,
                              '每隻貓／每${_medPriceUnit(setting['mode'])}費用（元）',
                              required: true,
                              number: true,
                            ),
                            _hint(
                              '${_medCountRule(setting)}\n'
                              "${setting['mode'] == 'visit' ? '例：一隻貓一天安排兩個時間，每次 50 元，當天共 100 元。' : '例：一隻貓在一個住宿日安排兩次同類型用藥，每日 50 元，當天共 50 元。'}",
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (['visit', 'day'].contains(setting['mode'])) ...[
                            DropdownButtonFormField<String>(
                              initialValue:
                                  setting['paymentTiming'] == 'advance'
                                  ? 'advance'
                                  : 'checkout',
                              decoration: const InputDecoration(
                                labelText: '用藥費何時收取',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'advance',
                                  child: Text('預約先收預估費用'),
                                ),
                                DropdownMenuItem(
                                  value: 'checkout',
                                  child: Text('退房時按實際結果收費'),
                                ),
                              ],
                              onChanged: (value) => change(
                                () => setting['paymentTiming'] = value,
                              ),
                            ),
                            _hint(medicationPaymentDescription(setting)),
                            const SizedBox(height: 12),
                          ],
                          if (setting['mode'] == 'quote')
                            _hint('客人先填寫用藥需求，店家再提出總報價，客人同意後生效。'),
                          if (setting['mode'] == 'free')
                            _hint('免收服務費；用藥安排仍須雙方確認。'),
                          if (setting['mode'] != 'free') ...[
                            _ruleSwitch(
                              '可拌入食物者免費',
                              '依原用藥指示可拌食時，不收此項服務費。',
                              'mixFree',
                            ),
                            _ruleSwitch(
                              '未成功不收費',
                              '依實際執行結果結算，未成功的服務不計費。',
                              'successOnly',
                            ),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text(
                                '更多計費規則',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: const Text(
                                '有分項計費或包含次數時再設定',
                                style: TextStyle(fontSize: 12),
                              ),
                              children: [
                                _ruleSwitch(
                                  '不同用藥類型分開計費',
                                  setting['mode'] == 'day'
                                      ? '開啟後，同一隻貓在同一住宿日的不同用藥類型分開收費。'
                                      : '按次收費時，開啟後同一隻貓在同一時間的不同用藥類型各算一次。',
                                  'splitTypes',
                                ),
                                _limitControl(
                                  times,
                                  '設定每日包含次數',
                                  '超過設定次數，改由店家個別報價。',
                                  '每日包含次數',
                                ),
                                if (types.contains('oral'))
                                  _limitControl(
                                    pills,
                                    '設定每次包含顆數',
                                    '適用口服藥錠與膠囊，超過顆數另報價。',
                                    '每次包含顆數',
                                  ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ],
                        ]),
                        if (constraints.maxWidth < 900) _settingsPreview(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _settingsColumns({required bool wide, required Widget sections}) {
    if (!wide || setting['enabled'] != true) return sections;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 20,
      children: [
        Expanded(child: sections),
        SizedBox(width: 290, child: _settingsPreview()),
      ],
    );
  }

  Widget _settingsPreview() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEDF1FA),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.visibility_outlined, size: 18),
            SizedBox(width: 8),
            Text('客人看到的規則', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          medRule({
            ...setting,
            'price': int.tryParse(price.text) ?? 0,
            'includedTimes': int.tryParse(times.text) ?? 0,
            'includedPills': int.tryParse(pills.text) ?? 0,
          }),
          style: const TextStyle(height: 1.6),
        ),
        const SizedBox(height: 6),
        const Text(
          '儲存後套用於新需求，既有訂單保留原規則。',
          style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
        ),
      ],
    ),
  );

  Widget _section(
    String step,
    String title,
    String subtitle,
    List<Widget> children,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE0E6F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 27,
              height: 27,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                step,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.5,
        color: Color(0xFF667085),
      ),
    ),
  );
  Widget _ruleSwitch(String title, String subtitle, String field) =>
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, height: 1.5),
        ),
        value: setting[field] == true,
        onChanged: (v) => change(() => setting[field] = v),
      );
  Widget _limitControl(
    TextEditingController controller,
    String title,
    String subtitle,
    String label,
  ) {
    final enabled = (int.tryParse(controller.text) ?? 0) > 0;
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            enabled ? subtitle : '未設定門檻，特殊需求仍由店家評估。',
            style: const TextStyle(fontSize: 12),
          ),
          value: enabled,
          onChanged: (v) => change(() => controller.text = v ? '1' : '0'),
        ),
        if (enabled) medInput(controller, label, number: true),
      ],
    );
  }

  Widget _timeButton(int i, String field, String label) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: () => pickWindow(i, field),
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
        ),
        const SizedBox(height: 4),
        Text(
          '${windows[i][field]}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
  Widget _saveFooter() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E6F0))),
      ),
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  saving
                      ? '正在儲存…'
                      : dirty
                      ? '有尚未儲存的變更'
                      : '設定已儲存',
                  style: TextStyle(
                    fontSize: 12,
                    color: dirty
                        ? const Color(0xFF946200)
                        : const Color(0xFF667085),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: const Icon(Icons.check, size: 18),
                label: Text(saving ? '儲存中…' : '儲存設定'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> pickWindow(int i, String field) async {
    final parts = '${windows[i][field]}'.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (t != null) {
      change(
        () => windows[i][field] =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
      );
    }
  }
}

class MedicationRequestEditor extends StatefulWidget {
  const MedicationRequestEditor({
    super.key,
    required this.shopId,
    required this.pets,
    required this.setting,
    required this.startDate,
    required this.endDate,
    required this.onChanged,
    this.initial,
    this.allowPhotoUpload = true,
    this.showFeeWaiverNotices = false,
    this.reviewByDate = false,
  });
  final String shopId;
  final List<Map<String, dynamic>> pets;
  final Map<String, dynamic> setting;
  final DateTime startDate, endDate;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final Map<String, dynamic>? initial;
  final bool allowPhotoUpload;
  final bool showFeeWaiverNotices;
  final bool reviewByDate;
  @override
  State<MedicationRequestEditor> createState() =>
      _MedicationRequestEditorState();
}

class _MedicationRequestEditorState extends State<MedicationRequestEditor> {
  late DateTime start, end;
  late List<Map<String, dynamic>> medicines;
  late Set<String> requiredPets;
  DateTime local(Object? raw, DateTime fallback) {
    final v = DateTime.tryParse('$raw');
    return v == null
        ? fallback
        : DateTime.parse(
            DateFormat(
              "yyyy-MM-dd'T'HH:mm:ss",
            ).format(v.toUtc().add(const Duration(hours: 8))),
          );
  }

  @override
  void initState() {
    super.initState();
    start = local(
      widget.initial?['careStart'],
      DateTime(
        widget.startDate.year,
        widget.startDate.month,
        widget.startDate.day,
        15,
      ),
    );
    end = local(
      widget.initial?['careEnd'],
      DateTime(
        widget.endDate.year,
        widget.endDate.month,
        widget.endDate.day,
        12,
      ),
    );
    final petIds = widget.pets.map(medPetId).toSet();
    medicines = medList(
      widget.initial?['medicines'],
    ).where((medicine) => petIds.contains(medicine['petId'])).toList();
    if (widget.reviewByDate && medicines.isEmpty) {
      for (final entry in medList(widget.initial?['preferences'])) {
        final dates = medList(entry['dates']);
        final types = entry['types'];
        if (dates.isEmpty ||
            types is! List ||
            types.isEmpty ||
            !petIds.contains(entry['petId'])) {
          continue;
        }
        medicines.add({
          'petId': entry['petId'],
          'type': types.first,
          'name': entry['name'] ?? '',
          'dose': entry['dose'] ?? '',
          'instruction': entry['note'] ?? '',
          'schedule': 'dated',
          'dates': dates,
        });
      }
    }
    requiredPets = {
      ...medicines.map((medicine) => '${medicine['petId']}'),
      ...?(widget.initial?['requiredPetIds'] as List?)?.whereType<String>(),
    }.intersection(petIds);
  }

  List<Map<String, dynamic>> get selectedMedicines => [
    for (final medicine in medicines)
      if (medicine['schedule'] != 'dated')
        medicine
      else if (_selectedDays(medicine).isNotEmpty)
        {...medicine, 'dates': _selectedDays(medicine)},
  ];

  List<Map<String, dynamic>> _selectedDays(Map<String, dynamic> medicine) =>
      medList(medicine['dates'])
          .where(
            (day) =>
                day['included'] != false && (day['times'] as List).isNotEmpty,
          )
          .map((day) => {'date': day['date'], 'times': day['times']})
          .toList();

  void emit() => widget.onChanged({
    'careStart': medIso(start),
    'careEnd': medIso(end),
    'medicines': selectedMedicines,
    'requiredPetIds': requiredPets.toList(),
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.reviewByDate)
        FormField<bool>(
          onSaved: (_) => emit(),
          builder: (_) => const SizedBox.shrink(),
        ),
      if (!widget.reviewByDate && widget.showFeeWaiverNotices)
        _MedicationWaiverNotices(widget.setting),
      if (!widget.reviewByDate) ...[
        Text(
          medRule(
            widget.setting,
            includeFeeWaivers: !widget.showFeeWaiverNotices,
          ),
        ),
        Text(
          '照護時段：${medList(widget.setting['windows']).map((w) => '${w['start']}～${w['end']}').join('、')}',
        ),
        if ('${widget.setting['note'] ?? ''}'.isNotEmpty)
          Text('${widget.setting['note']}'),
        const SizedBox(height: 8),
        const Text('依與飼主核對的日期、時間和藥袋指示填寫。'),
      ],
      if (widget.reviewByDate)
        LayoutBuilder(
          builder: (context, constraints) {
            const gutter = 20.0;
            final width = constraints.maxWidth >= 880 && widget.pets.length > 1
                ? (constraints.maxWidth - gutter) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: gutter,
              runSpacing: gutter,
              children: [
                for (final pet in widget.pets)
                  SizedBox(width: width, child: _petSection(pet)),
              ],
            );
          },
        )
      else
        for (final pet in widget.pets) _petSection(pet),
      if (!widget.reviewByDate && requiredPets.isNotEmpty) ...[
        const Divider(),
        const Text('店家負責的用藥期間'),
        const Text('填寫店家開始與停止負責用藥的時間。飼主已在家完成的次數請從安排中移除。'),
        TextButton(
          onPressed: () => pickRange(true),
          child: Text('開始：${DateFormat('MM/dd HH:mm').format(start)}'),
        ),
        TextButton(
          onPressed: () => pickRange(false),
          child: Text('結束：${DateFormat('MM/dd HH:mm').format(end)}'),
        ),
        FormField<bool>(
          validator: (_) => end.isAfter(start) ? null : '交接結束須晚於開始時間',
          builder: (state) => state.hasError
              ? Text(
                  state.errorText!,
                  style: const TextStyle(color: Colors.red),
                )
              : const SizedBox.shrink(),
        ),
      ],
    ],
  );
  Widget _petSection(Map<String, dynamic> pet) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: widget.reviewByDate
              ? CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: const Icon(Icons.pets, size: 19),
                )
              : null,
          title: Text(
            widget.reviewByDate
                ? '${pet['name'] ?? '貓咪'}'
                : '${pet['name'] ?? '貓咪'}需要用藥協助',
            style: widget.reviewByDate
                ? theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  )
                : null,
          ),
          subtitle: widget.reviewByDate ? const Text('用藥協助') : null,
          value: requiredPets.contains(medPetId(pet)),
          onChanged: (v) {
            setState(() {
              if (v) {
                requiredPets.add(medPetId(pet));
              } else {
                requiredPets.remove(medPetId(pet));
                medicines.removeWhere((m) => m['petId'] == medPetId(pet));
              }
            });
            emit();
          },
        ),
        if (requiredPets.contains(medPetId(pet))) ...[
          for (final entry in medList(widget.initial?['preferences']))
            if (entry['petId'] == medPetId(pet) &&
                (!widget.reviewByDate || medList(entry['dates']).isEmpty)) ...[
              Text(_medicationRequestLine(entry, '飼主預約需求')),
              for (final suggested in _requestedSchedules(entry))
                TextButton.icon(
                  onPressed: medicines.length >= 20
                      ? null
                      : () => edit(pet, null, suggested: suggested),
                  icon: const Icon(Icons.add),
                  label: Text('帶入 ${suggested['label']}'),
                ),
            ],
          FormField<bool>(
            validator: (_) {
              final selected = selectedMedicines.where(
                (m) => m['petId'] == medPetId(pet),
              );
              if (selected.isEmpty) {
                return widget.reviewByDate
                    ? '請排入至少一個用藥時段，或關閉此需求。'
                    : '請新增至少一筆藥品，或關閉此需求';
              }
              return null;
            },
            builder: (state) => state.hasError
                ? Text(
                    state.errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          for (final m in medicines.where((m) => m['petId'] == medPetId(pet)))
            if (widget.reviewByDate && m['schedule'] == 'dated')
              _datedCard(pet, m)
            else
              Card(
                child: ListTile(
                  title: Text('${m['name']}｜${medicationTypes[m['type']]}'),
                  subtitle: Text(
                    '每次 ${m['dose']}\n${scheduleText(m)}${m['from'] == null ? '' : '\n${medDate(m['from'])}～${medDate(m['until'])}'}',
                  ),
                  isThreeLine: false,
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: '編輯',
                        onPressed: () => edit(pet, m),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: '刪除',
                        onPressed: () {
                          setState(() => medicines.remove(m));
                          emit();
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: medicines.length >= 20 ? null : () => edit(pet, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增藥品／保健品'),
            ),
          ),
        ],
      ],
    );
    if (!widget.reviewByDate) return content;
    return Card.outlined(
      margin: EdgeInsets.zero,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
        child: content,
      ),
    );
  }

  Widget _datedCard(Map<String, dynamic> pet, Map<String, dynamic> medicine) {
    final days = medList(medicine['dates']);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = '${medicine['name'] ?? ''}'.trim();
    final dose = '${medicine['dose'] ?? ''}'.trim();
    return Card.outlined(
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: colors.surfaceContainerLow,
            child: ListTile(
              leading: Icon(Icons.medication_outlined, color: colors.primary),
              title: Text(
                medicationTypes[medicine['type']] ?? '用藥',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                [
                  if (name.isNotEmpty) name,
                  if (dose.isNotEmpty) '每次 $dose',
                ].join(' · '),
              ),
              trailing: TextButton(
                onPressed: () => edit(pet, medicine),
                child: const Text('藥名與用量'),
              ),
            ),
          ),
          for (final (index, day) in days.indexed) ...[
            if (index > 0) const Divider(height: 1),
            _datedRow(medicine, days, day, index),
          ],
        ],
      ),
    );
  }

  Widget _datedRow(
    Map<String, dynamic> medicine,
    List<Map<String, dynamic>> days,
    Map<String, dynamic> day,
    int index,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final included = day['included'] != false;
    final times = (day['times'] as List).whereType<String>().toList();
    final date = CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: included,
      dense: true,
      title: Text(
        DateFormat('yyyy/MM/dd').format(DateTime.parse('${day['date']}')),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: included ? null : const Text('不排入'),
      onChanged: (value) => setState(() {
        day['included'] = value;
        medicine['dates'] = days;
        emit();
      }),
    );
    final slots = !included
        ? Text(
            times.join('、'),
            style: TextStyle(color: colors.onSurfaceVariant),
          )
        : Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final time in times)
                InputChip(
                  backgroundColor: colors.secondaryContainer.withValues(
                    alpha: .48,
                  ),
                  avatar: Icon(Icons.schedule, size: 16, color: colors.primary),
                  label: Text(
                    time,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _changeTime(medicine, days, day, time),
                  onDeleted: () => setState(() {
                    day['times'] = times
                        .where((value) => value != time)
                        .toList();
                    medicine['dates'] = days;
                    emit();
                  }),
                  deleteButtonTooltipMessage: '刪除 $time',
                ),
              if (times.length < 12)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('加時間'),
                  onPressed: () => _changeTime(medicine, days, day),
                ),
            ],
          );
    return ColoredBox(
      color: index.isEven ? colors.surface : colors.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 410
              ? Row(
                  children: [
                    SizedBox(width: 140, child: date),
                    const SizedBox(width: 12),
                    Expanded(child: slots),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    date,
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 6),
                      child: slots,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _changeTime(
    Map<String, dynamic> medicine,
    List<Map<String, dynamic>> days,
    Map<String, dynamic> day, [
    String? old,
  ]) async {
    final parts = (old ?? '09:00').split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts.first),
        minute: int.parse(parts.last),
      ),
    );
    if (picked == null || !mounted) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    final times = (day['times'] as List).whereType<String>().toList();
    if (value == old) return;
    if (times.contains(value)) {
      medError(context, '這天已有相同用藥時間。');
      return;
    }
    setState(() {
      times.remove(old);
      times.add(value);
      day['times'] = times..sort();
      medicine['dates'] = days;
      emit();
    });
  }

  Future<void> pickRange(bool first) async {
    final value = await medPickDateTime(
      context,
      first ? start : end,
      widget.startDate,
      DateTime(
        widget.endDate.year,
        widget.endDate.month,
        widget.endDate.day,
        23,
        59,
      ),
    );
    if (value != null) {
      setState(() {
        if (first) {
          start = value;
        } else {
          end = value;
        }
      });
      emit();
    }
  }

  Iterable<Map<String, dynamic>> _requestedSchedules(
    Map<String, dynamic> entry,
  ) sync* {
    final types = entry['types'];
    if (types is! List || types.isEmpty) return;
    final days = medList(entry['dates']);
    int index = 0;
    while (index < days.length) {
      final day = days[index++];
      final date = DateTime.tryParse('${day['date']}');
      final times = (day['times'] as List? ?? []).whereType<String>().toList();
      if (date == null || times.isEmpty) continue;
      var last = date;
      while (index < days.length) {
        final next = DateTime.tryParse('${days[index]['date']}');
        if (next == null ||
            next.difference(last).inDays != 1 ||
            (days[index]['times'] as List? ?? []).join(',') !=
                times.join(',')) {
          break;
        }
        last = next;
        index++;
      }
      final endOfDay = DateTime(last.year, last.month, last.day, 23, 59);
      final format = DateFormat('MM/dd');
      final dateLabel = date == last
          ? format.format(date)
          : '${format.format(date)}–${format.format(last)}';
      yield {
        'type': types.first,
        'times': times,
        'name': entry['name'],
        'dose': entry['dose'],
        'instruction': entry['note'],
        'from': medIso(date.isBefore(start) ? start : date),
        'until': medIso(endOfDay.isAfter(end) ? end : endOfDay),
        'label': '$dateLabel ${times.join('、')}',
      };
    }
  }

  Future<void> edit(
    Map<String, dynamic> pet,
    Map<String, dynamic>? old, {
    Map<String, dynamic>? suggested,
  }) async {
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MedicationMedicineDialog(
        shopId: widget.shopId,
        setting: widget.setting,
        petId: medPetId(pet),
        initial: old ?? suggested,
        start: start,
        end: end,
        allowPhotoUpload: widget.allowPhotoUpload,
        allowMissingDetails: widget.reviewByDate,
      ),
    );
    if (value != null && mounted) {
      setState(() {
        final i = old == null ? -1 : medicines.indexOf(old);
        if (i < 0) {
          medicines.add(value);
        } else {
          medicines[i] = value;
        }
      });
      emit();
    }
  }
}

String scheduleText(Map<String, dynamic> m) => m['schedule'] == 'dated'
    ? medList(m['dates'])
          .map((day) => '${day['date']} ${(day['times'] as List).join('、')}')
          .join('\n')
    : m['schedule'] == 'interval'
    ? '從使用期間起點每隔 ${m['intervalHours']} 小時'
    : m['schedule'] == 'custom'
    ? '其他安排：${m['custom']}'
    : '${m['schedule'] == 'meal' ? '隨餐（時間待確認）' : '每日'} ${(m['times'] as List? ?? []).join('、')}';

class MedicationMedicineDialog extends StatefulWidget {
  const MedicationMedicineDialog({
    super.key,
    required this.shopId,
    required this.setting,
    required this.petId,
    required this.start,
    required this.end,
    this.initial,
    this.allowPhotoUpload = true,
    this.allowMissingDetails = false,
  });
  final String shopId, petId;
  final Map<String, dynamic> setting;
  final Map<String, dynamic>? initial;
  final DateTime start, end;
  final bool allowPhotoUpload;
  final bool allowMissingDetails;
  @override
  State<MedicationMedicineDialog> createState() =>
      _MedicationMedicineDialogState();
}

class _MedicationMedicineDialogState extends State<MedicationMedicineDialog> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      dose = TextEditingController(),
      instruction = TextEditingController(),
      reason = TextEditingController(),
      hours = TextEditingController(),
      custom = TextEditingController(),
      pills = TextEditingController();
  late String type, schedule, photoPath;
  late bool mix;
  bool uploading = false, limited = false;
  late DateTime from, until;
  List<String> times = [];
  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? {};
    name.text = '${m['name'] ?? ''}';
    dose.text = '${m['dose'] ?? ''}';
    instruction.text = '${m['instruction'] ?? ''}';
    reason.text = '${m['reason'] ?? ''}';
    hours.text = '${m['intervalHours'] ?? ''}';
    custom.text = '${m['custom'] ?? ''}';
    pills.text = '${m['pills'] ?? 0}';
    final accepted = (widget.setting['types'] as List? ?? []).where(
      (v) => medicationTypes.containsKey(v),
    );
    type = '${m['type'] ?? (accepted.isEmpty ? 'oral' : accepted.first)}';
    schedule = '${m['schedule'] ?? 'fixed'}';
    mix = m['mix'] == true;
    photoPath = '${m['photoPath'] ?? ''}';
    times = (m['times'] as List? ?? []).map((v) => '$v').toList();
    limited = m['from'] != null;
    from = parseLocal(m['from'], widget.start);
    until = parseLocal(m['until'], widget.end);
  }

  DateTime parseLocal(Object? v, DateTime fallback) {
    final d = DateTime.tryParse('$v');
    return d == null
        ? fallback
        : DateTime.parse(
            DateFormat(
              "yyyy-MM-dd'T'HH:mm:ss",
            ).format(d.toUtc().add(const Duration(hours: 8))),
          );
  }

  @override
  void dispose() {
    for (final c in [name, dose, instruction, reason, hours, custom, pills]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? '新增藥品／保健品' : '編輯用藥'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('依藥袋或獸醫指示填寫；不同藥品請分開新增。'),
              medInput(
                name,
                widget.allowMissingDetails ? '藥名（選填）' : '名稱',
                required: !widget.allowMissingDetails,
              ),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: '服務類型'),
                items: (widget.setting['types'] as List? ?? [])
                    .where((v) => medicationTypes.containsKey(v))
                    .map(
                      (v) => DropdownMenuItem(
                        value: '$v',
                        child: Text(medicationTypes[v]!),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => type = v!),
              ),
              medInput(
                dose,
                widget.allowMissingDetails
                    ? '每次用量與單位（選填）'
                    : '每次用量與單位，例如 1 顆、0.5 ml',
                required: !widget.allowMissingDetails,
              ),
              if (type == 'oral')
                medInput(pills, '每次藥錠／膠囊顆數（非錠劑填 0）', number: true),
              medInput(
                instruction,
                widget.allowMissingDetails ? '使用方式與注意事項（選填）' : '使用方式與注意事項',
                required: !widget.allowMissingDetails,
                lines: 3,
              ),
              medInput(reason, '用藥原因（選填）'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('依原有指示可拌入食物'),
                value: mix,
                onChanged: (v) => setState(() => mix = v!),
              ),
              if (schedule != 'dated') ...[
                DropdownButtonFormField<String>(
                  initialValue: schedule,
                  decoration: const InputDecoration(labelText: '用藥安排'),
                  items: const [
                    DropdownMenuItem(value: 'fixed', child: Text('每日指定時間')),
                    DropdownMenuItem(value: 'meal', child: Text('隨餐（填預計餐時）')),
                    DropdownMenuItem(value: 'interval', child: Text('每隔幾小時')),
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text('其他安排，請店家確認'),
                    ),
                  ],
                  onChanged: (v) => setState(() => schedule = v!),
                ),
                if (['fixed', 'meal'].contains(schedule)) ...[
                  Wrap(
                    spacing: 6,
                    children: times
                        .map(
                          (t) => InputChip(
                            label: Text(t),
                            onDeleted: () => setState(() => times.remove(t)),
                          ),
                        )
                        .toList(),
                  ),
                  TextButton(
                    onPressed: times.length >= 12
                        ? null
                        : () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: const TimeOfDay(hour: 9, minute: 0),
                            );
                            if (t != null && mounted) {
                              final value =
                                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                              setState(() {
                                if (!times.contains(value)) {
                                  times.add(value);
                                  times.sort();
                                }
                              });
                            }
                          },
                    child: const Text('＋新增時間'),
                  ),
                  Text('這項藥品每天安排 ${times.length} 個時間；預約試算會依旅館實際負責的期間計算。'),
                ],
                if (schedule == 'interval') ...[
                  medInput(hours, '間隔小時（1～168）', required: true, number: true),
                  const Text('以此藥使用期間的開始時間作為第一筆，請確認與原有指示一致。'),
                ],
                if (schedule == 'custom')
                  medInput(custom, '請說明安排，店家須確認具體時間', required: true, lines: 3),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('只在指定期間使用'),
                  value: limited,
                  onChanged: (v) => setState(() => limited = v!),
                ),
                if (limited) ...[
                  TextButton(
                    onPressed: () => pick(true),
                    child: Text('開始：${DateFormat('MM/dd HH:mm').format(from)}'),
                  ),
                  TextButton(
                    onPressed: () => pick(false),
                    child: Text(
                      '結束：${DateFormat('MM/dd HH:mm').format(until)}',
                    ),
                  ),
                ],
              ],
              if (photoPath.isNotEmpty) ...[
                const Text('已附藥袋照片'),
                TextButton(
                  onPressed: () => showMedicationPhoto(context, photoPath),
                  child: const Text('查看照片'),
                ),
              ],
              if (widget.allowPhotoUpload)
                OutlinedButton.icon(
                  onPressed: uploading ? null : upload,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    uploading
                        ? '照片上傳中…'
                        : photoPath.isEmpty
                        ? '上傳藥袋／說明照片'
                        : '更換照片',
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: uploading ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: uploading ? null : save,
        child: const Text('儲存藥品'),
      ),
    ],
  );
  Future<void> pick(bool first) async {
    final v = await medPickDateTime(
      context,
      first ? from : until,
      widget.start,
      widget.end,
    );
    if (v != null && mounted) {
      setState(() {
        if (first) {
          from = v;
        } else {
          until = v;
        }
      });
    }
  }

  void save() {
    if (!form.currentState!.validate()) return;
    if (['fixed', 'meal'].contains(schedule) && times.isEmpty) {
      medError(context, '請新增至少一個時間');
      return;
    }
    if (schedule == 'interval' &&
        ((int.tryParse(hours.text) ?? 0) < 1 ||
            (int.tryParse(hours.text) ?? 0) > 168)) {
      medError(context, '間隔請填 1～168 的整數');
      return;
    }
    if (limited &&
        (until.isBefore(from) ||
            from.isBefore(widget.start) ||
            until.isAfter(widget.end))) {
      medError(context, '使用期間須在交接期間內');
      return;
    }
    final count = int.tryParse(pills.text);
    if (type == 'oral' && (count == null || count < 0 || count > 100)) {
      medError(context, '顆數請填 0～100 的整數');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'petId': widget.petId,
      'name': name.text.trim(),
      'type': type,
      'dose': dose.text.trim(),
      'instruction': instruction.text.trim(),
      'reason': reason.text.trim(),
      'mix': mix,
      'pills': type == 'oral' ? count : 0,
      'schedule': schedule,
      'times': times,
      if (schedule == 'dated') 'dates': widget.initial?['dates'],
      'intervalHours': int.tryParse(hours.text) ?? 0,
      'custom': custom.text.trim(),
      'photoPath': photoPath,
      if (limited) 'from': medIso(from),
      if (limited) 'until': medIso(until),
    });
  }

  Future<void> upload() async {
    setState(() => uploading = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) throw Exception('請選擇 10 MB 以下的照片');
      final decoded = imaging.decodeImage(bytes);
      if (decoded == null) throw Exception('無法讀取照片，請選擇 JPG 或 PNG');
      final jpeg = imaging.encodeJpg(
        imaging.copyResize(
          decoded,
          width: decoded.width > 1600 ? 1600 : decoded.width,
        ),
        quality: 80,
      );
      if (jpeg.length > 5 * 1024 * 1024) throw Exception('照片過大，請縮小後重試');
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('請先登入');
      final path =
          'medication_uploads/$uid/${widget.shopId}/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await FirebaseStorage.instance
          .ref(path)
          .putData(jpeg, SettableMetadata(contentType: 'image/jpeg'));
      if (mounted) setState(() => photoPath = path);
    } catch (e) {
      if (mounted) medError(context, e);
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }
}

Future<void> showMedicationPhoto(BuildContext context, String path) async {
  try {
    final bytes = await FirebaseStorage.instance
        .ref(path)
        .getData(5 * 1024 * 1024);
    if (context.mounted && bytes != null) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('藥袋／用藥說明'),
          content: SizedBox(
            width: 600,
            child: InteractiveViewer(child: Image.memory(bytes)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('關閉'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    if (context.mounted) medError(context, e);
  }
}

bool medicationCollectsAdvance(Map<String, dynamic> setting) =>
    setting['enabled'] == true &&
    ['visit', 'day', 'night'].contains(setting['mode']) &&
    setting['paymentTiming'] == 'advance';

String medicationPaymentDescription(Map<String, dynamic> setting) =>
    medicationCollectsAdvance(setting)
    ? '預估用藥費隨預約收取；退房依實際結果重新結算。差額先抵扣尾款，已多付的部分由店家辦理退費。'
    : '預約時先顯示用藥預估費；退房依實際結果計入應付金額。';

List<Map<String, dynamic>> _datedMedicationTimes(Map<String, dynamic> entry) =>
    medList(entry['dates']);

List<String> _medTimes(Map<String, dynamic> entry) =>
    SafeParse.parseList(entry['times']).whereType<String>().toSet().toList();

String medicationBookingRate(Map<String, dynamic> setting) {
  final price = setting['price'] ?? 0;
  return switch (setting['mode']) {
    'visit' => 'NT\$ $price／每貓每次',
    'day' || 'night' => 'NT\$ $price／每貓每日',
    'free' => '免費',
    _ => '店家確認後報價',
  };
}

int? medicationPreferenceAmount(
  Map<String, dynamic> setting,
  List<Map<String, dynamic>> preferences,
  int stayDays,
) => _medicationPreferenceQuote(setting, preferences, stayDays)?.amount;

({int units, int amount})? _medicationPreferenceQuote(
  Map<String, dynamic> setting,
  List<Map<String, dynamic>> preferences,
  int stayDays,
) {
  if (setting['enabled'] != true || stayDays <= 0) return null;
  final mode = setting['mode'];
  if (!['visit', 'day', 'night', 'free'].contains(mode)) return null;
  final limit = SafeParse.parseMoney(setting['includedTimes']);
  final allowedTypes = SafeParse.parseList(setting['types']);
  final datedVisits = <(String, String, String), Set<String>>{};
  var legacyUnits = 0;
  for (final entry in preferences) {
    final petId = entry['petId'];
    final types = SafeParse.parseList(
      entry['types'],
    ).whereType<String>().toSet();
    if (petId is! String ||
        types.isEmpty ||
        !types.every(allowedTypes.contains)) {
      return null;
    }
    final groups = setting['splitTypes'] == true ? types : const {'all'};
    if (!entry.containsKey('dates')) {
      final times = _medTimes(entry);
      if (times.isEmpty ||
          (mode != 'free' && limit > 0 && times.length > limit)) {
        return null;
      }
      legacyUnits +=
          stayDays * groups.length * (mode == 'visit' ? times.length : 1);
      continue;
    }
    final dates = _datedMedicationTimes(entry);
    if (dates.isEmpty || types.length != 1) return null;
    for (final day in dates) {
      final date = day['date'];
      final times = _medTimes(day);
      if (date is! String || times.isEmpty) return null;
      datedVisits
          .putIfAbsent((petId, date, groups.single), () => {})
          .addAll(times);
    }
  }
  if (mode != 'free' &&
      limit > 0 &&
      datedVisits.values.any((times) => times.length > limit)) {
    return null;
  }
  final units =
      legacyUnits +
      (mode == 'visit'
          ? datedVisits.values.fold<int>(
              0,
              (runningUnits, times) => runningUnits + times.length,
            )
          : datedVisits.length);
  if (units == 0) return null;
  final unitPrice = mode == 'free'
      ? 0
      : (setting['price'] as num?)?.toInt() ?? 0;
  return (units: units, amount: units * unitPrice);
}

int _bookingMedicationStayDays(Map<String, dynamic> booking) {
  final start = SafeParse.parseDate(booking['startDate']);
  final end = SafeParse.parseDate(booking['endDate']);
  if (start == null || end == null) return 0;
  DateTime taiwanDay(DateTime date) {
    final taiwan = date.toUtc().add(const Duration(hours: 8));
    return DateTime.utc(taiwan.year, taiwan.month, taiwan.day);
  }

  return taiwanDay(end).difference(taiwanDay(start)).inDays;
}

class BookingMedicationRequestSection extends StatefulWidget {
  const BookingMedicationRequestSection({
    super.key,
    required this.theme,
    required this.pets,
    required this.startDate,
    required this.endDate,
    required this.setting,
    required this.initial,
    required this.onChanged,
  });

  final HomeThemeModel theme;
  final DateTime startDate, endDate;
  final List<Map<String, dynamic>> pets;
  final Map<String, dynamic> setting, initial;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<BookingMedicationRequestSection> createState() =>
      _BookingMedicationRequestSectionState();
}

class _MedicationDraftDetails {
  String name = '', dose = '', note = '';
}

class _MedicationDraftItem {
  _MedicationDraftItem(this.id, this.petId);

  final int id;
  final String petId;
  final dates = <String, List<String>>{};
  List<String> commonTimes = [];
  final types = <String>{};
  final details = <String, _MedicationDraftDetails>{};

  Iterable<Map<String, dynamic>> toPreferences() sync* {
    if (types.isEmpty) {
      yield _preference(null);
    } else {
      for (final type in types) {
        yield _preference(type);
      }
    }
  }

  Map<String, dynamic> _preference(String? type) {
    final info = details[type];
    final name = info?.name.trim() ?? '';
    final dose = info?.dose.trim() ?? '';
    final note = info?.note.trim() ?? '';
    return {
      'petId': petId,
      'dates': [
        for (final date in dates.keys.toList()..sort())
          {'date': date, 'times': List<String>.of(dates[date]!)},
      ],
      'types': [?type],
      if (name.trim().isNotEmpty) 'name': name.trim(),
      if (dose.trim().isNotEmpty) 'dose': dose.trim(),
      if (note.isNotEmpty) 'note': note,
    };
  }
}

class _BookingMedicationRequestSectionState
    extends State<BookingMedicationRequestSection> {
  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  List<DateTime> get _stayDates {
    final first = DateUtils.dateOnly(widget.startDate);
    final last = DateUtils.dateOnly(widget.endDate);
    return [
      for (
        var day = first;
        !day.isAfter(last);
        day = DateTime(day.year, day.month, day.day + 1)
      )
        day,
    ];
  }

  int _nextItemId = 0;
  late final _items = _restoreItems();

  int get _itemCount => _items.fold(
    0,
    (totalItems, item) =>
        totalItems + (item.types.isEmpty ? 1 : item.types.length),
  );

  List<_MedicationDraftItem> _restoreItems() {
    final items = <_MedicationDraftItem>[];
    final availableDates = _stayDates.map(_dateKey).toSet();
    final pets = widget.pets.map(medPetId).toSet();
    final savedCommonTimes = widget.initial['commonTimes'];
    final preferences = medList(widget.initial['preferences']);
    final sizes = widget.initial['arrangementSizes'];
    var offset = 0;
    for (var group = 0; offset < preferences.length; group++) {
      final size = sizes is List && group < sizes.length && sizes[group] is int
          ? (sizes[group] as int).clamp(1, preferences.length - offset)
          : 1;
      final entries = preferences.sublist(offset, offset + size);
      offset += size;
      final first = entries.first;
      final petId = first['petId'];
      if (petId is! String || !pets.contains(petId)) continue;
      final item = _MedicationDraftItem(_nextItemId++, petId);
      for (final entry in entries) {
        for (final type
            in (entry['types'] as List? ?? []).whereType<String>()) {
          item.types.add(type);
          item.details[type] = _MedicationDraftDetails()
            ..name = entry['name'] as String? ?? ''
            ..dose = entry['dose'] as String? ?? ''
            ..note = entry['note'] as String? ?? '';
        }
      }
      for (final day in _datedMedicationTimes(first)) {
        if (availableDates.contains(day['date'])) {
          item.dates[day['date'] as String] = _medTimes(day);
        }
      }
      final savedTimes = switch (savedCommonTimes) {
        List times when group < times.length => times[group],
        Map times => times[petId],
        _ => null,
      };
      item.commonTimes = savedTimes is List
          ? savedTimes.whereType<String>().toList()
          : item.dates.values.firstOrNull?.toList() ?? [];
      items.add(item);
    }
    return items;
  }

  @override
  void didUpdateWidget(covariant BookingMedicationRequestSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pets = widget.pets.map(medPetId).toSet();
    _items.removeWhere((item) => !pets.contains(item.petId));
  }

  List<String> get _allowedTypes => (widget.setting['types'] as List? ?? [])
      .whereType<String>()
      .where(medicationTypes.containsKey)
      .toSet()
      .toList();

  Widget _estimate(TextStyle style, List<String> available) {
    if (_items.isEmpty ||
        _items.any((item) => _itemError(item, available) != null)) {
      return const SizedBox.shrink();
    }
    final mode = widget.setting['mode'];
    final total = medicationPreferenceAmount(
      widget.setting,
      _preferences,
      _stayDates.length - 1,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode == 'free')
            Text('用藥預估 NT\$ 0（免費）', style: style)
          else if (total == null)
            Text(
              mode == 'quote' ? '用藥費由店家評估後報價' : '超出每日包含次數，由店家另行報價',
              style: style,
            )
          else
            Text(
              '用藥預估小計 NT\$ $total',
              style: style.copyWith(fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }

  String _arrangementTypes(_MedicationDraftItem item) => item.types
      .map((type) {
        final label = medicationTypes[type] ?? type;
        final name = item.details[type]?.name.trim() ?? '';
        return name.isEmpty ? label : '$label（$name）';
      })
      .join('、');

  String? _itemError(_MedicationDraftItem item, List<String> available) {
    if (item.commonTimes.isEmpty &&
        !item.dates.values.any((times) => times.isNotEmpty)) {
      return '請先選擇用藥時間';
    }
    if (item.types.isEmpty) return '請至少選一種用藥類型';
    if (!item.types.every(_allowedTypes.contains)) {
      return '店家接受的用藥類型已變更，請重新選擇';
    }
    if (item.dates.isEmpty) return '請先選擇需要用藥的日期';
    if (item.dates.values.any((times) => times.isEmpty)) {
      return '請為每個已選日期選擇至少一個時段';
    }
    if (item.dates.entries.any(
      (day) => day.value.any((time) => !available.contains(time)),
    )) {
      return '照護時段已變更，請重新選擇';
    }
    return null;
  }

  List<String> _availableTimes() {
    final windows = medList(widget.setting['windows']);
    final times = <String>[];
    for (var minute = 0; minute < 24 * 60; minute += 30) {
      final hour = (minute ~/ 60).toString().padLeft(2, '0');
      final time = '$hour:${minute % 60 == 0 ? '00' : '30'}';
      if (_withinWindow(time, windows)) times.add(time);
    }
    return times;
  }

  bool _withinWindow(String time, List<Map<String, dynamic>> windows) =>
      windows.any(
        (window) =>
            time.compareTo('${window['start']}') >= 0 &&
            time.compareTo('${window['end']}') <= 0,
      );

  void _setCommonTimes(_MedicationDraftItem item, List<String> times) {
    final dates = item.dates;
    for (final date in dates.keys.toList()) {
      if (dates.length == 1 || listEquals(dates[date], item.commonTimes)) {
        dates[date] = List.of(times);
      }
    }
    item.commonTimes = times;
  }

  List<Map<String, dynamic>> get _preferences => [
    for (final item in _items) ...item.toPreferences(),
  ];

  void _change(VoidCallback edit) {
    setState(edit);
    widget.onChanged({
      'preferences': _preferences,
      'arrangementSizes': [
        for (final item in _items) item.types.isEmpty ? 1 : item.types.length,
      ],
      'commonTimes': [
        for (final item in _items) List<String>.of(item.commonTimes),
      ],
    });
  }

  Widget _handoverFields(
    _MedicationDraftItem item,
    String type,
    TextStyle style,
  ) {
    final info = item.details.putIfAbsent(type, _MedicationDraftDetails.new);
    return Column(
      key: ValueKey(type),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (item.types.length > 1)
          Text(medicationTypes[type] ?? type, style: style),
        for (final (label, value, limit, update)
            in <(String, String, int, ValueChanged<String>)>[
              ('藥名', info.name, 100, (value) => info.name = value),
              ('每次用量', info.dose, 100, (value) => info.dose = value),
              ('注意事項', info.note, 500, (value) => info.note = value),
            ])
          TextFormField(
            key: PageStorageKey<String>('$type-$label'),
            initialValue: value,
            maxLength: limit,
            decoration: InputDecoration(labelText: label, counterText: ''),
            onChanged: update,
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _timePicker(
    String label,
    List<String> times,
    List<String> available,
    OutlinedBorder shape,
    TextStyle style,
    ValueChanged<List<String>> onChanged,
  ) {
    final theme = widget.theme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Text(label, style: style),
          if (times.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final time in times)
                  InputChip(
                    label: Text(time, style: style),
                    shape: shape,
                    backgroundColor: theme.backgroundColor,
                    deleteIconColor: theme.primaryColor,
                    onDeleted: () =>
                        onChanged(times.where((item) => item != time).toList()),
                  ),
              ],
            ),
          if (times.length < 12 &&
              available.any((time) => !times.contains(time)))
            DropdownButtonHideUnderline(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: theme.backgroundColor,
                  shape: shape,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    menuMaxHeight: 290,
                    dropdownColor: theme.cardColor,
                    style: style,
                    hint: Text(times.isEmpty ? '選擇時間' : '再加一個時間', style: style),
                    items: [
                      for (final time in available)
                        if (!times.contains(time))
                          DropdownMenuItem(value: time, child: Text(time)),
                    ],
                    onChanged: (time) {
                      if (time == null) return;
                      onChanged([...times, time]..sort());
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _dateSummary(Iterable<String> dates) =>
      (dates.toList()..sort()).map(_shortMedicationDate).join('、');

  String _scheduleSummary(_MedicationDraftItem item) {
    final groups = <String, List<String>>{};
    for (final date in item.dates.keys.toList()..sort()) {
      groups.putIfAbsent(item.dates[date]!.join('、'), () => []).add(date);
    }
    return groups.entries
        .map((group) => '${group.key} · ${_dateSummary(group.value)}')
        .join('；');
  }

  Future<void> _editArrangement(
    Map<String, dynamic> pet, {
    _MedicationDraftItem? original,
  }) async {
    final petId = medPetId(pet);
    final draft = _MedicationDraftItem(original?.id ?? _nextItemId++, petId);
    if (original != null) {
      draft.commonTimes = List.of(original.commonTimes);
      draft.types.addAll(original.types);
      for (final day in original.dates.entries) {
        draft.dates[day.key] = List.of(day.value);
      }
      for (final detail in original.details.entries) {
        draft.details[detail.key] = _MedicationDraftDetails()
          ..name = detail.value.name
          ..dose = detail.value.dose
          ..note = detail.value.note;
      }
    }
    final dates = draft.dates;
    final available = _availableTimes();
    final allowedTypes = _allowedTypes;
    final capacity = 20 - _itemCount + (original?.types.length ?? 0);
    final theme = widget.theme;
    final style = TextStyle(color: theme.textColor, fontSize: 14);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: theme.cardBorderColor),
    );
    final checkIn = _dateKey(widget.startDate);
    final checkout = _dateKey(widget.endDate);
    final stayDays = _stayDates
        .map(_dateKey)
        .where((date) => date != checkout)
        .toList();
    String? section, editingDate, error;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          void change(VoidCallback edit) => update(() {
            edit();
            error = null;
          });

          Widget field(String id, String label, String value, Widget content) {
            final expanded = section == id;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: theme.backgroundColor,
                  shape: shape,
                  child: InkWell(
                    customBorder: shape,
                    onTap: () => change(() => section = expanded ? null : id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: Text(
                              label,
                              style: style.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              value,
                              style: style,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            expanded ? Icons.expand_less : Icons.chevron_right,
                            color: theme.textColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (expanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                    child: content,
                  ),
              ],
            );
          }

          final dayKeys = dates.keys.toList()..sort();
          final editDay = dates.containsKey(editingDate)
              ? editingDate
              : dayKeys.where((date) => dates[date]!.isEmpty).firstOrNull ??
                    dayKeys.firstOrNull;
          final commonTimes = dates.length == 1
              ? dates.values.single
              : draft.commonTimes;
          final allStayDays =
              stayDays.isNotEmpty && stayDays.every(dates.containsKey);

          return AlertDialog(
            backgroundColor: theme.cardColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 20,
            ),
            scrollable: true,
            titlePadding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
            title: Row(
              children: [
                const SizedBox(width: 36),
                Expanded(
                  child: Column(
                    children: [
                      Text("${pet['name'] ?? '貓咪'}", style: style),
                      Text(
                        original == null ? '新增用藥安排' : '編輯用藥安排',
                        textAlign: TextAlign.center,
                        style: style.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '關閉',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: Icon(Icons.close, color: theme.textColor),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  field(
                    'time',
                    '時間',
                    commonTimes.isEmpty ? '選擇時間' : commonTimes.join('、'),
                    _timePicker(
                      '可選多個時間',
                      commonTimes,
                      available,
                      shape,
                      style,
                      (times) => change(() => _setCommonTimes(draft, times)),
                    ),
                  ),
                  field(
                    'types',
                    '用藥',
                    draft.types.isEmpty ? '選擇用藥類型' : _arrangementTypes(draft),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final type in {...allowedTypes, ...draft.types})
                          FilterChip(
                            label: Text(
                              medicationTypes[type] ?? type,
                              style: style,
                            ),
                            shape: shape,
                            selected: draft.types.contains(type),
                            selectedColor: theme.primaryColor.withValues(
                              alpha: .15,
                            ),
                            onSelected:
                                !draft.types.contains(type) &&
                                    draft.types.length >= capacity
                                ? null
                                : (selected) => change(() {
                                    if (selected) {
                                      draft.types.add(type);
                                    } else {
                                      draft.types.remove(type);
                                    }
                                  }),
                          ),
                      ],
                    ),
                  ),
                  field(
                    'dates',
                    '日期',
                    dates.isEmpty ? '選擇適用日期' : _dateSummary(dayKeys),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (stayDays.length > 1)
                              FilterChip(
                                label: const Text('全選住宿日'),
                                shape: shape,
                                selected: allStayDays,
                                onSelected: (selected) => change(() {
                                  for (final date in stayDays) {
                                    if (selected) {
                                      dates.putIfAbsent(
                                        date,
                                        () => List.of(draft.commonTimes),
                                      );
                                    } else {
                                      dates.remove(date);
                                    }
                                  }
                                }),
                              ),
                            for (final day in _stayDates)
                              FilterChip(
                                label: Text(
                                  _dateKey(day) == checkout
                                      ? '${day.month}/${day.day}（退房日）'
                                      : _dateKey(day) == checkIn
                                      ? '${day.month}/${day.day}（入住日）'
                                      : '${day.month}/${day.day}',
                                  style: style,
                                ),
                                shape: shape,
                                selected: dates.containsKey(_dateKey(day)),
                                selectedColor: theme.primaryColor.withValues(
                                  alpha: .15,
                                ),
                                onSelected: (selected) => change(() {
                                  final date = _dateKey(day);
                                  if (selected) {
                                    dates[date] = List.of(draft.commonTimes);
                                  } else {
                                    dates.remove(date);
                                  }
                                }),
                              ),
                          ],
                        ),
                        if (dates.values.any((times) => times.isEmpty) &&
                            draft.commonTimes.isNotEmpty)
                          Text('部分日期沒有可用時段，請調整時間。', style: style),
                        if (dayKeys.length > 1)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () =>
                                  change(() => section = 'override'),
                              child: const Text('調整個別日期'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (dates.containsKey(checkIn) || dates.containsKey(checkout))
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        [
                          if (dates.containsKey(checkIn)) '入住日：請確認用藥時間在辦理入住後。',
                          if (dates.containsKey(checkout)) '退房日：請確認用藥時間在接回貓咪前。',
                        ].join('\n'),
                        style: style.copyWith(fontSize: 12),
                      ),
                    ),
                  if (section == 'override' && editDay != null) ...[
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final date in dayKeys)
                          ChoiceChip(
                            label: Text(_shortMedicationDate(date)),
                            selected: editDay == date,
                            onSelected: (_) => change(() => editingDate = date),
                          ),
                      ],
                    ),
                    _timePicker(
                      '${_shortMedicationDate(editDay)}・希望時段',
                      dates[editDay]!,
                      available,
                      shape,
                      style,
                      (times) => change(() => dates[editDay] = times),
                    ),
                    TextButton(
                      onPressed: () => change(
                        () => dates[editDay] = List.of(draft.commonTimes),
                      ),
                      child: const Text('恢復共用時段'),
                    ),
                  ],
                  if (draft.types.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => change(
                          () =>
                              section = section == 'details' ? null : 'details',
                        ),
                        child: const Text('藥品資料（選填）'),
                      ),
                    ),
                    if (section == 'details')
                      for (final type in draft.types)
                        _handoverFields(draft, type, style),
                  ],
                  if (error != null)
                    Text(
                      error!,
                      style: style.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () {
                      final problem = _itemError(draft, available);
                      if (problem != null) {
                        update(() => error = problem);
                      } else {
                        Navigator.pop(dialogContext, 'save');
                      }
                    },
                    child: const Text('儲存安排'),
                  ),
                  if (original != null)
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, 'remove'),
                      child: const Text('移除安排'),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
    if (!mounted ||
        result == null ||
        !widget.pets.any((pet) => medPetId(pet) == petId)) {
      return;
    }
    _change(() {
      if (result == 'remove') {
        _items.remove(original);
      } else if (original == null) {
        _items.add(draft);
      } else {
        final index = _items.indexOf(original);
        if (index >= 0) _items[index] = draft;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final bodyStyle = TextStyle(color: theme.textColor, fontSize: 14);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(9),
      side: BorderSide(color: theme.cardBorderColor),
    );
    final available = _availableTimes();
    final allowedTypes = _allowedTypes;
    final note = (widget.setting['note'] as String? ?? '').trim();
    final pricing = {
      ...widget.setting,
      if (widget.setting['mode'] == 'night') 'mode': 'day',
      'dayRule': 'service_dates',
    };
    if ((available.isEmpty || allowedTypes.isEmpty) && _items.isEmpty) {
      return Text('如需用藥協助，請先聯繫店家。', style: bodyStyle);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final pet in widget.pets) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  "${pet['name'] ?? '貓咪'}",
                  style: bodyStyle.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _itemCount >= 20
                    ? null
                    : () => _editArrangement(pet),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增安排'),
              ),
            ],
          ),
          for (final item in _items.where(
            (item) => item.petId == medPetId(pet),
          ))
            FormField<bool>(
              key: ValueKey(item.id),
              validator: (_) => _itemError(item, available),
              builder: (state) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  shape: shape,
                  color: theme.backgroundColor,
                  child: ListTile(
                    shape: shape,
                    dense: true,
                    title: Text(
                      _arrangementTypes(item),
                      style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      state.errorText ?? _scheduleSummary(item),
                      style: bodyStyle.copyWith(
                        fontSize: 12,
                        color: state.hasError
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: theme.textColor,
                      size: 20,
                    ),
                    onTap: () => _editArrangement(pet, original: item),
                  ),
                ),
              ),
            ),
        ],
        _estimate(bodyStyle, available),
        if (pricing['mixFree'] == true || pricing['successOnly'] == true) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final label in [
                if (pricing['mixFree'] == true) '可拌食者免費',
                if (pricing['successOnly'] == true) '未成功不收費',
              ])
                Chip(
                  avatar: Icon(
                    Icons.check,
                    size: 16,
                    color: theme.primaryColor,
                  ),
                  label: Text(label, style: bodyStyle.copyWith(fontSize: 12)),
                  shape: shape,
                  side: BorderSide(color: theme.cardBorderColor),
                  backgroundColor: theme.primaryColor.withValues(alpha: .08),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        ExpansionTile(
          key: const PageStorageKey<String>('medication-fee-details'),
          dense: true,
          tilePadding: EdgeInsets.zero,
          title: Text('查看計費說明', style: bodyStyle),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              medRule(pricing, includeFeeWaivers: false),
              style: bodyStyle.copyWith(fontSize: 12),
            ),
            if (pricing['successOnly'] == true)
              Text(
                medicationCollectsAdvance(pricing)
                    ? '未成功的用藥費於退房時扣除。'
                    : '未成功的用藥不計入退房應付金額。',
                style: bodyStyle.copyWith(fontSize: 12),
              ),
            if (['visit', 'day'].contains(pricing['mode']))
              Text(
                medicationPaymentDescription(pricing),
                style: bodyStyle.copyWith(fontSize: 12),
              ),
            if (note.isNotEmpty)
              Text(note, style: bodyStyle.copyWith(fontSize: 12)),
            Text('實際用藥安排由店家確認。', style: bodyStyle.copyWith(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

List<String> _medicationRequestTypes(Map<String, dynamic> entry) {
  final requested = entry['types'];
  final types = [
    if (requested is List) ...requested.whereType<String>(),
    if (entry['type'] case final String type) type,
  ];
  return types.map((type) => medicationTypes[type]).nonNulls.toSet().toList();
}

List<String> _medicationRequestTimes(Map<String, dynamic> entry) {
  final requested = entry['times'];
  return requested is List
      ? requested
            .whereType<String>()
            .where((time) => time.trim().isNotEmpty)
            .toList()
      : const [];
}

String _shortMedicationDate(Object? value) {
  final date = DateTime.tryParse('$value');
  return date == null ? '$value' : '${date.month}/${date.day}';
}

List<String> _medicationScheduleLines(Map<String, dynamic> entry) => [
  for (final day in _datedMedicationTimes(entry))
    "${_shortMedicationDate(day['date'])} ${_medTimes(day).join('、')}",
  if (_medicationRequestTimes(entry) case final times when times.isNotEmpty)
    '每日 ${times.join('、')}',
];

List<String> _medicationHandoverDetails(Map<String, dynamic> entry) => [
  if (entry['name'] case final String name when name.isNotEmpty) '藥名 $name',
  if (entry['dose'] case final String dose when dose.isNotEmpty) '每次 $dose',
  if (entry['note'] case final String note when note.isNotEmpty) '注意事項 $note',
];

String _medicationRequestLine(Map<String, dynamic> entry, String petName) {
  final labels = _medicationRequestTypes(entry);
  return [
    petName.isEmpty ? '貓咪' : petName,
    if (labels.isNotEmpty) labels.join('、'),
    ..._medicationScheduleLines(entry),
    ..._medicationHandoverDetails(entry),
  ].join('・');
}

class _CustomerMedicationRequest extends StatelessWidget {
  const _CustomerMedicationRequest({
    required this.entry,
    required this.petName,
  });

  final Map<String, dynamic> entry;
  final String petName;

  @override
  Widget build(BuildContext context) {
    final theme = BookingDetailUi.of(context);
    final types = _medicationRequestTypes(entry);
    final days = _medicationScheduleLines(entry);
    final times = _medicationRequestTimes(entry);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.pets_outlined, size: 18, color: theme.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(
                    petName.isEmpty ? '貓咪' : petName,
                    style: TextStyle(
                      color: theme.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (types.isNotEmpty)
                    Text(types.join('、'), style: TextStyle(color: theme.muted)),
                  for (final detail in _medicationHandoverDetails(entry))
                    Text(detail, style: TextStyle(color: theme.muted)),
                  if (times.isEmpty)
                    for (final day in days)
                      Text(day, style: TextStyle(color: theme.text)),
                  if (times.isNotEmpty) ...[
                    Text(
                      '每日希望時段',
                      style: TextStyle(color: theme.muted, fontSize: 12),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final time in times)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.card,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              child: Text(
                                time,
                                style: TextStyle(
                                  color: theme.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic> _recordedMedicine(
  Map<String, dynamic> task,
  Map<String, dynamic> medicine,
) => {
  ...medicine,
  ...medMap(medMap(task['medicineDetailsSnapshot'])[medicine['id']]),
};

String _medicineTitle(Map<String, dynamic> medicine) {
  final name = '${medicine['name'] ?? ''}'.trim();
  final dose = '${medicine['dose'] ?? ''}'.trim();
  return [
    name.isEmpty ? (medicationTypes[medicine['type']] ?? '用藥') : name,
    if (dose.isNotEmpty) dose,
  ].join(' · ');
}

class BookingMedicationPanel extends StatefulWidget {
  const BookingMedicationPanel({
    super.key,
    required this.bookingId,
    required this.booking,
    this.staff = false,
    this.canManage = true,
    this.initialFilter = 'all',
    this.taskId,
    this.summaryOnly = false,
    this.customerDetails = false,
    this.arrangementLayout = false,
    this.inlineTaskResult = false,
    this.onTaskRecorded,
    this.onViewOrderConfirmation,
    this.referencePricing = const {},
  });
  final String bookingId;
  final Map<String, dynamic> booking;
  final bool staff;
  final bool canManage;
  final bool summaryOnly;
  final bool customerDetails;
  final bool arrangementLayout;
  final bool inlineTaskResult;
  final VoidCallback? onTaskRecorded;
  final VoidCallback? onViewOrderConfirmation;
  final Map<String, dynamic> referencePricing;
  final String initialFilter;
  final String? taskId;
  @override
  State<BookingMedicationPanel> createState() => _BookingMedicationPanelState();
}

class _BookingMedicationPanelState extends State<BookingMedicationPanel> {
  bool busy = false;
  late String filter;
  bool _openedTaskForm = false;
  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter;
  }

  Map<String, dynamic> get medication => medMap(widget.booking['medication']);
  Future<void> act(
    String action, [
    Map<String, dynamic> extra = const {},
  ]) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await medCall('manageBookingMedication', {
        'bookingId': widget.bookingId,
        'revision': medication['revision'],
        'action': action,
        ...extra,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('用藥資料已更新')));
      }
    } catch (e) {
      if (mounted) medError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = medication;
    final request = medMap(
      m.isEmpty ? widget.booking['medicationRequest'] : m['request'],
    );
    final setting = medMap(m['setting']);
    final preferences = medList(request['preferences']);
    final medicines = medList(request['medicines']),
        tasks = medList(m['tasks']);
    final pets = medList(widget.booking['pets']);
    String petName(Object? id) => pets
        .where((p) => medPetId(p) == id)
        .map((p) => '${p['name']}')
        .join('、');
    if (widget.taskId != null) {
      final task = tasks
          .where((entry) => entry['id'] == widget.taskId)
          .firstOrNull;
      final entry = BookingMedicationTask.fromBooking(
        widget.booking,
      ).where((entry) => entry.id == widget.taskId).firstOrNull;
      if (task == null || entry == null) {
        return const Text('這個用藥時段已取消或變更');
      }
      final canRecord =
          widget.staff &&
          widget.canManage &&
          entry.pending &&
          BookingMedicationTask.canRecord(widget.booking);
      final ids = task['medicineIds'];
      if (canRecord && widget.inlineTaskResult) {
        return _MedicationResultForm(
          bookingId: widget.bookingId,
          booking: widget.booking,
          task: task,
          entry: entry,
          onRecorded: widget.onTaskRecorded,
        );
      }
      if (canRecord && !_openedTaskForm) {
        _openedTaskForm = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ModalRoute.of(context)?.isCurrent == true) {
            record(task, entry: entry);
          }
        });
      }
      return medCard('本次用藥', [
        Text('貓咪：${entry.pet}', style: Theme.of(context).textTheme.titleLarge),
        Text('房間：${widget.booking['roomName'] ?? '尚未分房'}'),
        if ('${widget.booking['customerName'] ?? ''}'.trim().isNotEmpty)
          Text("飼主：${widget.booking['customerName']}"),
        Text('預定時間：${medDate(task['scheduledAt'])}'),
        if (entry.actualAt != null)
          Text('實際時間：${medDate(entry.actualAt!.toIso8601String())}'),
        if ('${task['note'] ?? ''}'.trim().isNotEmpty)
          Text("結果說明：${task['note']}"),
        Text('${entry.day} · ${entry.types} · ${entry.resultLabel}'),
        if (entry.pending && widget.booking['status'] == 'confirmed')
          const Text('辦理入住後即可登記用藥結果。'),
        for (final medicine in medicines)
          if (ids is List && ids.contains(medicine['id']))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_medicineTitle(_recordedMedicine(task, medicine))),
              subtitle: Text(
                [
                  '${_recordedMedicine(task, medicine)['instruction'] ?? ''}',
                  if (medicationResults[medMap(
                        task['medicineResults'],
                      )[medicine['id']]]
                      case final String result)
                    result,
                ].where((text) => text.isNotEmpty).join(' · '),
              ),
            ),
        if (canRecord)
          FilledButton(
            onPressed: busy ? null : () => record(task, entry: entry),
            child: const Text('記錄執行結果'),
          ),
      ]);
    }
    final estimate = medMap(m['estimate']);
    final customerLayout = widget.customerDetails && !widget.staff;
    final status = m['finalized'] == true
        ? '用藥費已結算'
        : medicationStates[m['state']] ?? '待店家確認';
    final theme = BookingDetailUi.of(context);

    Widget requestEntry(Map<String, dynamic> entry) {
      final name = petName(entry['petId']);
      return customerLayout || widget.staff || widget.arrangementLayout
          ? _CustomerMedicationRequest(entry: entry, petName: name)
          : Text(_medicationRequestLine(entry, name));
    }

    Widget panel(List<Widget> children, {bool showStatus = true}) {
      if (widget.arrangementLayout) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: children,
          ),
        );
      }
      if (widget.staff) {
        return Card.outlined(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Text('用藥協助', style: Theme.of(context).textTheme.titleMedium),
                ...children,
              ],
            ),
          ),
        );
      }
      if (!customerLayout) return medCard('用藥協助', children);
      final accent = m['state'] == 'confirmed' || m['finalized'] == true
          ? theme.success
          : theme.primary;
      return BookingDetailCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            const BookingDetailSectionTitle('用藥協助'),
            if (showStatus)
              Align(
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ...children,
          ],
        ),
      );
    }

    Widget fee(String text, {List<String> details = const []}) {
      if (widget.arrangementLayout) {
        final colors = Theme.of(context).colorScheme;
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: colors.primaryContainer.withValues(alpha: 0.45),
          leading: Icon(Icons.receipt_long_outlined, color: colors.primary),
          title: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      }
      if (!customerLayout) return Text(text);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.primary.withValues(alpha: 0.08),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.receipt_long_outlined, size: 18, color: theme.muted),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 5,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: theme.text,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  for (final detail in details)
                    Text(
                      detail,
                      style: TextStyle(color: theme.text, height: 1.45),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget customerFee() {
      final finalized = m['finalized'] == true;
      final declined = ['declined', 'cancelled'].contains(m['state']);
      final bookingStatus = widget.booking['status'];
      final closed =
          ['completed', 'cancelled', 'checked_out'].contains(bookingStatus) ||
          widget.booking['settlementConfirmed'] == true ||
          widget.booking['settledAt'] != null;
      final advance = m['advanceAmount'];
      final finalAmount = m['finalAmount'];
      final agreed = m['agreedAmount'];
      final estimateAmount = estimate['amount'];
      if (finalized) {
        return fee(finalAmount is num ? '用藥結算 NT\$ $finalAmount' : '用藥費已結算');
      }
      if (declined || bookingStatus == 'cancelled') return fee('用藥安排未成立');
      final reference = setting.isEmpty
          ? widget.referencePricing
          : const <String, dynamic>{};
      final price = setting.isEmpty ? reference : setting;
      final unit = _medPriceUnit(price['mode']);
      final defaultPrice = price['price'];
      final String? rate = switch (price['mode']) {
        'free' => '免費',
        'quote' => '評估後報價',
        _ when unit.isNotEmpty && defaultPrice is num && defaultPrice >= 0 =>
          '每隻貓每$unit NT\$ $defaultPrice',
        _ => null,
      };
      // Old requests may have schedules but no rate or estimate snapshot.
      // Show a reference estimate only, never use it as an amount due.
      final referenceQuote =
          !closed &&
              agreed is! num &&
              estimateAmount is! num &&
              estimate['manual'] != true &&
              rate != null &&
              reference.isNotEmpty
          ? _medicationPreferenceQuote(
              reference,
              preferences,
              _bookingMedicationStayDays(widget.booking),
            )
          : null;
      return fee(
        agreed is num
            ? '店家報價 NT\$ $agreed'
            : estimateAmount is num
            ? '用藥預估 NT\$ $estimateAmount'
            : referenceQuote != null
            ? '依現行費率預估 NT\$ ${referenceQuote.amount}'
            : '本單用藥費待確認',
        details: [
          if (rate != null && setting.isNotEmpty) '下單時的店家預設費率：$rate',
          if (rate != null && reference['enabled'] == true) ...[
            '店家目前參考費率：$rate',
            if (referenceQuote != null && unit.isNotEmpty)
              'NT\$ $defaultPrice × ${referenceQuote.units} $unit',
            '這筆訂單未保存下單時的費率，請以店家確認的金額為準。',
          ],
          if (advance is num && advance > 0)
            closed
                ? '預估用藥費 NT\$ $advance 曾列入預約應付，請向店家核對用藥結算紀錄。'
                : '預估用藥費 NT\$ $advance 已列入預約應付，退房依實際結果調整。'
          else if (closed)
            '請向店家核對本單的用藥結算紀錄。'
          else if (setting['mode'] == 'free')
            '依本單費率免費。'
          else if (m.isEmpty || setting.isEmpty)
            '本單尚無用藥收款紀錄，費用由店家確認，退房時結算。'
          else
            '用藥費尚未收款，退房時依實際用藥結果結算。',
        ],
      );
    }

    if (m.isEmpty && preferences.isEmpty && medicines.isEmpty) {
      return customerLayout
          ? panel([const Text('這筆訂單沒有用藥協助紀錄。')], showStatus: false)
          : const SizedBox.shrink();
    }
    if (m.isEmpty || widget.summaryOnly) {
      return panel([
        if (!customerLayout)
          Text(status, style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final entry in [...preferences, ...medicines]) requestEntry(entry),
        if (m.isEmpty &&
            !widget.summaryOnly &&
            widget.staff &&
            widget.canManage &&
            !['cancelled', 'completed'].contains(widget.booking['status']) &&
            widget.booking['settlementConfirmed'] != true &&
            widget.booking['settlementLocked'] != true &&
            widget.booking['settledAt'] == null)
          if (request['expectedAdvanceAmount'] case final num advance
              when advance > 0)
            const Text('這筆舊訂單有預收金額待核對。請先確認帳務，避免重複收費。')
          else
            FilledButton(
              onPressed: busy ? null : () => act('prepareLegacy'),
              child: const Text('開始核對用藥申請'),
            ),
        if (customerLayout && m.isEmpty)
          Text(
            '藥品與劑量由店家確認後顯示。',
            style: TextStyle(color: theme.muted, height: 1.5),
          ),
        if (!customerLayout &&
            m['finalized'] != true &&
            (m['advanceAmount'] as num? ?? 0) > 0)
          Text('預估用藥費已列入預約應付，退房依實際結果調整。', style: TextStyle(color: theme.muted)),
        if (customerLayout)
          customerFee()
        else if (m['finalized'] == true && m['finalAmount'] is num)
          fee("用藥結算 NT\$ ${m['finalAmount']}")
        else if (m['agreedAmount'] is num)
          fee("店家報價 NT\$ ${m['agreedAmount']}")
        else if (estimate['amount'] is num)
          fee("用藥預估 NT\$ ${estimate['amount']}")
        else if (!['declined', 'cancelled'].contains(m['state']))
          fee('用藥費待店家確認'),
      ]);
    }
    final locked =
        (widget.staff && !widget.canManage) ||
        widget.booking['settlementConfirmed'] == true ||
        widget.booking['settlementLocked'] == true ||
        widget.booking['settledAt'] != null ||
        ['completed', 'cancelled'].contains(widget.booking['status']) ||
        m['finalized'] == true;
    final confirmed = m['state'] == 'confirmed';
    final today = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().toUtc().add(const Duration(hours: 8)));
    final shown = tasks.where(
      (t) =>
          filter == 'all' ||
          (filter == 'pending' &&
              ['pending', 'mixed', 'partial'].contains(t['result']) &&
              t['finished'] != true) ||
          (filter == 'today' &&
              DateFormat('yyyy-MM-dd').format(
                    DateTime.parse(
                      '${t['scheduledAt']}',
                    ).toUtc().add(const Duration(hours: 8)),
                  ) ==
                  today),
    );
    return panel([
      if (!customerLayout)
        Text(
          m['finalized'] == true
              ? '用藥費已結算'
              : medicationStates[m['state']] ?? '待確認',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      if (widget.staff &&
          (setting['mixFree'] == true || setting['successOnly'] == true)) ...[
        const SizedBox(height: 8),
        _MedicationWaiverNotices(setting),
      ],
      if (widget.staff && !confirmed && !locked) ...[
        const SizedBox(height: 8),
        Text(
          m['state'] == 'pending_customer'
              ? '已送出安排，等待飼主同意。飼主確認後，入住中的用藥時段就會顯示「填寫結果」。'
              : _atArrival
              ? '飼主到店後，核對時間與用量即可加入排程。'
              : '核對用藥需求後，送出時程與費用給飼主確認。',
        ),
        const SizedBox(height: 12),
      ],
      if (!locked &&
          widget.staff &&
          (!confirmed || tasks.every((t) => t['result'] == 'pending')))
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: busy ? null : propose,
              child: Text(
                _atArrival
                    ? (confirmed ? '修改用藥排程' : '到店核對用藥')
                    : confirmed
                    ? '調整用藥安排（須重新確認）'
                    : m['state'] == 'pending_customer'
                    ? '修改安排並重新送確認'
                    : '準備用藥時程與費用',
              ),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => explain('decline', '無法提供原因'),
              child: const Text('無法提供'),
            ),
          ],
        ),
      Text(medRule(setting, includeFeeWaivers: !widget.staff)),
      if (!customerLayout && (m['advanceAmount'] as num? ?? 0) > 0)
        Text("預估用藥費 NT\$ ${m['advanceAmount']} 已列入預約應付，退房依實際結果調整。")
      else if (!customerLayout &&
          ['visit', 'day', 'night'].contains(setting['mode']))
        const Text('用藥費於退房依實際結果結算。'),
      if (widget.customerDetails &&
          preferences.isNotEmpty &&
          request['careStart'] != null &&
          request['careEnd'] != null)
        Text(
          "預計照護期間：${medDate(request['careStart'])}～${medDate(request['careEnd'])}",
        ),
      if (preferences.isNotEmpty) ...[
        if (!customerLayout || !confirmed)
          for (final entry in preferences) requestEntry(entry),
        if (customerLayout)
          customerFee()
        else if (estimate['amount'] != null)
          fee('用藥預估 NT\$ ${estimate['amount']}')
        else
          fee('費用待店家報價'),
        if (medicines.isEmpty) const Text('藥品與照護細節待到店交接，店家確認後才安排執行。'),
      ] else ...[
        Text(
          '旅館負責期間：${medDate(request['careStart'])}～${medDate(request['careEnd'])}',
        ),
        if (customerLayout) ...[
          Text('預計 ${estimate['plannedCount'] ?? tasks.length} 次'),
          customerFee(),
        ] else
          Text(
            '預計 ${estimate['plannedCount'] ?? tasks.length} 次｜${m['agreedAmount'] != null
                ? '已提報總價 ${m['agreedAmount']} 元'
                : estimate['amount'] == null
                ? '待報價'
                : '預估 ${estimate['amount']} 元'}',
          ),
      ],
      if (!customerLayout && m['finalized'] == true)
        Text('結算 ${m['finalAmount']} 元，已帶入訂單額外費用。'),
      if ('${m['proposalNote'] ?? ''}'.isNotEmpty)
        Text('店家說明：${m['proposalNote']}'),
      if (!confirmed &&
          !locked &&
          m['state'] == 'pending_shop' &&
          !widget.staff)
        const Text('到店時請與店家核對日期、時間和用量。'),
      if (medicines.isNotEmpty)
        ExpansionTile(
          title: const Text('藥品與使用指示'),
          initiallyExpanded: widget.customerDetails,
          children: medicines
              .map(
                (x) => ListTile(
                  title: Text(
                    '${petName(x['petId'])}｜${x['name']}（${medicationTypes[x['type']]}）',
                  ),
                  subtitle: Text(
                    '每次 ${x['dose']}\n${scheduleText(x)}\n${x['instruction']}\n${x['reason'] ?? ''}${x['mix'] == true ? '\n可拌食' : ''}'
                    '${widget.customerDetails && x['from'] != null && x['until'] != null ? '\n適用期間：${medDate(x['from'])}～${medDate(x['until'])}' : ''}',
                  ),
                  trailing: '${x['photoPath'] ?? ''}'.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '藥袋照片',
                          onPressed: () =>
                              showMedicationPhoto(context, '${x['photoPath']}'),
                          icon: const Icon(Icons.image_outlined),
                        ),
                ),
              )
              .toList(),
        ),
      if (!locked && !widget.staff && m['state'] == 'pending_customer')
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final revision = m['revision'];
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('確認用藥安排與收費'),
                          scrollable: true,
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(medRule(setting)),
                              const SizedBox(height: 8),
                              if (m['agreedAmount'] case final num quote)
                                Text('您同意的報價上限為 NT\$ $quote。')
                              else if (estimate['amount']
                                  case final num projected)
                                Text('目前預估 NT\$ $projected，退房依約定規則及實際執行紀錄確認。')
                              else
                                const Text('退房依約定規則及實際執行紀錄確認用藥費。'),
                              if (m['advanceAmount'] case final num advance
                                  when advance > 0)
                                Text('NT\$ $advance 已列入預約應付，退房合併核算差額。'),
                              const SizedBox(height: 8),
                              const Text(
                                '請先核對寵物、藥品、用量、時段與旅館負責期間。若需調整，請返回提出修改。',
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('返回檢查'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('同意安排'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && mounted) {
                        await act('accept', {'revision': revision});
                      }
                    },
              child: const Text('同意安排與費用'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => explain('reject', '需要調整的地方'),
              child: const Text('請店家調整'),
            ),
          ],
        ),
      if (confirmed || m['finalized'] == true) ...[
        const Divider(),
        Text(
          '執行紀錄｜完成 ${tasks.where((t) => t['result'] == 'done').length}／${tasks.length}',
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('全部')),
            ButtonSegment(value: 'today', label: Text('今日')),
            ButtonSegment(value: 'pending', label: Text('待處理')),
          ],
          selected: {filter},
          onSelectionChanged: (v) => setState(() => filter = v.first),
        ),
        ExpansionTile(
          title: Text(
            '查看${filter == 'today'
                ? '今日'
                : filter == 'pending'
                ? '待處理'
                : '全部'} ${shown.length} 筆',
          ),
          initiallyExpanded:
              widget.customerDetails || (widget.staff && tasks.length <= 8),
          children: shown
              .map(
                (t) => ListTile(
                  title: Text(
                    '${medDate(t['scheduledAt'])}｜${petName(t['petId'])}',
                  ),
                  subtitle: Text(
                    '${medicines.where((x) => (t['medicineIds'] as List).contains(x['id'])).map((x) => '${_medicineTitle(_recordedMedicine(t, x))}${medMap(t['medicineResults'])[x['id']] == null ? '' : '（${medicationResults[medMap(t['medicineResults'])[x['id']]]}）'}').join('、')}\n${medicationResults[t['result']] ?? t['result']}${t['actualAt'] == null ? '' : '｜實際 ${medDate(t['actualAt'])}'}${t['by'] == null ? '' : '\n執行人：${t['byName'] ?? '店家人員'}'}${t['note'] == null ? '' : '\n${t['note']}'}${t['outside'] == true ? '\n已確認超出一般照護時段' : ''}',
                  ),
                  trailing:
                      !locked &&
                          widget.staff &&
                          widget.booking['status'] == 'checked_in' &&
                          [
                            'pending',
                            'mixed',
                            'partial',
                          ].contains(t['result']) &&
                          t['finished'] != true
                      ? IconButton(
                          tooltip: '記錄結果',
                          onPressed: busy ? null : () => record(t),
                          icon: const Icon(Icons.edit_note),
                        )
                      : null,
                ),
              )
              .toList(),
        ),
        if (!locked && widget.staff) ...[
          FilledButton(
            onPressed: busy ? null : finalize,
            child: const Text('確認用藥費並帶入退房結算'),
          ),
          if (tasks.every((t) => t['result'] == 'pending'))
            TextButton(
              onPressed: busy
                  ? null
                  : () => explain('cancel', '取消協助原因（請先與客人確認）'),
              child: const Text('取消整份用藥協助'),
            ),
        ],
      ],
      ExpansionTile(
        title: const Text('用藥操作紀錄'),
        subtitle: const Text('查看送出、飼主確認與安排變更'),
        children: medList(m['history']).reversed
            .map(
              (h) => ListTile(
                dense: true,
                title: Text(
                  '${medDate(h['at'])}｜${{'confirmAtArrival': '店家完成到店核對', 'propose': '店家提出安排', 'accept': '客人同意', 'reject': '客人要求調整', 'decline': '店家無法提供', 'cancel': '取消協助', 'record': '記錄執行', 'finalize': '費用結算'}[h['action']] ?? h['action']}',
                ),
                subtitle: Text(
                  '${h['note'] ?? ''}${h['amount'] == null ? '' : '｜${h['amount']} 元'}\n操作人：${h['byName'] ?? '訂單相關人員'}',
                ),
              ),
            )
            .toList(),
      ),
      if (busy) const LinearProgressIndicator(),
    ]);
  }

  Future<void> explain(String action, String title) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '請填寫原因'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('確認'),
          ),
        ],
      ),
    );
    final note = c.text.trim();
    c.dispose();
    if (ok == true) await act(action, {'note': note});
  }

  bool get _atArrival => widget.booking['serviceType'] != 'daycare';

  Future<void> propose() => openMedicationArrangement(
    context,
    bookingId: widget.bookingId,
    booking: widget.booking,
    submitProposal: (request) => act('propose', request),
    onViewOrderConfirmation: widget.onViewOrderConfirmation,
  );

  Future<void> record(
    Map<String, dynamic> task, {
    BookingMedicationTask? entry,
  }) => showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 740),
        child: _MedicationResultForm(
          bookingId: widget.bookingId,
          booking: widget.booking,
          task: task,
          entry: entry,
        ),
      ),
    ),
  );

  Future<void> finalize() async {
    if (busy) return;
    setState(() => busy = true);
    Map<String, dynamic> preview;
    try {
      preview = await medCall('manageBookingMedication', {
        'bookingId': widget.bookingId,
        'revision': medication['revision'],
        'action': 'previewFinal',
      });
    } catch (e) {
      if (mounted) {
        medError(context, e);
        setState(() => busy = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => busy = false);
    final amount = TextEditingController(
          text: '${medication['agreedAmount'] ?? ''}',
        ),
        note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認用藥費'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              preview['amount'] == null
                  ? '已同意總報價 ${preview['agreedAmount']} 元，請確認最終金額。'
                  : '依已確認規則：${preview['units']} 個計費單位，共 ${preview['amount']} 元。',
            ),
            const Text('確認後會鎖定用藥紀錄，最終費用帶入退房結算。請再核對整筆應收或退款。'),
            if (medication['advanceAmount'] case final num advance
                when advance > 0)
              Text('預約應付原含 NT\$ $advance 用藥費，退房只核算差額。'),
            if (medication['agreedAmount'] != null)
              medInput(amount, '最終金額（不得超過已同意報價）', number: true),
            medInput(note, '結算說明（特殊報價必填）', lines: 2),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確認帶入'),
          ),
        ],
      ),
    );
    final value = int.tryParse(amount.text), text = note.text.trim();
    amount.dispose();
    note.dispose();
    if (ok == true) {
      await act('finalize', {
        'finalAmount': value,
        'note': text,
        'revision': preview['revision'],
      });
    }
  }
}

class MedicationTodayPage extends StatelessWidget {
  const MedicationTodayPage({super.key, required this.shopId});
  final String shopId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('今日用藥待辦')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('shopId', isEqualTo: shopId)
          .where('status', isEqualTo: 'checked_in')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('無法讀取照護待辦，請確認訂單權限後重試。'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs
            .where(
              (d) =>
                  d.data()['status'] == 'checked_in' &&
                  medMap(d.data()['medication'])['state'] == 'confirmed' &&
                  medMap(d.data()['medication'])['finalized'] != true,
            )
            .toList();
        if (docs.isEmpty) return const Center(child: Text('目前沒有入住中的已確認用藥需求'));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('展開各訂單的「今日」待辦記錄結果。'),
            for (final doc in docs)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${doc.data()['customerName'] ?? ''}｜${doc.data()['roomName'] ?? '未分房'}',
                  ),
                  BookingMedicationPanel(
                    bookingId: doc.id,
                    booking: doc.data(),
                    staff: true,
                    initialFilter: 'today',
                  ),
                ],
              ),
          ],
        );
      },
    ),
  );
}

class _MedicationResultForm extends StatefulWidget {
  const _MedicationResultForm({
    required this.bookingId,
    required this.booking,
    required this.task,
    required this.entry,
    this.onRecorded,
  });

  final String bookingId;
  final Map<String, dynamic> booking, task;
  final BookingMedicationTask? entry;
  final VoidCallback? onRecorded;

  @override
  State<_MedicationResultForm> createState() => _MedicationResultFormState();
}

class _MedicationResultFormState extends State<_MedicationResultForm> {
  late final _medication = medMap(widget.booking['medication']);
  late final task = widget.task;
  BookingMedicationTask? get entry => widget.entry;
  late String? result = entry == null ? 'done' : null;
  String? validation;
  late final medicines = medList(medMap(_medication['request'])['medicines'])
      .where(
        (medicine) => (task['medicineIds'] as List).contains(medicine['id']),
      )
      .toList();
  late final results = <String, String>{
    for (final medicine in medicines)
      '${medicine['id']}':
          '${medMap(task['medicineResults'])[medicine['id']] ?? (entry == null ? 'done' : '')}',
  };
  final medicineDetails = <String, Map<String, String>>{};
  final note = TextEditingController();
  late final scheduled = DateTime.parse('${task['scheduledAt']}');
  late DateTime actual = initialCareActualTime(scheduled, DateTime.now());
  bool saving = false;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Widget resultChoices(
    String? selected,
    ValueChanged<String>? onSelected, {
    required bool canMix,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in const {
          'done': '成功',
          'failed': '未成功',
          'skipped': '未執行',
        }.entries)
          ChoiceChip(
            label: Text(option.value),
            selected: selected == option.key,
            onSelected: onSelected == null
                ? null
                : (_) => onSelected(option.key),
          ),
        if (canMix)
          ChoiceChip(
            label: Text(medicationResults['mixed']!),
            selected: selected == 'mixed',
            onSelected: onSelected == null ? null : (_) => onSelected('mixed'),
          ),
      ],
    );
  }

  Future<void> _save() async {
    final values = medicines.length > 1 ? results.values : [result ?? ''];
    if (medicines.isEmpty || values.any((value) => value.isEmpty)) {
      setState(() => validation = '請確認每項用藥的執行結果');
      return;
    }
    if (values.any((value) => value != 'done') && note.text.trim().isEmpty) {
      setState(() => validation = '請填寫說明');
      return;
    }
    setState(() {
      saving = true;
      validation = null;
    });
    final onRecorded = widget.onRecorded;
    try {
      await medCall('manageBookingMedication', {
        'bookingId': widget.bookingId,
        'action': 'record',
        'revision': _medication['revision'],
        'taskId': task['id'],
        'result':
            result ??
            (values.every((value) => value == 'done') ? 'done' : 'partial'),
        if (medicines.length > 1) 'medicineResults': results,
        if (medicineDetails.isNotEmpty) 'medicineDetails': medicineDetails,
        'actualAt': actual.toUtc().toIso8601String(),
        'note': note.text.trim(),
      });
      if (!mounted) {
        onRecorded?.call();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('用藥結果已儲存')));
      if (onRecorded == null) {
        Navigator.of(context).pop();
      } else {
        setState(() => saving = false);
        onRecorded();
      }
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        medError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final roomName = '${widget.booking['roomName'] ?? ''}'.trim();
    final entry = this.entry;
    void update(VoidCallback change) => setState(change);
    return PopScope(
      canPop: !saving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: IgnorePointer(
              ignoring: saving,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(20),
                children: [
                  Text('記錄執行結果', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (entry != null) ...[
                    Text(
                      '貓咪：${entry.pet}',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    Text('房間：${roomName.isEmpty ? '尚未分房' : roomName}'),
                    if ('${widget.booking['customerName'] ?? ''}'
                        .trim()
                        .isNotEmpty)
                      Text("飼主：${widget.booking['customerName']}"),
                    Text(entry.types),
                  ],
                  Text('原訂 ${medDate(task['scheduledAt'])}'),
                  if (medicines.length > 1) const Text('請分別選擇每種藥品的結果。'),
                  for (final medicine in medicines) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_medicineTitle(medicine)),
                      subtitle: Text('${medicine['instruction'] ?? ''}'),
                    ),

                    ExpansionTile(
                      initiallyExpanded: true,
                      leading: const Icon(Icons.medication_outlined),
                      subtitle: const Text('入住前未提供的藥名、劑量，可在此補齊'),
                      title: const Text('補填或修改藥品資料（選填）'),
                      children: [
                        for (final (field, label, limit) in const [
                          ('name', '藥名', 100),
                          ('dose', '每次用量', 100),
                          ('instruction', '使用方式與注意事項', 1000),
                        ])
                          TextFormField(
                            initialValue:
                                medicineDetails['${medicine['id']}']?[field] ??
                                '${medicine[field] ?? ''}',
                            decoration: InputDecoration(
                              labelText: label,
                              border: const OutlineInputBorder(),
                              filled: true,
                            ),
                            maxLength: limit,
                            onChanged: (value) {
                              medicineDetails.putIfAbsent(
                                '${medicine['id']}',
                                () => {},
                              )[field] = value;
                            },
                          ),
                      ],
                    ),
                    resultChoices(
                      medicines.length == 1 ? result : results[medicine['id']],
                      medicines.length > 1 &&
                              ['done', 'failed', 'skipped'].contains(
                                medMap(task['medicineResults'])[medicine['id']],
                              )
                          ? null
                          : (value) => update(() {
                              if (medicines.length == 1) {
                                result = value;
                              } else {
                                results['${medicine['id']}'] = value;
                              }
                            }),
                      canMix: medicine['mix'] == true,
                    ),
                  ],
                  CareActualTimeField(
                    scheduledAt: scheduled,
                    value: actual,
                    onChanged: (value) => update(() => actual = value),
                  ),
                  medInput(note, '說明（非完成時必填）', lines: 3),
                  if (validation != null)
                    Text(
                      validation!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: saving ? null : _save,
                child: Text(saving ? '儲存中…' : '儲存結果'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _arrivalScheduleSummary(List<Map<String, dynamic>> items) {
  final pets = items.map((item) => item['petId']).whereType<String>().toSet();
  final slots = items
      .expand((item) => medList(item['dates']))
      .fold(0, (total, day) => total + (day['times'] as List).length);
  return slots == 0
      ? '${pets.length} 隻貓需要核對'
      : '${pets.length} 隻貓 · $slots 筆用藥時段';
}

Future<bool> checkMedicationOrderConfirmation(
  BuildContext context,
  Map<String, dynamic> booking, {
  VoidCallback? onViewOrderConfirmation,
}) async {
  if (BookingKind.isDaycare(booking) ||
      !const {
        'pending',
        'pending_confirmation',
        'pending_payment',
        'unpaid',
      }.contains(booking['status'])) {
    return true;
  }
  final action = BookingPaymentStatus.needsInitialPaymentConfirm(booking)
      ? BookingPaymentStatus.initialPaymentChoice(booking).confirmButtonLabel
      : '確認訂單';
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.assignment_turned_in_outlined),
      title: Text('請先$action'),
      content: const Text('完成訂單確認後，即可核對用藥日期與時段。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('關閉'),
        ),
        if (onViewOrderConfirmation != null)
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('前往$action'),
          ),
      ],
    ),
  );
  if (go == true && context.mounted) onViewOrderConfirmation?.call();
  return false;
}

Future<void> openMedicationArrangement(
  BuildContext context, {
  required String bookingId,
  required Map<String, dynamic> booking,
  Future<void> Function(Map<String, dynamic>)? submitProposal,
  VoidCallback? onViewOrderConfirmation,
}) async {
  if (!await checkMedicationOrderConfirmation(
        context,
        booking,
        onViewOrderConfirmation: onViewOrderConfirmation,
      ) ||
      !context.mounted) {
    return;
  }
  final atArrival = !BookingKind.isDaycare(booking);
  final m = medMap(booking['medication']), setting = medMap(m['setting']);
  var draft = medMap(m['request']);
  if (medList(draft['preferences']).isNotEmpty) {
    draft['requiredPetIds'] = medList(
      draft['preferences'],
    ).map((entry) => entry['petId']).toList();
  }
  final note = TextEditingController(),
      amount = TextEditingController(
        text: m['agreedAmount'] == null ? '' : '${m['agreedAmount']}',
      );
  bool outside = false;
  final form = GlobalKey<FormState>();
  final start = booking['startDate'] as Timestamp,
      end = booking['endDate'] as Timestamp;
  final preferences = medList(draft['preferences']);
  final pets = medList(booking['pets']);
  final estimate = medMap(m['estimate']);
  var editing = atArrival;
  var changed = false;
  var saving = false;
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => StatefulBuilder(
        builder: (ctx, update) {
          final medicines = medList(draft['medicines']);
          final needsSchedule =
              medicines.isEmpty ||
              medicines.any((entry) => entry['schedule'] == 'custom') ||
              draft['careStart'] == null ||
              draft['careEnd'] == null;
          final estimatedAmount = changed ? null : estimate['amount'];
          return Scaffold(
            appBar: AppBar(
              title: Text(
                atArrival
                    ? '到店核對用藥'
                    : editing
                    ? '調整用藥安排'
                    : '用藥時程與費用',
              ),
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: atArrival ? 1240 : 650),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    children: [
                      if (atArrival)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '核對用藥日期與時段',
                                style: Theme.of(ctx).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              const Text('勾選要排入的日期。藥名與用量可在記錄結果時補填。'),
                            ],
                          ),
                        ),
                      if (editing)
                        Form(
                          key: form,
                          child: MedicationRequestEditor(
                            shopId: '${booking['shopId']}',
                            pets: pets,
                            setting: setting,
                            startDate: start.toDate(),
                            endDate: end.toDate(),
                            initial: {...draft, 'preferences': preferences},
                            allowPhotoUpload: false,
                            showFeeWaiverNotices: true,
                            reviewByDate: atArrival,
                            onChanged: (value) => update(() {
                              draft = value;
                              changed = true;
                            }),
                          ),
                        ),
                      if (!editing || atArrival) ...[
                        if (!editing) ...[
                          _MedicationWaiverNotices(setting),
                          if (needsSchedule)
                            const Text('以下是預約需求。填寫藥品與執行時間後，即可送飼主確認。'),
                          for (final pet in pets)
                            if ([
                              ...medicines,
                              ...preferences,
                            ].any((entry) => entry['petId'] == medPetId(pet)))
                              medCard('${pet['name'] ?? '貓咪'}', [
                                for (final entry in medicines.where(
                                  (entry) => entry['petId'] == medPetId(pet),
                                ))
                                  Text(
                                    '${entry['name']}｜每次 ${entry['dose']}\n'
                                    '${scheduleText(entry)}',
                                  ),
                                for (final entry in preferences.where(
                                  (entry) => entry['petId'] == medPetId(pet),
                                ))
                                  Text(_medicationRequestLine(entry, '客人希望')),
                              ]),
                          medCard('店家負責的用藥期間', [
                            Text(
                              draft['careStart'] != null &&
                                      draft['careEnd'] != null
                                  ? '${medDate(draft['careStart'])} ～ ${medDate(draft['careEnd'])}'
                                  : '待確認交接時間',
                            ),
                          ]),
                          OutlinedButton.icon(
                            onPressed: () => update(() => editing = true),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(
                              needsSchedule ? '填寫藥品與執行時間' : '修改藥品與執行時間',
                            ),
                          ),
                          medCard('用藥費用', [
                            Text(
                              estimatedAmount is num
                                  ? '原安排預估 NT\$ $estimatedAmount'
                                  : '依送出的安排計價',
                            ),
                            if (m['advanceAmount'] case final num advance
                                when advance > 0)
                              Text('已列入預約應付 NT\$ $advance，退房合併核算。'),
                          ]),
                        ],
                        ExpansionTile(
                          title: Text(
                            estimate['manual'] == true
                                ? '用藥報價與說明'
                                : '特殊時段、報價或給飼主的說明',
                          ),
                          subtitle: const Text('需要告知飼主、另行報價或配合特殊時段時使用。'),
                          initiallyExpanded:
                              changed ||
                              estimate['manual'] == true ||
                              amount.text.isNotEmpty ||
                              note.text.isNotEmpty ||
                              outside,
                          childrenPadding: const EdgeInsets.all(12),
                          children: [
                            medInput(note, '安排／調整說明', lines: 3),
                            medInput(amount, '整筆用藥報價（元）', number: true),
                            const Text('一般安排按店家規則計價。系統要求另行報價時，請填寫整筆用藥費。'),
                            CheckboxListTile(
                              title: const Text('已確認可配合超出照護時段的需求'),
                              value: outside,
                              onChanged: (value) =>
                                  update(() => outside = value ?? false),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: Material(
              color: Theme.of(ctx).colorScheme.surface,
              elevation: 3,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    heightFactor: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 7,
                      children: [
                        if (atArrival)
                          Text(
                            _arrivalScheduleSummary(
                              changed || medicines.isNotEmpty
                                  ? medicines
                                  : preferences,
                            ),
                            style: Theme.of(ctx).textTheme.labelLarge,
                          ),
                        SizedBox(
                          width: 400,
                          child: FilledButton(
                            onPressed: saving
                                ? null
                                : editing
                                ? () async {
                                    if (form.currentState?.validate() == true) {
                                      if (atArrival) {
                                        form.currentState!.save();
                                        final selected = medList(
                                          draft['medicines'],
                                        );
                                        if (selected.isEmpty ||
                                            selected.any(
                                              (entry) =>
                                                  entry['schedule'] == 'custom',
                                            )) {
                                          medError(ctx, '請至少填好一項藥品和執行時間。');
                                          return;
                                        }
                                        update(() => saving = true);
                                        try {
                                          await medCall(
                                            'manageBookingMedication',
                                            {
                                              'bookingId': bookingId,
                                              'action': 'confirmAtArrival',
                                              'revision': m['revision'],
                                              'request': draft,
                                              'note': note.text.trim(),
                                              'allowOutside': outside,
                                              'agreedAmount': ?int.tryParse(
                                                amount.text,
                                              ),
                                            },
                                          );
                                          if (ctx.mounted) {
                                            Navigator.pop(ctx, true);
                                          }
                                        } catch (e) {
                                          if (ctx.mounted) {
                                            update(() => saving = false);
                                            medError(ctx, e);
                                          }
                                        }
                                      } else {
                                        update(() => editing = false);
                                      }
                                    }
                                  }
                                : needsSchedule
                                ? null
                                : () => Navigator.pop(ctx, true),
                            child: Text(
                              atArrival
                                  ? '確認並加入用藥排程'
                                  : editing
                                  ? '套用並查看摘要'
                                  : '送出安排給飼主確認',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
  final text = note.text.trim(), quoted = int.tryParse(amount.text);
  note.dispose();
  amount.dispose();
  if (ok == true && context.mounted) {
    if (atArrival) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已加入用藥排程')));
      return;
    }
    await submitProposal?.call({
      'revision': m['revision'],
      'request': draft,
      'note': text,
      'allowOutside': outside,
      'agreedAmount': ?quoted,
    });
  }
}

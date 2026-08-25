// lib/features/booking/pages/customer_daily_care_page.dart
// 🐾 客戶端每日照護紀錄頁
// 功能：讓會員在入住期間，以手機友善方式查看店家每日照護紀錄。
// 使用「日期切換 + 場次切換」，一次只顯示一個場次。
// 本頁為唯讀；照護照片維持獨立入口，不塞入表格內。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_record_model.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/services/daily_care_record_service.dart';
import '../../../core/services/daily_care_setting_service.dart';

class CustomerDailyCarePage extends StatefulWidget {
  const CustomerDailyCarePage({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.roomName,
  });

  final String shopId;
  final String bookingId;
  final String roomName;

  @override
  State<CustomerDailyCarePage> createState() => _CustomerDailyCarePageState();
}

class _CustomerDailyCarePageState extends State<CustomerDailyCarePage> {
  late Future<DailyCareSettingModel> _settingFuture;

  String? _selectedDateKey;
  int? _selectedSessionIndex;

  static const Map<String, String> _labels = <String, String>{
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
    'catHouse': '貓屋',
    'catnip': '貓薄荷',
    'silverVine': '木天蓼',
    'catGrass': '貓草',
  };

  static const List<String> _foodKeys = <String>[
    'water',
    'dryFood',
    'wetFood',
    'snack',
  ];

  static const List<String> _toiletKeys = <String>['stool', 'urine'];

  static const List<String> _activityKeys = <String>[
    'wandToy',
    'scratchBoard',
    'jumpPlatform',
    'toyBall',
    'catHouse',
  ];

  static const List<String> _relaxKeys = <String>[
    'catnip',
    'silverVine',
    'catGrass',
  ];

  @override
  void initState() {
    super.initState();

    _settingFuture = _loadSetting();
  }

  Future<DailyCareSettingModel> _loadSetting() async {
    try {
      if (widget.shopId.trim().isEmpty) {
        return const DailyCareSettingModel();
      }

      return await DailyCareSettingService.instance.getSetting(widget.shopId);
    } catch (_) {
      // 就算店家設定暫時讀不到，
      // 既有照護紀錄仍然可以繼續顯示。
      return const DailyCareSettingModel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(title: const Text('每日照護紀錄')),
      body: FutureBuilder<DailyCareSettingModel>(
        future: _settingFuture,
        builder: (context, settingSnapshot) {
          final DailyCareSettingModel setting =
              settingSnapshot.data ?? const DailyCareSettingModel();

          return StreamBuilder<List<DailyCareRecordModel>>(
            stream: DailyCareRecordService.instance.streamBookingRecords(
              bookingId: widget.bookingId,
            ),
            builder: (context, recordSnapshot) {
              if (recordSnapshot.hasError) {
                return _errorView('讀取每日照護紀錄失敗');
              }

              if (!recordSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<DailyCareRecordModel> records =
                  recordSnapshot.data ?? <DailyCareRecordModel>[];

              if (records.isEmpty) {
                return const _EmptyCareView();
              }

              final Map<String, List<DailyCareRecordModel>> grouped =
                  _groupRecords(records);

              final List<String> dateKeys = grouped.keys.toList()..sort();

              final String selectedDateKey = _resolveSelectedDateKey(dateKeys);

              final List<DailyCareRecordModel> selectedDateRecords =
                  List<DailyCareRecordModel>.from(
                    grouped[selectedDateKey] ?? <DailyCareRecordModel>[],
                  )..sort((DailyCareRecordModel a, DailyCareRecordModel b) {
                    return a.sessionIndex.compareTo(b.sessionIndex);
                  });

              if (selectedDateRecords.isEmpty) {
                return const _EmptyCareView();
              }

              final int selectedSessionIndex = _resolveSelectedSessionIndex(
                selectedDateRecords,
              );

              final DailyCareRecordModel record = selectedDateRecords
                  .firstWhere(
                    (DailyCareRecordModel item) =>
                        item.sessionIndex == selectedSessionIndex,
                    orElse: () => selectedDateRecords.first,
                  );

              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                children: <Widget>[
                  _buildHeaderCard(),

                  const SizedBox(height: 14),

                  _buildDateSelector(
                    dateKeys: dateKeys,
                    selectedDateKey: selectedDateKey,
                  ),

                  const SizedBox(height: 12),

                  _buildSessionSelector(
                    records: selectedDateRecords,
                    selectedSessionIndex: record.sessionIndex,
                  ),

                  const SizedBox(height: 14),

                  _buildSelectedRecord(record: record, setting: setting),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<String, List<DailyCareRecordModel>> _groupRecords(
    List<DailyCareRecordModel> records,
  ) {
    final Map<String, List<DailyCareRecordModel>> grouped =
        <String, List<DailyCareRecordModel>>{};

    for (final DailyCareRecordModel record in records) {
      final String dateKey = _dateKey(record.recordDate);

      grouped.putIfAbsent(dateKey, () => <DailyCareRecordModel>[]);

      grouped[dateKey]!.add(record);
    }

    return grouped;
  }

  String _resolveSelectedDateKey(List<String> dateKeys) {
    if (_selectedDateKey != null && dateKeys.contains(_selectedDateKey)) {
      return _selectedDateKey!;
    }

    // 預設顯示最新有紀錄的日期。
    _selectedDateKey = dateKeys.last;

    return _selectedDateKey!;
  }

  int _resolveSelectedSessionIndex(List<DailyCareRecordModel> records) {
    if (_selectedSessionIndex != null &&
        records.any(
          (DailyCareRecordModel record) =>
              record.sessionIndex == _selectedSessionIndex,
        )) {
      return _selectedSessionIndex!;
    }

    _selectedSessionIndex = records.first.sessionIndex;

    return _selectedSessionIndex!;
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3D6F9F).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF3D6F9F).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.pets_outlined,
              color: Color(0xFF3D6F9F),
              size: 26,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '住宿照護紀錄',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),

                const SizedBox(height: 4),

                Text(
                  widget.roomName.trim().isEmpty
                      ? '入住期間每日照護狀況'
                      : '${widget.roomName}・入住期間每日照護狀況',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector({
    required List<String> dateKeys,
    required String selectedDateKey,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.calendar_today_outlined,
                  size: 17,
                  color: Color(0xFF3D6F9F),
                ),
                SizedBox(width: 7),
                Text(
                  '選擇日期',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 64,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: dateKeys.length,
              separatorBuilder: (context, index) {
                return const SizedBox(width: 8);
              },
              itemBuilder: (context, index) {
                final String dateKey = dateKeys[index];

                final bool selected = dateKey == selectedDateKey;

                final DateTime? date = _parseDateKey(dateKey);

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _selectedDateKey = dateKey;

                      // 換日期後，
                      // 預設切回該日第一個場次。
                      _selectedSessionIndex = null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 68,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF3D6F9F)
                          : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF3D6F9F)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          date == null ? dateKey : '${date.month}/${date.day}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date == null ? '' : _weekdayText(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: selected
                                ? Colors.white.withValues(alpha: 0.85)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSelector({
    required List<DailyCareRecordModel> records,
    required int selectedSessionIndex,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: records.map((DailyCareRecordModel record) {
          final bool selected = record.sessionIndex == selectedSessionIndex;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _selectedSessionIndex = record.sessionIndex;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    vertical: 11,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFEAF2FA)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF3D6F9F).withValues(alpha: 0.30)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        _sessionIcon(record.sessionIndex, record.sessionName),
                        size: 20,
                        color: selected
                            ? const Color(0xFF3D6F9F)
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.sessionName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? const Color(0xFF3D6F9F)
                              : Colors.grey.shade700,
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
    );
  }

  Widget _buildSelectedRecord({
    required DailyCareRecordModel record,
    required DailyCareSettingModel setting,
  }) {
    final Map<String, dynamic> values = record.values;

    final List<DailyCareCustomField> foodCustomFields = _customFieldsByCategory(
      setting,
      'food',
    );

    final List<DailyCareCustomField> toiletCustomFields =
        _customFieldsByCategory(setting, 'toilet');

    final List<DailyCareCustomField> activityCustomFields =
        _customFieldsByCategory(setting, 'activity');

    final List<DailyCareCustomField> relaxCustomFields =
        _customFieldsByCategory(setting, 'relax');

    final List<DailyCareCustomField> otherCustomFields =
        _customFieldsByCategory(setting, 'other');

    return Column(
      children: <Widget>[
        _buildSessionSummary(record),

        const SizedBox(height: 12),

        _buildEnvironmentCard(values),

        if (_hasBuiltInOrCustomValue(
          values: values,
          builtInKeys: _foodKeys,
          customFields: foodCustomFields,
        )) ...<Widget>[
          const SizedBox(height: 12),
          _buildValueSection(
            title: '飲食與飲水',
            icon: Icons.restaurant_outlined,
            values: values,
            builtInKeys: _foodKeys,
            customFields: foodCustomFields,
          ),
        ],

        if (_hasBuiltInOrCustomValue(
          values: values,
          builtInKeys: _toiletKeys,
          customFields: toiletCustomFields,
        )) ...<Widget>[
          const SizedBox(height: 12),
          _buildValueSection(
            title: '大小便狀況',
            icon: Icons.health_and_safety_outlined,
            values: values,
            builtInKeys: _toiletKeys,
            customFields: toiletCustomFields,
          ),
        ],

        if (_hasBuiltInOrCustomValue(
          values: values,
          builtInKeys: _activityKeys,
          customFields: activityCustomFields,
        )) ...<Widget>[
          const SizedBox(height: 12),
          _buildValueSection(
            title: '活動與玩樂',
            icon: Icons.sports_esports_outlined,
            values: values,
            builtInKeys: _activityKeys,
            customFields: activityCustomFields,
          ),
        ],

        if (_hasBuiltInOrCustomValue(
          values: values,
          builtInKeys: _relaxKeys,
          customFields: relaxCustomFields,
        )) ...<Widget>[
          const SizedBox(height: 12),
          _buildValueSection(
            title: '放鬆與用品',
            icon: Icons.eco_outlined,
            values: values,
            builtInKeys: _relaxKeys,
            customFields: relaxCustomFields,
          ),
        ],

        if (_hasCustomValue(values, otherCustomFields)) ...<Widget>[
          const SizedBox(height: 12),
          _buildValueSection(
            title: '其他紀錄',
            icon: Icons.edit_note_outlined,
            values: values,
            builtInKeys: const <String>[],
            customFields: otherCustomFields,
          ),
        ],

        if (_stringValue(values['generalNote']).isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _buildGeneralNote(_stringValue(values['generalNote'])),
        ],
      ],
    );
  }

  Widget _buildSessionSummary(DailyCareRecordModel record) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF3D6F9F).withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _sessionIcon(record.sessionIndex, record.sessionName),
              size: 21,
              color: const Color(0xFF3D6F9F),
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  record.sessionName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '店家已完成本場照護紀錄',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          if (record.updatedAt != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _timeText(record.updatedAt!),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentCard(Map<String, dynamic> values) {
    final dynamic temperature = values['temperature'];

    final dynamic humidity = values['humidity'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.thermostat_outlined,
                size: 18,
                color: Color(0xFF3D6F9F),
              ),
              SizedBox(width: 7),
              Text(
                '環境紀錄',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: <Widget>[
              Expanded(
                child: _environmentItem(
                  icon: Icons.thermostat_outlined,
                  label: '室內溫度',
                  value: temperature == null
                      ? '-'
                      : '${_cleanNumber(temperature)} °C',
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _environmentItem(
                  icon: Icons.water_drop_outlined,
                  label: '室內濕度',
                  value: humidity == null ? '-' : '${_cleanNumber(humidity)} %',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _environmentItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 22, color: const Color(0xFF3D6F9F)),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueSection({
    required String title,
    required IconData icon,
    required Map<String, dynamic> values,
    required List<String> builtInKeys,
    required List<DailyCareCustomField> customFields,
  }) {
    final List<_DisplayCareValue> items = <_DisplayCareValue>[];

    for (final String key in builtInKeys) {
      final String value = _stringValue(values[key]);

      if (value.isEmpty) {
        continue;
      }

      items.add(
        _DisplayCareValue(
          label: _labels[key] ?? key,
          value: value,
          longText: false,
        ),
      );
    }

    for (final DailyCareCustomField field in customFields) {
      final String value = _stringValue(values[field.id]);

      if (value.isEmpty) {
        continue;
      }

      items.add(
        _DisplayCareValue(
          label: field.label,
          value: value,
          longText: field.inputType == 'text',
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: const Color(0xFF3D6F9F)),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ...items.map((_DisplayCareValue item) {
            if (item.longText) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.value,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return _buildCompactValueRow(label: item.label, value: item.value);
          }),
        ],
      ),
    );
  }

  Widget _buildCompactValueRow({required String label, required String value}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3D6F9F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralNote(String note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.notes_outlined, size: 18, color: Color(0xFF3D6F9F)),
              SizedBox(width: 7),
              Text(
                '今日概況',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              note,
              style: const TextStyle(fontSize: 13, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }

  List<DailyCareCustomField> _customFieldsByCategory(
    DailyCareSettingModel setting,
    String category,
  ) {
    return setting.customFields
        .where((DailyCareCustomField field) => field.category == category)
        .toList();
  }

  bool _hasBuiltInOrCustomValue({
    required Map<String, dynamic> values,
    required List<String> builtInKeys,
    required List<DailyCareCustomField> customFields,
  }) {
    if (_hasAnyValue(values, builtInKeys)) {
      return true;
    }

    return _hasCustomValue(values, customFields);
  }

  bool _hasAnyValue(Map<String, dynamic> values, List<String> keys) {
    return keys.any((String key) => _stringValue(values[key]).isNotEmpty);
  }

  bool _hasCustomValue(
    Map<String, dynamic> values,
    List<DailyCareCustomField> fields,
  ) {
    return fields.any(
      (DailyCareCustomField field) => _stringValue(values[field.id]).isNotEmpty,
    );
  }

  String _stringValue(Object? value) {
    return value?.toString().trim() ?? '';
  }

  IconData _sessionIcon(int sessionIndex, String sessionName) {
    if (sessionName.contains('上午')) {
      return Icons.wb_sunny_outlined;
    }

    if (sessionName.contains('下午')) {
      return Icons.light_mode_outlined;
    }

    if (sessionName.contains('晚上')) {
      return Icons.nightlight_outlined;
    }

    return Icons.edit_note_outlined;
  }

  String _cleanNumber(dynamic value) {
    if (value is num) {
      if (value % 1 == 0) {
        return value.toInt().toString();
      }

      return value.toString();
    }

    return value.toString();
  }

  String _timeText(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _weekdayText(DateTime value) {
    switch (value.weekday) {
      case DateTime.monday:
        return '週一';
      case DateTime.tuesday:
        return '週二';
      case DateTime.wednesday:
        return '週三';
      case DateTime.thursday:
        return '週四';
      case DateTime.friday:
        return '週五';
      case DateTime.saturday:
        return '週六';
      case DateTime.sunday:
      default:
        return '週日';
    }
  }

  DateTime? _parseDateKey(String value) {
    final List<String> parts = value.split('/');

    if (parts.length != 3) {
      return null;
    }

    final int? year = int.tryParse(parts[0]);

    final int? month = int.tryParse(parts[1]);

    final int? day = int.tryParse(parts[2]);

    if (year == null || month == null || day == null) {
      return null;
    }

    return DateTime(year, month, day);
  }

  static String _dateKey(DateTime value) {
    return '${value.year}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')}';
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 50,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisplayCareValue {
  const _DisplayCareValue({
    required this.label,
    required this.value,
    required this.longText,
  });

  final String label;
  final String value;
  final bool longText;
}

class _EmptyCareView extends StatelessWidget {
  const _EmptyCareView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.pets_outlined, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text(
              '目前還沒有照護紀錄',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '店家完成每日照護後，紀錄會顯示在這裡。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

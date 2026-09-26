// 檔案名稱：lib/features/room/widgets/daily_care_record_editor.dart
// 功能說明：一房一天一場的共同照護紀錄填寫內容（可重用）。
// 🐾 由 DailyCareRecordEditPage 整頁包裝，也可嵌入桌機每日回報右側面板。
// 室內溫度、室內濕度為固定必填欄位，
// 其他照護項目依店主「每日照護紀錄設定」決定是否顯示。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/daily_care_entitlement.dart';
import '../../../core/models/daily_care_journal_layout.dart';
import '../../../core/models/daily_care_photo_model.dart';
import '../../../core/models/daily_care_record_model.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/services/daily_care_photo_service.dart';
import '../../../core/services/daily_care_photo_upload_service.dart';
import '../../../core/services/daily_care_record_service.dart';
import '../../../core/services/daily_care_report_eligibility.dart';
import '../../../core/services/daily_care_report_write_access.dart';
import '../../../core/services/daily_care_setting_service.dart';
import '../../../core/widgets/daily_care_illustrations.dart';
import '../../../core/widgets/daily_care_journal_renderer.dart';

class DailyCareRecordEditor extends StatefulWidget {
  const DailyCareRecordEditor({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.roomId,
    required this.customFields,
    required this.roomName,
    required this.recordDate,
    required this.sessionIndex,
    required this.sessionName,
    required this.enabledFields,
    required this.photoEnabled,
    this.serviceType = DailyCareServiceTypes.accommodation,
    this.petIds = const <String>[],
    this.entitlement,
    this.readOnly = false,
    this.padding = const EdgeInsets.all(16),
    this.showHeaderCard = true,
    this.onSaved,
  });

  final String shopId;
  final String bookingId;
  final String roomId;
  final String roomName;
  final DateTime recordDate;
  final bool photoEnabled;
  final int sessionIndex;
  final String sessionName;
  final List<DailyCareCustomField> customFields;

  /// 店主在「每日照護紀錄設定」勾選的自選欄位。
  ///
  /// 室內溫度、室內濕度不在這裡，
  /// 因為兩者為系統固定必填欄位。
  final List<String> enabledFields;
  final String serviceType;
  final List<String> petIds;
  final DailyCareEntitlement? entitlement;
  final bool readOnly;

  final EdgeInsets padding;

  /// 嵌入右側面板時可關閉頁首卡片，避免資訊重複。
  final bool showHeaderCard;

  /// 儲存成功後的回呼。
  ///
  /// 沒有傳入時沿用整頁流程：直接 Navigator.pop(context, true)。
  final VoidCallback? onSaved;

  @override
  State<DailyCareRecordEditor> createState() => _DailyCareRecordEditorState();
}

class _DailyCareRecordEditorState extends State<DailyCareRecordEditor> {
  bool _loading = true;
  bool _saving = false;
  bool _locked = false;
  DailyCareSettingModel _setting = const DailyCareSettingModel();

  bool _uploadingPhoto = false;
  final List<Uint8List> _pendingPhotos = <Uint8List>[];

  final ImagePicker _imagePicker = ImagePicker();

  /// 店主自選欄位的實際填寫值。
  final Map<String, String> _values = <String, String>{};

  final Map<String, TextEditingController> _customTextControllers =
      <String, TextEditingController>{};

  /// 🌡️ 固定必填：室內溫度
  final TextEditingController _temperatureController = TextEditingController();

  /// 💧 固定必填：室內濕度
  final TextEditingController _humidityController = TextEditingController();

  /// 整房概況
  final TextEditingController _generalNoteController = TextEditingController();

  String get _dailyCareRecordId {
    return DailyCareRecordService.instance.buildRecordId(
      bookingId: widget.bookingId,
      recordDate: widget.recordDate,
      sessionIndex: widget.sessionIndex,
    );
  }

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _humidityController.dispose();
    _generalNoteController.dispose();

    for (final TextEditingController controller
        in _customTextControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _load() async {
    try {
      _setting = await DailyCareSettingService.instance.getSetting(
        widget.shopId,
      );
    } catch (_) {
      _setting = const DailyCareSettingModel();
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> bookingSnap =
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(widget.bookingId)
              .get();
      _locked =
          widget.readOnly ||
          !DailyCareReportWriteAccess.canWrite(bookingSnap.data());
    } catch (_) {
      _locked = widget.readOnly;
    }
    try {
      await _loadExistingRecord();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('讀取照護資料失敗：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// 讀取目前場次已存在的照護紀錄。
  ///
  /// 如果員工之前已經填過，
  /// 再次進入「查看 / 修改」時會自動帶回原本資料。
  Future<void> _loadExistingRecord() async {
    final DailyCareRecordModel? record = await DailyCareRecordService.instance
        .getRecord(
          shopId: widget.shopId,
          bookingId: widget.bookingId,
          recordDate: widget.recordDate,
          sessionIndex: widget.sessionIndex,
        );

    if (record == null) return;

    for (final MapEntry<String, dynamic> entry in record.values.entries) {
      switch (entry.key) {
        case 'temperature':
          _temperatureController.text = entry.value?.toString() ?? '';
          break;

        case 'humidity':
          _humidityController.text = entry.value?.toString() ?? '';
          break;

        case 'generalNote':
          _generalNoteController.text = entry.value?.toString() ?? '';
          break;

        default:
          final DailyCareCustomField? customField = _findCustomField(entry.key);

          if (customField?.inputType == 'text') {
            final TextEditingController controller = _customTextControllers
                .putIfAbsent(entry.key, () => TextEditingController());

            controller.text = entry.value?.toString() ?? '';
          } else {
            _values[entry.key] = entry.value?.toString() ?? '';
          }

          break;
      }
    }
  }

  Future<void> _confirmDeletePhoto(DailyCarePhotoModel photo) async {
    if (_locked) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('刪除照護照片'),
          content: const Text('確定要刪除這張照片嗎？\n刪除後無法復原。'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await DailyCarePhotoService.instance.deletePhoto(photo);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('照片已刪除')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除照片失敗：$e')));
    }
  }

  Future<void> _pickPendingPhoto(int uploadedCount) async {
    if (_locked || _uploadingPhoto) return;
    final int remaining =
        DailyCarePhotoService.maxPhotosPerSession -
        uploadedCount -
        _pendingPhotos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此場最多 3 張照片')));
      return;
    }

    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pendingPhotos.add(bytes);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('選擇照片失敗：$e')));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DailyCareReportWriteAccess.lockedMessage)),
      );
      return;
    }

    final DailyCareEntitlement? entitlement = widget.entitlement;
    if (entitlement != null &&
        !DailyCareReportEligibility.isEntitled(entitlement)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本訂單未包含每日照護回報')));
      return;
    }

    final String temperatureText = _temperatureController.text.trim();

    final String humidityText = _humidityController.text.trim();

    // 🌡️💧 固定必填
    if (temperatureText.isEmpty || humidityText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請填寫室內溫度與室內濕度')));
      return;
    }

    final double? temperatureValue = double.tryParse(temperatureText);

    final double? humidityValue = double.tryParse(humidityText);

    if (temperatureValue == null || humidityValue == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('溫度與濕度請輸入正確數字')));
      return;
    }

    if (humidityValue < 0 || humidityValue > 100) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('室內濕度請輸入 0～100')));
      return;
    }

    if (_pendingPhotos.isNotEmpty) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('確認送出此場回報'),
            content: Text(
              '將新選 ${_pendingPhotos.length} 張照片上傳。已存在的照片不會重複上傳或刪除。',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('再檢查'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('確認送出'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) {
        return;
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      final Map<String, dynamic> values = Map<String, dynamic>.from(_values);

      for (final DailyCareCustomField field in widget.customFields) {
        if (field.inputType != 'text') {
          continue;
        }

        final String value =
            _customTextControllers[field.id]?.text.trim() ?? '';

        if (value.isEmpty) {
          values.remove(field.id);
        } else {
          values[field.id] = value;
        }
      }

      // 🌡️ 系統固定欄位
      values['temperature'] = temperatureValue;

      // 💧 系統固定欄位
      values['humidity'] = humidityValue;

      // 📝 整房概況由店主決定是否啟用
      if (widget.enabledFields.contains('generalNote')) {
        values['generalNote'] = _generalNoteController.text.trim();
      } else {
        values.remove('generalNote');
      }

      final User? user = FirebaseAuth.instance.currentUser;

      final String? operatorName = user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : user?.email?.trim();

      await DailyCareRecordService.instance.saveRecord(
        shopId: widget.shopId,
        bookingId: widget.bookingId,
        roomId: widget.roomId,
        roomName: widget.roomName,
        recordDate: widget.recordDate,
        sessionIndex: widget.sessionIndex,
        sessionName: widget.sessionName,
        values: values,

        // 個別寵物概況目前正式停用。
        // 暫時保留 Service 現有參數，避免連動修改 Model / Service。
        petNotes: const <String, String>{},

        operatorUid: user?.uid,
        operatorName: operatorName,
        serviceType: widget.serviceType,
        petIds: widget.petIds,
      );

      if (_pendingPhotos.isNotEmpty) {
        setState(() {
          _uploadingPhoto = true;
        });
        for (final Uint8List bytes in List<Uint8List>.from(_pendingPhotos)) {
          await DailyCarePhotoUploadService.instance.uploadPhoto(
            originalBytes: bytes,
            shopId: widget.shopId,
            bookingId: widget.bookingId,
            roomId: widget.roomId,
            roomName: widget.roomName,
            recordDate: widget.recordDate,
            sessionIndex: widget.sessionIndex,
            sessionName: widget.sessionName,
            dailyCareRecordId: _dailyCareRecordId,
          );
        }
        _pendingPhotos.clear();
      }

      if (!mounted) return;

      final VoidCallback? onSaved = widget.onSaved;
      if (onSaved == null) {
        Navigator.pop(context, true);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本場照護紀錄已儲存')));
      onSaved();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存照護紀錄失敗：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadingPhoto = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String dateText =
        '${widget.recordDate.year}/'
        '${widget.recordDate.month.toString().padLeft(2, '0')}/'
        '${widget.recordDate.day.toString().padLeft(2, '0')}';

    final Widget? quotaBanner = _entitlementBanner();

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: widget.padding,
      children: <Widget>[
        if (widget.showHeaderCard) _headerCard(dateText),
        if (_locked) ...<Widget>[
          if (widget.showHeaderCard) const SizedBox(height: 12),
          _lockBanner(),
        ],
        if (quotaBanner != null) ...<Widget>[
          const SizedBox(height: 14),
          quotaBanner,
        ],

        const SizedBox(height: 14),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: _environmentCard()),
            const SizedBox(width: 10),
            Expanded(
              child: _illustratedSection(
                cardKey: DailyCareJournalCardKeys.toilet,
                title: '大小便狀況',
                children: <Widget>[
                  _choiceRow(keyName: 'stool', options: _fixedConditionOptions),
                  _choiceRow(keyName: 'urine', options: _fixedConditionOptions),
                ],
              ),
            ),
          ],
        ),

        if (_hasAny(<String>[
          'water',
          'dryFood',
          'wetFood',
          'snack',
        ])) ...<Widget>[
          const SizedBox(height: 14),
          _illustratedSection(
            cardKey: DailyCareJournalCardKeys.food,
            title: '生活狀況',
            children: <Widget>[
              if (_enabled('water'))
                _choiceRow(keyName: 'water', options: _fixedConditionOptions),
              if (_enabled('dryFood'))
                _choiceRow(keyName: 'dryFood', options: _fixedConditionOptions),
              if (_enabled('wetFood'))
                _choiceRow(keyName: 'wetFood', options: _fixedConditionOptions),
              if (_enabled('snack'))
                _choiceRow(keyName: 'snack', options: _fixedConditionOptions),
            ],
          ),
        ],

        if (_hasAny(<String>[
          'wandToy',
          'scratchBoard',
          'jumpPlatform',
          'toyBall',
          'catHouse',
        ])) ...<Widget>[
          const SizedBox(height: 14),
          _illustratedSection(
            cardKey: DailyCareJournalCardKeys.activity,
            title: '活動與玩樂',
            children: <Widget>[
              for (final String key in <String>[
                'wandToy',
                'scratchBoard',
                'jumpPlatform',
                'toyBall',
                'catHouse',
              ])
                if (_enabled(key))
                  _choiceRow(keyName: key, options: const <String>['無', '有']),
              for (final DailyCareCustomField field in _customFieldsByCategory(
                'activity',
              ))
                _customFieldWidget(field),
            ],
          ),
        ],

        if (_hasAny(<String>['catnip', 'silverVine', 'catGrass'])) ...<Widget>[
          const SizedBox(height: 14),
          _illustratedSection(
            cardKey: DailyCareJournalCardKeys.relax,
            title: '放鬆與用品',
            children: <Widget>[
              for (final String key in <String>[
                'catnip',
                'silverVine',
                'catGrass',
              ])
                if (_enabled(key))
                  _choiceRow(keyName: key, options: const <String>['無', '有']),
              for (final DailyCareCustomField field in _customFieldsByCategory(
                'relax',
              ))
                _customFieldWidget(field),
            ],
          ),
        ],

        if (_enabled('generalNote')) ...<Widget>[
          const SizedBox(height: 14),
          _illustratedSection(
            cardKey: DailyCareJournalCardKeys.generalNote,
            title: '今日概況',
            children: <Widget>[
              TextField(
                controller: _generalNoteController,
                minLines: 4,
                maxLines: 8,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: '例如：今天整體狀況穩定，進食正常，活動力良好...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ],

        if (_customFieldsByCategory('other').isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _illustratedSection(
            cardKey: 'other',
            title: '其他紀錄',
            children: <Widget>[
              for (final DailyCareCustomField field in _customFieldsByCategory(
                'other',
              ))
                _customFieldWidget(field),
            ],
          ),
        ],

        if (widget.photoEnabled) ...<Widget>[
          const SizedBox(height: 14),
          _photoCard(),
        ],

        if (!_locked) ...<Widget>[
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '儲存中...' : '儲存照護紀錄'),
            ),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _lockBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        DailyCareReportWriteAccess.lockedMessage,
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _headerCard(String dateText) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.pets_outlined, size: 32, color: Color(0xFF3D6F9F)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${widget.roomName}・${widget.sessionName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(dateText, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _entitlementBanner() {
    final DailyCareEntitlement? entitlement = widget.entitlement;
    if (entitlement == null || entitlement.finalReports < 1) {
      return null;
    }
    final int total = entitlement.finalReports;
    final int current = widget.sessionIndex + 1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '本日第 $current／$total 場：${widget.sessionName}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '基本包含：${entitlement.baseReports} 場',
            style: const TextStyle(color: Colors.black54),
          ),
          if (entitlement.addonReports > 0) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '加購增加：${entitlement.addonReports} 場・${entitlement.addonName}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '本日應回報：$total 場',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  /// 🌡️💧 固定環境紀錄
  DailyCareJournalCardLayout _layoutOf(String key) {
    return _setting.resolvedJournalCards[key] ??
        DailyCareJournalCardLayout(key: key, order: 99);
  }

  Widget _illustratedSection({
    required String cardKey,
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    final DailyCareJournalCardLayout layout = _layoutOf(cardKey);
    final Color fill = DailyCareJournalThemeTokens.fillOf(layout.colorKey);
    final Color ink = DailyCareInk.of(
      layout: layout,
      fill: fill,
      colors: Theme.of(context).colorScheme,
    );
    return DailyCareIllustratedShell(
      layout: layout,
      title: title,
      fill: fill,
      ink: ink,
      trailing: trailing,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: ink, fontSize: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _environmentCard() {
    final DailyCareJournalCardLayout layout = _layoutOf(
      DailyCareJournalCardKeys.environment,
    );
    final Color fill = DailyCareJournalThemeTokens.fillOf(layout.colorKey);
    final Color ink = DailyCareInk.of(
      layout: layout,
      fill: fill,
      colors: Theme.of(context).colorScheme,
    );
    final InputDecorationTheme inputTheme = InputDecorationTheme(
      labelStyle: TextStyle(color: ink.withValues(alpha: 0.78)),
      hintStyle: TextStyle(color: ink.withValues(alpha: 0.45)),
      suffixStyle: TextStyle(color: ink),
    );
    return DailyCareIllustratedShell(
      layout: layout,
      title: '環境狀況',
      fill: fill,
      ink: ink,
      trailing: Text(
        '必填',
        style: TextStyle(fontSize: 12, color: ink, fontWeight: FontWeight.w700),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(inputDecorationTheme: inputTheme),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '每一場照護紀錄都需要填寫目前房間的溫度與濕度。',
              style: TextStyle(
                fontSize: 12,
                color: ink.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _temperatureController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: ink, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: '溫度',
                hintText: '例如 28',
                suffixText: '°C',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(10),
                  child: DailyCareSvgIcon(
                    asset: DailyCareIllustrations.environment,
                    color: ink,
                    size: 20,
                  ),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _humidityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: ink, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: '濕度',
                hintText: '例如 60',
                suffixText: '%',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(10),
                  child: DailyCareSvgIcon(
                    asset: DailyCareIllustrations.humidity,
                    color: ink,
                    size: 20,
                  ),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 讀取本場照片。Firebase 尚未就緒時回空清單，避免整個面板失敗。
  Stream<List<DailyCarePhotoModel>> _recordPhotoStream() {
    final String roomFilter =
        widget.serviceType == DailyCareServiceTypes.daycare
        ? ''
        : widget.roomId;
    try {
      return DailyCarePhotoService.instance.streamRecordPhotos(
        bookingId: widget.bookingId,
        dailyCareRecordId: _dailyCareRecordId,
        recordDate: widget.recordDate,
        sessionIndex: widget.sessionIndex,
        roomId: roomFilter,
        shopId: widget.shopId,
      );
    } catch (_) {
      return Stream<List<DailyCarePhotoModel>>.value(
        const <DailyCarePhotoModel>[],
      );
    }
  }

  Widget _photoCard() {
    return StreamBuilder<List<DailyCarePhotoModel>>(
      stream: _recordPhotoStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('daily care photos stream error: ${snapshot.error}');
          return _illustratedSection(
            cardKey: DailyCareJournalCardKeys.photos,
            title: '照護照片',
            children: const <Widget>[Text('照片讀取失敗，請重新整理後再試')],
          );
        }
        final List<DailyCarePhotoModel> photos =
            snapshot.data ?? <DailyCarePhotoModel>[];

        final int uploadedCount = photos.length;
        final int currentCount = uploadedCount + _pendingPhotos.length;
        final int maxCount = DailyCarePhotoService.maxPhotosPerSession;
        final int remaining = currentCount >= maxCount
            ? 0
            : maxCount - currentCount;
        final bool reachedLimit = remaining <= 0;
        final int pendingCount = _pendingPhotos.length;

        final String quotaText = pendingCount > 0
            ? '本場照片 $currentCount / $maxCount 張（已上傳 $uploadedCount、待儲存 $pendingCount）'
            : remaining > 0
            ? '本場已上傳 $uploadedCount / $maxCount 張，尚可上傳 $remaining 張'
            : '本場已上傳 $uploadedCount / $maxCount 張，照片額度已用完';

        return _illustratedSection(
          cardKey: DailyCareJournalCardKeys.photos,
          title: '照護照片',
          trailing: Text(
            quotaText,
            style: TextStyle(
              fontSize: 12,
              color: reachedLimit ? Colors.red : Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: <Widget>[
            Text(
              '每場最多 3 張，以已成功上傳的照片為準。文字可重複儲存，不會清掉或重複上傳既有照片。',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),

            if (photos.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: photos.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final DailyCarePhotoModel photo = photos[index];
                  final String url = photo.previewUrl.trim();

                  return Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            color: Colors.grey.shade100,
                            child: url.isEmpty
                                ? const Center(
                                    child: Icon(
                                      Icons.photo_outlined,
                                      color: Colors.grey,
                                    ),
                                  )
                                : Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.grey,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _locked
                            ? const SizedBox.shrink()
                            : Material(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () {
                                    _confirmDeletePhoto(photo);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(5),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ],
            if (_pendingPhotos.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List<Widget>.generate(_pendingPhotos.length, (
                  int index,
                ) {
                  return Stack(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          _pendingPhotos[index],
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _pendingPhotos.removeAt(index);
                            });
                          },
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],

            if (!_locked && !reachedLimit) ...<Widget>[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _uploadingPhoto
                      ? null
                      : () => _pickPendingPhoto(uploadedCount),
                  icon: _uploadingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_uploadingPhoto ? '上傳中...' : '本機選擇照片'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  DailyCareCustomField? _findCustomField(String id) {
    for (final DailyCareCustomField field in widget.customFields) {
      if (field.id == id) {
        return field;
      }
    }

    return null;
  }

  List<DailyCareCustomField> _customFieldsByCategory(String category) {
    return widget.customFields
        .where((DailyCareCustomField field) => field.category == category)
        .toList();
  }

  Widget _customFieldWidget(DailyCareCustomField field) {
    switch (field.inputType) {
      case 'amount':
        return _choiceRow(
          keyName: field.id,
          label: field.label,
          options: const <String>['無', '少', '一般', '多'],
        );

      case 'condition':
        return _choiceRow(
          keyName: field.id,
          label: field.label,
          options: const <String>['正常', '偏少', '偏多', '異常'],
        );

      case 'text':
        final TextEditingController controller = _customTextControllers
            .putIfAbsent(field.id, () => TextEditingController());

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: field.label,
              hintText: '請填寫${field.label}',
              border: const OutlineInputBorder(),
            ),
          ),
        );

      case 'yesNo':
      default:
        return _choiceRow(
          keyName: field.id,
          label: field.label,
          options: const <String>['無', '有'],
        );
    }
  }

  static const List<String> _fixedConditionOptions = <String>[
    '正常',
    '偏少',
    '偏多',
    '異常',
  ];

  Widget _choiceRow({
    required String keyName,
    required List<String> options,
    String? label,
  }) {
    final String? selected = _values[keyName];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label ?? _labels[keyName] ?? keyName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((String value) {
              return ChoiceChip(
                label: Text(value),
                selected: selected == value,
                onSelected: _locked
                    ? null
                    : (_) {
                        setState(() {
                          _values[keyName] = value;
                        });
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  bool _enabled(String key) {
    if (DailyCareReportFormat.isAlwaysOn(key)) {
      return true;
    }
    return widget.enabledFields.contains(key);
  }

  bool _hasAny(List<String> keys) {
    return keys.any(_enabled);
  }
}

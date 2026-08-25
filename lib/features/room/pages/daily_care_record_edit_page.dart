// lib/features/room/pages/daily_care_record_edit_page.dart
// 🐾 每日照護紀錄填寫頁
// 功能：讓店員填寫一房一天一場的共同照護紀錄。
// 室內溫度、室內濕度為固定必填欄位，
// 其他照護項目依店主「每日照護紀錄設定」決定是否顯示。

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/models/daily_care_record_model.dart';
import '../../../core/services/daily_care_record_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/daily_care_photo_model.dart';
import '../../../core/services/daily_care_photo_service.dart';
import '../../../core/services/daily_care_photo_upload_service.dart';

class DailyCareRecordEditPage extends StatefulWidget {
  const DailyCareRecordEditPage({
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

  @override
  State<DailyCareRecordEditPage> createState() =>
      _DailyCareRecordEditPageState();
}

class _DailyCareRecordEditPageState extends State<DailyCareRecordEditPage> {
  bool _loading = true;
  bool _saving = false;

  bool _uploadingPhoto = false;

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

  Future<void> _pickAndUploadPhoto() async {
    if (_uploadingPhoto) return;

    try {
      final int remaining = await DailyCarePhotoService.instance
          .remainingPhotoCount(
            shopId: widget.shopId,
            bookingId: widget.bookingId,
            roomId: widget.roomId,
            recordDate: widget.recordDate,
          );
      if (remaining <= 0) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('此房今日照片已達上限')));
        return;
      }

      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        _uploadingPhoto = true;
      });

      await DailyCarePhotoUploadService.instance.uploadPhoto(
        originalBytes: bytes,
        shopId: widget.shopId,
        bookingId: widget.bookingId,
        roomId: widget.roomId,
        roomName: widget.roomName,
        recordDate: widget.recordDate,
        sessionIndex: widget.sessionIndex,
        sessionName: widget.sessionName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('照護照片上傳完成')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('照片上傳失敗：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;

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
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存照護紀錄失敗：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
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

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(title: Text('${widget.sessionName}照護紀錄')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _headerCard(dateText),

                const SizedBox(height: 14),

                // 🌡️💧 固定必填
                _environmentCard(),

                if (_hasAny(<String>[
                  'water',
                  'dryFood',
                  'wetFood',
                  'snack',
                ])) ...<Widget>[
                  const SizedBox(height: 14),
                  _sectionCard(
                    title: '飲食與飲水',
                    icon: Icons.restaurant_outlined,
                    children: <Widget>[
                      if (_enabled('water'))
                        _choiceRow(
                          keyName: 'water',
                          options: const <String>['無', '少', '一般', '多'],
                        ),
                      if (_enabled('dryFood'))
                        _choiceRow(
                          keyName: 'dryFood',
                          options: const <String>['無', '少', '一般', '多'],
                        ),
                      if (_enabled('wetFood'))
                        _choiceRow(
                          keyName: 'wetFood',
                          options: const <String>['無', '少', '一般', '多'],
                        ),
                      if (_enabled('snack'))
                        _choiceRow(
                          keyName: 'snack',
                          options: const <String>['無', '有'],
                        ),
                      for (final DailyCareCustomField field
                          in _customFieldsByCategory('food'))
                        _customFieldWidget(field),
                    ],
                  ),
                ],

                if (_hasAny(<String>['stool', 'urine'])) ...<Widget>[
                  const SizedBox(height: 14),
                  _sectionCard(
                    title: '大小便狀況',
                    icon: Icons.health_and_safety_outlined,
                    children: <Widget>[
                      if (_enabled('stool'))
                        _choiceRow(
                          keyName: 'stool',
                          options: const <String>['無', '正常', '偏少', '偏多', '異常'],
                        ),
                      if (_enabled('urine'))
                        _choiceRow(
                          keyName: 'urine',
                          options: const <String>['無', '正常', '偏少', '偏多', '異常'],
                        ),
                      for (final DailyCareCustomField field
                          in _customFieldsByCategory('toilet'))
                        _customFieldWidget(field),
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
                  _sectionCard(
                    title: '活動與玩樂',
                    icon: Icons.sports_esports_outlined,
                    children: <Widget>[
                      for (final String key in <String>[
                        'wandToy',
                        'scratchBoard',
                        'jumpPlatform',
                        'toyBall',
                        'catHouse',
                      ])
                        if (_enabled(key))
                          _choiceRow(
                            keyName: key,
                            options: const <String>['無', '有'],
                          ),
                      for (final DailyCareCustomField field
                          in _customFieldsByCategory('activity'))
                        _customFieldWidget(field),
                    ],
                  ),
                ],

                if (_hasAny(<String>[
                  'catnip',
                  'silverVine',
                  'catGrass',
                ])) ...<Widget>[
                  const SizedBox(height: 14),
                  _sectionCard(
                    title: '放鬆與用品',
                    icon: Icons.eco_outlined,
                    children: <Widget>[
                      for (final String key in <String>[
                        'catnip',
                        'silverVine',
                        'catGrass',
                      ])
                        if (_enabled(key))
                          _choiceRow(
                            keyName: key,
                            options: const <String>['無', '有'],
                          ),
                      for (final DailyCareCustomField field
                          in _customFieldsByCategory('relax'))
                        _customFieldWidget(field),
                    ],
                  ),
                ],

                if (_enabled('generalNote')) ...<Widget>[
                  const SizedBox(height: 14),
                  _sectionCard(
                    title: '整房概況',
                    icon: Icons.notes_outlined,
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
                  _sectionCard(
                    title: '其他紀錄',
                    icon: Icons.edit_note_outlined,
                    children: <Widget>[
                      for (final DailyCareCustomField field
                          in _customFieldsByCategory('other'))
                        _customFieldWidget(field),
                    ],
                  ),
                ],

                if (widget.photoEnabled) ...<Widget>[
                  const SizedBox(height: 14),
                  _photoCard(),
                ],

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

                const SizedBox(height: 24),
              ],
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

  /// 🌡️💧 固定環境紀錄
  Widget _environmentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.thermostat_outlined,
                size: 20,
                color: Color(0xFF3D6F9F),
              ),
              SizedBox(width: 8),
              Text(
                '環境紀錄',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Spacer(),
              Text(
                '必填',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            '每一場照護紀錄都需要填寫目前房間的溫度與濕度。',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 16),

          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _temperatureController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '室內溫度',
                    hintText: '例如 24.5',
                    suffixText: '°C',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: TextField(
                  controller: _humidityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '室內濕度',
                    hintText: '例如 55',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photoCard() {
    return StreamBuilder<List<DailyCarePhotoModel>>(
      stream: DailyCarePhotoService.instance.streamRoomDayPhotos(
        shopId: widget.shopId,
        bookingId: widget.bookingId,
        roomId: widget.roomId,
        recordDate: widget.recordDate,
      ),
      builder: (context, snapshot) {
        final List<DailyCarePhotoModel> photos =
            snapshot.data ?? <DailyCarePhotoModel>[];

        final int currentCount = photos.length;
        final int maxCount = DailyCarePhotoService.maxPhotosPerRoomPerDay;

        final bool reachedLimit = currentCount >= maxCount;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.photo_camera_outlined,
                    size: 20,
                    color: Color(0xFF3D6F9F),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '照護照片',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    '$currentCount / $maxCount 張',
                    style: TextStyle(
                      fontSize: 12,
                      color: reachedLimit ? Colors.red : Colors.grey.shade600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Text(
                '照片為整個房間當日共用，每房每天最多 $maxCount 張。',
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

                    return Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              color: Colors.grey.shade100,
                              child: Image.network(
                                photo.previewUrl,
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
                          child: Material(
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

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: reachedLimit || _uploadingPhoto
                      ? null
                      : _pickAndUploadPhoto,
                  icon: _uploadingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    _uploadingPhoto
                        ? '上傳中...'
                        : reachedLimit
                        ? '今日照片已達上限'
                        : '選擇照片上傳',
                  ),
                ),
              ),
            ],
          ),
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

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: const Color(0xFF3D6F9F)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

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
                onSelected: (_) {
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
    return widget.enabledFields.contains(key);
  }

  bool _hasAny(List<String> keys) {
    return keys.any(_enabled);
  }
}

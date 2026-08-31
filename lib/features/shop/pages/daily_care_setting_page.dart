// lib/features/shop/pages/daily_care_setting_page.dart
// 🐾 每日照護紀錄設定頁
// 功能：讓店主設定是否啟用每日照護紀錄、每天填寫次數、
// 要填寫的照護欄位、照片功能與退房後下載期限。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/services/daily_care_background_service.dart';
import '../../../core/services/daily_care_setting_service.dart';
import '../../../core/widgets/daily_care_card_surface.dart';
import '../../../core/widgets/shop_task_center_button.dart';

class DailyCareSettingPage extends StatefulWidget {
  const DailyCareSettingPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<DailyCareSettingPage> createState() => _DailyCareSettingPageState();
}

class _DailyCareSettingPageState extends State<DailyCareSettingPage> {
  bool _loading = true;
  bool _saving = false;
  bool _backgroundBusy = false;

  bool _enabled = false;
  int _sessionCount = 2;
  bool _photoEnabled = true;
  int _downloadHours = 24;

  String _backgroundType = DailyCareJournalTheme.typeSystem;
  String _backgroundColorKey = DailyCareJournalTheme.colorDefault;
  String _backgroundImageUrl = '';
  String _backgroundImagePath = '';
  String _backgroundImageFit = DailyCareJournalTheme.fitCover;
  String _backgroundImageFade = DailyCareJournalTheme.fadeLight;

  String _cardBackgroundType = DailyCareJournalTheme.cardTypeSolid;
  String _cardBackgroundPreset = DailyCareJournalTheme.cardPresetNone;
  String _cardBackgroundImageUrl = '';
  String _cardBackgroundImagePath = '';
  String _cardBackgroundImageFit = DailyCareJournalTheme.fitCover;
  String _cardBackgroundImageFade = DailyCareJournalTheme.fadeLight;

  Set<String> _enabledFields = <String>{};

  List<DailyCareCustomField> _customFields = <DailyCareCustomField>[];

  final List<TextEditingController> _sessionLabelControllers =
      List<TextEditingController>.generate(
        3,
        (int index) => TextEditingController(),
      );

  final ImagePicker _imagePicker = ImagePicker();

  static const List<_CareFieldOption> _fieldOptions = <_CareFieldOption>[
    _CareFieldOption(
      key: 'water',
      label: '飲水',
      icon: Icons.water_drop_outlined,
    ),
    _CareFieldOption(
      key: 'dryFood',
      label: '飼料',
      icon: Icons.restaurant_outlined,
    ),
    _CareFieldOption(
      key: 'wetFood',
      label: '罐頭',
      icon: Icons.soup_kitchen_outlined,
    ),
    _CareFieldOption(key: 'snack', label: '零食', icon: Icons.cookie_outlined),
    _CareFieldOption(
      key: 'stool',
      label: '大便',
      icon: Icons.check_circle_outline,
    ),
    _CareFieldOption(
      key: 'urine',
      label: '尿尿',
      icon: Icons.check_circle_outline,
    ),
    _CareFieldOption(
      key: 'wandToy',
      label: '逗貓棒',
      icon: Icons.sports_esports_outlined,
    ),
    _CareFieldOption(key: 'scratchBoard', label: '貓抓板', icon: Icons.texture),
    _CareFieldOption(
      key: 'jumpPlatform',
      label: '貓跳台',
      icon: Icons.stairs_outlined,
    ),
    _CareFieldOption(
      key: 'toyBall',
      label: '玩具球',
      icon: Icons.sports_soccer_outlined,
    ),
    _CareFieldOption(key: 'catHouse', label: '貓屋', icon: Icons.home_outlined),
    _CareFieldOption(key: 'catnip', label: '貓薄荷', icon: Icons.eco_outlined),
    _CareFieldOption(
      key: 'silverVine',
      label: '木天蓼',
      icon: Icons.local_florist_outlined,
    ),
    _CareFieldOption(key: 'catGrass', label: '貓草', icon: Icons.grass_outlined),
    _CareFieldOption(
      key: 'generalNote',
      label: '整房概況',
      icon: Icons.notes_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _syncSessionLabelControllers(_sessionCount);
    _loadSetting();
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _sessionLabelControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSetting() async {
    try {
      final DailyCareSettingModel setting = await DailyCareSettingService
          .instance
          .getSetting(widget.shopId);

      if (!mounted) return;

      setState(() {
        _enabled = setting.enabled;
        _sessionCount = setting.sessionCount;
        _photoEnabled = setting.photoEnabled;
        _downloadHours = setting.downloadHoursAfterCheckout;
        _enabledFields = setting.enabledFields.toSet();
        _customFields = List<DailyCareCustomField>.from(setting.customFields);
        _backgroundType = setting.backgroundType;
        _backgroundColorKey = setting.backgroundColorKey;
        _backgroundImageUrl = setting.backgroundImageUrl;
        _backgroundImagePath = setting.backgroundImagePath;
        _backgroundImageFit = setting.backgroundImageFit;
        _backgroundImageFade = setting.backgroundImageFade;
        _cardBackgroundType = setting.cardBackgroundType;
        _cardBackgroundPreset = setting.cardBackgroundPreset;
        _cardBackgroundImageUrl = setting.cardBackgroundImageUrl;
        _cardBackgroundImagePath = setting.cardBackgroundImagePath;
        _cardBackgroundImageFit = setting.cardBackgroundImageFit;
        _cardBackgroundImageFade = setting.cardBackgroundImageFade;
        _syncSessionLabelControllers(
          setting.sessionCount,
          labels: setting.resolvedSessionLabels(),
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('讀取設定失敗：$e')));
    }
  }

  void _syncSessionLabelControllers(int sessionCount, {List<String>? labels}) {
    final List<String> defaults = DailyCareSettingModel.defaultSessionLabels(
      sessionCount,
    );
    for (int index = 0; index < _sessionLabelControllers.length; index++) {
      if (index < sessionCount) {
        final String next = labels != null && index < labels.length
            ? labels[index]
            : _sessionLabelControllers[index].text.trim().isNotEmpty
            ? _sessionLabelControllers[index].text.trim()
            : defaults[index];
        _sessionLabelControllers[index].text = next;
      } else if (_sessionLabelControllers[index].text.trim().isEmpty) {
        final List<String> three = DailyCareSettingModel.defaultSessionLabels(3);
        _sessionLabelControllers[index].text = three[index];
      }
    }
  }

  List<String>? _readSessionLabelsOrNull() {
    final List<String> labels = <String>[];
    for (int index = 0; index < _sessionCount; index++) {
      final String label = _sessionLabelControllers[index].text.trim();
      if (label.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('照護 ${index + 1} 名稱不可空白')));
        return null;
      }
      if (label.length > DailyCareJournalTheme.sessionLabelMaxLength) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '照護 ${index + 1} 名稱請控制在 ${DailyCareJournalTheme.sessionLabelMaxLength} 字以內',
            ),
          ),
        );
        return null;
      }
      labels.add(label);
    }
    return labels;
  }

  DailyCareSettingModel? _draftSetting() {
    final List<String>? sessionLabels = _readSessionLabelsOrNull();
    if (sessionLabels == null) {
      return null;
    }

    String backgroundType = _backgroundType;
    if (backgroundType == DailyCareJournalTheme.typeImage &&
        _backgroundImageUrl.trim().isEmpty) {
      backgroundType = DailyCareJournalTheme.typeSystem;
    }

    return DailyCareSettingModel(
      enabled: _enabled,
      sessionCount: _sessionCount,
      sessionLabels: sessionLabels,
      enabledFields: _enabledFields.toList(),
      customFields: _customFields,
      photoEnabled: _photoEnabled,
      downloadHoursAfterCheckout: _downloadHours,
      backgroundType: backgroundType,
      backgroundColorKey: _backgroundColorKey,
      backgroundImageUrl: _backgroundImageUrl,
      backgroundImagePath: _backgroundImagePath,
      backgroundImageFit: _backgroundImageFit,
      backgroundImageFade: _backgroundImageFade,
      cardBackgroundType: _resolvedCardBackgroundType(),
      cardBackgroundPreset: _cardBackgroundPreset,
      cardBackgroundImageUrl: _cardBackgroundImageUrl,
      cardBackgroundImagePath: _cardBackgroundImagePath,
      cardBackgroundImageFit: _cardBackgroundImageFit,
      cardBackgroundImageFade: _cardBackgroundImageFade,
    );
  }

  String _resolvedCardBackgroundType() {
    if (_cardBackgroundType == DailyCareJournalTheme.cardTypeImage &&
        _cardBackgroundImageUrl.trim().isEmpty) {
      return _cardBackgroundPreset == DailyCareJournalTheme.cardPresetNone
          ? DailyCareJournalTheme.cardTypeSolid
          : DailyCareJournalTheme.cardTypePreset;
    }
    return _cardBackgroundType;
  }

  DailyCareSettingModel _previewSetting() {
    return DailyCareSettingModel(
      sessionCount: _sessionCount,
      sessionLabels: List<String>.generate(
        _sessionCount,
        (int index) => _sessionLabelControllers[index].text.trim(),
      ),
      backgroundType: _backgroundType,
      backgroundColorKey: _backgroundColorKey,
      backgroundImageUrl: _backgroundImageUrl,
      backgroundImagePath: _backgroundImagePath,
      backgroundImageFit: _backgroundImageFit,
      backgroundImageFade: _backgroundImageFade,
      cardBackgroundType: _resolvedCardBackgroundType(),
      cardBackgroundPreset: _cardBackgroundPreset,
      cardBackgroundImageUrl: _cardBackgroundImageUrl,
      cardBackgroundImagePath: _cardBackgroundImagePath,
      cardBackgroundImageFit: _cardBackgroundImageFit,
      cardBackgroundImageFade: _cardBackgroundImageFade,
    );
  }

  Future<void> _save({String successMessage = '每日照護紀錄設定已儲存'}) async {
    if (_saving || _backgroundBusy) return;

    if (_enabled && _enabledFields.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請至少選擇一個照護紀錄欄位')));
      return;
    }

    final DailyCareSettingModel? setting = _draftSetting();
    if (setting == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await DailyCareSettingService.instance.saveSetting(
        shopId: widget.shopId,
        setting: setting,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadBackground() async {
    if (_saving || _backgroundBusy) {
      return;
    }

    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );
    if (file == null) {
      return;
    }

    final String name = file.name.toLowerCase();
    final bool allowed =
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp');
    if (!allowed) {
      _showMessage('請選擇 JPG、PNG 或 WEBP 圖片。');
      return;
    }

    final Uint8List bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > DailyCareBackgroundService.maxImageBytes) {
      _showMessage('背景圖片不可超過 5 MB，請換一張較小的圖片。');
      return;
    }

    setState(() {
      _backgroundBusy = true;
    });

    String? uploadedPath;
    bool firestoreSaved = false;
    final String oldPath = _backgroundImagePath;
    final String oldUrl = _backgroundImageUrl;
    try {
      final DailyCareBackgroundUpload uploaded =
          await DailyCareBackgroundService.instance.uploadBytes(
            shopId: widget.shopId,
            bytes: bytes,
            contentType: file.mimeType ?? '',
          );
      uploadedPath = uploaded.storagePath;

      setState(() {
        _backgroundType = DailyCareJournalTheme.typeImage;
        _backgroundImageUrl = uploaded.downloadUrl;
        _backgroundImagePath = uploaded.storagePath;
      });

      final DailyCareSettingModel? setting = _draftSetting();
      if (setting == null) {
        await DailyCareBackgroundService.instance.deleteStoredFile(
          storagePath: uploaded.storagePath,
        );
        if (mounted) {
          setState(() {
            _backgroundImageUrl = oldUrl;
            _backgroundImagePath = oldPath;
          });
        }
        return;
      }

      await DailyCareSettingService.instance.saveSetting(
        shopId: widget.shopId,
        setting: setting,
      );
      firestoreSaved = true;

      await DailyCareBackgroundService.instance.deleteStoredFile(
        storagePath: oldPath,
        downloadUrl: oldUrl,
      );

      if (!mounted) {
        return;
      }
      _showMessage('背景圖片已更新');
    } catch (error) {
      if (!firestoreSaved && uploadedPath != null) {
        await DailyCareBackgroundService.instance.deleteStoredFile(
          storagePath: uploadedPath,
        );
        if (mounted) {
          setState(() {
            _backgroundImageUrl = oldUrl;
            _backgroundImagePath = oldPath;
          });
        }
      }
      if (!mounted) {
        return;
      }
      _showMessage('背景圖片上傳失敗，請稍後再試。');
      debugPrint('每日照護背景上傳失敗：$error');
    } finally {
      if (mounted) {
        setState(() {
          _backgroundBusy = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteBackground() async {
    if (_saving || _backgroundBusy || _backgroundImageUrl.isEmpty) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('刪除背景圖片'),
          content: const Text('確定刪除自訂背景圖片，並改回系統預設背景嗎？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _backgroundBusy = true;
    });

    final String oldPath = _backgroundImagePath;
    final String oldUrl = _backgroundImageUrl;

    try {
      setState(() {
        _backgroundType = DailyCareJournalTheme.typeSystem;
        _backgroundImageUrl = '';
        _backgroundImagePath = '';
      });

      final DailyCareSettingModel? setting = _draftSetting();
      if (setting == null) {
        if (mounted) {
          setState(() {
            _backgroundType = DailyCareJournalTheme.typeImage;
            _backgroundImageUrl = oldUrl;
            _backgroundImagePath = oldPath;
          });
        }
        return;
      }

      await DailyCareSettingService.instance.saveSetting(
        shopId: widget.shopId,
        setting: setting,
      );
      await DailyCareBackgroundService.instance.deleteStoredFile(
        storagePath: oldPath,
        downloadUrl: oldUrl,
      );

      if (!mounted) {
        return;
      }
      _showMessage('已改回系統預設背景');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('刪除背景圖片失敗，請稍後再試。');
      debugPrint('每日照護背景刪除失敗：$error');
    } finally {
      if (mounted) {
        setState(() {
          _backgroundBusy = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadCardBackground() async {
    if (_saving || _backgroundBusy) {
      return;
    }

    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (file == null) {
      return;
    }

    final String name = file.name.toLowerCase();
    final bool allowed =
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp');
    if (!allowed) {
      _showMessage('請選擇 JPG、PNG 或 WEBP 圖片。');
      return;
    }

    final Uint8List bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > DailyCareBackgroundService.maxImageBytes) {
      _showMessage('卡片背景圖片不可超過 5 MB，請換一張較小的圖片。');
      return;
    }

    setState(() {
      _backgroundBusy = true;
    });

    String? uploadedPath;
    bool firestoreSaved = false;
    final String oldPath = _cardBackgroundImagePath;
    final String oldUrl = _cardBackgroundImageUrl;
    try {
      final DailyCareBackgroundUpload uploaded =
          await DailyCareBackgroundService.instance.uploadBytes(
            shopId: widget.shopId,
            bytes: bytes,
            contentType: file.mimeType ?? '',
            folder: DailyCareBackgroundService.cardFolderPath,
            filePrefix: 'card_background_',
          );
      uploadedPath = uploaded.storagePath;

      setState(() {
        _cardBackgroundType = DailyCareJournalTheme.cardTypeImage;
        _cardBackgroundImageUrl = uploaded.downloadUrl;
        _cardBackgroundImagePath = uploaded.storagePath;
      });

      final DailyCareSettingModel? setting = _draftSetting();
      if (setting == null) {
        await DailyCareBackgroundService.instance.deleteStoredFile(
          storagePath: uploaded.storagePath,
        );
        if (mounted) {
          setState(() {
            _cardBackgroundImageUrl = oldUrl;
            _cardBackgroundImagePath = oldPath;
          });
        }
        return;
      }

      await DailyCareSettingService.instance.saveSetting(
        shopId: widget.shopId,
        setting: setting,
      );
      firestoreSaved = true;

      await DailyCareBackgroundService.instance.deleteStoredFile(
        storagePath: oldPath,
        downloadUrl: oldUrl,
      );

      if (!mounted) {
        return;
      }
      _showMessage('卡片背景圖片已更新');
    } catch (error) {
      if (!firestoreSaved && uploadedPath != null) {
        await DailyCareBackgroundService.instance.deleteStoredFile(
          storagePath: uploadedPath,
        );
        if (mounted) {
          setState(() {
            _cardBackgroundImageUrl = oldUrl;
            _cardBackgroundImagePath = oldPath;
          });
        }
      }
      if (!mounted) {
        return;
      }
      _showMessage('卡片背景圖片上傳失敗，請稍後再試。');
      debugPrint('每日照護卡片背景上傳失敗：$error');
    } finally {
      if (mounted) {
        setState(() {
          _backgroundBusy = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteCardBackground() async {
    if (_saving || _backgroundBusy || _cardBackgroundImageUrl.isEmpty) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('移除自訂卡片背景'),
          content: const Text(
            '移除後將恢復使用系統預設卡片樣式，伺服器上的圖片也會一併刪除。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('移除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _backgroundBusy = true;
    });

    final String oldPath = _cardBackgroundImagePath;
    final String oldUrl = _cardBackgroundImageUrl;

    try {
      setState(() {
        _cardBackgroundType = DailyCareJournalTheme.cardTypeSolid;
        _cardBackgroundPreset = DailyCareJournalTheme.cardPresetNone;
        _cardBackgroundImageUrl = '';
        _cardBackgroundImagePath = '';
      });

      final DailyCareSettingModel? setting = _draftSetting();
      if (setting == null) {
        if (mounted) {
          setState(() {
            _cardBackgroundType = DailyCareJournalTheme.cardTypeImage;
            _cardBackgroundImageUrl = oldUrl;
            _cardBackgroundImagePath = oldPath;
          });
        }
        return;
      }

      await DailyCareSettingService.instance.saveSetting(
        shopId: widget.shopId,
        setting: setting,
      );
      await DailyCareBackgroundService.instance.deleteStoredFile(
        storagePath: oldPath,
        downloadUrl: oldUrl,
      );

      if (!mounted) {
        return;
      }
      _showMessage('已恢復純色卡片');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('移除卡片背景失敗，請稍後再試。');
      debugPrint('每日照護卡片背景刪除失敗：$error');
    } finally {
      if (mounted) {
        setState(() {
          _backgroundBusy = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showAddCustomFieldDialog(String category) async {
    final TextEditingController nameController = TextEditingController();

    String inputType = 'yesNo';

    final DailyCareCustomField? result = await showDialog<DailyCareCustomField>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('新增自訂照護項目'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '項目名稱',
                      hintText: '例如：吃藥、梳毛、精神狀況',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: inputType,
                    decoration: const InputDecoration(
                      labelText: '填寫方式',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'yesNo', child: Text('有 / 無')),
                      DropdownMenuItem(
                        value: 'amount',
                        child: Text('無 / 少 / 一般 / 多'),
                      ),
                      DropdownMenuItem(
                        value: 'condition',
                        child: Text('正常 / 偏少 / 偏多 / 異常'),
                      ),
                      DropdownMenuItem(value: 'text', child: Text('自由文字')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) return;

                      setDialogState(() {
                        inputType = value;
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final String name = nameController.text.trim();

                    if (name.isEmpty) {
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      DailyCareCustomField(
                        id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
                        label: name,
                        category: category,
                        inputType: inputType,
                      ),
                    );
                  },
                  child: const Text('新增'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();

    if (result == null || !mounted) return;

    setState(() {
      _customFields.add(result);
    });
  }

  String _inputTypeLabel(String inputType) {
    switch (inputType) {
      case 'amount':
        return '無 / 少 / 一般 / 多';
      case 'condition':
        return '正常 / 偏少 / 偏多 / 異常';
      case 'text':
        return '自由文字';
      case 'yesNo':
      default:
        return '有 / 無';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('每日照護紀錄設定'),
        actions: <Widget>[
          ShopTaskCenterButton(shopId: widget.shopId),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _buildMainSwitchCard(),

                const SizedBox(height: 16),

                IgnorePointer(
                  ignoring: !_enabled,
                  child: Opacity(
                    opacity: _enabled ? 1 : 0.45,
                    child: Column(
                      children: <Widget>[
                        _buildSessionCard(),

                        const SizedBox(height: 16),

                        _buildAppearanceCard(),

                        const SizedBox(height: 16),

                        _buildFieldsCard(),

                        const SizedBox(height: 16),

                        _buildPhotoCard(),

                        const SizedBox(height: 16),

                        _buildDownloadCard(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _saving || _backgroundBusy ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? '儲存中...' : '儲存設定'),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildMainSwitchCard() {
    return _SettingCard(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          '啟用每日照護紀錄',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('開啟後，入住中的房間才會在房務管理出現照護紀錄填寫入口。'),
        ),
        value: _enabled,
        onChanged: (bool value) {
          setState(() {
            _enabled = value;
          });
        },
      ),
    );
  }

  Widget _buildSessionCard() {
    return _SettingCard(
      title: '每天填寫次數',
      subtitle: '每個房間每天填寫一份或多份紀錄。紀錄仍以順序辨識，改名稱不會影響舊紀錄。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SegmentedButton<int>(
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(value: 1, label: Text('1 次')),
              ButtonSegment<int>(value: 2, label: Text('2 次')),
              ButtonSegment<int>(value: 3, label: Text('3 次')),
            ],
            selected: <int>{_sessionCount},
            onSelectionChanged: (Set<int> values) {
              if (values.isEmpty) return;

              setState(() {
                _sessionCount = values.first;
                _syncSessionLabelControllers(_sessionCount);
              });
            },
          ),
          const SizedBox(height: 16),
          const Text(
            '照護紀錄名稱',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (int index = 0; index < _sessionCount; index++) ...<Widget>[
            TextField(
              controller: _sessionLabelControllers[index],
              maxLength: DailyCareJournalTheme.sessionLabelMaxLength,
              decoration: InputDecoration(
                labelText: '照護 ${index + 1}',
                hintText: DailyCareSettingModel.fallbackSessionLabel(index),
                border: const OutlineInputBorder(),
                counterText: '',
              ),
            ),
            if (index < _sessionCount - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildAppearanceCard() {
    final DailyCareSettingModel preview = _previewSetting();
    final bool useCardImageMode =
        _cardBackgroundType == DailyCareJournalTheme.cardTypePreset ||
        _cardBackgroundType == DailyCareJournalTheme.cardTypeImage;

    return _SettingCard(
      title: '日誌外觀設定',
      subtitle: '選擇客戶每日照護日誌的背景。顏色使用系統色卡，不必自行輸入色碼。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _appearanceChoice(
                selected: _backgroundType == DailyCareJournalTheme.typeSystem,
                label: '系統預設',
                color: const Color(0xFFF5F6F8),
                onTap: () {
                  setState(() {
                    _backgroundType = DailyCareJournalTheme.typeSystem;
                  });
                },
              ),
              _appearanceChoice(
                selected:
                    _backgroundType == DailyCareJournalTheme.typeColor &&
                    _backgroundColorKey == DailyCareJournalTheme.colorWarm,
                label: '暖米色',
                color: const Color(0xFFF6EFE4),
                onTap: () {
                  setState(() {
                    _backgroundType = DailyCareJournalTheme.typeColor;
                    _backgroundColorKey = DailyCareJournalTheme.colorWarm;
                  });
                },
              ),
              _appearanceChoice(
                selected:
                    _backgroundType == DailyCareJournalTheme.typeColor &&
                    _backgroundColorKey == DailyCareJournalTheme.colorBlue,
                label: '淡藍色',
                color: const Color(0xFFE8F1F8),
                onTap: () {
                  setState(() {
                    _backgroundType = DailyCareJournalTheme.typeColor;
                    _backgroundColorKey = DailyCareJournalTheme.colorBlue;
                  });
                },
              ),
              _appearanceChoice(
                selected:
                    _backgroundType == DailyCareJournalTheme.typeColor &&
                    _backgroundColorKey == DailyCareJournalTheme.colorPink,
                label: '淡粉色',
                color: const Color(0xFFF8E9EE),
                onTap: () {
                  setState(() {
                    _backgroundType = DailyCareJournalTheme.typeColor;
                    _backgroundColorKey = DailyCareJournalTheme.colorPink;
                  });
                },
              ),
              _appearanceChoice(
                selected:
                    _backgroundType == DailyCareJournalTheme.typeColor &&
                    _backgroundColorKey == DailyCareJournalTheme.colorGreen,
                label: '淡綠色',
                color: const Color(0xFFE8F3EA),
                onTap: () {
                  setState(() {
                    _backgroundType = DailyCareJournalTheme.typeColor;
                    _backgroundColorKey = DailyCareJournalTheme.colorGreen;
                  });
                },
              ),
              _appearanceChoice(
                selected: _backgroundType == DailyCareJournalTheme.typeImage,
                label: '自訂圖片',
                color: const Color(0xFFEDE7F6),
                onTap: () {
                  setState(() {
                    _backgroundType = DailyCareJournalTheme.typeImage;
                  });
                },
              ),
            ],
          ),
          if (_backgroundType == DailyCareJournalTheme.typeImage) ...<Widget>[
            const SizedBox(height: 14),
            const Text(
              '建議直式 9:16，1080 × 1920。最低 720 × 1280，最大 5 MB，支援 JPG／PNG／WEBP。',
              style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _backgroundBusy || _saving
                        ? null
                        : _pickAndUploadBackground,
                    icon: _backgroundBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_outlined),
                    label: Text(
                      _backgroundBusy
                          ? '處理中...'
                          : _backgroundImageUrl.isEmpty
                          ? '上傳背景圖片'
                          : '更換背景圖片',
                    ),
                  ),
                ),
                if (_backgroundImageUrl.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _backgroundBusy || _saving
                        ? null
                        : _confirmDeleteBackground,
                    child: const Text('刪除'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            const Text('圖片顯示方式', style: TextStyle(fontWeight: FontWeight.w700)),
            RadioGroup<String>(
              groupValue: _backgroundImageFit,
              onChanged: (String? value) {
                if (value == null) return;
                setState(() {
                  _backgroundImageFit = value;
                });
              },
              child: const Column(
                children: <Widget>[
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: DailyCareJournalTheme.fitCover,
                    title: Text('填滿畫面'),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: DailyCareJournalTheme.fitContain,
                    title: Text('完整顯示'),
                  ),
                ],
              ),
            ),
            const Text('背景淡化程度', style: TextStyle(fontWeight: FontWeight.w700)),
            RadioGroup<String>(
              groupValue: _backgroundImageFade,
              onChanged: (String? value) {
                if (value == null) return;
                setState(() {
                  _backgroundImageFade = value;
                });
              },
              child: const Column(
                children: <Widget>[
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: DailyCareJournalTheme.fadeNone,
                    title: Text('原圖'),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: DailyCareJournalTheme.fadeLight,
                    title: Text('淡化'),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: DailyCareJournalTheme.fadeHeavy,
                    title: Text('很淡'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            '內容卡片背景',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            '所有照護內容卡片會共用同一個背景樣式，讓整份日誌風格一致。',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 10),
          RadioGroup<String>(
            groupValue: useCardImageMode
                ? DailyCareJournalTheme.cardTypePreset
                : DailyCareJournalTheme.cardTypeSolid,
            onChanged: (String? value) {
              if (value == null) return;
              setState(() {
                if (value == DailyCareJournalTheme.cardTypeSolid) {
                  _cardBackgroundType = DailyCareJournalTheme.cardTypeSolid;
                } else if (_cardBackgroundImageUrl.isNotEmpty) {
                  _cardBackgroundType = DailyCareJournalTheme.cardTypeImage;
                } else {
                  _cardBackgroundType = DailyCareJournalTheme.cardTypePreset;
                  if (_cardBackgroundPreset ==
                      DailyCareJournalTheme.cardPresetNone) {
                    _cardBackgroundPreset = DailyCareJournalTheme.cardPresetPaw;
                  }
                }
              });
            },
            child: const Column(
              children: <Widget>[
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: DailyCareJournalTheme.cardTypeSolid,
                  title: Text('純色卡片'),
                ),
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: DailyCareJournalTheme.cardTypePreset,
                  title: Text('使用圖片'),
                ),
              ],
            ),
          ),
          if (useCardImageMode) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              '選擇卡片背景',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DailyCareJournalTheme.cardPresets.map((
                DailyCareCardBackgroundPreset preset,
              ) {
                final bool selected =
                    _cardBackgroundType ==
                        DailyCareJournalTheme.cardTypePreset &&
                    _cardBackgroundPreset == preset.key;
                return _cardPresetChoice(
                  preset: preset,
                  selected: selected,
                  onTap: () {
                    setState(() {
                      _cardBackgroundType =
                          DailyCareJournalTheme.cardTypePreset;
                      _cardBackgroundPreset = preset.key;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              '建議比例 4:3 或 3:2，1200 × 800。最低 900 × 600，最大 5 MB，支援 JPG／PNG／WEBP。',
              style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _backgroundBusy || _saving
                        ? null
                        : _pickAndUploadCardBackground,
                    icon: _backgroundBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_outlined),
                    label: Text(
                      _backgroundBusy
                          ? '處理中...'
                          : _cardBackgroundImageUrl.isEmpty
                          ? '上傳自己的卡片背景'
                          : '更換卡片背景',
                    ),
                  ),
                ),
                if (_cardBackgroundImageUrl.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _backgroundBusy || _saving
                        ? null
                        : _confirmDeleteCardBackground,
                    child: const Text('移除'),
                  ),
                ],
              ],
            ),
            if (_cardBackgroundImageUrl.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _cardBackgroundType = DailyCareJournalTheme.cardTypeImage;
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          _cardBackgroundType ==
                              DailyCareJournalTheme.cardTypeImage
                          ? const Color(0xFF3D6F9F)
                          : Colors.black12,
                      width:
                          _cardBackgroundType ==
                              DailyCareJournalTheme.cardTypeImage
                          ? 2
                          : 1,
                    ),
                  ),
                  child: const Text(
                    '目前使用店家自訂卡片背景',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            if (preview.hasCardBackgroundVisual) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                '卡片圖片顯示方式',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              RadioGroup<String>(
                groupValue: _cardBackgroundImageFit,
                onChanged: (String? value) {
                  if (value == null) return;
                  setState(() {
                    _cardBackgroundImageFit = value;
                  });
                },
                child: const Column(
                  children: <Widget>[
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: DailyCareJournalTheme.fitCover,
                      title: Text('填滿卡片'),
                    ),
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: DailyCareJournalTheme.fitContain,
                      title: Text('完整顯示'),
                    ),
                  ],
                ),
              ),
              const Text(
                '卡片圖片淡化程度',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              RadioGroup<String>(
                groupValue: _cardBackgroundImageFade,
                onChanged: (String? value) {
                  if (value == null) return;
                  setState(() {
                    _cardBackgroundImageFade = value;
                  });
                },
                child: const Column(
                  children: <Widget>[
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: DailyCareJournalTheme.fadeNone,
                      title: Text('原圖'),
                    ),
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: DailyCareJournalTheme.fadeLight,
                      title: Text('淡化'),
                    ),
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: DailyCareJournalTheme.fadeHeavy,
                      title: Text('很淡'),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          const Text(
            '每日照護日誌縮圖預覽',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _JournalPreviewCard(setting: preview),
        ],
      ),
    );
  }

  Widget _appearanceChoice({
    required bool selected,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 88,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF3D6F9F) : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: <Widget>[
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardPresetChoice({
    required DailyCareCardBackgroundPreset preset,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 96,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF3D6F9F) : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 40,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const ColoredBox(color: Color(0xFFF7F7F7)),
                    if (preset.hasAsset)
                      CustomPaint(
                        painter: DailyCareCardPresetPainter(
                          presetKey: preset.key,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              preset.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCategory({
    required String title,
    required String category,
    required IconData icon,
    required List<_CareFieldOption> builtInFields,
  }) {
    final List<DailyCareCustomField> customFields = _customFields
        .where((DailyCareCustomField field) => field.category == category)
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: const Color(0xFF3D6F9F)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  _showAddCustomFieldDialog(category);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增'),
              ),
            ],
          ),

          for (final _CareFieldOption option in builtInFields)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: Icon(option.icon, size: 20),
              title: Text(option.label),
              value: _enabledFields.contains(option.key),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _enabledFields.add(option.key);
                  } else {
                    _enabledFields.remove(option.key);
                  }
                });
              },
            ),

          for (final DailyCareCustomField field in customFields)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.extension_outlined, size: 20),
              title: Text(field.label),
              subtitle: Text(_inputTypeLabel(field.inputType)),
              trailing: IconButton(
                tooltip: '刪除自訂項目',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _customFields.removeWhere(
                      (DailyCareCustomField item) => item.id == field.id,
                    );
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldsCard() {
    return _SettingCard(
      title: '照護紀錄欄位',
      subtitle: '溫度與濕度為固定紀錄；其他項目可依店家流程自行勾選或新增。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 固定紀錄
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.thermostat_outlined),
                  title: Text('室內溫度'),
                  trailing: Text(
                    '必填',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.water_drop_outlined),
                  title: Text('室內濕度'),
                  trailing: Text(
                    '必填',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          _buildFieldCategory(
            title: '飲食與飲水',
            category: 'food',
            icon: Icons.restaurant_outlined,
            builtInFields: _fieldOptions
                .where(
                  (_CareFieldOption item) => <String>[
                    'water',
                    'dryFood',
                    'wetFood',
                    'snack',
                  ].contains(item.key),
                )
                .toList(),
          ),

          _buildFieldCategory(
            title: '大小便狀況',
            category: 'toilet',
            icon: Icons.health_and_safety_outlined,
            builtInFields: _fieldOptions
                .where(
                  (_CareFieldOption item) =>
                      <String>['stool', 'urine'].contains(item.key),
                )
                .toList(),
          ),

          _buildFieldCategory(
            title: '活動與玩樂',
            category: 'activity',
            icon: Icons.sports_esports_outlined,
            builtInFields: _fieldOptions
                .where(
                  (_CareFieldOption item) => <String>[
                    'wandToy',
                    'scratchBoard',
                    'jumpPlatform',
                    'toyBall',
                    'catHouse',
                  ].contains(item.key),
                )
                .toList(),
          ),

          _buildFieldCategory(
            title: '放鬆與用品',
            category: 'relax',
            icon: Icons.eco_outlined,
            builtInFields: _fieldOptions
                .where(
                  (_CareFieldOption item) => <String>[
                    'catnip',
                    'silverVine',
                    'catGrass',
                  ].contains(item.key),
                )
                .toList(),
          ),

          _buildFieldCategory(
            title: '文字紀錄',
            category: 'other',
            icon: Icons.notes_outlined,
            builtInFields: _fieldOptions
                .where((_CareFieldOption item) => item.key == 'generalNote')
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard() {
    return _SettingCard(
      title: '照護照片',
      subtitle: '照片會使用壓縮預覽圖顯示，下載版會控制尺寸以降低儲存與流量成本。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('啟用照護照片'),
            value: _photoEnabled,
            onChanged: (bool value) {
              setState(() {
                _photoEnabled = value;
              });
            },
          ),
          const Divider(),
          const Text(
            '照片數量限制由平台統一控制，店家無法自行增加上限。',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard() {
    return _SettingCard(
      title: '退房後下載期限',
      subtitle: '退房後客戶可在期限內下載住宿紀錄與照片；到期後照片將關閉並進入自動清除流程。',
      child: DropdownButtonFormField<int>(
        initialValue: _downloadHours,
        decoration: const InputDecoration(
          labelText: '下載期限',
          border: OutlineInputBorder(),
        ),
        items: const <DropdownMenuItem<int>>[
          DropdownMenuItem<int>(value: 12, child: Text('12 小時')),
          DropdownMenuItem<int>(value: 24, child: Text('24 小時')),
          DropdownMenuItem<int>(value: 48, child: Text('48 小時')),
          DropdownMenuItem<int>(value: 72, child: Text('72 小時')),
        ],
        onChanged: (int? value) {
          if (value == null) return;

          setState(() {
            _downloadHours = value;
          });
        },
      ),
    );
  }
}

class _JournalPreviewCard extends StatelessWidget {
  const _JournalPreviewCard({required this.setting});

  final DailyCareSettingModel setting;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 268,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DailyCareJournalPageBackground(setting: setting),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '每日照護日誌',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          setting.sessionLabel(0),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: DailyCareCardSurface(
                      setting: setting,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '環境狀況',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '生活狀況　飲水 一般',
                            style: TextStyle(fontSize: 11),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '今日概況',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '今天精神很好，有好好吃飯喝水。',
                            style: TextStyle(fontSize: 11, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.child, this.title, this.subtitle});

  final Widget child;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(
              title!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 5),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _CareFieldOption {
  const _CareFieldOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

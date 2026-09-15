// 檔案名稱：lib/features/shop/pages/daily_care_setting_page.dart
// 功能說明：讓店主設定是否啟用每日照護紀錄、每天填寫次數
// 🐾 每日照護紀錄設定頁
// 要填寫的照護欄位、照片功能與退房後下載期限。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/daily_care_journal_layout.dart';
import '../../../core/models/daily_care_offer_quota.dart';
import '../../../core/models/daily_care_paid_plan.dart';
import '../../../core/models/daily_care_report_mode.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/services/daily_care_background_service.dart';
import '../../../core/services/daily_care_setting_service.dart';
import '../../../core/services/daycare_enabled.dart';
import '../../../core/services/shop_room_service.dart';
import '../../../core/services/shop_service.dart';
import '../../../core/widgets/daily_care_card_surface.dart';
import '../../../core/widgets/shop_task_center_button.dart';
import '../widgets/daily_care_full_journal_preview.dart';

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
  DailyCareSettingModel _loaded = const DailyCareSettingModel();

  bool _enabled = false;
  int _sessionCount = 2;
  bool _photoEnabled = true;
  String _stayReportMode = DailyCareReportMode.includedFixed;
  int _stayPhotosIncluded = 3;
  bool _stayAddonUpgradeEnabled = false;
  Map<String, DailyCareOfferQuota> _stayOfferQuotas =
      <String, DailyCareOfferQuota>{};
  bool _daycareEnabled = false;
  int _daycareSessionCount = 1;
  String _daycareReportMode = DailyCareReportMode.includedFixed;
  int _daycarePhotosIncluded = 3;
  bool _daycareAddonUpgradeEnabled = false;
  Map<String, DailyCareOfferQuota> _daycareOfferQuotas =
      <String, DailyCareOfferQuota>{};
  DailyCarePaidPlan _stayPaidPlan = const DailyCarePaidPlan();
  DailyCarePaidPlan _daycarePaidPlan = const DailyCarePaidPlan(
    chargeUnit: DailyCareReportMode.chargePerVisit,
  );
  bool _logoVisible = true;
  String _logoAlign = 'left';
  double _logoSize = 36;
  double _titleFontSize = 18;
  double _bodyFontSize = 14;
  String _textColorKey = 'ink';
  String _accentColorKey = 'brown';
  double _iconSize = 18;
  String _iconColorKey = 'brown';
  double _cardRadius = 16;
  double _cardPadding = 12;
  double _cardGap = 12;
  bool _showCardBorder = true;
  double _photoRadius = 10;
  int _tabIndex = 0;
  int _previewSessionIndex = 0;
  bool _previewPhotos = true;
  String _previewOfferId = '';
  DailyCarePreviewPhoneSize _previewPhoneSize =
      DailyCarePreviewPhoneSize.standard;

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
  DailyCareJournalDisplayFlags _journalDisplay =
      const DailyCareJournalDisplayFlags();
  Map<String, DailyCareJournalCardLayout> _journalCards =
      DailyCareJournalCardLayout.mapFrom(null);

  Set<String> _enabledFields = <String>{};

  List<DailyCareCustomField> _customFields = <DailyCareCustomField>[];

  final List<TextEditingController> _sessionLabelControllers =
      List<TextEditingController>.generate(
        3,
        (int index) => TextEditingController(),
      );

  final List<TextEditingController> _daycareLabelControllers =
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
    _syncDaycareLabelControllers(_daycareSessionCount);
    _loadSetting();
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _sessionLabelControllers) {
      controller.dispose();
    }
    for (final TextEditingController controller in _daycareLabelControllers) {
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
        _loaded = setting;
        _enabled = setting.enabled;
        _sessionCount = setting.sessionCount;
        _photoEnabled = setting.photoEnabled;
        _stayReportMode = setting.stayReportMode;
        _stayPhotosIncluded = setting.stayPhotosIncluded;
        _stayAddonUpgradeEnabled = setting.stayAddonUpgradeEnabled;
        _stayOfferQuotas = Map<String, DailyCareOfferQuota>.from(
          setting.stayOfferQuotas,
        );
        _daycareEnabled = setting.daycareEnabled;
        _daycareSessionCount = setting.daycareSessionCount;
        _daycareReportMode = setting.daycareReportMode;
        _daycarePhotosIncluded = setting.daycarePhotosIncluded;
        _daycareAddonUpgradeEnabled = setting.daycareAddonUpgradeEnabled;
        _daycareOfferQuotas = Map<String, DailyCareOfferQuota>.from(
          setting.daycareOfferQuotas,
        );
        _stayPaidPlan = setting.stayPaidPlan;
        _daycarePaidPlan = setting.daycarePaidPlan;
        _logoVisible = setting.logoVisible;
        _logoAlign = setting.logoAlign;
        _logoSize = setting.logoSize;
        _titleFontSize = setting.titleFontSize;
        _bodyFontSize = setting.bodyFontSize;
        _textColorKey = setting.textColorKey;
        _accentColorKey = setting.accentColorKey;
        _iconSize = setting.iconSize;
        _iconColorKey = setting.iconColorKey;
        _cardRadius = setting.cardRadius;
        _cardPadding = setting.cardPadding;
        _cardGap = setting.cardGap;
        _showCardBorder = setting.showCardBorder;
        _photoRadius = setting.photoRadius;
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
        _journalDisplay = setting.journalDisplay;
        _journalCards = setting.resolvedJournalCards;
        _syncSessionLabelControllers(
          setting.sessionCount,
          labels: setting.resolvedSessionLabels(),
        );
        _syncDaycareLabelControllers(
          setting.daycareSessionCount,
          labels: setting.resolvedDaycareSessionLabels(),
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

  void _syncDaycareLabelControllers(int sessionCount, {List<String>? labels}) {
    final List<String> defaults = DailyCareSettingModel.defaultSessionLabels(
      sessionCount,
    );
    for (int index = 0; index < _daycareLabelControllers.length; index++) {
      if (labels != null && index < labels.length && labels[index].trim().isNotEmpty) {
        _daycareLabelControllers[index].text = labels[index];
      } else if (_daycareLabelControllers[index].text.trim().isEmpty) {
        _daycareLabelControllers[index].text = defaults[index < defaults.length ? index : 0];
      }
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
        final List<String> three = DailyCareSettingModel.defaultSessionLabels(
          3,
        );
        _sessionLabelControllers[index].text = three[index];
      }
    }
  }

  List<String>? _readSessionLabelsOrNull() {
    final List<String> labels = <String>[];
    for (int index = 0; index < 3; index++) {
      labels.add(_sessionLabelControllers[index].text.trim());
    }
    int required = 0;
    if (_enabled && _stayReportMode == DailyCareReportMode.includedFixed) {
      required = _sessionCount;
    }
    if (_enabled && _stayReportMode == DailyCareReportMode.paidAddon) {
      required = _stayPaidPlan.reports;
    }
    for (int index = 0; index < required; index++) {
      if (labels[index].isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('住宿第 ${index + 1} 場名稱不可空白')),
        );
        return null;
      }
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
      stayReportMode: _stayReportMode,
      stayPhotosIncluded: _stayPhotosIncluded,
      stayAddonUpgradeEnabled: _stayAddonUpgradeEnabled,
      stayOfferQuotas: _stayOfferQuotas,
      stayPaidPlan: _stayPaidPlan.copyWith(
        sessionLabels: List<String>.generate(
          _stayPaidPlan.reports,
          (int index) => _sessionLabelControllers[index].text.trim(),
        ),
      ),
      daycarePaidPlan: _daycarePaidPlan.copyWith(
        sessionLabels: List<String>.generate(
          _daycarePaidPlan.reports,
          (int index) => _daycareLabelControllers[index].text.trim(),
        ),
      ),
      logoVisible: _logoVisible,
      logoAlign: _logoAlign,
      logoSize: _logoSize,
      titleFontSize: _titleFontSize,
      bodyFontSize: _bodyFontSize,
      textColorKey: _textColorKey,
      accentColorKey: _accentColorKey,
      iconSize: _iconSize,
      iconColorKey: _iconColorKey,
      categoryIcons: _loaded.categoryIcons,
      cardRadius: _cardRadius,
      cardPadding: _cardPadding,
      cardGap: _cardGap,
      showCardBorder: _showCardBorder,
      photoRadius: _photoRadius,
      daycareEnabled: _daycareEnabled,
      daycareSessionCount: _daycareSessionCount,
      daycareSessionLabels: List<String>.generate(
        3,
        (int index) => _daycareLabelControllers[index].text.trim(),
      ),
      daycareReportMode: _daycareReportMode,
      daycarePhotosIncluded: _daycarePhotosIncluded,
      daycareAddonUpgradeEnabled: _daycareAddonUpgradeEnabled,
      daycareOfferQuotas: _daycareOfferQuotas,
      revision: _loaded.revision,
      downloadHoursAfterCheckout: 24,
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
      journalDisplay: _journalDisplay.copyWith(
        showRoomOrOffer: true,
        showPetNames: true,
        showServiceDate: true,
        showFilledTime: true,
      ),
      journalCards: _journalCards,
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
    return _draftSetting() ?? _loaded;
  }

  Future<bool> _save({
    String successMessage = '每日照護紀錄設定已儲存',
    DailyCareSettingSection section = DailyCareSettingSection.all,
  }) async {
    if (_saving || _backgroundBusy) return false;

    if (_enabled && _enabledFields.isEmpty && _tabIndex == 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請至少選擇一個照護紀錄欄位')));
      return false;
    }

    final DailyCareSettingModel? setting = _draftSetting();
    if (setting == null) {
      return false;
    }

    setState(() {
      _saving = true;
    });

    try {
      await DailyCareSettingService.instance.saveSetting(
        shopId: widget.shopId,
        setting: setting,
        expectedRevision: _loaded.revision,
        section: section == DailyCareSettingSection.all
            ? _sectionForTab(_tabIndex)
            : section,
      );
      final DailyCareSettingModel stored = await DailyCareSettingService
          .instance
          .getSetting(widget.shopId);
      if (mounted) {
        setState(() {
          _loaded = stored;
        });
      }

      if (!mounted) return true;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      return true;
    } catch (e, stack) {
      DailyCareSaveErrorProbe.debugLog(
        'DailyCareSetting page save failed',
        e,
        stack,
      );
      if (!mounted) return false;
      final String message = DailyCareSettingSaveException.fromError(e).message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  DailyCareSettingSection _sectionForTab(int index) {
    switch (index) {
      case 1:
        return DailyCareSettingSection.content;
      case 2:
        return DailyCareSettingSection.appearance;
      default:
        return DailyCareSettingSection.rules;
    }
  }

  bool _sectionDirty(int index) {
    final DailyCareSettingModel? draft = _draftSetting();
    if (draft == null) {
      return true;
    }
    switch (_sectionForTab(index)) {
      case DailyCareSettingSection.rules:
        return draft.enabled != _loaded.enabled ||
            draft.sessionCount != _loaded.sessionCount ||
            draft.sessionLabels.toString() != _loaded.sessionLabels.toString() ||
            draft.stayReportMode != _loaded.stayReportMode ||
            draft.stayPaidPlan.toMap().toString() !=
                _loaded.stayPaidPlan.toMap().toString() ||
            draft.daycareEnabled != _loaded.daycareEnabled ||
            draft.daycareReportMode != _loaded.daycareReportMode ||
            draft.photoEnabled != _loaded.photoEnabled;
      case DailyCareSettingSection.content:
        return draft.enabledFields.toString() !=
                _loaded.enabledFields.toString() ||
            draft.customFields.map((e) => e.id).join() !=
                _loaded.customFields.map((e) => e.id).join() ||
            draft.journalDisplay.showTemperature !=
                _loaded.journalDisplay.showTemperature ||
            draft.journalDisplay.showHumidity !=
                _loaded.journalDisplay.showHumidity;
      case DailyCareSettingSection.appearance:
        return draft.backgroundType != _loaded.backgroundType ||
            draft.cardBackgroundType != _loaded.cardBackgroundType ||
            draft.logoVisible != _loaded.logoVisible ||
            draft.titleFontSize != _loaded.titleFontSize ||
            draft.journalDisplay.toMap().toString() !=
                _loaded.journalDisplay.toMap().toString() ||
            DailyCareJournalCardLayout.mapToFirestore(draft.resolvedJournalCards)
                    .toString() !=
                DailyCareJournalCardLayout.mapToFirestore(
                  _loaded.resolvedJournalCards,
                ).toString();
      case DailyCareSettingSection.all:
        return true;
    }
  }

  Future<void> _requestTab(int next) async {
    if (next == _tabIndex) {
      return;
    }
    if (!_sectionDirty(_tabIndex)) {
      setState(() {
        _tabIndex = next;
      });
      return;
    }
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('有尚未儲存的變更'),
          content: const Text('要先儲存目前分頁，還是放棄變更再前往？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('放棄變更並前往'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('儲存並前往'),
            ),
          ],
        );
      },
    );
    if (action == 'save') {
      final bool ok = await _save(section: _sectionForTab(_tabIndex));
      if (ok && mounted) {
        setState(() {
          _tabIndex = next;
        });
      }
    } else if (action == 'discard') {
      await _loadSetting();
      if (mounted) {
        setState(() {
          _tabIndex = next;
        });
      }
    }
  }

  Future<bool> _onLeaveEditor() async {
    if (!_sectionDirty(_tabIndex)) {
      return true;
    }
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('有尚未儲存的變更'),
          content: const Text('離開前要儲存、放棄，還是繼續編輯？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('繼續編輯'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('放棄變更'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
    if (action == 'save') {
      return _save(section: _sectionForTab(_tabIndex));
    }
    return action == 'discard';
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
          content: const Text('移除後將恢復使用系統預設卡片樣式，伺服器上的圖片也會一併刪除。'),
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
    if (category == 'food' || category == 'toilet') {
      return;
    }
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
    final bool wide = MediaQuery.sizeOf(context).width >= 900;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        final bool leave = await _onLeaveEditor();
        if (leave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          title: const Text('每日照護紀錄設定'),
          actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Row(
              children: <Widget>[
                _tabButton(0, '回報規則'),
                _tabButton(1, '照護內容'),
                _tabButton(2, '外觀設定'),
              ],
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: <Widget>[
                  Expanded(
                    child: IndexedStack(
                      index: _tabIndex,
                      children: <Widget>[
                        _wrapWidth(wide, _buildReportRulesTab()),
                        _buildContentTab(wide),
                        _buildAppearanceTab(wide),
                      ],
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _saving || _backgroundBusy
                              ? null
                              : () => _save(
                                  section: _sectionForTab(_tabIndex),
                                ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_saving ? '儲存中...' : '確認儲存此分頁'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final bool selected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _requestTab(index),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? const Color(0xFF3D6F9F) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? const Color(0xFF3D6F9F) : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrapWidth(bool wide, Widget child) {
    if (!wide) {
      return child;
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: child,
      ),
    );
  }

  Widget _buildReportRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildMainSwitchCard(),
        const SizedBox(height: 16),
        _buildStayRuleCard(),
        const SizedBox(height: 16),
        StreamBuilder<Map<String, dynamic>?>(
          stream: ShopService.instance.streamShop(widget.shopId),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<Map<String, dynamic>?> shopSnap,
              ) {
                if (!DaycareEnabled.isOn(shop: shopSnap.data)) {
                  return const SizedBox.shrink();
                }
                return _buildDaycareRuleCard();
              },
        ),
        const SizedBox(height: 16),
        _SettingCard(
          title: '照片與保存',
          subtitle: '回報照片與保存期限由平台規則決定。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('啟用回報照片'),
                value: _photoEnabled,
                onChanged: (bool value) {
                  setState(() {
                    _photoEnabled = value;
                  });
                },
              ),
              const Text('每場最多 3 張'),
              const SizedBox(height: 6),
              const Text('服務實際結束後保留 24 小時'),
              const SizedBox(height: 6),
              const Text('到期自動清除'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentTab(bool wide) {
    final Widget settings = ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          '場次數量與名稱請在「回報規則」設定。此頁只編輯顧客日誌會出現的照護項目。',
          style: TextStyle(height: 1.4),
        ),
        const SizedBox(height: 16),
        _buildFieldsCard(),
        if (!wide) ...<Widget>[
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => _openMobilePreview(),
            child: const Text('預覽圖片'),
          ),
        ],
      ],
    );
    return _splitEditor(wide: wide, settings: settings);
  }

  Widget _buildAppearanceTab(bool wide) {
    final Widget settings = ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _logoAndTypeCard(),
        const SizedBox(height: 16),
        _headerDisplayCard(),
        const SizedBox(height: 16),
        _cardLayoutEditorCard(),
        const SizedBox(height: 16),
        _buildAppearanceCard(),
        if (!wide) ...<Widget>[
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => _openMobilePreview(),
            child: const Text('預覽圖片'),
          ),
        ],
      ],
    );
    return _splitEditor(wide: wide, settings: settings);
  }

  Widget _splitEditor({required bool wide, required Widget settings}) {
    if (!wide) {
      return settings;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: _desktopPreviewPane()),
        const VerticalDivider(width: 1),
        Expanded(child: settings),
      ],
    );
  }

  Widget _desktopPreviewPane() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(widget.shopId),
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, dynamic>?> snap) {
            final String shopName = (snap.data?['name'] ??
                    snap.data?['shopName'] ??
                    '')
                .toString()
                .trim();
            final String shopLogo = (snap.data?['logoUrl'] ?? '')
                .toString()
                .trim();
            return _desktopPreviewBody(
              shopName: shopName,
              shopLogo: shopLogo,
            );
          },
    );
  }

  Widget _desktopPreviewBody({
    required String shopName,
    required String shopLogo,
  }) {
    final DailyCareSettingModel preview = _previewSetting();
    final List<String> labels = DailyCarePreviewSession.labelsFor(
      preview,
      isDaycare: false,
      offerId: _previewOfferId,
    );
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final DailyCarePreviewPhoneSize phone
                  in DailyCarePreviewPhoneSize.all)
                ChoiceChip(
                  label: Text(
                    '${phone.label} ${phone.size.width.toInt()}×${phone.size.height.toInt()}',
                  ),
                  selected: _previewPhoneSize.id == phone.id,
                  onSelected: (_) {
                    setState(() {
                      _previewPhoneSize = phone;
                    });
                  },
                ),
              ChoiceChip(
                label: Text(_previewPhotos ? '有照片' : '無照片'),
                selected: _previewPhotos,
                onSelected: (_) {
                  setState(() {
                    _previewPhotos = !_previewPhotos;
                  });
                },
              ),
              for (int i = 0; i < labels.length; i++)
                ChoiceChip(
                  label: Text(labels[i]),
                  selected: _previewSessionIndex == i,
                  onSelected: (_) {
                    setState(() {
                      _previewSessionIndex = i;
                    });
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: DailyCareFullJournalPreview(
            setting: preview,
            isDaycare: false,
            sessionLabels: labels,
            sessionIndex: _previewSessionIndex,
            showPhotos: _previewPhotos,
            usePhoneFrame: true,
            shopName: shopName,
            shopLogoUrl: shopLogo,
            phoneSize: _previewPhoneSize,
          ),
        ),
      ],
    );
  }

  Future<void> _openMobilePreview() async {
    final DailyCareSettingModel preview = _previewSetting();
    final List<String> labels = DailyCarePreviewSession.labelsFor(
      preview,
      isDaycare: false,
      offerId: _previewOfferId,
    );
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(title: const Text('照護日誌預覽')),
            body: DailyCareFullJournalPreview(
              setting: preview,
              isDaycare: false,
              sessionLabels: labels,
              sessionIndex: _previewSessionIndex,
              showPhotos: _previewPhotos,
              usePhoneFrame: false,
              shopName: '',
              shopLogoUrl: '',
            ),
          );
        },
      ),
    );
  }

  Widget _logoAndTypeCard() {
    return _SettingCard(
      title: '品牌與文字',
      subtitle: '預設使用店家 LOGO。還原預設後仍是本機草稿，需確認儲存才生效。',
      child: Column(
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示店家 LOGO'),
            value: _logoVisible,
            onChanged: (bool value) {
              setState(() {
                _logoVisible = value;
              });
            },
          ),
          RadioListTile<String>(
            value: 'left',
            groupValue: _logoAlign,
            title: const Text('LOGO 靠左'),
            onChanged: (String? value) {
              setState(() {
                _logoAlign = value ?? 'left';
              });
            },
          ),
          RadioListTile<String>(
            value: 'center',
            groupValue: _logoAlign,
            title: const Text('LOGO 置中'),
            onChanged: (String? value) {
              setState(() {
                _logoAlign = value ?? 'center';
              });
            },
          ),
          Text('LOGO 大小 ${_logoSize.round()}'),
          Slider(
            min: 20,
            max: 72,
            value: _logoSize,
            onChanged: (double value) {
              setState(() {
                _logoSize = value;
              });
            },
          ),
          Text('標題字級 ${_titleFontSize.round()}'),
          Slider(
            min: 14,
            max: 28,
            value: _titleFontSize,
            onChanged: (double value) {
              setState(() {
                _titleFontSize = value;
              });
            },
          ),
          Text('內文字級 ${_bodyFontSize.round()}'),
          Slider(
            min: 12,
            max: 20,
            value: _bodyFontSize,
            onChanged: (double value) {
              setState(() {
                _bodyFontSize = value;
              });
            },
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _logoVisible = true;
                _logoAlign = 'left';
                _logoSize = 36;
                _titleFontSize = 18;
                _bodyFontSize = 14;
                _cardRadius = 16;
                _cardPadding = 12;
                _cardGap = 12;
                _photoRadius = 10;
                _backgroundType = DailyCareJournalTheme.typeSystem;
                _cardBackgroundType = DailyCareJournalTheme.cardTypeSolid;
                _cardBackgroundPreset = DailyCareJournalTheme.cardPresetNone;
              });
            },
            child: const Text('還原預設（本機草稿）'),
          ),
        ],
      ),
    );
  }

  Widget _headerDisplayCard() {
    Widget switchRow(String title, bool value, ValueChanged<bool> onChanged) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        value: value,
        onChanged: (bool next) {
          setState(() => onChanged(next));
        },
      );
    }

    return _SettingCard(
      title: '頁首與顯示內容',
      subtitle: '控制客戶端照護日誌要顯示哪些資訊。未設定的舊店家全部預設開啟。',
      child: Column(
        children: <Widget>[
          switchRow('顯示店名', _journalDisplay.showShopName, (bool v) {
            _journalDisplay = _journalDisplay.copyWith(showShopName: v);
          }),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('顯示 Logo'),
            subtitle: Text('照護日誌是否顯示 Logo，沿用上方「品牌與文字」的開關。'),
          ),
          switchRow('顯示照護照片區', _journalDisplay.showPhotoSection, (bool v) {
            _journalDisplay = _journalDisplay.copyWith(showPhotoSection: v);
          }),
        ],
      ),
    );
  }

  Widget _cardLayoutEditorCard() {
    final List<DailyCareJournalCardLayout> rows =
        DailyCareJournalCardLayout.sorted(_journalCards);
    return _SettingCard(
      title: '回報卡片編排',
      subtitle: '調整顯示、滿寬／半寬、色彩與順序。半寬在過窄或文字過長時會自動改滿寬。',
      child: Column(
        children: <Widget>[
          for (int index = 0; index < rows.length; index++)
            _cardLayoutRow(rows[index], index, rows.length),
        ],
      ),
    );
  }

  Widget _cardLayoutRow(
    DailyCareJournalCardLayout item,
    int index,
    int total,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '${index + 1}.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  DailyCareJournalCardKeys.labelOf(item.key),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Switch(
                value: item.visible,
                onChanged: (bool value) {
                  setState(() {
                    _journalCards = Map<String, DailyCareJournalCardLayout>.from(
                      _journalCards,
                    )..[item.key] = item.copyWith(visible: value);
                  });
                },
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ChoiceChip(
                label: const Text('滿寬'),
                selected: !item.isHalf,
                onSelected: (_) {
                  setState(() {
                    _journalCards = Map<String, DailyCareJournalCardLayout>.from(
                      _journalCards,
                    )..[item.key] = item.copyWith(
                      width: DailyCareJournalCardStyle.widthFull,
                    );
                  });
                },
              ),
              ChoiceChip(
                label: const Text('半寬'),
                selected: item.isHalf,
                onSelected: (_) {
                  setState(() {
                    _journalCards = Map<String, DailyCareJournalCardLayout>.from(
                      _journalCards,
                    )..[item.key] = item.copyWith(
                      width: DailyCareJournalCardStyle.widthHalf,
                    );
                  });
                },
              ),
              DropdownButton<String>(
                value: item.colorKey,
                items: DailyCareJournalCardStyle.colorKeys
                    .map(
                      (String key) => DropdownMenuItem<String>(
                        value: key,
                        child: Text(DailyCareJournalCardStyle.colorLabel(key)),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _journalCards = Map<String, DailyCareJournalCardLayout>.from(
                      _journalCards,
                    )..[item.key] = item.copyWith(colorKey: value);
                  });
                },
              ),
              IconButton(
                tooltip: '上移',
                onPressed: index == 0
                    ? null
                    : () => _moveCard(item.key, -1),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: '下移',
                onPressed: index == total - 1
                    ? null
                    : () => _moveCard(item.key, 1),
                icon: const Icon(Icons.arrow_downward),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _moveCard(String key, int delta) {
    final List<DailyCareJournalCardLayout> rows =
        DailyCareJournalCardLayout.sorted(_journalCards);
    final int index = rows.indexWhere(
      (DailyCareJournalCardLayout row) => row.key == key,
    );
    final int next = index + delta;
    if (index < 0 || next < 0 || next >= rows.length) {
      return;
    }
    final DailyCareJournalCardLayout a = rows[index];
    final DailyCareJournalCardLayout b = rows[next];
    setState(() {
      final Map<String, DailyCareJournalCardLayout> nextMap =
          Map<String, DailyCareJournalCardLayout>.from(_journalCards);
      nextMap[a.key] = a.copyWith(order: b.order);
      nextMap[b.key] = b.copyWith(order: a.order);
      _journalCards = nextMap;
    });
  }

  Widget _modeSelector({
    required String value,
    required ValueChanged<String> onChanged,
    required bool daycare,
    bool roomBased = true,
  }) {
    return Column(
      children: <Widget>[
        RadioListTile<String>(
          value: DailyCareReportMode.includedFixed,
          groupValue: value,
          title: const Text('固定提供'),
          subtitle: const Text('所有訂單提供相同場次數量與名稱'),
          onChanged: (String? next) {
            if (next != null) {
              onChanged(next);
            }
          },
        ),
        RadioListTile<String>(
          value: DailyCareReportMode.includedByOffer,
          groupValue: value,
          title: Text(daycare && !roomBased ? '依方案提供' : '依房型提供'),
          subtitle: Text(
            daycare
                ? (roomBased ? '依安親房型設定場次，購買時即確定，不等分房。' : '依安親方案設定場次。')
                : '各房型只設定回報幾場與各場名稱，購買房型時即確定。',
          ),
          onChanged: (String? next) {
            if (next != null) {
              onChanged(next);
            }
          },
        ),
        RadioListTile<String>(
          value: DailyCareReportMode.paidAddon,
          groupValue: value,
          title: const Text('付費加購'),
          subtitle: const Text('店家不免費提供；顧客購買後才享有回報及可附照片的服務。'),
          onChanged: (String? next) {
            if (next != null) {
              onChanged(next);
            }
          },
        ),
      ],
    );
  }

  Widget _buildStayRuleCard() {
    return _SettingCard(
      title: '住宿回報規則',
      subtitle: '住宿獨立保存啟用狀態、模式、場次與付費方案。',
      child: Column(
        children: <Widget>[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '回報日期依住宿晚數計算：入住日包含，退房日不包含。',
              style: TextStyle(height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          _modeSelector(
            value: _stayReportMode,
            onChanged: (String value) {
              setState(() {
                _stayReportMode = value;
              });
            },
            daycare: false,
          ),
          if (_stayReportMode == DailyCareReportMode.includedFixed) ...<Widget>[
            DropdownButtonFormField<int>(
              initialValue: _sessionCount,
              decoration: const InputDecoration(labelText: '每天回報幾場'),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 1, child: Text('1 場')),
                DropdownMenuItem<int>(value: 2, child: Text('2 場')),
                DropdownMenuItem<int>(value: 3, child: Text('3 場')),
              ],
              onChanged: (int? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _sessionCount = value;
                  _syncSessionLabelControllers(_sessionCount);
                });
              },
            ),
            ..._sessionNameFields(_sessionCount, _sessionLabelControllers),
          ],
          if (_stayReportMode == DailyCareReportMode.includedByOffer)
            _roomTypeQuotaEditor(),
          if (_stayReportMode == DailyCareReportMode.paidAddon)
            _paidPlanEditor(daycare: false),
        ],
      ),
    );
  }

  List<Widget> _sessionNameFields(
    int count,
    List<TextEditingController> controllers,
  ) {
    return List<Widget>.generate(count, (int index) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextField(
          controller: controllers[index],
          decoration: InputDecoration(labelText: '第 ${index + 1} 場名稱'),
          onChanged: (_) => setState(() {}),
        ),
      );
    });
  }

  Widget _paidPlanEditor({required bool daycare}) {
    final DailyCarePaidPlan plan = daycare ? _daycarePaidPlan : _stayPaidPlan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: TextEditingController(text: plan.name)
            ..selection = TextSelection.collapsed(offset: plan.name.length),
          decoration: const InputDecoration(labelText: '方案名稱'),
          onChanged: (String value) {
            setState(() {
              if (daycare) {
                _daycarePaidPlan = _daycarePaidPlan.copyWith(name: value);
              } else {
                _stayPaidPlan = _stayPaidPlan.copyWith(name: value);
              }
            });
          },
        ),
        TextField(
          controller: TextEditingController(text: plan.description)
            ..selection =
                TextSelection.collapsed(offset: plan.description.length),
          decoration: const InputDecoration(labelText: '方案說明'),
          maxLines: 2,
          onChanged: (String value) {
            setState(() {
              if (daycare) {
                _daycarePaidPlan = _daycarePaidPlan.copyWith(description: value);
              } else {
                _stayPaidPlan = _stayPaidPlan.copyWith(description: value);
              }
            });
          },
        ),
        if (!daycare)
          DropdownButtonFormField<String>(
            initialValue: DailyCareReportMode.normalizeChargeUnit(
              plan.chargeUnit,
            ),
            decoration: const InputDecoration(labelText: '收費方式'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: DailyCareReportMode.chargePerServiceDay,
                child: Text('每日計費（依服務日期）'),
              ),
              DropdownMenuItem<String>(
                value: DailyCareReportMode.chargeOncePerStay,
                child: Text('整筆住宿收費一次'),
              ),
            ],
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() {
                _stayPaidPlan = _stayPaidPlan.copyWith(chargeUnit: value);
              });
            },
          ),
        TextField(
          keyboardType: TextInputType.number,
          controller: TextEditingController(text: '${plan.price}')
            ..selection = TextSelection.collapsed(offset: '${plan.price}'.length),
          decoration: InputDecoration(
            labelText: daycare ? '每筆價格' : '價格',
          ),
          onChanged: (String value) {
            final int price = int.tryParse(value) ?? 0;
            setState(() {
              if (daycare) {
                _daycarePaidPlan = _daycarePaidPlan.copyWith(price: price);
              } else {
                _stayPaidPlan = _stayPaidPlan.copyWith(price: price);
              }
            });
          },
        ),
        DropdownButtonFormField<int>(
          initialValue: plan.reports,
          decoration: InputDecoration(
            labelText: daycare ? '每筆回報幾場' : '每日回報幾場',
          ),
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem<int>(value: 1, child: Text('1 場')),
            DropdownMenuItem<int>(value: 2, child: Text('2 場')),
            DropdownMenuItem<int>(value: 3, child: Text('3 場')),
          ],
          onChanged: (int? value) {
            if (value == null) {
              return;
            }
            setState(() {
              if (daycare) {
                _daycarePaidPlan = _daycarePaidPlan.copyWith(reports: value);
              } else {
                _stayPaidPlan = _stayPaidPlan.copyWith(reports: value);
              }
            });
          },
        ),
        ..._sessionNameFields(
          plan.reports,
          daycare ? _daycareLabelControllers : _sessionLabelControllers,
        ),
      ],
    );
  }

  Widget _roomTypeQuotaEditor({bool daycare = false}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ShopRoomService.instance.getRoomTypes(widget.shopId),
      builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snap) {
        final List<Map<String, dynamic>> types =
            snap.data ?? const <Map<String, dynamic>>[];
        if (types.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('尚未設定房型'),
          );
        }
        return Column(
          children: types.map((Map<String, dynamic> type) {
            final String id = (type['id'] ?? type['roomTypeId'] ?? '').toString();
            final String name = (type['name'] ?? id).toString();
            final DailyCareOfferQuota? quota = daycare
                ? _daycareOfferQuotas[id]
                : _stayOfferQuotas[id];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(name),
              subtitle: Text(
                quota == null || !quota.configured
                    ? '尚未設定場次，下單時無法使用此房型照護回報'
                    : '每天 ${quota.reports} 場：${quota.resolvedLabels().join('、')}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  int reports = quota?.reports ?? 1;
                  final List<TextEditingController> names =
                      List<TextEditingController>.generate(
                    3,
                    (int index) => TextEditingController(
                      text: quota != null && index < quota.sessionLabels.length
                          ? quota.sessionLabels[index]
                          : '',
                    ),
                  );
                  final bool? ok = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('$name 場次'),
                        content: StatefulBuilder(
                          builder: (BuildContext context, StateSetter setLocal) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                DropdownButtonFormField<int>(
                                  initialValue: reports,
                                  decoration: const InputDecoration(
                                    labelText: '每天回報幾場',
                                  ),
                                  items: const <DropdownMenuItem<int>>[
                                    DropdownMenuItem<int>(
                                      value: 1,
                                      child: Text('1 場'),
                                    ),
                                    DropdownMenuItem<int>(
                                      value: 2,
                                      child: Text('2 場'),
                                    ),
                                    DropdownMenuItem<int>(
                                      value: 3,
                                      child: Text('3 場'),
                                    ),
                                  ],
                                  onChanged: (int? value) {
                                    setLocal(() {
                                      reports = value ?? 1;
                                    });
                                  },
                                ),
                                for (int i = 0; i < reports; i++)
                                  TextField(
                                    controller: names[i],
                                    decoration: InputDecoration(
                                      labelText: '第 ${i + 1} 場名稱',
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('套用草稿'),
                          ),
                        ],
                      );
                    },
                  );
                  if (ok == true) {
                    setState(() {
                      final DailyCareOfferQuota next = DailyCareOfferQuota(
                        configured: true,
                        reports: reports,
                        sessionLabels: List<String>.generate(
                          reports,
                          (int i) => names[i].text.trim(),
                        ),
                      );
                      if (daycare) {
                        _daycareOfferQuotas[id] = next;
                      } else {
                        _stayOfferQuotas[id] = next;
                      }
                    });
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDaycareRuleCard() {
    return _SettingCard(
      title: '安親回報規則',
      subtitle: '顯示為每筆安親回報次數。全店安親關閉時會隱藏此區，不會清除資料。',
      child: Column(
        children: <Widget>[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '每筆安親服務於服務當日提供回報。',
              style: TextStyle(height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('啟用安親照護回報'),
            value: _daycareEnabled,
            onChanged: (bool value) {
              setState(() {
                _daycareEnabled = value;
              });
            },
          ),
          _modeSelector(
            value: _daycareReportMode,
            onChanged: (String value) {
              setState(() {
                _daycareReportMode = value;
              });
            },
            daycare: true,
          ),
          if (_daycareReportMode == DailyCareReportMode.includedFixed) ...<Widget>[
            DropdownButtonFormField<int>(
              initialValue: _daycareSessionCount,
              decoration: const InputDecoration(labelText: '每筆回報幾場'),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 1, child: Text('1 場')),
                DropdownMenuItem<int>(value: 2, child: Text('2 場')),
                DropdownMenuItem<int>(value: 3, child: Text('3 場')),
              ],
              onChanged: (int? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _daycareSessionCount = value;
                  _syncDaycareLabelControllers(_daycareSessionCount);
                });
              },
            ),
            ..._sessionNameFields(
              _daycareSessionCount,
              _daycareLabelControllers,
            ),
          ],
          if (_daycareReportMode == DailyCareReportMode.includedByOffer)
            _roomTypeQuotaEditor(daycare: true),
          if (_daycareReportMode == DailyCareReportMode.paidAddon)
            _paidPlanEditor(daycare: true),
        ],
      ),
    );
  }

  Widget _buildMainSwitchCard() {
    return _SettingCard(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          '啟用住宿照護回報',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('開啟後，入住中的房間才會出現住宿照護紀錄填寫入口。此開關不控制安親。'),
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
            '照護紀錄名稱（第 1～3 個名稱同時給安親回報使用）',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (int index = 0; index < 3; index++) ...<Widget>[
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
            if (index < 2) const SizedBox(height: 10),
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.4,
              ),
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
            const Text('選擇卡片背景', style: TextStyle(fontWeight: FontWeight.w700)),
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.4,
              ),
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
    bool allowCustom = true,
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
              if (allowCustom)
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

          if (allowCustom)
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
      subtitle: '溫度與濕度為固定紀錄。飲食與大小便為固定六項，不可新增自訂；活動、放鬆與文字可依店家流程勾選或新增。',
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
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.thermostat_outlined),
                  title: const Text('室內溫度'),
                  value: _journalDisplay.showTemperature,
                  onChanged: (bool value) {
                    setState(() {
                      _journalDisplay = _journalDisplay.copyWith(
                        showTemperature: value,
                      );
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.water_drop_outlined),
                  title: const Text('室內濕度'),
                  value: _journalDisplay.showHumidity,
                  onChanged: (bool value) {
                    setState(() {
                      _journalDisplay = _journalDisplay.copyWith(
                        showHumidity: value,
                      );
                    });
                  },
                ),
              ],
            ),
          ),

          _buildFieldCategory(
            title: '飲食與飲水',
            category: 'food',
            icon: Icons.restaurant_outlined,
            allowCustom: false,
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
            allowCustom: false,
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

  Widget _buildDaycareCareCard() {
    return _SettingCard(
      title: '安親照護回報',
      subtitle: '開啟後，可在今日安親看板與安親訂單詳細填寫本次安親回報。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('啟用安親照護回報'),
            subtitle: const Text('開啟後，可在今日安親看板與安親訂單詳細填寫本次安親回報。'),
            value: _daycareEnabled,
            onChanged: (bool value) {
              setState(() {
                _daycareEnabled = value;
              });
            },
          ),
          if (_daycareEnabled) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              '每筆安親回報次數',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const <ButtonSegment<int>>[
                ButtonSegment<int>(value: 1, label: Text('1 次')),
                ButtonSegment<int>(value: 2, label: Text('2 次')),
                ButtonSegment<int>(value: 3, label: Text('3 次')),
              ],
              selected: <int>{_daycareSessionCount},
              onSelectionChanged: (Set<int> values) {
                if (values.isEmpty) {
                  return;
                }
                setState(() {
                  _daycareSessionCount = values.first;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              '回報名稱使用上方「照護紀錄名稱」的第 1～$_daycareSessionCount 個。',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
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
            '每房每天最多 6 張（不乘寵物數、不乘場次）。同房寵物共用額度。',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard() {
    return _SettingCard(
      title: '實際結束後下載期限',
      subtitle:
          '住宿以實際退房、安親以實際結束起算 24 小時。不從上傳或預定時間起算，補退款也不延長。檔案由後續排程清除，不保證第 24 小時整點已全部刪除。',
      child: const Text('固定保留 24 小時，此期限由平台統一，確認儲存時仍會一併寫入設定。'),
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

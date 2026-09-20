// 檔案名稱：lib/features/shop/pages/daily_care_setting_page.dart
// 功能說明：讓店主設定是否啟用每日照護紀錄、每天填寫次數
// 🐾 每日照護紀錄設定頁
// 要填寫的照護欄位、照片功能與退房後下載期限。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_journal_layout.dart';
import '../../../core/models/daily_care_offer_quota.dart';
import '../../../core/models/daily_care_paid_plan.dart';
import '../../../core/models/daily_care_report_mode.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/models/platform_media_asset.dart';
import '../../../core/services/daily_care_setting_service.dart';
import '../../../core/services/daycare_enabled.dart';
import '../../../core/services/shop_room_service.dart';
import '../../../core/services/shop_service.dart';
import '../../../core/widgets/daily_care_card_surface.dart';
import '../../../core/widgets/daily_care_illustrations.dart';
import '../../../core/widgets/platform_media_library_scope.dart';
import '../../../core/widgets/shop_task_center_button.dart';
import '../widgets/daily_care_full_journal_preview.dart';
import '../widgets/platform_media_asset_picker.dart';
import '../widgets/store/store_banner_color_field.dart';

class DailyCareSettingPage extends StatefulWidget {
  const DailyCareSettingPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<DailyCareSettingPage> createState() => _DailyCareSettingPageState();
}

class _DailyCareSettingPageState extends State<DailyCareSettingPage> {
  bool _loading = true;
  bool _saving = false;
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
  bool _previewPhotos = true;
  bool _previewSingleDay = false;
  bool _previewSingleSession = false;
  DailyCarePreviewPhoneSize _previewPhoneSize =
      DailyCarePreviewPhoneSize.standard;

  String _backgroundType = DailyCareJournalTheme.typeSystem;
  String _backgroundColorKey = DailyCareJournalTheme.colorDefault;
  String _backgroundImageUrl = '';
  String _backgroundImagePath = '';
  String _backgroundImageFit = DailyCareJournalTheme.fitCover;
  String _backgroundImageFade = DailyCareJournalTheme.fadeLight;

  String _pageBackgroundSource = DailyCareJournalTheme.pageSourceSystem;
  String _pageBackgroundAssetId = '';

  String _cardBackgroundType = DailyCareJournalTheme.cardTypeSolid;
  String _cardBackgroundPreset = DailyCareJournalTheme.cardPresetNone;
  String _cardBackgroundImageUrl = '';
  String _cardBackgroundImagePath = '';
  String _cardBackgroundImageFit = DailyCareJournalTheme.fitCover;
  String _cardBackgroundImageFade = DailyCareJournalTheme.fadeLight;
  String _cardDefaultSurfaceMode = DailyCareJournalCardStyle.surfaceSolid;
  String _cardDefaultBackgroundAssetId = '';
  DailyCareJournalDisplayFlags _journalDisplay =
      const DailyCareJournalDisplayFlags();
  Map<String, DailyCareJournalCardLayout> _journalCards =
      DailyCareJournalCardLayout.mapFrom(null);
  DailyCareJournalHeaderStyle _journalHeader =
      const DailyCareJournalHeaderStyle();
  String? _expandedJournalCardKey;

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

  static const List<_CareFieldOption> _fieldOptions = <_CareFieldOption>[
    _CareFieldOption(
      key: 'water',
      label: '飲水',
      icon: Icons.water_drop_outlined,
      inputType: DailyCareReportFormat.condition,
    ),
    _CareFieldOption(
      key: 'dryFood',
      label: '飼料',
      icon: Icons.restaurant_outlined,
      inputType: DailyCareReportFormat.condition,
    ),
    _CareFieldOption(
      key: 'wetFood',
      label: '罐頭',
      icon: Icons.soup_kitchen_outlined,
      inputType: DailyCareReportFormat.condition,
    ),
    _CareFieldOption(
      key: 'snack',
      label: '零食',
      icon: Icons.cookie_outlined,
      inputType: DailyCareReportFormat.condition,
    ),
    _CareFieldOption(
      key: 'stool',
      label: '大便',
      icon: Icons.check_circle_outline,
      inputType: DailyCareReportFormat.condition,
      fixed: true,
    ),
    _CareFieldOption(
      key: 'urine',
      label: '尿尿',
      icon: Icons.check_circle_outline,
      inputType: DailyCareReportFormat.condition,
      fixed: true,
    ),
    _CareFieldOption(
      key: 'wandToy',
      label: '逗貓棒',
      icon: Icons.sports_esports_outlined,
      inputType: DailyCareReportFormat.yesNo,
    ),
    _CareFieldOption(
      key: 'scratchBoard',
      label: '貓抓板',
      icon: Icons.texture,
      inputType: DailyCareReportFormat.yesNo,
    ),
    _CareFieldOption(
      key: 'jumpPlatform',
      label: '貓跳台',
      icon: Icons.stairs_outlined,
      inputType: DailyCareReportFormat.yesNo,
    ),
    _CareFieldOption(
      key: 'toyBall',
      label: '玩具球',
      icon: Icons.sports_soccer_outlined,
      inputType: DailyCareReportFormat.yesNo,
    ),
    _CareFieldOption(
      key: 'catHouse',
      label: '貓屋',
      icon: Icons.home_outlined,
      inputType: DailyCareReportFormat.yesNo,
    ),
    _CareFieldOption(
      key: 'catnip',
      label: '貓薄荷',
      icon: Icons.eco_outlined,
      inputType: DailyCareReportFormat.yesNo,
    ),
    _CareFieldOption(
      key: 'silverVine',
      label: '木天蓼',
      icon: Icons.local_florist_outlined,
      inputType: DailyCareReportFormat.yesNo,
    ),
    _CareFieldOption(
      key: 'catGrass',
      label: '貓草',
      icon: Icons.grass_outlined,
      inputType: DailyCareReportFormat.yesNo,
    ),
    _CareFieldOption(
      key: 'generalNote',
      label: '整房概況',
      icon: Icons.notes_outlined,
      inputType: DailyCareReportFormat.text,
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
        _pageBackgroundSource = setting.pageBackgroundSource.trim().isEmpty
            ? setting.resolvedPageBackgroundSource
            : setting.pageBackgroundSource;
        _pageBackgroundAssetId = setting.pageBackgroundAssetId;
        _cardBackgroundType = setting.cardBackgroundType;
        _cardBackgroundPreset = setting.cardBackgroundPreset;
        _cardBackgroundImageUrl = setting.cardBackgroundImageUrl;
        _cardBackgroundImagePath = setting.cardBackgroundImagePath;
        _cardBackgroundImageFit = setting.cardBackgroundImageFit;
        _cardBackgroundImageFade = setting.cardBackgroundImageFade;
        _cardDefaultSurfaceMode = setting.cardDefaultSurfaceMode.trim().isEmpty
            ? DailyCareJournalCardStyle.surfaceSolid
            : setting.cardDefaultSurfaceMode;
        _cardDefaultBackgroundAssetId = setting.cardDefaultBackgroundAssetId;
        _journalDisplay = setting.journalDisplay;
        _journalCards = setting.resolvedJournalCards;
        _journalHeader = setting.journalHeader;
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
      if (labels != null &&
          index < labels.length &&
          labels[index].trim().isNotEmpty) {
        _daycareLabelControllers[index].text = labels[index];
      } else if (_daycareLabelControllers[index].text.trim().isEmpty) {
        _daycareLabelControllers[index].text =
            defaults[index < defaults.length ? index : 0];
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('住宿第 ${index + 1} 場名稱不可空白')));
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

    String backgroundType = DailyCareJournalTheme.typeSystem;
    if (_pageBackgroundSource == DailyCareJournalTheme.pageSourceColor) {
      backgroundType = DailyCareJournalTheme.typeColor;
    } else if (_pageBackgroundSource ==
            DailyCareJournalTheme.pageSourceSystem &&
        _backgroundType == DailyCareJournalTheme.typeImage &&
        _pageBackgroundAssetId.isEmpty) {
      backgroundType = DailyCareJournalTheme.typeImage;
    }

    String cardBackgroundType = DailyCareJournalTheme.cardTypeSolid;
    if (_cardDefaultSurfaceMode == DailyCareJournalCardStyle.surfaceSolid &&
        _cardBackgroundType == DailyCareJournalTheme.cardTypePreset) {
      cardBackgroundType = DailyCareJournalTheme.cardTypePreset;
    }

    return DailyCareSettingModel(
      enabled: _enabled,
      sessionCount: _sessionCount,
      sessionLabels: sessionLabels,
      enabledFields: DailyCareReportFormat.persistableEnabledFields(
        _enabledFields,
      ),
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
      pageBackgroundSource: _pageBackgroundSource,
      pageBackgroundAssetId: _pageBackgroundAssetId,
      cardBackgroundType: cardBackgroundType,
      cardBackgroundPreset: _cardBackgroundPreset,
      cardBackgroundImageUrl: _cardBackgroundImageUrl,
      cardBackgroundImagePath: _cardBackgroundImagePath,
      cardBackgroundImageFit: _cardBackgroundImageFit,
      cardBackgroundImageFade: _cardBackgroundImageFade,
      cardDefaultSurfaceMode: _cardDefaultSurfaceMode,
      cardDefaultBackgroundAssetId: _cardDefaultBackgroundAssetId,
      journalDisplay: _journalDisplay.copyWith(
        showRoomOrOffer: true,
        showPetNames: true,
        showServiceDate: true,
        showFilledTime: true,
      ),
      journalCards: _journalCards,
      journalHeader: _journalHeader,
    );
  }

  DailyCareSettingModel _previewSetting() {
    return _draftSetting() ?? _loaded;
  }

  Future<void> _pickPageAsset() async {
    final PlatformMediaAsset? asset = await showPlatformMediaAssetPicker(
      context: context,
      category: PlatformMediaCategories.dailyCarePage,
      selectedId: _pageBackgroundAssetId,
    );
    if (asset == null) {
      return;
    }
    setState(() {
      _pageBackgroundSource = DailyCareJournalTheme.pageSourceLibrary;
      _pageBackgroundAssetId = asset.id;
      _backgroundType = DailyCareJournalTheme.typeSystem;
    });
  }

  Future<void> _pickDefaultCardAsset() async {
    final PlatformMediaAsset? asset = await showPlatformMediaAssetPicker(
      context: context,
      category: PlatformMediaCategories.dailyCareCard,
      selectedId: _cardDefaultBackgroundAssetId,
    );
    if (asset == null) {
      return;
    }
    setState(() {
      _cardDefaultSurfaceMode = DailyCareJournalCardStyle.surfaceLibrary;
      _cardDefaultBackgroundAssetId = asset.id;
      _cardBackgroundType = DailyCareJournalTheme.cardTypeSolid;
    });
  }

  Future<void> _pickCardIconFor(DailyCareJournalCardLayout item) async {
    final PlatformMediaAsset? asset = await showPlatformMediaAssetPicker(
      context: context,
      category: PlatformMediaCategories.dailyCareIcon,
      selectedId: item.iconAssetId,
    );
    if (asset == null) {
      return;
    }
    setState(() {
      _patchCard(item.copyWith(iconAssetId: asset.id));
    });
  }

  Future<void> _pickCardAssetFor(DailyCareJournalCardLayout item) async {
    final PlatformMediaAsset? asset = await showPlatformMediaAssetPicker(
      context: context,
      category: PlatformMediaCategories.dailyCareCard,
      selectedId: item.backgroundAssetId,
    );
    if (asset == null) {
      return;
    }
    setState(() {
      _patchCard(
        item.copyWith(
          surfaceMode: DailyCareJournalCardStyle.surfaceLibrary,
          backgroundAssetId: asset.id,
          backgroundSource: DailyCareJournalCardStyle.backgroundFollow,
        ),
      );
    });
  }

  Future<bool> _save({
    String successMessage = '每日照護紀錄設定已儲存',
    DailyCareSettingSection section = DailyCareSettingSection.all,
  }) async {
    if (_saving) return false;

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
            draft.sessionLabels.toString() !=
                _loaded.sessionLabels.toString() ||
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
                _loaded.customFields.map((e) => e.id).join();
      case DailyCareSettingSection.appearance:
        return draft.backgroundType != _loaded.backgroundType ||
            draft.pageBackgroundSource != _loaded.pageBackgroundSource ||
            draft.pageBackgroundAssetId != _loaded.pageBackgroundAssetId ||
            draft.cardDefaultSurfaceMode != _loaded.cardDefaultSurfaceMode ||
            draft.cardDefaultBackgroundAssetId !=
                _loaded.cardDefaultBackgroundAssetId ||
            draft.cardBackgroundType != _loaded.cardBackgroundType ||
            draft.logoVisible != _loaded.logoVisible ||
            draft.journalDisplay.toMap().toString() !=
                _loaded.journalDisplay.toMap().toString() ||
            DailyCareJournalCardLayout.mapToFirestore(
                  draft.resolvedJournalCards,
                ).toString() !=
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

  Widget _formatHint(String inputType) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE8EEF4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          DailyCareReportFormat.hintOf(inputType),
          style: const TextStyle(
            fontSize: 11,
            height: 1.3,
            color: Color(0xFF4A5B6B),
          ),
        ),
      ),
    );
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
      child: PlatformMediaLibraryScope(
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
                            onPressed: _saving
                                ? null
                                : () =>
                                      _save(section: _sectionForTab(_tabIndex)),
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
            final String shopName =
                (snap.data?['name'] ?? snap.data?['shopName'] ?? '')
                    .toString()
                    .trim();
            final String shopLogo = (snap.data?['logoUrl'] ?? '')
                .toString()
                .trim();
            return _desktopPreviewBody(shopName: shopName, shopLogo: shopLogo);
          },
    );
  }

  Widget _desktopPreviewBody({
    required String shopName,
    required String shopLogo,
  }) {
    final DailyCareSettingModel preview = _previewSetting();
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
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
              FilterChip(
                label: const Text('單日模式'),
                selected: _previewSingleDay,
                onSelected: (bool selected) {
                  setState(() {
                    _previewSingleDay = selected;
                  });
                },
              ),
              FilterChip(
                label: const Text('單場模式'),
                selected: _previewSingleSession,
                onSelected: (bool selected) {
                  setState(() {
                    _previewSingleSession = selected;
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
            ],
          ),
        ),
        Expanded(
          child: DailyCareFullJournalPreview(
            setting: preview,
            isDaycare: false,
            sessionLabels: const <String>[],
            sessionIndex: 0,
            showPhotos: _previewPhotos,
            usePhoneFrame: true,
            shopName: shopName,
            shopLogoUrl: shopLogo,
            phoneSize: _previewPhoneSize,
            singleDayMode: _previewSingleDay,
            singleSessionMode: _previewSingleSession,
          ),
        ),
      ],
    );
  }

  Future<void> _openMobilePreview() async {
    final DailyCareSettingModel preview = _previewSetting();
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(title: const Text('照護日誌預覽')),
            body: DailyCareFullJournalPreview(
              setting: preview,
              isDaycare: false,
              sessionLabels: const <String>[],
              sessionIndex: 0,
              showPhotos: _previewPhotos,
              usePhoneFrame: false,
              shopName: '',
              shopLogoUrl: '',
              singleDayMode: _previewSingleDay,
              singleSessionMode: _previewSingleSession,
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
          TextButton(
            onPressed: () {
              setState(() {
                _logoVisible = true;
                _cardRadius = 16;
                _cardPadding = 12;
                _cardGap = 12;
                _photoRadius = 10;
                _backgroundType = DailyCareJournalTheme.typeSystem;
                _pageBackgroundSource = DailyCareJournalTheme.pageSourceSystem;
                _pageBackgroundAssetId = '';
                _cardBackgroundType = DailyCareJournalTheme.cardTypeSolid;
                _cardBackgroundPreset = DailyCareJournalTheme.cardPresetNone;
                _cardDefaultSurfaceMode =
                    DailyCareJournalCardStyle.surfaceSolid;
                _cardDefaultBackgroundAssetId = '';
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
      subtitle: '店名固定顯示。Logo 顯示與否只由上方「顯示店家 LOGO」控制。',
      child: Column(
        children: <Widget>[
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '各卡片個別外觀',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          '點卡片展開設定。每張卡可跟隨預設，或改為單色、透明、霧化或套用圖庫。',
          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 10),
        for (int index = 0; index < rows.length; index++)
          _cardLayoutRow(rows[index], index, rows.length),
      ],
    );
  }

  void _patchCard(DailyCareJournalCardLayout item) {
    _journalCards = Map<String, DailyCareJournalCardLayout>.from(_journalCards)
      ..[item.key] = item;
  }

  Widget _cardLayoutRow(DailyCareJournalCardLayout item, int index, int total) {
    final bool pinned = item.isPinned;
    final bool expanded = _expandedJournalCardKey == item.key;
    final String bgLabel = DailyCareJournalCardStyle.surfaceLabel(
      item.resolvedSurfaceMode == DailyCareJournalCardStyle.backgroundPreset
          ? DailyCareJournalCardStyle.surfaceLibrary
          : item.surfaceMode.trim().isEmpty
          ? DailyCareJournalCardStyle.surfaceFollow
          : item.surfaceMode,
    );
    final String widthLabel = pinned || item.isHalf ? '半寬' : '滿寬';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: () {
              setState(() {
                _expandedJournalCardKey = expanded ? null : item.key;
              });
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${DailyCareJournalCardKeys.labelOf(item.key)}　｜　$widthLabel　｜　$bgLabel　｜　文字：${DailyCareJournalCardStyle.inkLabel(item.inkMode)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!pinned)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('顯示此卡'),
                      value: item.visible,
                      onChanged: (bool value) {
                        setState(() {
                          _patchCard(item.copyWith(visible: value));
                        });
                      },
                    )
                  else
                    const Text(
                      '固定卡片，不可隱藏。',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  if (!pinned)
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('滿寬'),
                          selected: !item.isHalf,
                          onSelected: (_) {
                            setState(() {
                              _patchCard(
                                item.copyWith(
                                  width: DailyCareJournalCardStyle.widthFull,
                                ),
                              );
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('半寬'),
                          selected: item.isHalf,
                          onSelected: (_) {
                            setState(() {
                              _patchCard(
                                item.copyWith(
                                  width: DailyCareJournalCardStyle.widthHalf,
                                ),
                              );
                            });
                          },
                        ),
                      ],
                    )
                  else
                    const Text(
                      '半寬固定',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  if (!pinned)
                    Row(
                      children: <Widget>[
                        const Text('排序', style: TextStyle(fontSize: 12)),
                        IconButton(
                          tooltip: '上移',
                          onPressed: index <= 2
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
                  const SizedBox(height: 6),
                  const Text(
                    '背景',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final String mode
                          in DailyCareJournalCardStyle.surfaceModes)
                        ChoiceChip(
                          label: Text(
                            DailyCareJournalCardStyle.surfaceLabel(mode),
                          ),
                          selected:
                              item.surfaceMode == mode ||
                              (mode ==
                                      DailyCareJournalCardStyle.surfaceFollow &&
                                  item.surfaceMode.trim().isEmpty &&
                                  item.followsSharedBackground),
                          onSelected: (_) {
                            setState(() {
                              _patchCard(
                                item.copyWith(
                                  surfaceMode: mode,
                                  backgroundSource: DailyCareJournalCardStyle
                                      .backgroundFollow,
                                  backgroundAssetId:
                                      mode ==
                                          DailyCareJournalCardStyle
                                              .surfaceLibrary
                                      ? item.backgroundAssetId
                                      : '',
                                ),
                              );
                            });
                            if (mode ==
                                DailyCareJournalCardStyle.surfaceLibrary) {
                              _pickCardAssetFor(item);
                            }
                          },
                        ),
                    ],
                  ),
                  if (item.surfaceMode ==
                      DailyCareJournalCardStyle.surfaceLibrary)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => _pickCardAssetFor(item),
                        icon: const Icon(Icons.collections_outlined),
                        label: Text(
                          item.backgroundAssetId.isEmpty
                              ? '選擇圖庫圖片'
                              : '已選圖庫（${item.backgroundAssetId}）',
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    '文字顏色',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      for (final String mode
                          in DailyCareJournalCardStyle.inkModes)
                        ChoiceChip(
                          label: Text(DailyCareJournalCardStyle.inkLabel(mode)),
                          selected: item.inkMode == mode,
                          onSelected: (_) {
                            setState(() {
                              _patchCard(item.copyWith(inkMode: mode));
                            });
                          },
                        ),
                    ],
                  ),
                  if (item.inkMode == DailyCareJournalCardStyle.inkCustom)
                    _cardInkColorRow(item),
                  const SizedBox(height: 8),
                  const Text(
                    '標題小圖示',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '未選擇時使用內建圖示。圖庫圖片失效時也會自動改回內建圖示。',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      DailyCareTitleIcon(
                        layout: item,
                        color: DailyCareInk.dark,
                        size: 28,
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickCardIconFor(item),
                        icon: const Icon(Icons.collections_outlined),
                        label: Text(
                          item.iconAssetId.isEmpty ? '從圖庫選擇' : '更換圖示',
                        ),
                      ),
                      if (item.iconAssetId.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _patchCard(item.copyWith(iconAssetId: ''));
                            });
                          },
                          child: const Text('使用預設圖示'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardInkColorRow(DailyCareJournalCardLayout item) {
    final int argb = item.inkColorArgb == 0
        ? DailyCareInk.dark.toARGB32()
        : item.inkColorArgb;
    const List<int> swatches = <int>[
      0xFF3A332C,
      0xFF2F5D50,
      0xFF3D6F9F,
      0xFFC47A4A,
      0xFFF6F0E6,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final int color in swatches)
            InkWell(
              onTap: () {
                setState(() {
                  _patchCard(item.copyWith(inkColorArgb: color));
                });
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Color(color),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: argb == color ? Colors.black87 : Colors.black26,
                    width: argb == color ? 2 : 1,
                  ),
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () async {
              final int? next = await showStoreBannerColorPicker(
                context,
                initial: Color(argb),
              );
              if (next == null || !mounted) {
                return;
              }
              setState(() {
                _patchCard(item.copyWith(inkColorArgb: next));
              });
            },
            icon: const Icon(Icons.palette_outlined, size: 18),
            label: const Text('色盤'),
          ),
          SizedBox(
            width: 108,
            child: TextFormField(
              key: ValueKey<int>(argb),
              initialValue:
                  '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
              decoration: const InputDecoration(
                isDense: true,
                labelText: '#RRGGBB',
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (String raw) {
                final int? parsed = _parseRgbHex(raw);
                if (parsed == null) {
                  return;
                }
                setState(() {
                  _patchCard(item.copyWith(inkColorArgb: parsed));
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  int? _parseRgbHex(String raw) {
    final String hex = raw.trim().replaceFirst('#', '');
    if (hex.length != 6) {
      return null;
    }
    final int? rgb = int.tryParse(hex, radix: 16);
    if (rgb == null) {
      return null;
    }
    return 0xFF000000 | rgb;
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
    if (a.isPinned || b.isPinned) {
      return;
    }
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
            ..selection = TextSelection.collapsed(
              offset: plan.description.length,
            ),
          decoration: const InputDecoration(labelText: '方案說明'),
          maxLines: 2,
          onChanged: (String value) {
            setState(() {
              if (daycare) {
                _daycarePaidPlan = _daycarePaidPlan.copyWith(
                  description: value,
                );
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
            ..selection = TextSelection.collapsed(
              offset: '${plan.price}'.length,
            ),
          decoration: InputDecoration(labelText: daycare ? '每筆價格' : '價格'),
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
          decoration: InputDecoration(labelText: daycare ? '每筆回報幾場' : '每日回報幾場'),
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
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> snap,
          ) {
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
                final String id = (type['id'] ?? type['roomTypeId'] ?? '')
                    .toString();
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
                              text:
                                  quota != null &&
                                      index < quota.sessionLabels.length
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
                              builder:
                                  (BuildContext context, StateSetter setLocal) {
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
            child: Text('每筆安親服務於服務當日提供回報。', style: TextStyle(height: 1.4)),
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
          if (_daycareReportMode ==
              DailyCareReportMode.includedFixed) ...<Widget>[
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
    final bool legacyPageImage =
        _pageBackgroundSource != DailyCareJournalTheme.pageSourceLibrary &&
        _backgroundType == DailyCareJournalTheme.typeImage &&
        _backgroundImageUrl.trim().isNotEmpty;
    final bool showPageImageOptions =
        _pageBackgroundSource == DailyCareJournalTheme.pageSourceLibrary ||
        legacyPageImage;
    final bool showCardImageOptions =
        _cardDefaultSurfaceMode == DailyCareJournalCardStyle.surfaceLibrary;

    return _SettingCard(
      title: '日誌外觀設定',
      subtitle: '整頁、卡片預設與單卡外觀分開設定。背景圖只能從平台圖庫套用。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '整頁背景',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            '選項：系統預設、內建單色、套用圖庫。',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _appearanceChoice(
                selected:
                    _pageBackgroundSource ==
                    DailyCareJournalTheme.pageSourceSystem,
                label: '系統預設',
                color: const Color(0xFFF5F6F8),
                onTap: () {
                  setState(() {
                    _pageBackgroundSource =
                        DailyCareJournalTheme.pageSourceSystem;
                    _backgroundType = DailyCareJournalTheme.typeSystem;
                    _pageBackgroundAssetId = '';
                  });
                },
              ),
              _appearanceChoice(
                selected:
                    _pageBackgroundSource ==
                        DailyCareJournalTheme.pageSourceColor &&
                    _backgroundColorKey == DailyCareJournalTheme.colorWarm,
                label: '暖米色',
                color: const Color(0xFFF6EFE4),
                onTap: () {
                  setState(() {
                    _pageBackgroundSource =
                        DailyCareJournalTheme.pageSourceColor;
                    _backgroundType = DailyCareJournalTheme.typeColor;
                    _backgroundColorKey = DailyCareJournalTheme.colorWarm;
                  });
                },
              ),
              _appearanceChoice(
                selected:
                    _pageBackgroundSource ==
                        DailyCareJournalTheme.pageSourceColor &&
                    _backgroundColorKey == DailyCareJournalTheme.colorBlue,
                label: '淡藍色',
                color: const Color(0xFFE8F1F8),
                onTap: () {
                  setState(() {
                    _pageBackgroundSource =
                        DailyCareJournalTheme.pageSourceColor;
                    _backgroundType = DailyCareJournalTheme.typeColor;
                    _backgroundColorKey = DailyCareJournalTheme.colorBlue;
                  });
                },
              ),
              _appearanceChoice(
                selected:
                    _pageBackgroundSource ==
                        DailyCareJournalTheme.pageSourceColor &&
                    _backgroundColorKey == DailyCareJournalTheme.colorPink,
                label: '淡粉色',
                color: const Color(0xFFF8E9EE),
                onTap: () {
                  setState(() {
                    _pageBackgroundSource =
                        DailyCareJournalTheme.pageSourceColor;
                    _backgroundType = DailyCareJournalTheme.typeColor;
                    _backgroundColorKey = DailyCareJournalTheme.colorPink;
                  });
                },
              ),
              _appearanceChoice(
                selected:
                    _pageBackgroundSource ==
                        DailyCareJournalTheme.pageSourceColor &&
                    _backgroundColorKey == DailyCareJournalTheme.colorGreen,
                label: '淡綠色',
                color: const Color(0xFFE8F3EA),
                onTap: () {
                  setState(() {
                    _pageBackgroundSource =
                        DailyCareJournalTheme.pageSourceColor;
                    _backgroundType = DailyCareJournalTheme.typeColor;
                    _backgroundColorKey = DailyCareJournalTheme.colorGreen;
                  });
                },
              ),
              _appearanceChoice(
                selected:
                    _pageBackgroundSource ==
                    DailyCareJournalTheme.pageSourceLibrary,
                label: '套用圖庫',
                color: const Color(0xFFEDE7F6),
                onTap: () {
                  setState(() {
                    _pageBackgroundSource =
                        DailyCareJournalTheme.pageSourceLibrary;
                    _backgroundType = DailyCareJournalTheme.typeSystem;
                  });
                  _pickPageAsset();
                },
              ),
            ],
          ),
          if (legacyPageImage)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '目前仍使用舊版店家背景圖。選擇上方選項後，會改用系統預設、單色或平台圖庫。',
                style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
              ),
            ),
          if (showPageImageOptions) ...<Widget>[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickPageAsset,
              icon: const Icon(Icons.collections_outlined),
              label: Text(
                _pageBackgroundAssetId.isEmpty ? '選擇圖庫圖片' : '重新選擇圖庫圖片',
              ),
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
            '卡片預設外觀',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            '所有照護內容卡的預設背景。單色使用現有色卡。',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String mode in <String>[
                DailyCareJournalCardStyle.surfaceSolid,
                DailyCareJournalCardStyle.surfaceTransparent,
                DailyCareJournalCardStyle.surfaceFrosted,
                DailyCareJournalCardStyle.surfaceLibrary,
              ])
                ChoiceChip(
                  label: Text(DailyCareJournalCardStyle.surfaceLabel(mode)),
                  selected: _cardDefaultSurfaceMode == mode,
                  onSelected: (_) {
                    setState(() {
                      _cardDefaultSurfaceMode = mode;
                      if (mode != DailyCareJournalCardStyle.surfaceLibrary) {
                        _cardBackgroundType =
                            DailyCareJournalTheme.cardTypeSolid;
                      }
                    });
                    if (mode == DailyCareJournalCardStyle.surfaceLibrary) {
                      _pickDefaultCardAsset();
                    }
                  },
                ),
            ],
          ),
          if (showCardImageOptions) ...<Widget>[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickDefaultCardAsset,
              icon: const Icon(Icons.collections_outlined),
              label: Text(
                _cardDefaultBackgroundAssetId.isEmpty
                    ? '選擇卡片圖庫圖片'
                    : '重新選擇卡片圖庫圖片',
              ),
            ),
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
          const SizedBox(height: 16),
          _headerAppearanceCard(preview),
          const SizedBox(height: 16),
          _cardLayoutEditorCard(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _headerAppearanceCard(DailyCareSettingModel preview) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7D7C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '頁首卡片外觀',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            '套用到日期選擇、場次選擇與房間基本資訊。與照護內容分類卡分開設定。',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text('文字顏色', style: TextStyle(fontWeight: FontWeight.w700)),
          RadioGroup<String>(
            groupValue: _journalHeader.inkMode,
            onChanged: (String? value) {
              if (value == null) return;
              setState(() {
                _journalHeader = _journalHeader.copyWith(inkMode: value);
              });
            },
            child: const Column(
              children: <Widget>[
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: DailyCareJournalCardStyle.inkAuto,
                  title: Text('自動'),
                ),
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: DailyCareJournalCardStyle.inkDark,
                  title: Text('深色'),
                ),
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: DailyCareJournalCardStyle.inkLight,
                  title: Text('淺色'),
                ),
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: DailyCareJournalCardStyle.inkCustom,
                  title: Text('自訂顏色'),
                ),
              ],
            ),
          ),
          if (_journalHeader.inkMode == DailyCareJournalCardStyle.inkCustom)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  for (final int color in const <int>[
                    0xFF3A332C,
                    0xFF2F5D50,
                    0xFF3D6F9F,
                    0xFFC47A4A,
                    0xFFF6F0E6,
                  ])
                    InkWell(
                      onTap: () {
                        setState(() {
                          _journalHeader = _journalHeader.copyWith(
                            inkColorArgb: color,
                          );
                        });
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(color),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _journalHeader.inkColorArgb == color
                                ? Colors.black87
                                : Colors.black26,
                            width: _journalHeader.inkColorArgb == color ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final int argb = _journalHeader.inkColorArgb == 0
                          ? DailyCareInk.dark.toARGB32()
                          : _journalHeader.inkColorArgb;
                      final int? next = await showStoreBannerColorPicker(
                        context,
                        initial: Color(argb),
                      );
                      if (next == null || !mounted) {
                        return;
                      }
                      setState(() {
                        _journalHeader = _journalHeader.copyWith(
                          inkColorArgb: next,
                        );
                      });
                    },
                    icon: const Icon(Icons.palette_outlined, size: 18),
                    label: const Text('色盤'),
                  ),
                ],
              ),
            ),
          const Text('卡片顯示', style: TextStyle(fontWeight: FontWeight.w700)),
          RadioGroup<bool>(
            groupValue: _journalHeader.useCardBackground,
            onChanged: (bool? value) {
              if (value == null) return;
              setState(() {
                _journalHeader = _journalHeader.copyWith(
                  useCardBackground: value,
                );
              });
            },
            child: const Column(
              children: <Widget>[
                RadioListTile<bool>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: false,
                  title: Text('純色卡片'),
                ),
                RadioListTile<bool>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  title: Text('使用目前選擇的卡片背景圖片'),
                ),
              ],
            ),
          ),
          Text(
            preview.journalHeader.useCardBackground
                ? '頁首卡會套用目前內容卡片的圖片、填滿／完整顯示與淡化程度。'
                : '頁首卡維持原本淺奶油底與深色文字，舊店家外觀不變。',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
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
            option.fixed
                ? ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(option.icon, size: 20),
                    title: Text(option.label),
                    subtitle: _formatHint(option.inputType),
                  )
                : CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    secondary: Icon(option.icon, size: 20),
                    title: Text(option.label),
                    subtitle: _formatHint(option.inputType),
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
                subtitle: _formatHint(field.inputType),
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
      subtitle: '環境狀況的溫度與濕度、大小便狀況的大便與尿尿為固定紀錄，不可關閉。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '環境狀況',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.thermostat_outlined),
                  title: Text('室內溫度'),
                ),
                _formatHint(DailyCareReportFormat.temperature),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.water_drop_outlined),
                  title: Text('室內濕度'),
                ),
                _formatHint(DailyCareReportFormat.humidity),
                const SizedBox(height: 8),
                const Text(
                  '溫度與濕度固定存在於環境狀況，不可關閉。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
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
    required this.inputType,
    this.fixed = false,
  });

  final String key;
  final String label;
  final IconData icon;
  final String inputType;
  final bool fixed;
}

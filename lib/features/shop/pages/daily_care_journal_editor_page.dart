// 檔案名稱：lib/features/shop/pages/daily_care_journal_editor_page.dart
// 功能說明：日誌外觀全螢幕編輯：本機草稿預覽，確認後才上傳與儲存。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/services/daily_care_background_service.dart';
import '../../../core/services/daily_care_setting_service.dart';
import '../widgets/daily_care_journal_demo_preview.dart';

class DailyCareJournalEditorPage extends StatefulWidget {
  const DailyCareJournalEditorPage({
    super.key,
    required this.shopId,
    required this.initial,
  });

  final String shopId;
  final DailyCareSettingModel initial;

  @override
  State<DailyCareJournalEditorPage> createState() =>
      _DailyCareJournalEditorPageState();
}

class _DailyCareJournalEditorPageState
    extends State<DailyCareJournalEditorPage> {
  late DailyCareSettingModel _saved;
  late DailyCareSettingModel _draft;
  Uint8List? _pageBytes;
  Uint8List? _cardBytes;
  bool _removePageImage = false;
  bool _removeCardImage = false;
  bool _saving = false;
  bool _mobilePreview = false;
  final ImagePicker _picker = ImagePicker();

  bool get _dirty {
    return _draft.toMap().toString() != _saved.toMap().toString() ||
        _pageBytes != null ||
        _cardBytes != null ||
        _removePageImage ||
        _removeCardImage;
  }

  @override
  void initState() {
    super.initState();
    _saved = widget.initial;
    _draft = widget.initial;
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) {
      return true;
    }
    final bool? stay = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('尚未儲存'),
          content: const Text('外觀變更尚未確認儲存，要放棄變更嗎？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('繼續編輯'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放棄變更'),
            ),
          ],
        );
      },
    );
    return stay == true;
  }

  Future<void> _pick({required bool page}) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );
    if (file == null) {
      return;
    }
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > DailyCareBackgroundService.maxImageBytes) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('圖片不可超過 5 MB')));
      return;
    }
    setState(() {
      if (page) {
        _pageBytes = bytes;
        _removePageImage = false;
        _draft = _draft.copyWith(
          backgroundType: DailyCareJournalTheme.typeImage,
        );
      } else {
        _cardBytes = bytes;
        _removeCardImage = false;
        _draft = _draft.copyWith(
          cardBackgroundType: DailyCareJournalTheme.cardTypeImage,
        );
      }
    });
  }

  Future<void> _save() async {
    if (_saving || !_dirty) {
      return;
    }
    setState(() {
      _saving = true;
    });
    String? newPagePath;
    String? newCardPath;
    try {
      DailyCareSettingModel next = _draft;
      if (_pageBytes != null) {
        final uploaded = await DailyCareBackgroundService.instance.uploadBytes(
          shopId: widget.shopId,
          bytes: _pageBytes!,
          contentType: 'image/jpeg',
        );
        newPagePath = uploaded.storagePath;
        next = next.copyWith(
          backgroundType: DailyCareJournalTheme.typeImage,
          backgroundImageUrl: uploaded.downloadUrl,
          backgroundImagePath: uploaded.storagePath,
        );
      } else if (_removePageImage) {
        next = next.copyWith(
          backgroundType: next.backgroundType == DailyCareJournalTheme.typeImage
              ? DailyCareJournalTheme.typeSystem
              : next.backgroundType,
          backgroundImageUrl: '',
          backgroundImagePath: '',
        );
      }
      if (_cardBytes != null) {
        final uploaded = await DailyCareBackgroundService.instance.uploadBytes(
          shopId: widget.shopId,
          bytes: _cardBytes!,
          contentType: 'image/jpeg',
          folder: DailyCareBackgroundService.cardFolderPath,
          filePrefix: 'card_',
        );
        newCardPath = uploaded.storagePath;
        next = next.copyWith(
          cardBackgroundType: DailyCareJournalTheme.cardTypeImage,
          cardBackgroundImageUrl: uploaded.downloadUrl,
          cardBackgroundImagePath: uploaded.storagePath,
        );
      } else if (_removeCardImage) {
        next = next.copyWith(
          cardBackgroundType:
              next.cardBackgroundPreset == DailyCareJournalTheme.cardPresetNone
              ? DailyCareJournalTheme.cardTypeSolid
              : DailyCareJournalTheme.cardTypePreset,
          cardBackgroundImageUrl: '',
          cardBackgroundImagePath: '',
        );
      }
      await DailyCareSettingService.instance.saveSetting(
        shopId: widget.shopId,
        setting: next,
        expectedRevision: _saved.revision,
      );
      final DailyCareSettingModel stored = await DailyCareSettingService
          .instance
          .getSetting(widget.shopId);
      if (_saved.backgroundImagePath.isNotEmpty &&
          stored.backgroundImagePath != _saved.backgroundImagePath) {
        await DailyCareBackgroundService.instance.deleteStoredFile(
          storagePath: _saved.backgroundImagePath,
        );
      }
      if (_saved.cardBackgroundImagePath.isNotEmpty &&
          stored.cardBackgroundImagePath != _saved.cardBackgroundImagePath) {
        await DailyCareBackgroundService.instance.deleteStoredFile(
          storagePath: _saved.cardBackgroundImagePath,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _saved = stored;
        _draft = stored;
        _pageBytes = null;
        _cardBytes = null;
        _removePageImage = false;
        _removeCardImage = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日誌外觀已儲存')));
    } catch (error) {
      if (newPagePath != null) {
        await DailyCareBackgroundService.instance.deleteStoredFile(
          storagePath: newPagePath,
        );
      }
      if (newCardPath != null) {
        await DailyCareBackgroundService.instance.deleteStoredFile(
          storagePath: newCardPath,
        );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗，原設定未變更：$error')));
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
    final bool wide = MediaQuery.sizeOf(context).width >= 900;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        if (await _confirmLeave() && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_dirty ? '日誌外觀（未儲存）' : '日誌外觀'),
          actions: <Widget>[
            if (!wide)
              TextButton(
                onPressed: () {
                  setState(() {
                    _mobilePreview = !_mobilePreview;
                  });
                },
                child: Text(_mobilePreview ? '關閉預覽' : '預覽'),
              ),
            FilledButton(
              onPressed: _saving || !_dirty ? null : _save,
              child: Text(_saving ? '儲存中...' : '確認儲存'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: wide
            ? Row(
                children: <Widget>[
                  Expanded(child: _previewPane()),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 420, child: _settingsPane()),
                ],
              )
            : (_mobilePreview ? _previewPane() : _settingsPane()),
      ),
    );
  }

  Widget _previewPane() {
    return ColoredBox(
      color: const Color(0xFFEEF1F4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DailyCareJournalDemoPreview(
              setting: _draft,
              pageImage: _pageBytes == null ? null : MemoryImage(_pageBytes!),
              cardImage: _cardBytes == null ? null : MemoryImage(_cardBytes!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsPane() {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: <Widget>[
        const Text('日誌背景', style: TextStyle(fontWeight: FontWeight.w800)),
        Wrap(
          spacing: 8,
          children: <Widget>[
            _chip('系統預設', DailyCareJournalTheme.typeSystem, true),
            _chip('暖米色', DailyCareJournalTheme.typeColor, false, colorKey: DailyCareJournalTheme.colorWarm),
            _chip('淡藍', DailyCareJournalTheme.typeColor, false, colorKey: DailyCareJournalTheme.colorBlue),
            _chip('淡粉', DailyCareJournalTheme.typeColor, false, colorKey: DailyCareJournalTheme.colorPink),
            _chip('淡綠', DailyCareJournalTheme.typeColor, false, colorKey: DailyCareJournalTheme.colorGreen),
            _chip('自訂圖片', DailyCareJournalTheme.typeImage, false),
          ],
        ),
        if (_draft.backgroundType == DailyCareJournalTheme.typeImage) ...<Widget>[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _pick(page: true),
            icon: const Icon(Icons.upload_outlined),
            label: Text(_pageBytes != null || _draft.backgroundImageUrl.isNotEmpty
                ? '更換背景圖片'
                : '選擇背景圖片'),
          ),
          if (_draft.backgroundImageUrl.isNotEmpty || _pageBytes != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _pageBytes = null;
                  _removePageImage = true;
                  _draft = _draft.copyWith(
                    backgroundType: DailyCareJournalTheme.typeSystem,
                    backgroundImageUrl: '',
                    backgroundImagePath: '',
                  );
                });
              },
              child: const Text('移除背景圖片'),
            ),
          _fitFade(
            fit: _draft.backgroundImageFit,
            fade: _draft.backgroundImageFade,
            onFit: (String value) {
              setState(() {
                _draft = _draft.copyWith(backgroundImageFit: value);
              });
            },
            onFade: (String value) {
              setState(() {
                _draft = _draft.copyWith(backgroundImageFade: value);
              });
            },
          ),
        ],
        const SizedBox(height: 16),
        const Text('內容卡片背景', style: TextStyle(fontWeight: FontWeight.w800)),
        RadioListTile<String>(
          value: DailyCareJournalTheme.cardTypeSolid,
          groupValue: _draft.cardBackgroundType,
          title: const Text('純色卡片'),
          onChanged: (String? value) {
            if (value == null) {
              return;
            }
            setState(() {
              _draft = _draft.copyWith(cardBackgroundType: value);
            });
          },
        ),
        RadioListTile<String>(
          value: DailyCareJournalTheme.cardTypePreset,
          groupValue:
              _draft.cardBackgroundType == DailyCareJournalTheme.cardTypeImage
              ? DailyCareJournalTheme.cardTypePreset
              : _draft.cardBackgroundType,
          title: const Text('使用圖片'),
          onChanged: (String? value) {
            setState(() {
              _draft = _draft.copyWith(
                cardBackgroundType: DailyCareJournalTheme.cardTypePreset,
                cardBackgroundPreset:
                    _draft.cardBackgroundPreset ==
                        DailyCareJournalTheme.cardPresetNone
                    ? DailyCareJournalTheme.cardPresetPaw
                    : _draft.cardBackgroundPreset,
              );
            });
          },
        ),
        if (_draft.cardBackgroundType !=
            DailyCareJournalTheme.cardTypeSolid) ...<Widget>[
          Wrap(
            spacing: 8,
            children: DailyCareJournalTheme.cardPresets.map((preset) {
              return ChoiceChip(
                label: Text(preset.label),
                selected:
                    _draft.cardBackgroundType ==
                        DailyCareJournalTheme.cardTypePreset &&
                    _draft.cardBackgroundPreset == preset.key,
                onSelected: (_) {
                  setState(() {
                    _draft = _draft.copyWith(
                      cardBackgroundType: DailyCareJournalTheme.cardTypePreset,
                      cardBackgroundPreset: preset.key,
                    );
                  });
                },
              );
            }).toList(),
          ),
          FilledButton.icon(
            onPressed: () => _pick(page: false),
            icon: const Icon(Icons.upload_outlined),
            label: const Text('上傳自己的卡片背景'),
          ),
          _fitFade(
            fit: _draft.cardBackgroundImageFit,
            fade: _draft.cardBackgroundImageFade,
            onFit: (String value) {
              setState(() {
                _draft = _draft.copyWith(cardBackgroundImageFit: value);
              });
            },
            onFade: (String value) {
              setState(() {
                _draft = _draft.copyWith(cardBackgroundImageFade: value);
              });
            },
            fitCoverLabel: '填滿卡片',
          ),
        ],
      ],
    );
  }

  Widget _chip(
    String label,
    String type,
    bool system, {
    String? colorKey,
  }) {
    final bool selected = system
        ? _draft.backgroundType == DailyCareJournalTheme.typeSystem
        : type == DailyCareJournalTheme.typeImage
        ? _draft.backgroundType == DailyCareJournalTheme.typeImage
        : _draft.backgroundType == DailyCareJournalTheme.typeColor &&
              _draft.backgroundColorKey == colorKey;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _draft = _draft.copyWith(
            backgroundType: type,
            backgroundColorKey: colorKey ?? _draft.backgroundColorKey,
          );
        });
      },
    );
  }

  Widget _fitFade({
    required String fit,
    required String fade,
    required ValueChanged<String> onFit,
    required ValueChanged<String> onFade,
    String fitCoverLabel = '填滿畫面',
  }) {
    return Column(
      children: <Widget>[
        RadioListTile<String>(
          value: DailyCareJournalTheme.fitCover,
          groupValue: fit,
          title: Text(fitCoverLabel),
          onChanged: (String? value) {
            if (value != null) {
              onFit(value);
            }
          },
        ),
        RadioListTile<String>(
          value: DailyCareJournalTheme.fitContain,
          groupValue: fit,
          title: const Text('完整顯示'),
          onChanged: (String? value) {
            if (value != null) {
              onFit(value);
            }
          },
        ),
        RadioListTile<String>(
          value: DailyCareJournalTheme.fadeNone,
          groupValue: fade,
          title: const Text('原圖'),
          onChanged: (String? value) {
            if (value != null) {
              onFade(value);
            }
          },
        ),
        RadioListTile<String>(
          value: DailyCareJournalTheme.fadeLight,
          groupValue: fade,
          title: const Text('淡化'),
          onChanged: (String? value) {
            if (value != null) {
              onFade(value);
            }
          },
        ),
        RadioListTile<String>(
          value: DailyCareJournalTheme.fadeHeavy,
          groupValue: fade,
          title: const Text('很淡'),
          onChanged: (String? value) {
            if (value != null) {
              onFade(value);
            }
          },
        ),
      ],
    );
  }
}

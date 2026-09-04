// lib/features/shop/pages/shop_pre_arrival_guide_setting_page.dart
// 店家後台：入住前準備圖文設定（住宿／安親），不是條款。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/core/services/pre_arrival_guide_service.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/booking/pages/pre_arrival_guide_page.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';

class ShopPreArrivalGuideSettingPage extends StatefulWidget {
  const ShopPreArrivalGuideSettingPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopPreArrivalGuideSettingPage> createState() =>
      _ShopPreArrivalGuideSettingPageState();
}

class _ShopPreArrivalGuideSettingPageState
    extends State<ShopPreArrivalGuideSettingPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  PreArrivalGuideModel? _accommodation;
  PreArrivalGuideModel? _daycare;
  PreArrivalGuideModel? _savedAccommodation;
  PreArrivalGuideModel? _savedDaycare;
  bool _loading = true;
  bool _saving = false;
  final Set<String> _sessionUploads = <String>{};
  final Set<String> _pendingDeletes = <String>{};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _cleanupOrphans();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cleanupOrphans() async {
    final Set<String> savedPaths = <String>{
      ..._pathsOf(_savedAccommodation),
      ..._pathsOf(_savedDaycare),
    };
    for (final String path in _sessionUploads) {
      if (!savedPaths.contains(path)) {
        await PreArrivalGuideService.instance.deleteImage(storagePath: path);
      }
    }
  }

  Set<String> _pathsOf(PreArrivalGuideModel? guide) {
    if (guide == null) {
      return <String>{};
    }
    return guide.blocks
        .map((PreArrivalGuideBlock b) => b.storagePath)
        .where((String p) => p.isNotEmpty)
        .toSet();
  }

  bool get _dirty {
    return _encode(_accommodation) != _encode(_savedAccommodation) ||
        _encode(_daycare) != _encode(_savedDaycare);
  }

  String _encode(PreArrivalGuideModel? guide) {
    if (guide == null) {
      return '';
    }
    return '${guide.enabled}|${guide.title}|${guide.inheritAccommodation}|${guide.blocks.map((PreArrivalGuideBlock b) => '${b.id}:${b.type}:${b.text}:${b.imageUrl}:${b.caption}').join(';')}';
  }

  Future<void> _load() async {
    final PreArrivalGuideModel acc = await PreArrivalGuideService.instance
        .getGuide(
          shopId: widget.shopId,
          serviceType: PreArrivalGuideServiceType.accommodation,
        );
    final PreArrivalGuideModel day = await PreArrivalGuideService.instance
        .getGuide(
          shopId: widget.shopId,
          serviceType: PreArrivalGuideServiceType.daycare,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _accommodation = acc;
      _daycare = day;
      _savedAccommodation = acc;
      _savedDaycare = day;
      _loading = false;
    });
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) {
      return true;
    }
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('尚未儲存'),
          content: const Text('離開此頁面將放棄未儲存的修改。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('繼續編輯'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('離開'),
            ),
          ],
        );
      },
    );
    return leave == true;
  }

  Future<void> _save() async {
    if (_accommodation == null || _daycare == null) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await PreArrivalGuideService.instance.saveGuide(_accommodation!);
      await PreArrivalGuideService.instance.saveGuide(_daycare!);
      for (final String path in _pendingDeletes) {
        await PreArrivalGuideService.instance.deleteImage(storagePath: path);
      }
      _pendingDeletes.clear();
      _sessionUploads.clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAccommodation = _accommodation;
        _savedDaycare = _daycare;
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存入住前準備')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShopFrontendThemeScope(
      shopId: widget.shopId,
      builder: (BuildContext context) {
        return PopScope(
          canPop: !_dirty,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            if (didPop) {
              return;
            }
            final bool leave = await _confirmLeave();
            if (!context.mounted) {
              return;
            }
            if (leave) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            backgroundColor: BookingDetailUi.of(context).background,
            appBar: AppBar(
              title: const Text('入住前準備'),
              backgroundColor: BookingDetailUi.of(context).background,
              bottom: TabBar(
                controller: _tabs,
                tabs: const <Widget>[
                  Tab(text: '住宿'),
                  Tab(text: '安親'),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '儲存中' : '儲存'),
                ),
              ],
            ),
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: <Widget>[
                      _editor(isDaycare: false),
                      _editor(isDaycare: true),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _editor({required bool isDaycare}) {
    final PreArrivalGuideModel guide = isDaycare ? _daycare! : _accommodation!;
    final bool inherit = isDaycare && guide.inheritAccommodation;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SwitchListTile(
          title: const Text('啟用入住前準備'),
          value: guide.enabled,
          onChanged: (bool value) {
            setState(() {
              if (isDaycare) {
                _daycare = guide.copyWith(enabled: value);
              } else {
                _accommodation = guide.copyWith(enabled: value);
              }
            });
          },
        ),
        if (isDaycare)
          SwitchListTile(
            title: const Text('沿用住宿內容'),
            subtitle: const Text('開啟後，客戶安親訂單會顯示住宿的入住前準備'),
            value: guide.inheritAccommodation,
            onChanged: (bool value) {
              setState(() {
                _daycare = guide.copyWith(inheritAccommodation: value);
              });
            },
          ),
        TextFormField(
          initialValue: guide.title,
          decoration: const InputDecoration(labelText: '標題'),
          enabled: !inherit,
          onChanged: (String value) {
            setState(() {
              if (isDaycare) {
                _daycare = guide.copyWith(title: value);
              } else {
                _accommodation = guide.copyWith(title: value);
              }
            });
          },
        ),
        const SizedBox(height: 12),
        if (!inherit) ...<Widget>[
          Wrap(
            spacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed: () =>
                    _addBlock(isDaycare, PreArrivalGuideBlockType.heading),
                child: const Text('新增標題'),
              ),
              OutlinedButton(
                onPressed: () =>
                    _addBlock(isDaycare, PreArrivalGuideBlockType.text),
                child: const Text('新增文字'),
              ),
              OutlinedButton(
                onPressed: () => _addImage(isDaycare),
                child: const Text('上傳圖片'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < guide.blocks.length; i++)
            _blockEditor(
              isDaycare: isDaycare,
              index: i,
              block: guide.blocks[i],
            ),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            final PreArrivalGuideModel preview = inherit
                ? _accommodation!
                : guide;
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PreArrivalGuidePage(guide: preview),
              ),
            );
          },
          child: const Text('客戶畫面預覽'),
        ),
      ],
    );
  }

  Widget _blockEditor({
    required bool isDaycare,
    required int index,
    required PreArrivalGuideBlock block,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  block.type == PreArrivalGuideBlockType.heading
                      ? '標題'
                      : block.type == PreArrivalGuideBlockType.image
                      ? '圖片'
                      : '文字',
                ),
                const Spacer(),
                IconButton(
                  onPressed: index == 0
                      ? null
                      : () => _move(isDaycare, index, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  onPressed: () => _move(isDaycare, index, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  onPressed: () => _removeBlock(isDaycare, index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (block.type != PreArrivalGuideBlockType.image)
              TextFormField(
                initialValue: block.text,
                maxLines: block.type == PreArrivalGuideBlockType.heading
                    ? 1
                    : 4,
                decoration: const InputDecoration(labelText: '內容'),
                onChanged: (String value) {
                  _updateBlock(isDaycare, index, block.copyWith(text: value));
                },
              )
            else ...<Widget>[
              if (block.imageUrl.isNotEmpty)
                Image.network(
                  block.imageUrl,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? stack) {
                        return const SizedBox(
                          height: 80,
                          child: Center(child: Text('圖片載入失敗')),
                        );
                      },
                ),
              TextFormField(
                initialValue: block.caption,
                decoration: const InputDecoration(labelText: '圖片說明（可空白）'),
                onChanged: (String value) {
                  _updateBlock(
                    isDaycare,
                    index,
                    block.copyWith(caption: value),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _addBlock(bool isDaycare, String type) {
    final PreArrivalGuideModel guide = isDaycare ? _daycare! : _accommodation!;
    final List<PreArrivalGuideBlock> blocks =
        List<PreArrivalGuideBlock>.from(guide.blocks)..add(
          PreArrivalGuideBlock(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: type,
            sortOrder: guide.blocks.length,
          ),
        );
    setState(() {
      if (isDaycare) {
        _daycare = guide.copyWith(blocks: blocks);
      } else {
        _accommodation = guide.copyWith(blocks: blocks);
      }
    });
  }

  Future<void> _addImage(bool isDaycare) async {
    try {
      final picked = await PreArrivalGuideService.instance.pickImage();
      if (picked == null) {
        return;
      }
      final PreArrivalGuideImageUpload uploaded = await PreArrivalGuideService
          .instance
          .uploadImage(
            shopId: widget.shopId,
            serviceType: isDaycare
                ? PreArrivalGuideServiceType.daycare
                : PreArrivalGuideServiceType.accommodation,
            image: picked,
          );
      _sessionUploads.add(uploaded.storagePath);
      final PreArrivalGuideModel guide = isDaycare
          ? _daycare!
          : _accommodation!;
      final List<PreArrivalGuideBlock> blocks =
          List<PreArrivalGuideBlock>.from(guide.blocks)..add(
            PreArrivalGuideBlock(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              type: PreArrivalGuideBlockType.image,
              imageUrl: uploaded.imageUrl,
              storagePath: uploaded.storagePath,
              sortOrder: guide.blocks.length,
            ),
          );
      setState(() {
        if (isDaycare) {
          _daycare = guide.copyWith(blocks: blocks);
        } else {
          _accommodation = guide.copyWith(blocks: blocks);
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _updateBlock(bool isDaycare, int index, PreArrivalGuideBlock block) {
    final PreArrivalGuideModel guide = isDaycare ? _daycare! : _accommodation!;
    final List<PreArrivalGuideBlock> blocks = List<PreArrivalGuideBlock>.from(
      guide.blocks,
    );
    blocks[index] = block;
    setState(() {
      if (isDaycare) {
        _daycare = guide.copyWith(blocks: blocks);
      } else {
        _accommodation = guide.copyWith(blocks: blocks);
      }
    });
  }

  void _move(bool isDaycare, int index, int delta) {
    final PreArrivalGuideModel guide = isDaycare ? _daycare! : _accommodation!;
    final int next = index + delta;
    if (next < 0 || next >= guide.blocks.length) {
      return;
    }
    final List<PreArrivalGuideBlock> blocks = List<PreArrivalGuideBlock>.from(
      guide.blocks,
    );
    final PreArrivalGuideBlock item = blocks.removeAt(index);
    blocks.insert(next, item);
    setState(() {
      if (isDaycare) {
        _daycare = guide.copyWith(blocks: blocks);
      } else {
        _accommodation = guide.copyWith(blocks: blocks);
      }
    });
  }

  void _removeBlock(bool isDaycare, int index) {
    final PreArrivalGuideModel guide = isDaycare ? _daycare! : _accommodation!;
    final PreArrivalGuideBlock removed = guide.blocks[index];
    if (removed.storagePath.isNotEmpty) {
      if (_sessionUploads.contains(removed.storagePath)) {
        PreArrivalGuideService.instance.deleteImage(
          storagePath: removed.storagePath,
        );
        _sessionUploads.remove(removed.storagePath);
      } else {
        _pendingDeletes.add(removed.storagePath);
      }
    }
    final List<PreArrivalGuideBlock> blocks = List<PreArrivalGuideBlock>.from(
      guide.blocks,
    )..removeAt(index);
    setState(() {
      if (isDaycare) {
        _daycare = guide.copyWith(blocks: blocks);
      } else {
        _accommodation = guide.copyWith(blocks: blocks);
      }
    });
  }
}

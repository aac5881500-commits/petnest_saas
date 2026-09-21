// 檔案名稱：lib/features/platform/pages/platform_media_library_page.dart
// 功能說明：平台管理員上傳、啟用、停用與刪除外觀圖庫。

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/platform_permission_keys.dart';
import '../../../core/constants/platform_root_admin.dart';
import '../../../core/models/platform_admin_model.dart';
import '../../../core/models/platform_media_asset.dart';
import '../../../core/services/platform_admin_service.dart';
import '../../../core/services/platform_media_library_service.dart';

class PlatformMediaLibraryPage extends StatelessWidget {
  const PlatformMediaLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlatformAdminModel?>(
      future: PlatformAdminService.instance.getCurrentAdmin(),
      builder:
          (BuildContext context, AsyncSnapshot<PlatformAdminModel?> snapshot) {
            final bool isRoot = PlatformRootAdmin.isRoot(
              PlatformAdminService.instance.currentUserId,
            );
            final bool allowed =
                isRoot ||
                PlatformAdminService.instance.adminHasPermission(
                  snapshot.data,
                  PlatformPermissionKeys.managePlatformMedia,
                );
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!allowed) {
              return Scaffold(
                appBar: AppBar(title: const Text('外觀圖庫')),
                body: const Center(child: Text('你沒有管理平台外觀圖庫的權限')),
              );
            }
            return const _PlatformMediaLibraryBody();
          },
    );
  }
}

class _PlatformMediaLibraryBody extends StatefulWidget {
  const _PlatformMediaLibraryBody();

  @override
  State<_PlatformMediaLibraryBody> createState() =>
      _PlatformMediaLibraryBodyState();
}

class _PlatformMediaLibraryBodyState extends State<_PlatformMediaLibraryBody> {
  String _category = PlatformMediaCategories.dailyCarePage;

  Future<void> _openEditor({PlatformMediaAsset? asset}) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return _AssetEditorDialog(
          asset: asset,
          defaultCategory: asset?.category ?? _category,
        );
      },
    );
  }

  Future<void> _confirmDelete(PlatformMediaAsset asset) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('刪除圖庫圖片'),
          content: const Text('確定刪除這張平台圖庫圖片嗎？已被店家套用的舊設定將安全改用系統預設，不會讓客戶頁面壞掉。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (ok != true) {
      return;
    }
    try {
      await PlatformMediaLibraryService.instance.deleteAsset(asset.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除圖庫圖片')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('外觀圖庫'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            label: const Text('新增圖片'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: PlatformMediaCategories.dailyCarePage,
                  label: Text('頁背景'),
                ),
                ButtonSegment<String>(
                  value: PlatformMediaCategories.dailyCareCard,
                  label: Text('卡片背景'),
                ),
                ButtonSegment<String>(
                  value: PlatformMediaCategories.dailyCareIcon,
                  label: Text('小圖示'),
                ),
              ],
              selected: <String>{_category},
              onSelectionChanged: (Set<String> values) {
                if (values.isEmpty) {
                  return;
                }
                setState(() {
                  _category = values.first;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PlatformMediaAsset>>(
              stream: PlatformMediaLibraryService.instance.streamAllAssets(
                _category,
              ),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<PlatformMediaAsset>> snapshot,
                  ) {
                    if (snapshot.hasError) {
                      return Center(child: Text('讀取失敗：${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final List<PlatformMediaAsset> assets =
                        snapshot.data ?? const <PlatformMediaAsset>[];
                    if (assets.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.collections_outlined,
                                size: 48,
                                color: Color(0xFF1565C0),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '這個分類還沒有圖片',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                PlatformMediaCategories.hint(_category),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () => _openEditor(),
                                icon: const Icon(Icons.add),
                                label: const Text('新增圖片'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: assets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        final PlatformMediaAsset asset = assets[index];
                        return _AssetCard(
                          asset: asset,
                          onEdit: () => _openEditor(asset: asset),
                          onToggle: () async {
                            await PlatformMediaLibraryService.instance
                                .setEnabled(
                                  id: asset.id,
                                  enabled: !asset.enabled,
                                );
                          },
                          onDelete: () => _confirmDelete(asset),
                        );
                      },
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final PlatformMediaAsset asset;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final String sizeLabel = asset.width > 0 && asset.height > 0
        ? '${asset.width} × ${asset.height}'
        : '尺寸未解析';
    final String bytesLabel = asset.fileBytes <= 0
        ? ''
        : '／${(asset.fileBytes / 1024).toStringAsFixed(0)} KB';
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 88,
                height: 88,
                child: Image.network(
                  asset.thumbnailUrl.isEmpty
                      ? asset.imageUrl
                      : asset.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return const ColoredBox(
                      color: Color(0xFFF3F4F6),
                      child: Icon(Icons.broken_image_outlined),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    asset.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(PlatformMediaCategories.label(asset.category)),
                  Text('$sizeLabel$bytesLabel'),
                  Text('排序 ${asset.sortOrder}'),
                  Text(asset.enabled ? '啟用中' : '已停用'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: onEdit,
                        child: const Text('編輯'),
                      ),
                      OutlinedButton(
                        onPressed: onToggle,
                        child: Text(asset.enabled ? '停用' : '啟用'),
                      ),
                      OutlinedButton(
                        onPressed: onDelete,
                        child: const Text('刪除'),
                      ),
                    ],
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

class _AssetEditorDialog extends StatefulWidget {
  const _AssetEditorDialog({this.asset, required this.defaultCategory});

  final PlatformMediaAsset? asset;
  final String defaultCategory;

  @override
  State<_AssetEditorDialog> createState() => _AssetEditorDialogState();
}

class _AssetEditorDialogState extends State<_AssetEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _sort;
  late String _category;
  late bool _enabled;
  Uint8List? _bytes;
  String _contentType = 'image/jpeg';
  int _width = 0;
  int _height = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final PlatformMediaAsset? asset = widget.asset;
    _name = TextEditingController(text: asset?.name ?? '');
    _sort = TextEditingController(text: '${asset?.sortOrder ?? 0}');
    _category = asset?.category ?? widget.defaultCategory;
    _enabled = asset?.enabled ?? true;
    _width = asset?.width ?? 0;
    _height = asset?.height ?? 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (file == null) {
      return;
    }
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > PlatformMediaLibraryService.maxImageBytes) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('圖片不可超過 5 MB')));
      return;
    }
    final String mime = file.mimeType ?? _guessType(file.name);
    int width = 0;
    int height = 0;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      width = frame.image.width;
      height = frame.image.height;
    } catch (_) {}
    setState(() {
      _bytes = bytes;
      _contentType = mime;
      _width = width;
      _height = height;
    });
  }

  Future<void> _save() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      final int sortOrder = int.tryParse(_sort.text.trim()) ?? 0;
      if (widget.asset == null) {
        if (_bytes == null) {
          throw ArgumentError('請先選擇圖片');
        }
        await PlatformMediaLibraryService.instance.uploadAsset(
          bytes: _bytes!,
          contentType: _contentType,
          name: _name.text,
          category: _category,
          sortOrder: sortOrder,
          enabled: _enabled,
          width: _width,
          height: _height,
        );
      } else {
        await PlatformMediaLibraryService.instance.updateAsset(
          id: widget.asset!.id,
          name: _name.text,
          category: _category,
          sortOrder: sortOrder,
          enabled: _enabled,
          bytes: _bytes,
          contentType: _bytes == null ? null : _contentType,
          width: _width,
          height: _height,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.asset == null ? '新增圖片' : '編輯圖片'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_bytes != null)
                Image.memory(_bytes!, height: 120, fit: BoxFit.contain)
              else if ((widget.asset?.imageUrl ?? '').isNotEmpty)
                Image.network(
                  widget.asset!.imageUrl,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('選擇圖片'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '僅 JPG、PNG、WEBP，最大 5 MB。\n'
                  '${PlatformMediaCategories.hint(_category)}；比例為建議與裁切提示，不符仍可上傳。'
                  '${_category == PlatformMediaCategories.dailyCareIcon ? '\n建議尺寸：256 × 256\n建議格式：透明背景 PNG 或 WebP\n四周請保留安全空間' : ''}',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '名稱',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: '分類',
                  border: OutlineInputBorder(),
                ),
                items: PlatformMediaCategories.known
                    .map(
                      (String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(PlatformMediaCategories.label(value)),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _category = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sort,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '排序',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('啟用'),
                value: _enabled,
                onChanged: (bool value) {
                  setState(() {
                    _enabled = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? '儲存中...' : '儲存'),
        ),
      ],
    );
  }

  static String _guessType(String name) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}

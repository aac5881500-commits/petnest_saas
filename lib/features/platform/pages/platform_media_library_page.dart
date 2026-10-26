import 'package:flutter/services.dart';
import '../../../core/models/shop_house_local_assets.dart';
// 檔案名稱：lib/features/platform/pages/platform_media_library_page.dart
// 功能說明：平台管理員上傳、啟用、停用與刪除外觀圖庫。

import 'dart:ui' as ui;

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
  String? _subcategory;
  List<PlatformMediaAsset> _currentAssets = const [];

  Future<void> _openEditor({PlatformMediaAsset? asset}) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return PlatformMediaAssetEditorDialog(
          asset: asset,
          defaultCategory: asset?.category ?? _category,
          defaultSubcategory: _subcategory ?? '',
          subcategories:
              _currentAssets
                  .map((a) => a.subcategory)
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort(),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Column(
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
                    ButtonSegment<String>(
                      value: PlatformMediaCategories.shopHouse,
                      label: Text('店家小屋'),
                    ),
                    ButtonSegment<String>(
                      value: PlatformMediaCategories.appBackground,
                      label: Text('顧客端背景'),
                    ),
                  ],
                  selected: <String>{_category},
                  onSelectionChanged: (Set<String> values) {
                    if (values.isEmpty) {
                      return;
                    }
                    setState(() {
                      _category = values.first;
                      _subcategory = null;
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
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final allAssets =
                            snapshot.data ?? const <PlatformMediaAsset>[];
                        _currentAssets = allAssets;
                        final groups =
                            allAssets
                                .map((a) => a.subcategory)
                                .where((s) => s.isNotEmpty)
                                .toSet()
                                .toList()
                              ..sort();
                        final assets = _subcategory == null
                            ? allAssets
                            : allAssets
                                  .where((a) => a.subcategory == _subcategory)
                                  .toList();
                        if (allAssets.isEmpty) {
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
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
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  ChoiceChip(
                                    label: Text('全部 (${allAssets.length})'),
                                    selected: _subcategory == null,
                                    onSelected: (_) =>
                                        setState(() => _subcategory = null),
                                  ),
                                  const SizedBox(width: 8),
                                  for (final group in ['', ...groups]) ...[
                                    ChoiceChip(
                                      label: Text(
                                        '${group.isEmpty ? '未分類' : group} (${allAssets.where((a) => a.subcategory == group).length})',
                                      ),
                                      selected: _subcategory == group,
                                      onSelected: (_) =>
                                          setState(() => _subcategory = group),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              child: assets.isEmpty
                                  ? const Center(child: Text('這個子分類目前沒有圖片'))
                                  : LayoutBuilder(
                                      builder: (context, constraints) =>
                                          GridView.builder(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              12,
                                              16,
                                              24,
                                            ),
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount:
                                                      constraints.maxWidth >=
                                                          1100
                                                      ? 4
                                                      : constraints.maxWidth >=
                                                            800
                                                      ? 3
                                                      : constraints.maxWidth >=
                                                            560
                                                      ? 2
                                                      : 1,
                                                  mainAxisExtent: 370,
                                                  crossAxisSpacing: 16,
                                                  mainAxisSpacing: 16,
                                                ),
                                            itemCount: assets.length,
                                            itemBuilder:
                                                (
                                                  BuildContext context,
                                                  int index,
                                                ) {
                                                  final PlatformMediaAsset
                                                  asset = assets[index];
                                                  return _AssetCard(
                                                    asset: asset,
                                                    onEdit: () => _openEditor(
                                                      asset: asset,
                                                    ),
                                                    onToggle: () async {
                                                      await PlatformMediaLibraryService
                                                          .instance
                                                          .setEnabled(
                                                            id: asset.id,
                                                            enabled:
                                                                !asset.enabled,
                                                          );
                                                    },
                                                    onDelete: () =>
                                                        _confirmDelete(asset),
                                                  );
                                                },
                                          ),
                                    ),
                            ),
                          ],
                        );
                      },
                ),
              ),
            ],
          ),
        ),
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
    final theme = Theme.of(context);
    final isHouse = asset.category == PlatformMediaCategories.shopHouse;
    final usage = [
      if (asset.subcategory.isNotEmpty) asset.subcategory,
      isHouse
          ? asset.placements.map(ShopHousePlacements.label).join('、')
          : PlatformMediaCategories.label(asset.category),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 170,
            child: ColoredBox(
              color: const Color(0xFFF0F1F5),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.network(
                      asset.thumbnailUrl.isEmpty
                          ? asset.imageUrl
                          : asset.thumbnailUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.grey,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: asset.enabled
                            ? const Color(0xFFE8F5EF)
                            : const Color(0xFFEAECF0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        asset.enabled ? '● 啟用中' : '已停用',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: asset.enabled
                              ? const Color(0xFF287456)
                              : const Color(0xFF667085),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: asset.name,
                    child: Text(
                      asset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    usage.isEmpty ? '尚未設定使用位置' : usage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$sizeLabel$bytesLabel',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isHouse ? '${asset.device == 'phone'
                              ? '手機'
                              : asset.device == 'desktop'
                              ? '桌機'
                              : '通用'} · ' : ''}排序 ${asset.sortOrder}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF667085),
                    ),
                  ),
                  if (isHouse && asset.sourceFileName.isNotEmpty)
                    Tooltip(
                      message: asset.sourceFileName,
                      child: Text(
                        asset.sourceFileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF667085),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEF0F4)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('編輯圖片'),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: '更多操作',
                  onSelected: (value) {
                    if (value == 'toggle') {
                      onToggle();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(asset.enabled ? '停用圖片' : '啟用圖片'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        '刪除圖片',
                        style: TextStyle(color: Color(0xFFB42318)),
                      ),
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
}

class PlatformMediaAssetEditorDialog extends StatefulWidget {
  const PlatformMediaAssetEditorDialog({
    super.key,
    this.asset,
    required this.defaultCategory,
    this.defaultSubcategory = '',
    this.subcategories = const [],
  });

  final PlatformMediaAsset? asset;
  final String defaultCategory;
  final String defaultSubcategory;
  final List<String> subcategories;

  @override
  State<PlatformMediaAssetEditorDialog> createState() =>
      PlatformMediaAssetEditorDialogState();
}

class PlatformMediaAssetEditorDialogState
    extends State<PlatformMediaAssetEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _sort;
  late final TextEditingController _subcategory;
  final _formKey = GlobalKey<FormState>();
  late String _category;
  late bool _enabled;
  late Set<String> _placements;
  Uint8List? _bytes;
  String _contentType = 'image/jpeg';
  int _width = 0;
  int _height = 0;
  bool _busy = false;
  String _device = 'any';
  String _sourceFileName = '';

  @override
  void initState() {
    super.initState();
    final PlatformMediaAsset? asset = widget.asset;
    _name = TextEditingController(text: asset?.name ?? '');
    _sort = TextEditingController(text: '${asset?.sortOrder ?? 0}');
    _subcategory = TextEditingController(
      text: asset?.subcategory ?? widget.defaultSubcategory,
    );
    _category = asset?.category ?? widget.defaultCategory;
    _enabled = asset?.enabled ?? true;
    _placements = <String>{...?asset?.placements};
    _width = asset?.width ?? 0;
    _height = asset?.height ?? 0;
    _device = asset?.device ?? 'any';
    _sourceFileName = asset?.sourceFileName ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _sort.dispose();
    _subcategory.dispose();
    super.dispose();
  }

  Future<void> _loadLocal(ShopHouseLocalAsset entry) async {
    try {
      final bytes = (await rootBundle.load(entry.path)).buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width, height = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _contentType = _guessType(entry.fileName);
        _name.text = entry.label;
        _sort.text = entry.sortOrder.toString();
        _sourceFileName = entry.fileName;
        if (_subcategory.text.trim().isEmpty) {
          _subcategory.text = entry.directory == 'romantic_garden'
              ? '浪漫花園'
              : '暖木小屋';
        }
        _width = width;
        _height = height;
        _device = entry.device;
        _placements = entry.placements.toSet();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('本機素材無法讀取')));
      }
    }
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
      frame.image.dispose();
      codec.dispose();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法讀取圖片，請選擇 JPG、PNG 或 WebP')),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      if (_name.text.trim().isEmpty) {
        _name.text = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      }
      _sourceFileName = file.name;
      _bytes = bytes;
      _contentType = mime;
      _width = width;
      _height = height;
    });
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (widget.asset == null && _bytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先選擇圖片')));
      return;
    }
    if (_category == PlatformMediaCategories.shopHouse && _placements.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請至少選擇一個小屋使用區域')));
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      final int sortOrder = int.tryParse(_sort.text.trim()) ?? 0;
      final List<String> placements =
          _category == PlatformMediaCategories.shopHouse
          ? _placements.toList()
          : const <String>[];
      if (widget.asset == null) {
        if (_bytes == null) {
          throw ArgumentError('請先選擇圖片');
        }
        await PlatformMediaLibraryService.instance.uploadAsset(
          bytes: _bytes!,
          contentType: _contentType,
          name: _name.text,
          subcategory: _subcategory.text.trim(),
          category: _category,
          placements: placements,
          device: _device,
          sourceFileName: _sourceFileName,
          sortOrder: sortOrder,
          enabled: _enabled,
          width: _width,
          height: _height,
        );
      } else {
        await PlatformMediaLibraryService.instance.updateAsset(
          id: widget.asset!.id,
          name: _name.text,
          subcategory: _subcategory.text.trim(),
          category: _category,
          placements: placements,
          device: _device,
          sourceFileName: _sourceFileName,
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
      title: Text(widget.asset == null ? '新增共用素材' : '編輯共用素材'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      content: SizedBox(
        width: 520,
        child: AbsorbPointer(
          absorbing: _busy,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_category == PlatformMediaCategories.shopHouse &&
                      widget.asset == null) ...[
                    DropdownButtonFormField<ShopHouseLocalAsset>(
                      decoration: const InputDecoration(
                        labelText: '載入本機小屋素材（儲存前不上傳）',
                      ),
                      isExpanded: true,
                      items: [
                        for (final entry in ShopHouseLocalAsset.entries)
                          DropdownMenuItem(
                            value: entry,
                            child: Text(
                              entry.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (entry) {
                              if (entry != null) _loadLocal(entry);
                            },
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '上傳素材並依類型、子分類整理，供各頁面選用。',
                      style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 160,
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _bytes != null
                        ? Image.memory(_bytes!, fit: BoxFit.contain)
                        : (widget.asset?.imageUrl ?? '').isNotEmpty
                        ? Image.network(
                            widget.asset!.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const Center(child: Text('預覽無法載入，可重新選擇圖片')),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 36,
                                color: Color(0xFF8991A5),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '選擇圖片後會在這裡預覽',
                                style: TextStyle(color: Color(0xFF667085)),
                              ),
                            ],
                          ),
                  ),
                  if (_width > 0 && _height > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '$_width × $_height${_bytes == null ? '' : ' · ${(_bytes!.lengthInBytes / 1024).toStringAsFixed(0)} KB'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      _bytes != null || widget.asset != null ? '更換圖片' : '選擇圖片',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '僅 JPG、PNG、WEBP，最大 5 MB。\n'
                      '${_category == PlatformMediaCategories.shopHouse ? ShopHousePlacements.known.where(_placements.contains).map(ShopHousePlacements.hint).where((String line) => line.isNotEmpty).join('\n') : PlatformMediaCategories.hint(_category)}'
                      '；比例為建議與裁切提示，不符仍可上傳。'
                      '${_category == PlatformMediaCategories.dailyCareIcon ? '\n建議尺寸：256 × 256\n建議格式：透明背景 PNG 或 WebP\n四周請保留安全空間' : ''}',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    validator: (value) =>
                        (value?.trim().isEmpty ?? true) ? '請輸入圖片名稱' : null,
                    decoration: const InputDecoration(
                      labelText: '名稱',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: '素材類型',
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
                      if (_busy) return;
                      setState(() {
                        _category = value;
                        _subcategory.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subcategory,
                    enabled: !_busy,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: '子分類',
                      hintText: '例如：自然風景、貓咪、浪漫花園',
                      helperText: '可自行命名；留空會歸入「未分類」',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_category == widget.defaultCategory &&
                      widget.subcategories.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final group in widget.subcategories)
                            ActionChip(
                              label: Text(group),
                              onPressed: _busy
                                  ? null
                                  : () => setState(
                                      () => _subcategory.text = group,
                                    ),
                            ),
                        ],
                      ),
                    ),
                  if (_category ==
                      PlatformMediaCategories.shopHouse) ...<Widget>[
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '允許使用區域',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (_placements.contains(ShopHousePlacements.roof))
                      DropdownButtonFormField<String>(
                        initialValue: _device,
                        decoration: const InputDecoration(labelText: '屋頂裝置用途'),
                        items: const [
                          DropdownMenuItem(
                            value: 'any',
                            child: Text('桌機與手機通用'),
                          ),
                          DropdownMenuItem(
                            value: 'desktop',
                            child: Text('桌機屋頂（手機可回退）'),
                          ),
                          DropdownMenuItem(value: 'phone', child: Text('手機屋頂')),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) =>
                                  setState(() => _device = value ?? 'any'),
                      ),
                    for (final String placement in ShopHousePlacements.known)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(ShopHousePlacements.label(placement)),
                        value: _placements.contains(placement),
                        onChanged: (bool? checked) {
                          setState(() {
                            if (checked == true) {
                              _placements.add(placement);
                            } else {
                              _placements.remove(placement);
                            }
                          });
                        },
                      ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sort,
                    enabled: !_busy,
                    validator: (value) =>
                        int.tryParse(value?.trim() ?? '') == null
                        ? '請輸入整數排序'
                        : null,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '顯示排序',
                      helperText: '數字越小越前面',
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
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(
            _busy
                ? '儲存中...'
                : widget.asset == null
                ? '新增素材'
                : '儲存變更',
          ),
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

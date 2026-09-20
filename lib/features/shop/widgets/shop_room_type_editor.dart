// 檔案名稱：lib/features/shop/widgets/shop_room_type_editor.dart
// 功能說明：新增與編輯共用的房型編輯器，包含分區表單與即時預覽。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';
import 'package:petnest_saas/core/services/shop_plan_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_aspect_image_crop_page.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_spec_hint.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_live_preview.dart';

class MaxValueInputFormatter extends TextInputFormatter {
  MaxValueInputFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    final int? value = int.tryParse(newValue.text);
    if (value == null || value > max) {
      return oldValue;
    }
    return newValue;
  }
}

class ShopRoomTypeFeatureCatalog {
  const ShopRoomTypeFeatureCatalog._();

  static const List<Map<String, dynamic>> options = <Map<String, dynamic>>[
    {'key': 'private_space', 'name': '🏡 獨立包廂', 'icon': Icons.home},
    {'key': 'daily_clean', 'name': '🧹 每日整理', 'icon': Icons.cleaning_services},
    {'key': 'camera', 'name': '📹 全日監控', 'icon': Icons.videocam},
    {'key': 'aircon', 'name': '❄️ 舒適空調', 'icon': Icons.ac_unit},
    {'key': 'private_door', 'name': '🔒 獨立房門', 'icon': Icons.lock},
    {'key': 'cat_window', 'name': '🪟 透明貓窗', 'icon': Icons.window},
    {'key': 'sky_walk', 'name': '🌉 天空步道', 'icon': Icons.architecture},
    {'key': 'scratch', 'name': '🐾 貓抓板', 'icon': Icons.pets},
    {'key': 'jump', 'name': '🪜 跳台設計', 'icon': Icons.stairs},
    {'key': 'bed', 'name': '🛏️ 舒眠睡窩', 'icon': Icons.bed},
  ];

  static const List<String> customIcons = <String>[
    '💊',
    '🧸',
    '🍖',
    '🎁',
    '🚗',
    '📷',
    '❤️',
    '⭐',
    '🌙',
    '☀️',
    '🐟',
    '🐾',
    '🛁',
    '🧼',
    '🧹',
    '🍗',
    '🥣',
    '🍼',
    '🏠',
    '🛏️',
    '🌿',
    '🌸',
    '🎵',
    '🔔',
    '📹',
    '🪟',
    '❄️',
    '🔥',
    '🧊',
    '🚿',
    '🏥',
    '🩺',
    '📝',
    '📦',
    '👜',
    '🧑‍⚕️',
  ];
}

class ShopRoomTypeEditorPage extends StatefulWidget {
  const ShopRoomTypeEditorPage({
    super.key,
    required this.shopId,
    this.existing,
    this.embedded = false,
    this.onDraftChanged,
    this.onCancel,
    this.onSaved,
  });

  final String shopId;
  final Map<String, dynamic>? existing;
  final bool embedded;
  final ValueChanged<ShopRoomTypeDraft>? onDraftChanged;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onSaved;

  static const double splitMinWidth = 1100;

  bool get isEditing => existing != null;

  @override
  State<ShopRoomTypeEditorPage> createState() => _ShopRoomTypeEditorPageState();
}

class _ShopRoomTypeEditorPageState extends State<ShopRoomTypeEditorPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _totalRoomsController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _extraPriceController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _depthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _customFeatureNameController =
      TextEditingController();

  final List<String> _selectedFeatures = <String>[];
  final List<Map<String, String>> _customFeatures = <Map<String, String>>[];
  final List<String> _existingImageUrls = <String>[];
  final List<String> _removedImageUrls = <String>[];
  final List<Uint8List> _pendingImageBytes = <Uint8List>[];

  String _selectedCustomIcon = '💊';
  bool _loading = false;
  bool _showPreviewPane = false;
  bool _iconPickerExpanded = false;
  String _initialFingerprint = '';

  static const InputDecoration _fieldDecoration = InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFFE2E6EE)),
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic>? existing = widget.existing;
    if (existing != null) {
      _nameController.text = (existing['name'] ?? '').toString();
      _capacityController.text = _numText(existing['capacity']);
      _priceController.text = _numText(existing['price']);
      _totalRoomsController.text = _numText(existing['totalRooms']);
      _descriptionController.text = (existing['description'] ?? '').toString();
      _extraPriceController.text = _numText(existing['extraPrice']);
      _widthController.text = _numText(existing['width']);
      _depthController.text = _numText(existing['depth']);
      _heightController.text = _numText(existing['height']);
      final Object? rawFeatures = existing['features'];
      if (rawFeatures is List) {
        _selectedFeatures.addAll(
          rawFeatures
              .map((Object? e) => e.toString())
              .where((String value) => value.isNotEmpty),
        );
      }
      final Object? rawCustom = existing['customFeatures'];
      if (rawCustom is List) {
        for (final Object? raw in rawCustom) {
          if (raw is! Map) {
            continue;
          }
          _customFeatures.add(<String, String>{
            'icon': (raw['icon'] ?? '').toString(),
            'name': (raw['name'] ?? '').toString(),
          });
        }
      }
      final Object? rawImages = existing['images'];
      if (rawImages is List) {
        _existingImageUrls.addAll(
          rawImages
              .map((Object? e) => e.toString())
              .where((String value) => value.isNotEmpty),
        );
      }
    }
    _initialFingerprint = _fingerprint();
    for (final TextEditingController controller in _textControllers) {
      controller.addListener(_onDraftChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDraftChanged?.call(_draft());
    });
  }

  List<TextEditingController> get _textControllers => <TextEditingController>[
    _nameController,
    _capacityController,
    _priceController,
    _totalRoomsController,
    _descriptionController,
    _extraPriceController,
    _widthController,
    _depthController,
    _heightController,
  ];

  String _numText(Object? raw) {
    if (raw == null) {
      return '';
    }
    if (raw is num) {
      return raw.toInt() == 0 ? '' : raw.toInt().toString();
    }
    return raw.toString().trim();
  }

  void _onDraftChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    widget.onDraftChanged?.call(_draft());
  }

  bool get _isDirty => _fingerprint() != _initialFingerprint;

  String _fingerprint() {
    return <String>[
      _nameController.text,
      _capacityController.text,
      _priceController.text,
      _totalRoomsController.text,
      _descriptionController.text,
      _extraPriceController.text,
      _widthController.text,
      _depthController.text,
      _heightController.text,
      _selectedFeatures.join(','),
      _customFeatures
          .map((Map<String, String> e) => '${e['icon']}|${e['name']}')
          .join(';'),
      _existingImageUrls.join('|'),
      _pendingImageBytes.length.toString(),
      _removedImageUrls.join('|'),
    ].join('::');
  }

  ShopRoomTypeDraft _draft() {
    return ShopRoomTypeDraft(
      name: _nameController.text,
      description: _descriptionController.text,
      priceText: _priceController.text,
      capacityText: _capacityController.text,
      extraPriceText: _extraPriceController.text,
      totalRoomsText: _totalRoomsController.text,
      widthText: _widthController.text,
      depthText: _depthController.text,
      heightText: _heightController.text,
      featureKeys: List<String>.from(_selectedFeatures),
      customFeatures: List<Map<String, String>>.from(_customFeatures),
      existingImageUrls: List<String>.from(_existingImageUrls),
      pendingImageBytes: List<Uint8List>.from(_pendingImageBytes),
    );
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _textControllers) {
      controller.removeListener(_onDraftChanged);
      controller.dispose();
    }
    _customFeatureNameController.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (!_isDirty) {
      return true;
    }
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('尚未儲存'),
          content: const Text('目前有未儲存的變更，確定要離開嗎？離開後輸入內容會消失。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('繼續編輯'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('離開'),
            ),
          ],
        );
      },
    );
    return leave == true;
  }

  Future<void> _handlePop() async {
    if (_loading) {
      return;
    }
    if (await _confirmLeave() && mounted) {
      if (widget.embedded) {
        widget.onCancel?.call();
      } else {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _save() async {
    if (_loading) {
      return;
    }
    final String name = _nameController.text.trim();
    final int capacity = int.tryParse(_capacityController.text) ?? 0;
    final int price = int.tryParse(_priceController.text) ?? 0;
    final int totalRooms = int.tryParse(_totalRoomsController.text) ?? 0;
    final String description = _descriptionController.text.trim();
    final int extraPrice = int.tryParse(_extraPriceController.text) ?? 0;
    final int width = int.tryParse(_widthController.text) ?? 0;
    final int depth = int.tryParse(_depthController.text) ?? 0;
    final int height = int.tryParse(_heightController.text) ?? 0;

    if (name.isEmpty || capacity <= 0 || price <= 0 || totalRooms <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請填寫完整資料')));
      return;
    }
    if (price > 9999) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('每晚價格不可超過 9999')));
      return;
    }
    if (capacity > 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('房間最高可住不可超過 10')));
      return;
    }
    if (extraPrice > 999) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('每隻加購價格不可超過 999')));
      return;
    }
    if (totalRooms > 30) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('房間數量不可超過 30')));
      return;
    }
    if (width > 999 || depth > 999 || height > 999) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('房間尺寸不可超過 999 cm')));
      return;
    }

    if (!widget.isEditing) {
      final List<Map<String, dynamic>> roomTypes = await ShopService.instance
          .getRoomTypes(widget.shopId);
      final DocumentSnapshot<Map<String, dynamic>> shopDoc =
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(widget.shopId)
              .get();
      final Map<String, dynamic> shop = shopDoc.data() ?? <String, dynamic>{};
      final int limit = ShopPlanService.roomTypeLimit(shop);
      if (roomTypes.length >= limit) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('免費版最多建立 $limit 種房型，升級 999 方案即可解除限制')),
        );
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      String roomTypeId = (widget.existing?['id'] ?? '').toString();
      if (widget.isEditing) {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('room_types')
            .doc(roomTypeId)
            .update(<String, dynamic>{
              'name': name,
              'capacity': capacity,
              'price': price,
              'totalRooms': totalRooms,
              'description': description,
              'extraPrice': extraPrice,
              'width': width,
              'depth': depth,
              'height': height,
              'features': List<String>.from(_selectedFeatures),
              'customFeatures': List<Map<String, String>>.from(_customFeatures),
              'updatedAt': FieldValue.serverTimestamp(),
            });
        await ActionLogService.instance.logAction(
          shopId: widget.shopId,
          targetType: 'room_type',
          targetId: roomTypeId,
          action: '編輯房型',
          operatorUid: user?.uid ?? '',
          operatorRole: 'owner',
          payload: <String, dynamic>{'roomTypeName': name},
        );
      } else {
        await ShopService.instance.createRoomType(
          shopId: widget.shopId,
          name: name,
          capacity: capacity,
          price: price,
          totalRooms: totalRooms,
          description: description,
          extraPrice: extraPrice,
          width: width,
          depth: depth,
          height: height,
          extraData: <String, dynamic>{
            'features': List<String>.from(_selectedFeatures),
            'customFeatures': List<Map<String, String>>.from(_customFeatures),
          },
        );
        await ActionLogService.instance.logAction(
          shopId: widget.shopId,
          targetType: 'room_type',
          targetId: name,
          action: '新增房型',
          operatorUid: user?.uid ?? '',
          operatorRole: 'owner',
          payload: <String, dynamic>{'roomTypeName': name},
        );
        final List<Map<String, dynamic>> created = await ShopService.instance
            .getRoomTypes(widget.shopId);
        String foundId = '';
        for (final Map<String, dynamic> item in created.reversed) {
          if ((item['name'] ?? '').toString() != name) {
            continue;
          }
          foundId = (item['id'] ?? '').toString();
          final Object? images = item['images'];
          if (images is! List || images.isEmpty) {
            break;
          }
        }
        roomTypeId = foundId;
      }

      if (roomTypeId.isNotEmpty) {
        try {
          for (final Uint8List bytes in List<Uint8List>.from(
            _pendingImageBytes,
          )) {
            await ShopService.instance.uploadRoomTypeImage(
              shopId: widget.shopId,
              roomTypeId: roomTypeId,
              bytes: bytes,
              contentType: 'image/jpeg',
            );
          }
          for (final String url in List<String>.from(_removedImageUrls)) {
            await ShopService.instance.deleteRoomTypeImage(
              shopId: widget.shopId,
              roomTypeId: roomTypeId,
              imageUrl: url,
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('房型已儲存，但照片處理失敗：$e')));
          }
        }
      }

      if (!mounted) {
        return;
      }
      _initialFingerprint = _fingerprint();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isEditing ? '已儲存變更' : '新增成功')),
      );
      if (widget.embedded) {
        widget.onSaved?.call(roomTypeId);
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('錯誤：$e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickPhoto() async {
    final int total = _existingImageUrls.length + _pendingImageBytes.length;
    if (total >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('最多只能上傳5張圖片')));
      return;
    }
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (file == null) {
      return;
    }
    final Uint8List originalBytes = await file.readAsBytes();
    if (originalBytes.length > 5 * 1024 * 1024) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('圖片不可超過 5MB')));
      return;
    }
    String contentType = file.mimeType ?? '';
    if (contentType.isEmpty) {
      final String fileName = file.name.toLowerCase();
      if (fileName.endsWith('.png')) {
        contentType = 'image/png';
      } else if (fileName.endsWith('.webp')) {
        contentType = 'image/webp';
      } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      }
    }
    if (contentType != 'image/jpeg' &&
        contentType != 'image/png' &&
        contentType != 'image/webp') {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目前只支援 JPG、PNG、WEBP')));
      return;
    }
    if (!mounted) {
      return;
    }
    final Uint8List? bytes = await FixedAspectImageCropPage.open(
      context: context,
      imageBytes: originalBytes,
      spec: FixedImageSpec.roomTypePhoto,
      title: '裁切房型照片',
    );
    if (bytes == null || !mounted) {
      return;
    }
    setState(() {
      _pendingImageBytes.add(bytes);
    });
    widget.onDraftChanged?.call(_draft());
  }

  void _addCustomFeature() {
    final String name = _customFeatureNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入特色名稱')));
      return;
    }
    if (name.length > 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('特色名稱最多 4 個字')));
      return;
    }
    if (_customFeatures.any(
      (Map<String, String> item) => item['name'] == name,
    )) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此特色已存在')));
      return;
    }
    setState(() {
      _customFeatures.add(<String, String>{
        'icon': _selectedCustomIcon,
        'name': name,
      });
      _customFeatureNameController.clear();
    });
    widget.onDraftChanged?.call(_draft());
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    if (widget.embedded) {
      return _formColumn(colors, scroll: true);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        await _handlePop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        appBar: AppBar(
          title: Text(widget.isEditing ? '編輯房型' : '新增房型'),
          leading: IconButton(
            icon: const BackButtonIcon(),
            onPressed: _handlePop,
          ),
        ),
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool split =
                constraints.maxWidth >= ShopRoomTypeEditorPage.splitMinWidth;
            if (split) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  key: const ValueKey<String>('shop-room-type-editor-split'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: (constraints.maxWidth - 64) * 0.4,
                      child: ShopRoomTypeLivePreview(draft: _draft()),
                    ),
                    const SizedBox(width: 24),
                    Expanded(child: _formColumn(colors, scroll: true)),
                  ],
                ),
              );
            }
            return Column(
              key: const ValueKey<String>('shop-room-type-editor-mobile'),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SegmentedButton<bool>(
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('編輯'),
                        icon: Icon(Icons.edit_outlined),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('預覽'),
                        icon: Icon(Icons.visibility_outlined),
                      ),
                    ],
                    selected: <bool>{_showPreviewPane},
                    onSelectionChanged: (Set<bool> value) {
                      setState(() {
                        _showPreviewPane = value.first;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _showPreviewPane
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: ShopRoomTypeLivePreview(draft: _draft()),
                        )
                      : _formColumn(colors, scroll: true),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _formColumn(ColorScheme colors, {required bool scroll}) {
    final Widget form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _sectionCard(
          title: '基本資料',
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: _fieldDecoration.copyWith(labelText: '房型名稱'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                MaxValueInputFormatter(9999),
              ],
              decoration: _fieldDecoration.copyWith(labelText: '每晚價格'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                MaxValueInputFormatter(10),
              ],
              decoration: _fieldDecoration.copyWith(labelText: '最多入住數'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _extraPriceController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                MaxValueInputFormatter(999),
              ],
              decoration: _fieldDecoration.copyWith(labelText: '每隻加價'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _totalRoomsController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                MaxValueInputFormatter(30),
              ],
              decoration: _fieldDecoration.copyWith(labelText: '房間數量／上限'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(title: '照片', children: <Widget>[_photoEditor()]),
        const SizedBox(height: 12),
        _sectionCard(
          title: '空間資料',
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool three = constraints.maxWidth >= 420;
                final List<Widget> fields = <Widget>[
                  _sizeField(_widthController, '寬（cm）'),
                  _sizeField(_depthController, '深（cm）'),
                  _sizeField(_heightController, '高（cm）'),
                ];
                if (three) {
                  return Row(
                    children: <Widget>[
                      Expanded(child: fields[0]),
                      const SizedBox(width: 8),
                      Expanded(child: fields[1]),
                      const SizedBox(width: 8),
                      Expanded(child: fields[2]),
                    ],
                  );
                }
                return Column(
                  children: <Widget>[
                    fields[0],
                    const SizedBox(height: 12),
                    fields[1],
                    const SizedBox(height: 12),
                    fields[2],
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '房型特色',
          children: <Widget>[
            _featureSelector(colors),
            const SizedBox(height: 12),
            _customFeatureEditor(colors),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '房型介紹',
          children: <Widget>[
            TextField(
              controller: _descriptionController,
              maxLines: 6,
              decoration: _fieldDecoration.copyWith(
                labelText: '房型介紹',
                helperText:
                    '${_descriptionController.text.characters.length} 字',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : _handlePop,
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('儲存房型'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
    if (!scroll) {
      return form;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: form,
    );
  }

  Widget _sizeField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        MaxValueInputFormatter(999),
      ],
      decoration: _fieldDecoration.copyWith(labelText: label),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _photoEditor() {
    final List<Widget> thumbs = <Widget>[];
    for (int i = 0; i < _existingImageUrls.length; i++) {
      final String url = _existingImageUrls[i];
      thumbs.add(
        _thumb(
          networkUrl: url,
          onRemove: () {
            setState(() {
              _existingImageUrls.remove(url);
              _removedImageUrls.add(url);
            });
            widget.onDraftChanged?.call(_draft());
          },
        ),
      );
    }
    for (int i = 0; i < _pendingImageBytes.length; i++) {
      final Uint8List bytes = _pendingImageBytes[i];
      thumbs.add(
        _thumb(
          bytes: bytes,
          onRemove: () {
            setState(() {
              _pendingImageBytes.remove(bytes);
            });
            widget.onDraftChanged?.call(_draft());
          },
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('房型照片', style: TextStyle(fontWeight: FontWeight.w700)),
        const FixedImageSpecHint(spec: FixedImageSpec.roomTypePhoto),
        if (thumbs.isEmpty)
          Container(
            width: double.infinity,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E6EE)),
            ),
            child: Text(
              '尚未選擇照片',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          )
        else
          Wrap(spacing: 8, runSpacing: 8, children: thumbs),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _loading ? null : _pickPhoto,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('選擇並裁切照片'),
        ),
      ],
    );
  }

  Widget _thumb({
    String? networkUrl,
    Uint8List? bytes,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 72,
            height: 72,
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover)
                : Image.network(
                    networkUrl!,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return ColoredBox(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_outlined),
                          );
                        },
                  ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: InkWell(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _featureSelector(ColorScheme colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ShopRoomTypeFeatureCatalog.options.map((
        Map<String, dynamic> item,
      ) {
        final String key = item['key'] as String;
        final bool selected = _selectedFeatures.contains(key);
        return FilterChip(
          label: Text(item['name'] as String),
          avatar: Icon(
            item['icon'] as IconData,
            size: 16,
            color: selected ? colors.onPrimary : colors.primary,
          ),
          selected: selected,
          showCheckmark: false,
          selectedColor: colors.primary,
          labelStyle: TextStyle(
            color: selected ? colors.onPrimary : colors.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          onSelected: (bool value) {
            setState(() {
              if (value) {
                _selectedFeatures.add(key);
              } else {
                _selectedFeatures.remove(key);
              }
            });
            widget.onDraftChanged?.call(_draft());
          },
        );
      }).toList(),
    );
  }

  Widget _customFeatureEditor(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '自訂特色（${_customFeatures.length} / 10）',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (_customFeatures.length >= 10)
              const Text(
                '已達上限',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _customFeatures.map((Map<String, String> item) {
            return InputChip(
              label: Text('${item['icon'] ?? ''} ${item['name'] ?? ''}'.trim()),
              onDeleted: () {
                setState(() {
                  _customFeatures.remove(item);
                });
                widget.onDraftChanged?.call(_draft());
              },
              onPressed: () {
                _customFeatureNameController.text = item['name'] ?? '';
                _selectedCustomIcon = item['icon'] ?? '💊';
                setState(() {
                  _customFeatures.remove(item);
                });
                widget.onDraftChanged?.call(_draft());
              },
            );
          }).toList(),
        ),
        if (_customFeatures.length < 10) ...<Widget>[
          const SizedBox(height: 8),
          TextField(
            controller: _customFeatureNameController,
            decoration: _fieldDecoration.copyWith(
              labelText: '特色名稱',
              hintText: '最多4個字',
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _iconPickerExpanded = !_iconPickerExpanded;
              });
            },
            child: Text(
              _iconPickerExpanded ? '收合圖示' : '選擇圖示（目前 $_selectedCustomIcon）',
            ),
          ),
          if (_iconPickerExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ShopRoomTypeFeatureCatalog.customIcons.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 48,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final String icon =
                      ShopRoomTypeFeatureCatalog.customIcons[index];
                  final bool selected = icon == _selectedCustomIcon;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCustomIcon = icon;
                      });
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.primary.withValues(alpha: 0.12)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? colors.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Text(icon, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _addCustomFeature,
            icon: const Icon(Icons.add),
            label: const Text('新增自訂特色'),
          ),
        ],
      ],
    );
  }
}

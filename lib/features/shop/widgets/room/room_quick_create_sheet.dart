// 檔案名稱：lib/features/shop/widgets/room/room_quick_create_sheet.dart
// 功能說明：快速建房 Dialog／BottomSheet，沿用既有房間欄位與批次寫入。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/services/shop_plan_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_quick_create_logic.dart';

class RoomQuickCreateResult {
  const RoomQuickCreateResult({
    required this.createdCount,
    required this.skippedCount,
  });

  final int createdCount;
  final int skippedCount;
}

class RoomQuickCreateSheet extends StatefulWidget {
  const RoomQuickCreateSheet({
    super.key,
    required this.shopId,
    required this.roomType,
    required this.existingRooms,
  });

  final String shopId;
  final Map<String, dynamic> roomType;
  final List<Map<String, dynamic>> existingRooms;

  static Future<RoomQuickCreateResult?> show({
    required BuildContext context,
    required String shopId,
    required Map<String, dynamic> roomType,
    required List<Map<String, dynamic>> existingRooms,
  }) {
    final Widget sheet = RoomQuickCreateSheet(
      shopId: shopId,
      roomType: roomType,
      existingRooms: existingRooms,
    );
    final bool narrow = MediaQuery.sizeOf(context).width < 600;
    if (narrow) {
      return showModalBottomSheet<RoomQuickCreateResult>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext context) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: sheet,
          );
        },
      );
    }
    return showDialog<RoomQuickCreateResult>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
            child: sheet,
          ),
        );
      },
    );
  }

  @override
  State<RoomQuickCreateSheet> createState() => _RoomQuickCreateSheetState();
}

class _RoomQuickCreateSheetState extends State<RoomQuickCreateSheet> {
  final TextEditingController _prefixController = TextEditingController(
    text: 'A',
  );
  final TextEditingController _startController = TextEditingController(
    text: '1',
  );
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _customController = TextEditingController();

  int _digitCount = 2;
  bool _useCustom = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final int remaining = _typeRemaining(widget.existingRooms);
    _countController.text = remaining > 0 ? remaining.toString() : '1';
    _startController.text = (_sameTypeCount(widget.existingRooms) + 1)
        .toString();
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _startController.dispose();
    _countController.dispose();
    _customController.dispose();
    super.dispose();
  }

  String get _roomTypeId => SafeParse.parseString(widget.roomType['id']);
  String get _roomTypeName =>
      SafeParse.parseString(widget.roomType['name'], fallback: '未命名房型');
  int get _limit => SafeParse.parseInt(widget.roomType['totalRooms']);

  int _sameTypeCount(List<Map<String, dynamic>> rooms) {
    return rooms
        .where(
          (Map<String, dynamic> room) =>
              SafeParse.parseString(room['roomTypeId']) == _roomTypeId,
        )
        .length;
  }

  int _typeRemaining(List<Map<String, dynamic>> rooms) {
    return _limit - _sameTypeCount(rooms);
  }

  List<String> _requestedNames() {
    if (_useCustom) {
      return RoomQuickCreateLogic.parseCustomNames(_customController.text);
    }
    return RoomQuickCreateLogic.sequentialNames(
      prefix: _prefixController.text.trim(),
      start: int.tryParse(_startController.text.trim()) ?? 0,
      count: int.tryParse(_countController.text.trim()) ?? 0,
      digitCount: _digitCount,
    );
  }

  RoomQuickCreatePlan _plan(List<Map<String, dynamic>> rooms) {
    final Set<String> existing = rooms
        .map((Map<String, dynamic> room) => SafeParse.parseString(room['name']))
        .where((String name) => name.isNotEmpty)
        .toSet();
    return RoomQuickCreateLogic.plan(
      names: _requestedNames(),
      existingNames: existing,
      remaining: _typeRemaining(rooms),
    );
  }

  Future<void> _submit() async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Map<String, dynamic>> allRooms = await ShopService.instance
          .getRooms(widget.shopId);
      final DocumentSnapshot<Map<String, dynamic>> shopDoc =
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(widget.shopId)
              .get();
      if (!mounted) {
        return;
      }
      final Map<String, dynamic> shop = shopDoc.data() ?? <String, dynamic>{};
      final int planLimit = ShopPlanService.roomLimit(shop);
      final RoomQuickCreatePlan plan = _plan(allRooms);
      if (plan.toCreate.isEmpty) {
        setState(() {
          _loading = false;
          _error = plan.skippedExisting.isEmpty ? '請輸入要建立的房號' : '沒有可建立的新房號';
        });
        return;
      }
      if (plan.exceedsRemaining) {
        setState(() {
          _loading = false;
          _error = '此房型最多還能建立 ${plan.remaining} 間房';
        });
        return;
      }
      if (allRooms.length + plan.toCreate.length > planLimit) {
        setState(() {
          _loading = false;
          _error = '免費版最多建立 $planLimit 間房間，升級 999 方案即可解除限制';
        });
        return;
      }
      await ShopService.instance.createRoomsBatch(
        shopId: widget.shopId,
        roomTypeId: _roomTypeId,
        names: plan.toCreate,
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(
        context,
        RoomQuickCreateResult(
          createdCount: plan.toCreate.length,
          skippedCount:
              plan.skippedExisting.length + plan.skippedInBatch.length,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '建立失敗：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final RoomQuickCreatePlan plan = _plan(widget.existingRooms);
    final int created = _sameTypeCount(widget.existingRooms);
    final int remaining = plan.remaining;
    final bool canSubmit =
        !_loading && plan.toCreate.isNotEmpty && !plan.exceedsRemaining;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '快速建房',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_roomTypeName｜已建立 $created 間／上限 $_limit 間｜還可建立 $remaining 間',
                  style: TextStyle(color: Colors.blue.shade700, height: 1.4),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const <ButtonSegment<bool>>[
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('連續房號'),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('自行輸入'),
                            ),
                          ],
                          selected: <bool>{_useCustom},
                          onSelectionChanged: _loading
                              ? null
                              : (Set<bool> value) {
                                  setState(() {
                                    _useCustom = value.first;
                                    _error = null;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        if (!_useCustom) ...<Widget>[
                          TextField(
                            controller: _prefixController,
                            enabled: !_loading,
                            decoration: const InputDecoration(
                              labelText: '房號前綴',
                              hintText: '例如 A、B、VIP、2F',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _startController,
                            enabled: !_loading,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: '起始編號',
                              hintText: '例如 1',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _countController,
                            enabled: !_loading,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: '建立數量',
                              hintText: '例如 5',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          const Text('數字位數'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: <Widget>[
                              ChoiceChip(
                                label: const Text('1 位'),
                                selected: _digitCount == 1,
                                onSelected: _loading
                                    ? null
                                    : (_) => setState(() => _digitCount = 1),
                              ),
                              ChoiceChip(
                                label: const Text('2 位'),
                                selected: _digitCount == 2,
                                onSelected: _loading
                                    ? null
                                    : (_) => setState(() => _digitCount = 2),
                              ),
                              ChoiceChip(
                                label: const Text('3 位'),
                                selected: _digitCount == 3,
                                onSelected: _loading
                                    ? null
                                    : (_) => setState(() => _digitCount = 3),
                              ),
                            ],
                          ),
                        ] else
                          TextField(
                            controller: _customController,
                            enabled: !_loading,
                            maxLines: 6,
                            decoration: const InputDecoration(
                              labelText: '自行輸入房號',
                              hintText: '可用換行、逗號或空格分隔\n例如：\nA01\nA02\nVIP01',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        const SizedBox(height: 12),
                        _previewBox(plan),
                        if (plan.exceedsRemaining)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '此房型最多還能建立 $remaining 間房',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: canSubmit ? _submit : null,
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('確認建立'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewBox(RoomQuickCreatePlan plan) {
    final String preview = plan.toCreate.isEmpty
        ? '尚未產生可建立的房號'
        : plan.toCreate.join('、');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '即將建立：${plan.toCreate.length} 間',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(preview, style: const TextStyle(height: 1.4)),
          if (plan.skippedExisting.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ...plan.skippedExisting.map(
              (String name) => Text(
                '「$name」已存在，將不會建立',
                style: const TextStyle(color: Color(0xFF8A5A00)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

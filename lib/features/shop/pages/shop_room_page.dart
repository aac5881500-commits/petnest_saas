// 檔案名稱 lib/features/shop/pages/shop_room_page.dart
// 🏠 房間管理（完整升級版🔥）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/shop_plan_service.dart';
import 'package:petnest_saas/core/utils/natural_sort.dart';

class ShopRoomPage extends StatefulWidget {
  const ShopRoomPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopRoomPage> createState() => _ShopRoomPageState();
}

class _ShopRoomPageState extends State<ShopRoomPage> {
  final _nameController = TextEditingController();
  final _batchPrefixController = TextEditingController();
  final _batchStartController = TextEditingController();
  final _batchCountController = TextEditingController();

  String? _selectedRoomTypeId;
  String? _expandedRoomTypeId;
  Future<void> _createRoom() async {
    final name = _nameController.text.trim();

    if (name.isEmpty || _selectedRoomTypeId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請填寫完整資料')));
      return;
    }

    final roomTypes = await ShopService.instance.getRoomTypes(widget.shopId);

    final selectedType = roomTypes.firstWhere(
      (e) => e['id'] == _selectedRoomTypeId,
    );

    final totalRooms = selectedType['totalRooms'] ?? 0;
    final rooms = await ShopService.instance.getRooms(widget.shopId);

    final sameTypeRooms = rooms
        .where((r) => r['roomTypeId'] == _selectedRoomTypeId)
        .toList();

    final shopDoc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .get();

    final shop = shopDoc.data() ?? {};
    final limit = ShopPlanService.roomLimit(shop);

    if (rooms.length >= limit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('免費版最多建立 $limit 間房間，升級 999 方案即可解除限制')),
      );
      return;
    }

    if (sameTypeRooms.length >= totalRooms) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此房型已達最大房間數')));
      return;
    }

    final isDuplicate = rooms.any(
      (r) => (r['name'] ?? '').toString().trim() == name,
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此房號已存在，請使用不同房號')));
      return;
    }

    await ShopService.instance.createRoom(
      shopId: widget.shopId,
      name: name,
      roomTypeId: _selectedRoomTypeId!,
    );

    _nameController.clear();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('新增房間成功')));
  }

  Future<void> _deleteRoom(String roomId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('確定要刪除此房間嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ShopService.instance.deleteRoom(
      shopId: widget.shopId,
      roomId: roomId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已刪除房間')));
  }

  Future<void> _showBatchCreateRoomSheet({
    required Map<String, dynamic> roomType,
    required List<Map<String, dynamic>> existingRooms,
  }) async {
    final roomTypeId = roomType['id'] as String;
    final roomTypeName = roomType['name'] ?? '未命名房型';
    final totalRooms = roomType['totalRooms'] ?? 0;

    final sameTypeRooms = existingRooms
        .where((room) => room['roomTypeId'] == roomTypeId)
        .toList();

    final remainingCount = totalRooms - sameTypeRooms.length;

    if (remainingCount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此房型已達房間數上限')));
      return;
    }

    _batchPrefixController.text = 'A';
    _batchStartController.text = (sameTypeRooms.length + 1).toString();
    _batchCountController.text = remainingCount.toString();

    int digitCount = 2;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final start = int.tryParse(_batchStartController.text) ?? 1;
            final count = int.tryParse(_batchCountController.text) ?? 0;
            final prefix = _batchPrefixController.text.trim();

            final safeCount = count <= remainingCount ? count : remainingCount;
            final end = start + safeCount - 1;

            final preview = safeCount <= 0
                ? ''
                : '$prefix${start.toString().padLeft(digitCount, '0')} ～ '
                      '$prefix${end.toString().padLeft(digitCount, '0')}';

            return AlertDialog(
              title: const Text('快速建立房間'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$roomTypeName｜已建立 ${sameTypeRooms.length} / 設定 $totalRooms 間｜還可建立 $remainingCount 間',
                      style: const TextStyle(color: Colors.blue),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _batchPrefixController,
                      decoration: const InputDecoration(
                        labelText: '房號前綴',
                        hintText: '例如 A、B、VIP、2F',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),

                    TextField(
                      controller: _batchStartController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '起始號碼'),
                      onChanged: (_) => setDialogState(() {}),
                    ),

                    TextField(
                      controller: _batchCountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '建立數量',
                        helperText: '最多可建立 $remainingCount 間',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),

                    const SizedBox(height: 12),

                    const Text('房號位數'),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('1位'),
                          selected: digitCount == 1,
                          onSelected: (_) {
                            setDialogState(() => digitCount = 1);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('2位（01）'),
                          selected: digitCount == 2,
                          onSelected: (_) {
                            setDialogState(() => digitCount = 2);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('3位（001）'),
                          selected: digitCount == 3,
                          onSelected: (_) {
                            setDialogState(() => digitCount = 3);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        preview.isEmpty ? '請輸入正確數量' : '預覽：$preview',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final prefix = _batchPrefixController.text.trim();
                    final start = int.tryParse(_batchStartController.text) ?? 0;
                    final count = int.tryParse(_batchCountController.text) ?? 0;

                    if (start <= 0 || count <= 0) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('請輸入正確數字')));
                      return;
                    }

                    if (count > remainingCount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('最多只能建立 $remainingCount 間')),
                      );
                      return;
                    }

                    final allRooms = await ShopService.instance.getRooms(
                      widget.shopId,
                    );

                    final existingNames = allRooms
                        .map((room) => (room['name'] ?? '').toString().trim())
                        .toSet();

                    final names = List.generate(count, (index) {
                      final number = start + index;
                      return '$prefix${number.toString().padLeft(digitCount, '0')}';
                    });

                    final duplicateNames = names
                        .where(existingNames.contains)
                        .toList();

                    if (duplicateNames.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('房號已存在：${duplicateNames.join(', ')}'),
                        ),
                      );
                      return;
                    }

                    for (final name in names) {
                      await ShopService.instance.createRoom(
                        shopId: widget.shopId,
                        name: name,
                        roomTypeId: roomTypeId,
                      );
                    }

                    if (!mounted) return;

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已建立 ${names.length} 間房間')),
                    );
                  },
                  child: const Text('確認建立'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _batchPrefixController.dispose();
    _batchStartController.dispose();
    _batchCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('房間管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '使用說明',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('房間管理說明'),
                  content: const SingleChildScrollView(
                    child: Text(
                      '1. 此頁用來建立實際房間，例如 A01、A02。\n\n'
                      '2. 房型管理設定幾間房，這裡就需要建立幾次房間。\n\n'
                      '3. 每個房號不可重複，不同房型也不能使用同一個房號。\n\n'
                      '4. 關閉房間後，前台不會將此房間納入可預約數量。\n\n'
                      '5. 刪除房型時，底下所有房間也會一起刪除。\n\n'
                      '6. 若只是某一天維修，請到房務管理設定單日關閉。',
                      style: TextStyle(
                        height: 1.6,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '房號（例如 A1）'),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: ShopService.instance.streamRoomTypes(widget.shopId),
                    builder: (context, typeSnapshot) {
                      final roomTypes = typeSnapshot.data ?? [];

                      if (roomTypes.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('尚未建立房型，請先到房型管理新增房型'),
                          ),
                        );
                      }

                      return StreamBuilder<List<Map<String, dynamic>>>(
                        stream: ShopService.instance.streamRooms(widget.shopId),
                        builder: (context, roomSnapshot) {
                          final rooms = roomSnapshot.data ?? [];

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: roomTypes.length,
                            itemBuilder: (context, index) {
                              final roomType = roomTypes[index];
                              final roomTypeId = roomType['id'] as String;
                              final roomTypeName = roomType['name'] ?? '未命名房型';
                              final totalRooms = roomType['totalRooms'] ?? 0;

                              final typeRooms =
                                  rooms
                                      .where(
                                        (room) =>
                                            room['roomTypeId'] == roomTypeId,
                                      )
                                      .toList()
                                    ..sort((a, b) {
                                      final roomA = (a['name'] ?? '')
                                          .toString();
                                      final roomB = (b['name'] ?? '')
                                          .toString();

                                      return naturalCompare(roomA, roomB);
                                    });

                              final createdCount = typeRooms.length;
                              final remainingCount = totalRooms - createdCount;
                              final isExpanded =
                                  _expandedRoomTypeId == roomTypeId;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  children: [
                                    ListTile(
                                      title: Text(
                                        roomTypeName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '已建立 $createdCount / 設定 $totalRooms 間'
                                        '${remainingCount > 0 ? '｜還可建立 $remainingCount 間' : '｜已達上限'}',
                                        style: TextStyle(
                                          color: remainingCount > 0
                                              ? Colors.blue
                                              : Colors.green,
                                        ),
                                      ),
                                      trailing: Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _expandedRoomTypeId = isExpanded
                                              ? null
                                              : roomTypeId;
                                        });
                                      },
                                    ),

                                    if (isExpanded) ...[
                                      const Divider(height: 1),

                                      if (typeRooms.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Text(
                                            '此房型尚未建立實際房間',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),

                                      ...typeRooms.map((room) {
                                        return ListTile(
                                          title: Text(room['name'] ?? ''),
                                          subtitle: Text(
                                            (room['enabled'] ?? true)
                                                ? '開啟中'
                                                : '已關閉',
                                            style: TextStyle(
                                              color: (room['enabled'] ?? true)
                                                  ? Colors.green
                                                  : Colors.grey,
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Switch(
                                                value: room['enabled'] ?? true,
                                                onChanged: (value) {
                                                  ShopService.instance
                                                      .updateRoomStatus(
                                                        shopId: widget.shopId,
                                                        roomId: room['id'],
                                                        enabled: value,
                                                      );
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () {
                                                  _deleteRoom(room['id']);
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      }),

                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          12,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: remainingCount <= 0
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          _selectedRoomTypeId =
                                                              roomTypeId;
                                                        });

                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              '已選擇「$roomTypeName」，請在上方輸入房號新增',
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                icon: const Icon(Icons.add),
                                                label: const Text('新增'),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: remainingCount <= 0
                                                    ? null
                                                    : () {
                                                        _showBatchCreateRoomSheet(
                                                          roomType: roomType,
                                                          existingRooms: rooms,
                                                        );
                                                      },
                                                icon: const Icon(Icons.bolt),
                                                label: const Text('快速建立'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _createRoom,
                    child: const Text('新增房間'),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

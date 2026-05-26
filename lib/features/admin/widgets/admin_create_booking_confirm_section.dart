// lib/features/admin/widgets/admin_create_booking_confirm_section.dart
// ✅ 後台手動新增訂單：確認資料區塊
// 功能：顯示會員、寵物、日期、房型、加值服務與總金額確認

import 'package:flutter/material.dart';

class AdminCreateBookingConfirmSection extends StatelessWidget {
  const AdminCreateBookingConfirmSection({
    super.key,
    required this.member,
    required this.roomType,
    required this.startDate,
    required this.endDate,
    required this.selectedPetIds,
    required this.selectedTimeAddon,
    required this.selectedValueServices,
    required this.selectedCustomServices,
    required this.addonData,
    required this.adminOrderSource,
    required this.noteController,
    required this.onOrderSourceChanged,
    required this.formatDate,
  });

  final Map<String, dynamic>? member;
  final Map<String, dynamic>? roomType;
  final DateTime? startDate;
  final DateTime? endDate;

  final Set<String> selectedPetIds;

  final Map<String, dynamic>? selectedTimeAddon;

  final List<Map<String, dynamic>> selectedValueServices;

  final Map<String, List<String>> selectedCustomServices;

  final Map<String, dynamic>? addonData;

  final String adminOrderSource;

  final TextEditingController noteController;

  final void Function(String value) onOrderSourceChanged;

  final String Function(DateTime date) formatDate;

  @override
  Widget build(BuildContext context) {
    if (member == null ||
        roomType == null ||
        startDate == null ||
        endDate == null) {
      return const SizedBox();
    }

    final nights = endDate!.difference(startDate!).inDays;

    final roomName =
        roomType!['name']?.toString() ?? '未選房型';

    final price = roomType!['price'] ?? 0;

    final extraPetPrice =
        roomType!['extraPrice'] ?? 0;

    final extraPetCount =
        selectedPetIds.length > 1
            ? selectedPetIds.length - 1
            : 0;

    final extraPetTotal =
        extraPetPrice * extraPetCount * nights;

    final valueAddonTotal =
        selectedValueServices.fold<int>(
      0,
      (sum, item) =>
          sum + ((item['total'] ?? 0) as int),
    );

    final timeAddonTotal =
        (selectedTimeAddon?['total'] ?? 0) as int;

    final customAddonTotal =
        selectedCustomServices.entries.fold<int>(
      0,
      (sum, entry) {
        final service =
            List<Map<String, dynamic>>.from(
          addonData?['customServices'] ?? [],
        ).firstWhere(
          (item) => item['name'] == entry.key,
          orElse: () => {},
        );

        final price = service['price'] ?? 0;

        return sum + ((price as int) * entry.value.length);
      },
    );

    final addonTotal =
        valueAddonTotal +
            timeAddonTotal +
            customAddonTotal;

    final totalPrice =
        (price * nights) +
            extraPetTotal +
            addonTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '第六步：確認資料',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          '確認資料無誤後，下一步會建立訂單並鎖房。',
          style: TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: adminOrderSource,
          decoration: InputDecoration(
            labelText: '下單方式',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: '電話預約',
              child: Text('電話預約'),
            ),
            DropdownMenuItem(
              value: 'LINE 預約',
              child: Text('LINE 預約'),
            ),
            DropdownMenuItem(
              value: '現場預約',
              child: Text('現場預約'),
            ),
            DropdownMenuItem(
              value: '其他',
              child: Text('其他'),
            ),
          ],
          onChanged: (value) {
            onOrderSourceChanged(
              value ?? '電話預約',
            );
          },
        ),

        const SizedBox(height: 12),

        TextField(
          controller: noteController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '訂單備註',
            hintText:
                '例如：電話預約、LINE 預約、已口頭確認、特殊照顧事項',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade300,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _confirmRow(
                '會員',
                member!['name'] ?? '未填姓名',
              ),

              _confirmRow(
                '電話',
                member!['phone'] ?? '未填電話',
              ),

              _confirmRow(
                '寵物數',
                '${selectedPetIds.length} 隻',
              ),

              _confirmRow(
                '日期',
                '${formatDate(startDate!)} ～ ${formatDate(endDate!)}',
              ),

              _confirmRow(
                '晚數',
                '$nights 晚',
              ),

              _confirmRow(
                '房型',
                roomName,
              ),

              _confirmRow(
                '房型單價',
                'NT\$ $price',
              ),

              if (extraPetCount > 0)
                _confirmRow(
                  '寵物加價',
                  'NT\$ $extraPetPrice × '
                      '$extraPetCount 隻 × '
                      '$nights 晚 = NT\$ $extraPetTotal',
                ),

              if (selectedTimeAddon != null)
                _confirmRow(
                  '時間加購',
                  '${selectedTimeAddon!['name']} '
                      '/ NT\$ $timeAddonTotal',
                ),

              if (selectedCustomServices.isNotEmpty)
                ...selectedCustomServices.entries.map(
                  (entry) {
                    final serviceName = entry.key;
                    final count = entry.value.length;

                    if (count <= 0) {
                      return const SizedBox();
                    }

                    final service =
                        List<Map<String, dynamic>>.from(
                      addonData?['customServices'] ?? [],
                    ).firstWhere(
                      (item) =>
                          item['name'] == serviceName,
                      orElse: () => {},
                    );

                    final price =
                        service['price'] ?? 0;

                    final total = price * count;

                    return _confirmRow(
                      '客製化服務',
                      '$serviceName '
                          '/ $count 隻 '
                          '/ NT\$ $total',
                    );
                  },
                ),

              if (selectedValueServices.isNotEmpty)
                ...selectedValueServices.map((item) {
                  final name =
                      item['name']?.toString() ??
                          '加值服務';

                  final total =
                      item['total'] ??
                          item['price'] ??
                          0;

                  return _confirmRow(
                    '加值服務',
                    '$name / NT\$ $total',
                  );
                }),

              if (addonTotal > 0)
                _confirmRow(
                  '加值服務小計',
                  'NT\$ $addonTotal',
                ),

              _confirmRow(
                '總金額',
                'NT\$ $totalPrice',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _confirmRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
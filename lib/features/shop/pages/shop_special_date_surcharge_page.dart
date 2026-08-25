// lib/features/shop/pages/shop_special_date_surcharge_page.dart
// 📅 特殊日期加價管理頁
// 功能：讓店主管理春節、連假、跨年等指定住宿日期的每晚固定加價。

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/special_date_surcharge_model.dart';
import '../../../core/services/special_date_surcharge_service.dart';

class ShopSpecialDateSurchargePage extends StatefulWidget {
  const ShopSpecialDateSurchargePage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopSpecialDateSurchargePage> createState() =>
      _ShopSpecialDateSurchargePageState();
}

class _ShopSpecialDateSurchargePageState
    extends State<ShopSpecialDateSurchargePage> {
  final SpecialDateSurchargeService _service =
      SpecialDateSurchargeService.instance;

  Future<List<Map<String, dynamic>>> _loadRoomTypes() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
        .instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('room_types')
        .get();

    return snapshot.docs.map((doc) {
      return <String, dynamic>{'id': doc.id, ...doc.data()};
    }).toList();
  }

  String? _processingId;

  String _dateText(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '${date.year}/$month/$day';
  }

  Future<void> _openEditor({SpecialDateSurchargeModel? surcharge}) async {
    final TextEditingController nameController = TextEditingController(
      text: surcharge?.name ?? '',
    );

    final TextEditingController descriptionController = TextEditingController(
      text: surcharge?.description ?? '',
    );

    final TextEditingController amountController = TextEditingController(
      text: surcharge == null ? '' : surcharge.amountPerNight.toString(),
    );

    DateTime? startDate = surcharge?.startDate;
    DateTime? endDate = surcharge?.endDate;

    bool enabled = surcharge?.enabled ?? true;

    bool allowCampaignDiscount = surcharge?.allowCampaignDiscount ?? true;

    bool allowCoupon = surcharge?.allowCoupon ?? true;

    List<String> selectedRoomTypeIds = List<String>.from(
      surcharge?.roomTypeIds ?? const <String>[],
    );

    bool applyToAllRoomTypes = selectedRoomTypeIds.isEmpty;

    final Future<List<Map<String, dynamic>>> roomTypesFuture = _loadRoomTypes();

    bool saving = false;
    final bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            Future<void> pickStartDate() async {
              final DateTime now = DateTime.now();

              final DateTime? selected = await showDatePicker(
                context: context,
                initialDate: startDate ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 10),
              );

              if (selected == null) {
                return;
              }

              setDialogState(() {
                startDate = DateTime(
                  selected.year,
                  selected.month,
                  selected.day,
                );

                if (endDate != null && endDate!.isBefore(startDate!)) {
                  endDate = null;
                }
              });
            }

            Future<void> pickEndDate() async {
              final DateTime now = DateTime.now();
              final DateTime firstDate = startDate ?? now;

              final DateTime? selected = await showDatePicker(
                context: context,
                initialDate: endDate ?? firstDate,
                firstDate: firstDate,
                lastDate: DateTime(now.year + 10),
              );

              if (selected == null) {
                return;
              }

              setDialogState(() {
                endDate = DateTime(selected.year, selected.month, selected.day);
              });
            }

            Future<void> save() async {
              if (saving) {
                return;
              }

              final String name = nameController.text.trim();
              final String description = descriptionController.text.trim();
              final int amount =
                  int.tryParse(amountController.text.trim()) ?? 0;

              if (name.isEmpty) {
                _showMessage('請輸入加價名稱');
                return;
              }

              if (startDate == null || endDate == null) {
                _showMessage('請選擇加價日期');
                return;
              }

              if (amount <= 0) {
                _showMessage('每晚加價金額必須大於 0');
                return;
              }

              if (!applyToAllRoomTypes && selectedRoomTypeIds.isEmpty) {
                _showMessage('請至少選擇一個適用房型');
                return;
              }

              setDialogState(() {
                saving = true;
              });

              try {
                if (surcharge == null) {
                  await _service.createSurcharge(
                    shopId: widget.shopId,
                    name: name,
                    description: description,
                    startDate: startDate!,
                    endDate: endDate!,
                    amountPerNight: amount,
                    enabled: enabled,
                    allowCampaignDiscount: allowCampaignDiscount,
                    allowCoupon: allowCoupon,
                    roomTypeIds: selectedRoomTypeIds,
                  );
                } else {
                  await _service.updateSurcharge(
                    shopId: widget.shopId,
                    surchargeId: surcharge.id,
                    name: name,
                    description: description,
                    startDate: startDate!,
                    endDate: endDate!,
                    amountPerNight: amount,
                    enabled: enabled,
                    allowCampaignDiscount: allowCampaignDiscount,
                    allowCoupon: allowCoupon,
                    roomTypeIds: selectedRoomTypeIds,
                  );
                }

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(dialogContext, true);
              } catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  saving = false;
                });

                _showMessage('儲存失敗：$error');
              }
            }

            return AlertDialog(
              title: Text(surcharge == null ? '新增特殊日期加價' : '編輯特殊日期加價'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: '名稱',
                          hintText: '例如：春節加價',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '說明',
                          hintText: '例如：春節期間住宿每晚加價',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: saving ? null : pickStartDate,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(
                                startDate == null
                                    ? '開始日期'
                                    : '開始：${_dateText(startDate!)}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: saving ? null : pickEndDate,
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                endDate == null
                                    ? '結束日期'
                                    : '結束：${_dateText(endDate!)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '每晚加價',
                          hintText: '例如：500',
                          suffixText: '元 / 晚',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('全部房型適用'),
                        subtitle: const Text('開啟後，這筆特殊日期加價會套用到所有房型。'),
                        value: applyToAllRoomTypes,
                        onChanged: saving
                            ? null
                            : (bool value) {
                                setDialogState(() {
                                  applyToAllRoomTypes = value;

                                  if (value) {
                                    selectedRoomTypeIds = <String>[];
                                  }
                                });
                              },
                      ),

                      const SizedBox(height: 14),

                      if (!applyToAllRoomTypes)
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: roomTypesFuture,
                          builder:
                              (
                                BuildContext context,
                                AsyncSnapshot<List<Map<String, dynamic>>>
                                snapshot,
                              ) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                    child: const Text('房型讀取失敗，請稍後再試。'),
                                  );
                                }

                                final List<Map<String, dynamic>> roomTypes =
                                    snapshot.data ??
                                    const <Map<String, dynamic>>[];

                                if (roomTypes.isEmpty) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text('目前尚未建立房型，請先建立房型後再指定。'),
                                  );
                                }

                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const Text(
                                        '指定適用房型',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ...roomTypes.map((
                                        Map<String, dynamic> roomType,
                                      ) {
                                        final String roomTypeId =
                                            (roomType['id'] ?? '').toString();

                                        final String roomTypeName =
                                            (roomType['name'] ?? '未命名房型')
                                                .toString();

                                        final bool selected =
                                            selectedRoomTypeIds.contains(
                                              roomTypeId,
                                            );

                                        return CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          value: selected,
                                          title: Text(roomTypeName),
                                          onChanged: saving
                                              ? null
                                              : (bool? value) {
                                                  setDialogState(() {
                                                    if (value == true) {
                                                      if (!selectedRoomTypeIds
                                                          .contains(
                                                            roomTypeId,
                                                          )) {
                                                        selectedRoomTypeIds.add(
                                                          roomTypeId,
                                                        );
                                                      }
                                                    } else {
                                                      selectedRoomTypeIds
                                                          .remove(roomTypeId);
                                                    }
                                                  });
                                                },
                                        );
                                      }),
                                    ],
                                  ),
                                );
                              },
                        ),

                      if (!applyToAllRoomTypes) const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          children: <Widget>[
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('允許套用其他優惠活動'),
                              subtitle: const Text(
                                '關閉後，只要住宿日期碰到這筆特殊日期加價，就不套用自動優惠活動。',
                              ),
                              value: allowCampaignDiscount,
                              onChanged: saving
                                  ? null
                                  : (bool value) {
                                      setDialogState(() {
                                        allowCampaignDiscount = value;
                                      });
                                    },
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('允許使用優惠券'),
                              subtitle: const Text(
                                '關閉後，只要住宿日期碰到這筆特殊日期加價，就不能使用優惠券。',
                              ),
                              value: allowCoupon,
                              onChanged: saving
                                  ? null
                                  : (bool value) {
                                      setDialogState(() {
                                        allowCoupon = value;
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 6),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('啟用'),
                        subtitle: const Text('開啟後，符合住宿日期時會自動計算加價。'),
                        value: enabled,
                        onChanged: saving
                            ? null
                            : (bool value) {
                                setDialogState(() {
                                  enabled = value;
                                });
                              },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext, false);
                        },
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(saving ? '儲存中…' : '儲存'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    amountController.dispose();

    if (saved == true && mounted) {
      _showMessage(surcharge == null ? '特殊日期加價已建立' : '特殊日期加價已更新');
    }
  }

  Future<void> _setEnabled({
    required SpecialDateSurchargeModel surcharge,
    required bool enabled,
  }) async {
    if (_processingId != null) {
      return;
    }

    setState(() {
      _processingId = surcharge.id;
    });

    try {
      await _service.setEnabled(
        shopId: widget.shopId,
        surchargeId: surcharge.id,
        enabled: enabled,
      );

      if (!mounted) {
        return;
      }

      _showMessage(enabled ? '已啟用特殊日期加價' : '已停用特殊日期加價');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('更新失敗：$error');
    } finally {
      if (mounted) {
        setState(() {
          _processingId = null;
        });
      }
    }
  }

  Future<void> _delete(SpecialDateSurchargeModel surcharge) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('刪除特殊日期加價'),
          content: Text(
            '確定要刪除「${surcharge.name}」嗎？\n\n'
            '已建立訂單的歷史金額之後會由訂單快照保存，'
            '不會依賴這筆設定。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('確認刪除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    if (_processingId != null) {
      return;
    }

    setState(() {
      _processingId = surcharge.id;
    });

    try {
      await _service.deleteSurcharge(
        shopId: widget.shopId,
        surchargeId: surcharge.id,
      );

      if (!mounted) {
        return;
      }

      _showMessage('特殊日期加價已刪除');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('刪除失敗：$error');
    } finally {
      if (mounted) {
        setState(() {
          _processingId = null;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('特殊日期加價')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openEditor();
        },
        icon: const Icon(Icons.add),
        label: const Text('新增加價'),
      ),
      body: StreamBuilder<List<SpecialDateSurchargeModel>>(
        stream: _service.streamSurcharges(widget.shopId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<SpecialDateSurchargeModel>> snapshot,
            ) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '讀取特殊日期加價失敗：${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<SpecialDateSurchargeModel> items =
                  snapshot.data ?? const <SpecialDateSurchargeModel>[];

              if (items.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.event_available_outlined,
                          size: 72,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '尚未設定特殊日期加價',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '例如春節、跨年或連假期間，'
                          '可以設定指定住宿日期每晚固定加價。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () {
                            _openEditor();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('建立第一個加價設定'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: items.length,
                separatorBuilder: (BuildContext context, int index) {
                  return const SizedBox(height: 12);
                },
                itemBuilder: (BuildContext context, int index) {
                  final SpecialDateSurchargeModel surcharge = items[index];

                  final bool processing = _processingId == surcharge.id;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(Icons.calendar_month_outlined),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      surcharge.name,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_dateText(surcharge.startDate)} ～ '
                                      '${_dateText(surcharge.endDate)}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (processing)
                                const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else
                                Switch(
                                  value: surcharge.enabled,
                                  onChanged: (bool value) {
                                    _setEnabled(
                                      surcharge: surcharge,
                                      enabled: value,
                                    );
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '+ NT\$ ${surcharge.amountPerNight} / 晚',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (surcharge.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              surcharge.description.trim(),
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          Row(
                            children: <Widget>[
                              Text(
                                surcharge.enabled ? '目前啟用中' : '目前已停用',
                                style: TextStyle(
                                  color: surcharge.enabled
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: processing
                                    ? null
                                    : () {
                                        _openEditor(surcharge: surcharge);
                                      },
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('編輯'),
                              ),
                              TextButton.icon(
                                onPressed: processing
                                    ? null
                                    : () {
                                        _delete(surcharge);
                                      },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('刪除'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
      ),
    );
  }
}

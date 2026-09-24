// 檔案名稱：lib/features/shop/pages/shop_special_date_surcharge_page.dart
// 功能說明：讓店主管理春節、連假、跨年等指定住宿日期的每晚固定加價。
// 📅 特殊日期加價管理頁

import 'package:flutter/material.dart';
import '../../../core/models/special_date_surcharge_model.dart';
import '../../../core/services/special_date_surcharge_service.dart';
import 'shop_special_date_surcharge_form_page.dart';

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

  String? _processingId;

  String _dateText(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '${date.year}/$month/$day';
  }

  Future<void> _openEditor({SpecialDateSurchargeModel? surcharge}) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) {
          return ShopSpecialDateSurchargeFormPage(
            shopId: widget.shopId,
            surcharge: surcharge,
          );
        },
      ),
    );
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

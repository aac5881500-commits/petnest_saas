// lib/features/shop/pages/shop_addon_page.dart
// 🧩 加購服務管理頁（完整版🔥🔥🔥）
// 👉 已升級：
// - 預設時間自動建立
// - 每項都有介紹 desc
// - 三大區塊：時間 / 加值 / 客製
// - Firebase 存取完整

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopAddonPage extends StatefulWidget {
  final String shopId;

  const ShopAddonPage({super.key, required this.shopId});

  @override
  State<ShopAddonPage> createState() => _ShopAddonPageState();
}

class _ShopAddonPageState extends State<ShopAddonPage> {
  bool enabled = false;

  List<Map<String, dynamic>> timeOptions = [];
  List<Map<String, dynamic>> valueServices = [];
  List<Map<String, dynamic>> customServices = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 🔥 預設時間
  List<Map<String, dynamic>> _defaultTimeOptions() {
    return [
      {
        "label": "09:00 - 09:59 入住",
        "price": 400,
        "desc": "提早入住（早上）"
      },
      {
        "label": "10:00 - 10:59 入住",
        "price": 200,
        "desc": "提早入住"
      },
      {
        "label": "20:01 - 21:00 退房",
        "price": 200,
        "desc": "延後退房"
      },
      {
        "label": "21:01 - 22:00 退房",
        "price": 400,
        "desc": "延後退房（晚）"
      },
    ];
  }

  /// 🔥 讀取
  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('addons')
        .doc('main')
        .get();

    final data = doc.data();

    if (data != null) {
      setState(() {
        enabled = data['enabled'] ?? false;

        timeOptions = List<Map<String, dynamic>>.from(
          data['timeOptions'] ?? _defaultTimeOptions(),
        );

        valueServices = List<Map<String, dynamic>>.from(
          data['valueServices'] ?? [],
        );

        customServices = List<Map<String, dynamic>>.from(
          data['customServices'] ?? [],
        );
      });
    } else {
      /// 🔥 沒資料 → 自動給預設
      setState(() {
        timeOptions = _defaultTimeOptions();
      });
    }
  }

  /// 🔥 儲存
  Future<void> _save() async {
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('addons')
        .doc('main')
        .set({
      'enabled': enabled,
      'timeOptions': timeOptions,
      'valueServices': valueServices,
      'customServices': customServices,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已儲存')),
    );
  }

  /// 🔥 卡片（含介紹）
  Widget _buildServiceItem(
    Map<String, dynamic> item,
    VoidCallback onDelete,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [

            /// 第一行
            Row(
              children: [

                Expanded(
                  child: TextFormField(
                    initialValue: item['name'] ?? item['label'] ?? '',
                    decoration: const InputDecoration(
                      labelText: '名稱 / 時間',
                    ),
                    onChanged: (val) {
                      if (item.containsKey('label')) {
                        item['label'] = val;
                      } else {
                        item['name'] = val;
                      }
                    },
                  ),
                ),

                const SizedBox(width: 10),

                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: (item['price'] ?? 0).toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '價格'),
                    onChanged: (val) {
                      item['price'] = int.tryParse(val) ?? 0;
                    },
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),

            const SizedBox(height: 8),

            /// 🔥 第二行：介紹
            TextFormField(
              initialValue: item['desc'] ?? '',
              decoration: const InputDecoration(
                labelText: '介紹（前台顯示）',
              ),
              onChanged: (val) {
                item['desc'] = val;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('加購服務設定')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '啟用時間加購',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),

        Switch(
          value: enabled,
          onChanged: (v) {
            setState(() => enabled = v);
          },
        ),
      ],
    ),

    const SizedBox(height: 6),

    Text(
      enabled
          ? '🟢 已啟用（前台會顯示）'
          : '🔴 未啟用（前台不顯示）',
      style: TextStyle(
        color: enabled ? Colors.green : Colors.red,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    ),

    const SizedBox(height: 10),
  ],
),
            Expanded(
              child: ListView(
                children: [

                  /// ⏰ 時間加購
                  _title('時間加購'),
                  const Text(
  '⚠️ 此區為「單選」，顧客只能選擇一個時間方案',
  style: TextStyle(
    fontSize: 14,
    color: Colors.red,
    fontWeight: FontWeight.bold,
  ),
),

                  ...timeOptions.map((item) {
                    return _buildServiceItem(
                      item,
                      () => setState(() => timeOptions.remove(item)),
                    );
                  }),

                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        timeOptions.add({
                          "label": "",
                          "price": 0,
                          "desc": "",
                        });
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('新增時間'),
                  ),

                  const SizedBox(height: 20),

                  /// 💰 加值服務
                  _title('加值服務'),
                  const Text(
  '⚠️ 此區為「單次計算」，不論幾隻寵物只收一次費用',
  style: TextStyle(
    fontSize: 14,
    color: Colors.red,
    fontWeight: FontWeight.bold,
  ),
),

                  ...valueServices.map((item) {
                    return _buildServiceItem(
                      item,
                      () => setState(() => valueServices.remove(item)),
                    );
                  }),

                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        valueServices.add({
                          "name": "",
                          "price": 0,
                          "desc": "",
                        });
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('新增加值服務'),
                  ),

                  const SizedBox(height: 20),

                  /// 🛠 客製化服務
                  _title('客製化服務'),
                  const Text(
  '⚠️ 此區為「每隻寵物計算」，前台可選擇套用單隻或全部寵物',
  style: TextStyle(
    fontSize: 14,
    color: Colors.red,
    fontWeight: FontWeight.bold,
  ),
),

                  ...customServices.map((item) {
                    return _buildServiceItem(
                      item,
                      () => setState(() => customServices.remove(item)),
                    );
                  }),

                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        customServices.add({
                          "name": "",
                          "price": 0,
                          "desc": "",
                        });
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('新增客製化服務'),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),

            /// 儲存
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('儲存設定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
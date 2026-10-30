import 'package:petnest_saas/features/admin/pages/admin_member_list_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_dashboard_page.dart';
import 'package:petnest_saas/features/platform/models/inspection_error_message.dart';
import 'package:petnest_saas/features/platform/widgets/inspection_email_code_dialog.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/platform_root_admin.dart';
import 'package:petnest_saas/core/services/inspection_download.dart';
import 'package:petnest_saas/features/platform/widgets/platform_inspection_workspace.dart';

class PlatformShopInspectionPage extends StatefulWidget {
  const PlatformShopInspectionPage({super.key});
  @override
  State<PlatformShopInspectionPage> createState() => _InspectionState();
}

class _InspectionState extends State<PlatformShopInspectionPage> {
  static String? _token;
  static DateTime? _access;
  Timer? _timer;
  StreamSubscription<User?>? _auth;
  final _customer = TextEditingController();
  Map<String, dynamic> _data = {};
  String? _shop;
  String? _shopName;
  final _search = TextEditingController();
  final _history = <(String?, String, String?)>[];
  String _path = '';
  String? _error;
  bool _busy = false;
  bool _reportOpen = false;
  bool get _root =>
      PlatformRootAdmin.isRoot(FirebaseAuth.instance.currentUser?.uid);
  @override
  void initState() {
    super.initState();
    if (_access == null ||
        DateTime.now().difference(_access!) >= const Duration(minutes: 30)) {
      _token = null;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_token != null &&
          _access != null &&
          DateTime.now().difference(_access!) >= const Duration(minutes: 30)) {
        _lock();
      }
    });
    _auth = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (!PlatformRootAdmin.isRoot(u?.uid)) _lock();
    });
    if (_token != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _token != null) _run(() => _load());
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _auth?.cancel();
    _customer.dispose();
    _search.dispose();
    super.dispose();
  }

  void _lock() {
    if (_reportOpen && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _reportOpen = false;
    }
    _token = null;
    _access = null;
    if (mounted) {
      setState(() {
        _data = {};
        _shop = null;
        _path = '';
        _shopName = null;
        _history.clear();
        _customer.clear();
        _search.clear();
      });
    }
  }

  Future<Map<String, dynamic>> _call(
    String action, [
    Map<String, dynamic> args = const {},
  ]) async {
    if (!_root) throw StateError('僅最高權限可使用');
    final requestToken = _token;
    final result = await FirebaseFunctions.instanceFor(region: 'asia-east1')
        .httpsCallable(
          'inspectShop',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
        )
        .call({'action': action, 'token': _token, ...args});
    if (!_root || (requestToken != _token)) {
      throw StateError('查核已鎖定，請重新驗證');
    }
    _access = DateTime.now();
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated' || e.code == 'permission-denied') _lock();
      if (mounted) {
        setState(() => _error = inspectionErrorMessage(e.code, e.message));
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load({String? cursor}) async {
    final data = await _call(_shop == null ? 'shops' : 'read', {
      'shopId': _shop,
      'path': _path,
      'cursor': ?cursor,
    });
    if (mounted) setState(() => _data = data);
  }

  Future<void> _open(
    String path, {
    String? shopId,
    String? shopName,
    bool allShops = false,
  }) async {
    _history.add((_shop, _path, _shopName));
    setState(() {
      if (allShops || shopId != null && shopId != _shop) {
        _customer.clear();
      }
      if (allShops) {
        _shop = null;
        _shopName = null;
      } else if (shopId != null) {
        _shop = shopId;
        _shopName = shopName;
      }
      _path = path;
      _data = {};
      _search.clear();
    });
    await _load();
  }

  Future<void> _back() async {
    if (_history.isEmpty) return;
    final previous = _history.removeLast();
    setState(() {
      if (_shop != previous.$1) _customer.clear();
      _shop = previous.$1;
      _path = previous.$2;
      _shopName = previous.$3;
      _search.clear();
      _data = {};
    });
    await _load();
  }

  Future<void> _unlock() async {
    final delivery = await _call('send_code');
    if (!mounted || !_root) return;
    _reportOpen = true;
    String? token;
    try {
      token = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => InspectionEmailCodeDialog(
          initialDelivery: delivery,
          onResend: () async {
            try {
              return await _call('send_code');
            } on FirebaseFunctionsException catch (e) {
              throw Exception(inspectionErrorMessage(e.code, e.message));
            }
          },
          onVerify: (id, code) async {
            try {
              final result = await _call('verify_code', {
                'challengeId': id,
                'code': code,
              });
              return result['token'] as String;
            } on FirebaseFunctionsException catch (e) {
              throw Exception(inspectionErrorMessage(e.code, e.message));
            }
          },
        ),
      );
    } finally {
      _reportOpen = false;
    }
    if (!mounted || !_root || token == null) return;
    _token = token;
    await _load();
  }

  Future<void> _export() async {
    if (_customer.text.trim().isEmpty) throw StateError('請先選擇客戶 ID');
    final data = await _call('export', {
      'shopId': _shop,
      'customerId': _customer.text.trim(),
    });
    if (!mounted) return;
    final text = const JsonEncoder.withIndent('  ').convert(data);
    final report = StringBuffer()
      ..writeln('PetNest 客戶查核報告')
      ..writeln('店家：${data['shopId']}')
      ..writeln('客戶：${data['customerId']}')
      ..writeln('產生時間：${inspectionValue(data['generatedAt'])}')
      ..writeln('範圍：${data['coverage']}')
      ..writeln('範圍內是否完整：${data['complete'] == true ? '是' : '否，請核對未涵蓋清單'}')
      ..writeln('未涵蓋：${data['incomplete']}')
      ..writeln(
        '各類筆數：${(data['summary'] as Map).entries.map((e) => '${inspectionCollectionLabel('${e.key}')} ${e.value} 筆').join('、')}',
      )
      ..writeln('JSON 內容摘要 SHA-256：${data['sha256']}')
      ..writeln('以下依時間整理中文紀錄。原始內容另保留於原始資料檔案，供必要時核對。');
    final evidence = List<Map<String, dynamic>>.from(
      (data['records'] as List).map((r) => Map<String, dynamic>.from(r as Map)),
    );
    evidence.sort((a, b) {
      String time(Map<String, dynamic> row) {
        final value = row['data'] as Map;
        return (value['createdAt'] ??
                value['paidAt'] ??
                value['updatedAt'] ??
                '')
            .toString();
      }

      return time(a).compareTo(time(b));
    });
    for (final row in evidence) {
      report
        ..writeln(
          '\n【${inspectionCollectionLabel('${row['path']}'.split('/').take('${row['path']}'.split('/').length - 1).join('/'))}】',
        )
        ..writeln(inspectionValue(row['data']))
        ..writeln('核對來源：${row['path']}');
    }
    _reportOpen = true;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 960,
            maxHeight: MediaQuery.sizeOf(ctx).height - 48,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        data['complete'] == true ? '客戶紀錄彙整報告' : '客戶紀錄彙整（部分資料）',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '關閉報告',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '客戶：${data['customerId']}・${(data['records'] as List).length} 筆・依原始來源彙整',
                ),
                if (data['complete'] != true)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '尚有未涵蓋資料，請核對報告中的範圍清單。',
                      style: TextStyle(color: Colors.deepOrange),
                    ),
                  ),
                const Divider(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      report.toString(),
                      style: const TextStyle(fontSize: 13, height: 1.7),
                    ),
                  ),
                ),
                const Divider(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => downloadInspection(
                        report.toString(),
                        filename: 'petnest_inspection_report.txt',
                      ),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('下載／分享文字報告'),
                    ),
                    OutlinedButton(
                      onPressed: () => downloadInspection(text),
                      child: const Text('下載原始資料（進階核對）'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _reportOpen = false;
  }

  Future<void> _previewOwner(Map<String, dynamic> record) async {
    final shopPath = record['path'] as String;
    final shopId = shopPath.split('/')[1];
    // Always revalidate server session and audit before opening protected UI.
    final response = await _call('read', {'shopId': shopId, 'path': shopPath});
    final rows = response['records'] as List;
    if (!mounted || _token == null || rows.isEmpty) return;
    final shop = Map<String, dynamic>.from((rows.first as Map)['data'] as Map);
    _reportOpen = true;
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) => Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (previewContext) => ShopDashboardInspectionView(
                shopId: shopId,
                shop: shop,
                onLock: _lock,
                onExit: () => Navigator.of(context, rootNavigator: true).pop(),
                onOpenEntry: (entry) {
                  if (entry == 'AdminMemberListPage') {
                    Navigator.of(previewContext).push(
                      MaterialPageRoute(
                        builder: (memberContext) => AdminMemberListPage(
                          shopId: shopId,
                          inspectionShop: shop,
                          inspectionLoadPage: (cursor) async {
                            try {
                              return await _call('read', {
                                'shopId': shopId,
                                'path': '$shopPath/members',
                                'cursor': ?cursor,
                              });
                            } on FirebaseFunctionsException catch (e) {
                              if (e.code == 'unauthenticated' ||
                                  e.code == 'permission-denied') {
                                _lock();
                              }
                              rethrow;
                            }
                          },
                          onInspectionMember: (member) => showDialog<void>(
                            context: memberContext,
                            useRootNavigator: false,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('會員查核資料（唯讀）'),
                              content: SingleChildScrollView(
                                child: SelectableText(
                                  inspectionValue(member['data']),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('關閉'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    return;
                  }
                  // Unconverted production pages must never be instantiated here.
                  ScaffoldMessenger.of(previewContext).showSnackBar(
                    const SnackBar(
                      content: Text('此功能的原畫面唯讀版正在接入，請先從「資料查核與下載」查看紀錄。'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    } finally {
      _reportOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_root) {
      return const Scaffold(body: Center(child: Text('僅 APP 最高權限帳號可使用')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('店家唯讀查核'),
        actions: [
          if (_token != null)
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await _call('end');
                      _lock();
                    }),
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('鎖定'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: PlatformInspectionWorkspace(
        unlocked: _token != null,
        busy: _busy,
        shopId: _shop,
        shopName: _shopName,
        path: _path,
        error: _error,
        records: ((_data['records'] as List?) ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList(),
        collections: ((_data['collections'] as List?) ?? []).cast<String>(),
        customerController: _customer,
        searchController: _search,
        onSearch: (_) => setState(() {}),
        onUnlock: () => _run(_unlock),
        onAllShops: () => _run(() => _open('', allShops: true)),
        onRefresh: () => _run(() async {
          _search.clear();
          await _load();
        }),
        onRetry: _token == null ? null : () => _run(() => _load()),
        onOpenPath: (path) => _run(() => _open(path)),
        onBack: _history.isEmpty ? null : () => _run(_back),
        onNext: _data['next'] == null
            ? null
            : () => _run(() async {
                _search.clear();
                await _load(cursor: _data['next'] as String);
              }),
        onOwnerPreview: (record) => _run(() => _previewOwner(record)),
        onRecord: (record) => _run(() async {
          final path = record['path'] as String;
          final data = record['data'] as Map;
          await _open(
            path,
            shopId: _shop == null ? path.split('/')[1] : null,
            shopName: data['name']?.toString(),
          );
        }),
        onCustomer: (record) {
          final data = record['data'] as Map;
          final path = record['path'] as String;
          _customer.text =
              (data['customerUid'] ??
                      data['userId'] ??
                      data['uid'] ??
                      path.split('/').last)
                  .toString();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已選取客戶，可在「客戶紀錄彙整」下載報告')));
        },
        onExport: () => _run(_export),
      ),
    );
  }
}

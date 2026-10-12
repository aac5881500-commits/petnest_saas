// 檔案名稱：lib/features/platform/widgets/platform_shop_deletion_dialog.dart
// 功能說明：第一階段最高管理員可信預覽、重新驗證與唯讀工作查詢。

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:petnest_saas/core/services/shop_deletion_service.dart';

Future<void> showPlatformShopDeletionDialog({
  required BuildContext context,
  required String shopId,
  required String shopName,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) =>
        PlatformShopDeletionDialog(shopId: shopId, shopName: shopName),
  );
}

class PlatformShopDeletionDialog extends StatefulWidget {
  const PlatformShopDeletionDialog({
    super.key,
    required this.shopId,
    required this.shopName,
    this.service,
  });

  final String shopId;
  final String shopName;
  final ShopDeletionGateway? service;

  @override
  State<PlatformShopDeletionDialog> createState() =>
      _PlatformShopDeletionDialogState();
}

class _PlatformShopDeletionDialogState
    extends State<PlatformShopDeletionDialog> {
  late final ShopDeletionGateway _service =
      widget.service ?? ShopDeletionService.instance;
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _shopCode = TextEditingController();
  final TextEditingController _password = TextEditingController();

  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _job;
  List<Map<String, dynamic>> _failures = <Map<String, dynamic>>[];
  String _mode = 'test_reset';
  bool _loading = true;
  bool _working = false;
  bool _irreversible = false;
  bool _testConfirmed = false;
  bool _identityVerified = false;
  DateTime? _identityVerifiedAt;
  String? _error;

  Set<String> get _providerIds {
    if (Firebase.apps.isEmpty) return <String>{};
    return FirebaseAuth.instance.currentUser?.providerData
            .map((UserInfo info) => info.providerId)
            .toSet() ??
        <String>{};
  }

  bool get _usesGoogle => _providerIds.contains('google.com');
  bool get _usesPassword => _providerIds.contains('password');
  bool get _scanComplete =>
      _preview?['scan'] is Map &&
      (_preview!['scan'] as Map)['complete'] == true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _reason.dispose();
    _shopCode.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> preview = await _service.preview(
        widget.shopId,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _identityVerified = false;
        _identityVerifiedAt = null;
        _loading = false;
      });
      try {
        final Map<String, dynamic> job = await _service.getJob(
          shopId: widget.shopId,
        );
        if (mounted) setState(() => _setJobResponse(job));
      } catch (_) {
        // 舊工作的唯讀查詢不影響本次預覽可信度。
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _setJobResponse(Map<String, dynamic> response) {
    final dynamic rawJob = response['job'] ?? response;
    _job = rawJob is Map && rawJob.isNotEmpty
        ? Map<String, dynamic>.from(rawJob)
        : null;
    final dynamic rawFailures = response['failures'];
    _failures = rawFailures is List
        ? rawFailures.whereType<Map>().map((Map<dynamic, dynamic> value) {
            return Map<String, dynamic>.from(value);
          }).toList()
        : <Map<String, dynamic>>[];
  }

  Future<void> _reauthenticate() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = '找不到目前登入的最高管理員帳號。');
      return;
    }
    if (_usesPassword && !_usesGoogle && _password.text.isEmpty) {
      setState(() => _error = '請輸入最高管理員密碼。');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final String expectedUid = user.uid;
      UserCredential credential;
      if (_usesGoogle) {
        final GoogleAuthProvider provider = GoogleAuthProvider();
        provider.setCustomParameters(<String, String>{
          'prompt': 'select_account',
        });
        if (kIsWeb) {
          credential = await user.reauthenticateWithPopup(provider);
        } else {
          final GoogleSignInAccount? account = await GoogleSignIn().signIn();
          if (account == null) {
            throw const _ReauthenticationCancelled();
          }
          final GoogleSignInAuthentication auth = await account.authentication;
          credential = await user.reauthenticateWithCredential(
            GoogleAuthProvider.credential(
              accessToken: auth.accessToken,
              idToken: auth.idToken,
            ),
          );
        }
      } else if (_usesPassword && user.email != null) {
        credential = await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: user.email!,
            password: _password.text,
          ),
        );
      } else {
        throw const ShopDeletionException('目前登入方式不支援在此重新驗證，請登出後使用相同帳號重新登入。');
      }
      if (credential.user?.uid != expectedUid) {
        throw const ShopDeletionException('重新驗證帳號與目前最高管理員不一致。');
      }
      await user.getIdToken(true);
      _password.clear();
      if (!mounted) return;
      setState(() {
        _identityVerified = true;
        _identityVerifiedAt = DateTime.now();
      });
    } on _ReauthenticationCancelled {
      if (!mounted) return;
      setState(() => _error = '已取消重新驗證，未進行任何操作。');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final String message = switch (error.code) {
        'popup-closed-by-user' ||
        'cancelled-popup-request' => '已取消 Google 重新驗證。',
        'popup-blocked' => '瀏覽器阻擋了 Google 驗證視窗，請允許彈出視窗後重試。',
        'user-mismatch' => '選取的 Google 帳號與目前最高管理員不一致。',
        _ => error.message ?? '最高管理員身分重新驗證失敗。',
      };
      setState(() => _error = message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _refreshJob() async {
    final String jobId = '${_job?['jobId'] ?? ''}';
    if (jobId.isEmpty) return;
    try {
      final Map<String, dynamic> result = await _service.getJob(jobId: jobId);
      if (!mounted) return;
      setState(() => _setJobResponse(result));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bool mobile = MediaQuery.sizeOf(context).width < 700;
    final Widget content = DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('完整刪除店家'),
          actions: <Widget>[
            IconButton(
              tooltip: '關閉',
              onPressed: _working ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'A. 完整資料掃描'),
              Tab(text: 'B. 刪除範圍'),
              Tab(text: 'C. 安全確認'),
              Tab(text: 'D. 進度與結果'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: <Widget>[
                  if (_error case final String message)
                    MaterialBanner(
                      content: Text(message),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => setState(() => _error = null),
                          child: const Text('關閉'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        _previewTab(),
                        _scopeTab(),
                        _safetyTab(),
                        _progressTab(),
                      ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: <Widget>[
                const Expanded(child: Text('第一階段預覽模式：不會建立或執行刪除工作')),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _working || _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新掃描'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mobile) return Dialog.fullscreen(child: content);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 840),
        child: content,
      ),
    );
  }

  Widget _previewTab() {
    final Map<String, dynamic> scan = _map(_preview?['scan']);
    final Map<String, dynamic> shop = _map(_preview?['shop']);
    final Map<String, dynamic> firestore = _map(_preview?['firestore']);
    final Map<String, dynamic> storage = _map(_preview?['storage']);
    final Map<String, dynamic> transactions = _map(_preview?['transactions']);
    final List<Map<String, dynamic>> memberCounts = _maps(
      firestore['memberCounts'],
    );
    final List<Map<String, dynamic>> scanFailures = _maps(scan['failures']);
    final List<dynamic> scanWarnings =
        scan['warnings'] as List<dynamic>? ?? const <dynamic>[];
    return _TabScroll(
      side: _scanSidePanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _scanBanner(scan),
          const SizedBox(height: 18),
          _title('店家資訊'),
          _ResponsiveCards(
            children: <Widget>[
              _InfoCard(
                label: '店家名稱',
                value: '${shop['name'] ?? widget.shopName}',
              ),
              _InfoCard(
                label: '店家編號',
                value: '${shop['shopCode'] ?? widget.shopId}',
              ),
              _InfoCard(
                label: '店主帳號',
                value:
                    '${shop['ownerEmail'] ?? '無可用紀錄'}\n'
                    '${shop['ownerUid'] ?? '無可用紀錄'}\n'
                    '來源：${shop['ownerResolutionSource'] ?? '無可用紀錄'}',
              ),
              _InfoCard(label: '目前狀態', value: '${shop['status'] ?? ''}'),
              _InfoCard(label: '建立時間', value: _date(shop['createdAtMillis'])),
              _InfoCard(
                label: '店家最後更新',
                value:
                    '${_date(shop['updatedAtMillis'])}\n'
                    '來源：${shop['updatedAtSource'] ?? '無可用紀錄'}',
              ),
              _InfoCard(
                label: '最後活動時間',
                value:
                    '${_date(shop['lastActivityAtMillis'])}\n依據：${shop['lastActivityBasis'] ?? '無'}',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _title('資料統計'),
          _ResponsiveCards(
            children: <Widget>[
              _InfoCard(
                label: '店家樹文件',
                value: _metric(
                  firestore['shopTreeCount'],
                  '${firestore['shopTreeStatus'] ?? 'not_scanned'}',
                ),
              ),
              _InfoCard(
                label: '預估可刪除文件',
                value: _metric(
                  firestore['estimatedDeleteCount'],
                  '${firestore['status'] ?? 'not_scanned'}',
                ),
              ),
              _InfoCard(
                label: 'Storage 檔案',
                value: _metric(
                  storage['fileCount'],
                  '${storage['status'] ?? 'not_scanned'}',
                ),
              ),
              _InfoCard(
                label: 'Storage 大小',
                value: storage['totalBytes'] == null
                    ? _metric(null, '${storage['status'] ?? 'not_scanned'}')
                    : _bytes(storage['totalBytes']),
              ),
              _InfoCard(
                label: '住宿訂單',
                value: _metric(
                  transactions['stayBookingCount'],
                  _sectionStatus(transactions, 'bookings'),
                ),
              ),
              _InfoCard(
                label: '安親訂單',
                value: _metric(
                  transactions['daycareBookingCount'],
                  _sectionStatus(transactions, 'bookings'),
                ),
              ),
              _InfoCard(
                label: '付款紀錄',
                value: _metric(
                  transactions['paymentCount'],
                  _sectionStatus(transactions, 'payments'),
                ),
              ),
              for (final Map<String, dynamic> member in memberCounts)
                _InfoCard(
                  label: '${member['label'] ?? '會員'}',
                  value: _metric(
                    member['count'],
                    '${member['status'] ?? 'not_scanned'}',
                  ),
                ),
            ],
          ),
          if (scanFailures.isNotEmpty || scanWarnings.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            _title('掃描失敗與待確認項目'),
            for (final Map<String, dynamic> failure in scanFailures)
              ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text('${failure['source'] ?? '未知來源'}'),
                subtitle: Text(
                  '${failure['errorCode'] ?? 'unknown'}'
                  '\n${failure['reason'] ?? '請重新掃描'}',
                ),
              ),
            for (final dynamic warning in scanWarnings)
              ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: Text(warning.toString()),
              ),
          ],
        ],
      ),
    );
  }

  Widget _scopeTab() {
    final Map<String, dynamic> firestore = _map(_preview?['firestore']);
    final Map<String, dynamic> storage = _map(_preview?['storage']);
    final List<Map<String, dynamic>> collections = _maps(
      firestore['collections'],
    );
    final Map<String, dynamic> shopSubcollections = _map(
      firestore['shopSubcollections'],
    );
    final List<Map<String, dynamic>> userRelated = _maps(
      firestore['userRelatedCollections'],
    );
    final List<Map<String, dynamic>> accountLinks = _maps(
      firestore['accountShopLinks'],
    );
    final List<Map<String, dynamic>> prefixes = _maps(storage['prefixes']);
    final List<dynamic> retainedReferences =
        storage['retainedReferences'] as List<dynamic>? ?? const <dynamic>[];
    final List<dynamic> unknownReferences =
        storage['unknownReferences'] as List<dynamic>? ?? const <dynamic>[];
    final List<dynamic> blockers =
        _preview?['blockers'] as List<dynamic>? ?? const <dynamic>[];
    return _TabScroll(
      side: _scanSidePanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _warning(
            '正式交易、付款、退款、申訴、訂閱收款與平台稽核資料會保留。'
            '未知集合或無法確認歸屬的檔案會阻止執行。',
          ),
          const SizedBox(height: 16),
          _title('Firestore 集合'),
          for (final Map<String, dynamic> row in collections)
            ListTile(
              dense: true,
              leading: Icon(_scopeIcon('${row['classification'] ?? ''}')),
              title: Text('${row['path'] ?? row['collection'] ?? ''}'),
              subtitle: Text(
                '${_scopeLabel('${row['classification'] ?? ''}')}'
                '\n關聯：${row['relation'] ?? '待確認'}'
                '\n狀態：${_statusLabel('${row['status'] ?? 'not_scanned'}')}',
              ),
              trailing: Text(
                _metric(row['count'], '${row['status'] ?? 'not_scanned'}'),
              ),
            ),
          for (final MapEntry<String, dynamic> row
              in shopSubcollections.entries)
            ListTile(
              dense: true,
              leading: const Icon(Icons.account_tree_outlined),
              title: Text('shops/{shopId}/…/${row.key}'),
              subtitle: Text(
                '店家主文件下的子集合；隨店家樹盤點'
                '\n狀態：${_statusLabel('${firestore['shopTreeStatus'] ?? 'not_scanned'}')}',
              ),
              trailing: Text(
                _metric(
                  row.value,
                  '${firestore['shopTreeStatus'] ?? 'not_scanned'}',
                ),
              ),
            ),
          if (userRelated.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _title('會員／寵物內的店家專屬子資料'),
            for (final Map<String, dynamic> row in userRelated)
              ListTile(
                dense: true,
                leading: const Icon(Icons.link_off_outlined),
                title: Text('${row['collectionGroup'] ?? ''}'),
                subtitle: Text(
                  '只盤點 shopId 完全相符的子文件，保留會員與寵物主資料'
                  '\n狀態：${_statusLabel('${row['status'] ?? 'not_scanned'}')}',
                ),
                trailing: Text(
                  _metric(row['count'], '${row['status'] ?? 'not_scanned'}'),
                ),
              ),
          ],
          if (accountLinks.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _title('會員主資料中的店家索引'),
            for (final Map<String, dynamic> row in accountLinks)
              ListTile(
                dense: true,
                leading: const Icon(Icons.person_remove_alt_1_outlined),
                title: Text('${row['collection'] ?? ''}.shopIds'),
                subtitle: Text(
                  '共用帳號資料保留；僅盤點指定店號關聯'
                  '\n狀態：${_statusLabel('${row['status'] ?? 'not_scanned'}')}',
                ),
                trailing: Text(
                  _metric(row['count'], '${row['status'] ?? 'not_scanned'}'),
                ),
              ),
          ],
          const SizedBox(height: 16),
          _title('Firebase Storage 路徑'),
          for (final Map<String, dynamic> row in prefixes)
            ListTile(
              dense: true,
              leading: const Icon(Icons.folder_delete_outlined),
              title: Text('${row['prefix'] ?? ''}'),
              subtitle: Text(
                '擁有權：${row['ownership'] ?? '待確認'}'
                '\n狀態：${_statusLabel('${row['status'] ?? 'not_scanned'}')}'
                '${'${row['reason'] ?? ''}'.isEmpty ? '' : '\n${row['reason']}'}',
              ),
              trailing: Text(
                _metric(row['count'], '${row['status'] ?? 'not_scanned'}'),
              ),
            ),
          if (retainedReferences.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _title('保留的共用／會員檔案引用'),
            for (final dynamic path in retainedReferences)
              ListTile(
                dense: true,
                leading: const Icon(Icons.lock_outline),
                title: Text(path.toString()),
              ),
          ],
          if (unknownReferences.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _title('需要人工確認的檔案引用'),
            for (final dynamic path in unknownReferences)
              ListTile(
                dense: true,
                leading: const Icon(Icons.help_outline, color: Colors.red),
                title: Text(path.toString()),
              ),
          ],
          if (blockers.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _title('目前阻擋原因'),
            for (final dynamic blocker in blockers)
              ListTile(
                dense: true,
                leading: const Icon(Icons.block, color: Colors.red),
                title: Text(blocker.toString()),
              ),
          ],
        ],
      ),
    );
  }

  Widget _safetyTab() {
    final Map<String, dynamic> shop = _map(_preview?['shop']);
    final String expectedCode = '${shop['shopCode'] ?? widget.shopId}';
    final bool formal = _mode == 'permanent_delete';
    return _TabScroll(
      side: _scanSidePanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _title('刪除模式'),
          RadioGroup<String>(
            groupValue: _mode,
            onChanged: (String? value) {
              if (_job != null) return;
              setState(() => _mode = value ?? _mode);
            },
            child: Column(
              children: <Widget>[
                const RadioListTile<String>(
                  value: 'test_reset',
                  title: Text('A. 測試重置'),
                  subtitle: Text('保留登入帳號與會員／寵物資料，讓店主重新走創店流程。'),
                ),
                const RadioListTile<String>(
                  value: 'permanent_delete',
                  title: Text('B. 正式永久刪除'),
                  subtitle: Text('資料保留政策尚未完成，目前只可預覽，後端禁止執行。'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 4,
            enabled: _job == null,
            decoration: const InputDecoration(labelText: '刪除原因（至少 10 個字）'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _shopCode,
            enabled: _job == null,
            decoration: InputDecoration(labelText: '手動輸入完整店家編號：$expectedCode'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _testConfirmed,
            onChanged: _job == null && !formal
                ? (bool? value) =>
                      setState(() => _testConfirmed = value == true)
                : null,
            title: const Text('我已人工確認這間店及本次清除內容全部為隔離測試資料'),
            subtitle: const Text('不能只因店名含有「測試」就勾選。'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _irreversible,
            onChanged: _job == null
                ? (bool? value) => setState(() => _irreversible = value == true)
                : null,
            title: const Text('我了解刪除不可還原，且不會刪除 Firebase Auth 帳號'),
          ),
          const Divider(height: 28),
          _title('重新驗證最高管理員'),
          Text(
            _usesGoogle
                ? '目前登入方式：Google。將開啟 Firebase Auth Google 驗證視窗。'
                : _usesPassword
                ? '目前登入方式：Email／Password。'
                : '目前登入方式不支援直接重新驗證，需使用相同帳號重新登入。',
          ),
          if (_usesPassword && !_usesGoogle) ...<Widget>[
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_identityVerified && _job == null,
              decoration: const InputDecoration(labelText: '目前帳號密碼'),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _working || _identityVerified || _job != null
                ? null
                : _reauthenticate,
            icon: Icon(
              _identityVerified ? Icons.verified_user : Icons.lock_outline,
            ),
            label: Text(_identityVerified ? '身分已重新驗證' : '重新驗證'),
          ),
          if (_identityVerifiedAt case final DateTime verifiedAt)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('驗證時間：${_date(verifiedAt.millisecondsSinceEpoch)}'),
            ),
          const SizedBox(height: 20),
          _warning(
            _scanComplete
                ? '掃描完整，但第一階段仍只允許預覽與安全驗證；'
                      '後端禁止建立或執行任何刪除工作。'
                : '掃描尚未完整，不能進入任何刪除程序。請回到 A 階段重新掃描並處理失敗項目。',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: null,
            style: FilledButton.styleFrom(
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            icon: const Icon(Icons.lock_outline),
            label: const Text('第一階段鎖定：不可建立刪除工作'),
          ),
        ],
      ),
    );
  }

  Widget _progressTab() {
    final Map<String, dynamic>? job = _job;
    if (job == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '第一階段不建立刪除工作。\n此頁只保留既有工作紀錄的唯讀查詢介面。',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final String status = '${job['status'] ?? ''}';
    final String phase = '${job['phase'] ?? ''}';
    final bool complete = status == 'completed';
    return _TabScroll(
      side: _scanSidePanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _title(complete ? '刪除與殘留驗證已完成' : '刪除工作尚未完成'),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: complete ? 1 : null),
          const SizedBox(height: 16),
          _ResponsiveCards(
            children: <Widget>[
              _InfoCard(label: '工作 ID', value: '${job['jobId'] ?? ''}'),
              _InfoCard(label: '狀態', value: status),
              _InfoCard(label: '目前階段', value: phase),
              _InfoCard(
                label: '已刪 Firestore',
                value: '${job['deletedFirestore'] ?? 0}',
              ),
              _InfoCard(
                label: '已刪 Storage',
                value: '${job['deletedStorage'] ?? 0}',
              ),
              _InfoCard(label: '失敗次數', value: '${job['failedCount'] ?? 0}'),
            ],
          ),
          if ('${job['lastError'] ?? ''}'.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _warning('${job['lastError']}'),
          ],
          if (_failures.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _title('失敗項目'),
            for (final Map<String, dynamic> failure in _failures)
              ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text('${failure['phase'] ?? ''}'),
                subtitle: Text(
                  '${failure['message'] ?? ''}'
                  '${'${failure['storageObject'] ?? ''}'.isEmpty ? '' : '\n${failure['storageObject']}'}',
                ),
              ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _working ? null : _refreshJob,
                icon: const Icon(Icons.refresh),
                label: const Text('重新載入進度'),
              ),
              const Chip(
                avatar: Icon(Icons.lock_outline, size: 18),
                label: Text('執行與重試已鎖定'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scanBanner(Map<String, dynamic> scan) {
    final String status = '${scan['status'] ?? 'not_scanned'}';
    final bool complete = scan['complete'] == true;
    final List<Map<String, dynamic>> failures = _maps(scan['failures']);
    final List<dynamic> warnings =
        scan['warnings'] as List<dynamic>? ?? const <dynamic>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: complete ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        border: Border.all(
          color: complete ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '掃描狀態：${_statusLabel(status)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text('完成時間：${_date(scan['completedAtMillis'])}'),
          Text(
            '專案／區域：${scan['projectId'] ?? '未知'}／'
            '${scan['region'] ?? '未知'}',
          ),
          if (failures.isNotEmpty)
            Text('失敗項目：${failures.length}（掃描不完整，不可進入刪除程序）'),
          if (warnings.isNotEmpty) Text('待確認警告：${warnings.length}（請展開明細核對）'),
        ],
      ),
    );
  }

  Widget _scanSidePanel() {
    final Map<String, dynamic> scan = _map(_preview?['scan']);
    final Map<String, dynamic> firestore = _map(_preview?['firestore']);
    final Map<String, dynamic> storage = _map(_preview?['storage']);
    final List<dynamic> blockers =
        _preview?['blockers'] as List<dynamic>? ?? const <dynamic>[];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD7E0EA)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _title('掃描摘要'),
          const SizedBox(height: 10),
          Text('完整性：${_statusLabel('${scan['status'] ?? 'not_scanned'}')}'),
          Text(
            'Firestore：'
            '${_statusLabel('${firestore['status'] ?? 'not_scanned'}')}',
          ),
          Text(
            'Storage：${_statusLabel('${storage['status'] ?? 'not_scanned'}')}',
          ),
          const Divider(height: 24),
          const Text('安全鎖', style: TextStyle(fontWeight: FontWeight.w800)),
          const Text('• 正式永久刪除未開放'),
          const Text('• 測試重置工作亦不會建立'),
          const Text('• 掃描失敗不會顯示為 0'),
          if (blockers.isNotEmpty) ...<Widget>[
            const Divider(height: 24),
            Text(
              '阻擋原因 ${blockers.length} 項',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  String _sectionStatus(Map<String, dynamic> section, String source) {
    for (final Map<String, dynamic> row in _maps(section['sections'])) {
      if ('${row['source'] ?? ''}' == source) {
        return '${row['status'] ?? 'not_scanned'}';
      }
    }
    return 'not_scanned';
  }

  String _metric(dynamic value, String status) {
    if (status == 'failed') return '掃描失敗';
    if (status == 'not_scanned') return '尚未掃描';
    if (value == null) return status == 'partial' ? '部分結果' : '無可用紀錄';
    return status == 'partial' ? '$value（部分）' : '$value';
  }

  String _statusLabel(String status) {
    return switch (status) {
      'success' => '已完整掃描',
      'partial' => '部分完成',
      'failed' => '掃描失敗',
      _ => '尚未掃描',
    };
  }

  Widget _warning(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        border: Border.all(color: const Color(0xFFFDBA74)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message),
    );
  }

  Widget _title(String value) {
    return Text(
      value,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  IconData _scopeIcon(String classification) {
    switch (classification) {
      case 'delete':
        return Icons.delete_outline;
      case 'retain':
        return Icons.lock_outline;
      case 'special':
        return Icons.link_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _scopeLabel(String classification) {
    switch (classification) {
      case 'delete':
        return '測試重置可刪除';
      case 'retain':
        return '依法規／金流／稽核政策保留';
      case 'special':
        return '精確關聯資料；第一階段僅盤點';
      default:
        return '人工確認，會阻止執行';
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    return value is List
        ? value.whereType<Map>().map((Map<dynamic, dynamic> item) {
            return Map<String, dynamic>.from(item);
          }).toList()
        : <Map<String, dynamic>>[];
  }

  String _date(dynamic value) {
    final int millis = value is num ? value.toInt() : 0;
    if (millis <= 0) return '無資料';
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _bytes(dynamic value) {
    final num bytes = value is num ? value : 0;
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '$bytes B';
  }
}

class _TabScroll extends StatelessWidget {
  const _TabScroll({required this.child, this.side});

  final Widget child;
  final Widget? side;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool desktop = constraints.maxWidth >= 900 && side != null;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: desktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: child),
                        const SizedBox(width: 20),
                        SizedBox(width: 300, child: side),
                      ],
                    )
                  : child,
            ),
          );
        },
      ),
    );
  }
}

class _ReauthenticationCancelled implements Exception {
  const _ReauthenticationCancelled();
}

class _ResponsiveCards extends StatelessWidget {
  const _ResponsiveCards({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final double width =
            (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map((Widget child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD7E0EA)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

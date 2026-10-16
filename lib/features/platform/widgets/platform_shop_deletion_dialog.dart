// 檔案名稱：lib/features/platform/widgets/platform_shop_deletion_dialog.dart
// 功能說明：最高管理員安全掃描、測試／閒置店家清理及工作進度查詢。

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
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
  final TextEditingController _emailCode = TextEditingController();

  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _job;
  Map<String, dynamic>? _verification;
  List<Map<String, dynamic>> _failures = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _working = false;
  bool _irreversible = false;
  String _emailChallengeId = '';
  String _maskedEmail = '';
  String? _error;
  bool get _scanComplete =>
      _preview?['scan'] is Map &&
      (_preview!['scan'] as Map)['complete'] == true;
  bool get _consistencyComplete =>
      _map(_preview?['consistency'])['complete'] == true;
  bool get _scanCurrent {
    final Map<String, dynamic> scan = _map(_preview?['scan']);
    final int expiresAt = scan['expiresAtMillis'] is num
        ? (scan['expiresAtMillis'] as num).toInt()
        : 0;
    return expiresAt > DateTime.now().millisecondsSinceEpoch;
  }

  bool get _contractCompatible =>
      (_preview?['contractVersion'] is num &&
          (_preview!['contractVersion'] as num).toInt() >= 4) &&
      (_preview?['classification'] is Map || _preview?['ownership'] is Map);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _emailCode.dispose();
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
        _emailChallengeId = '';
        _maskedEmail = '';
        _emailCode.clear();
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
    final dynamic rawJob = response.containsKey('job')
        ? response['job']
        : response;
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

  Future<void> _requestEmailCode() async {
    final String scanId = '${_map(_preview?['scan'])['scanId'] ?? ''}';
    if (scanId.isEmpty ||
        _working ||
        !_scanComplete ||
        !_consistencyComplete ||
        !_cleanupAllowed) {
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> result = await _service.requestEmailCode(
        shopId: widget.shopId,
        mode: 'test_reset',
        previewScanId: scanId,
      );
      if (!mounted) return;
      setState(() {
        _emailChallengeId = '${result['challengeId'] ?? ''}';
        _maskedEmail = '${result['maskedEmail'] ?? ''}';
        _emailCode.clear();
      });
    } on ShopDeletionException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _emailChallengeId = '';
        _maskedEmail = '';
      });
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

  bool get _cleanupAllowed =>
      _map(_preview?['execution'])['cleanupAllowed'] == true;


  List<String> get _cleanupBlockers {
    final dynamic raw = _map(_preview?['execution'])['cleanupBlockers'];
    if (raw is List) {
      return raw.map((dynamic value) => value.toString()).toList();
    }
    if (_cleanupAllowed) return <String>[];
    return <String>['後端尚未完成刪除資格檢查'];
  }


  bool get _emailReady =>
      _emailChallengeId.isNotEmpty &&
      RegExp(r'^\d{6}$').hasMatch(_emailCode.text.trim());

  bool get _canCreateJob =>
      !_working &&
      _job == null &&
      _contractCompatible &&
      _scanComplete &&
      _consistencyComplete &&
      _scanCurrent &&
      _emailReady &&
      _irreversible &&
      _cleanupAllowed &&
      _cleanupBlockers.isEmpty;

  Future<void> _createJob() async {
    if (!_canCreateJob) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> result = await _service.createJob(
        shopId: widget.shopId,
        mode: 'test_reset',
        reason: '平台管理員清理無實際交易店家',
        typedShopCode: widget.shopId,
        irreversibleAcknowledged: _irreversible,
        scopeConfirmed: _irreversible,
        testDataConfirmed: true,
        previewScanId: '${_map(_preview?['scan'])['scanId'] ?? ''}',
        emailChallengeId: _emailChallengeId,
        emailCode: _emailCode.text.trim(),
      );
      if (!mounted) return;
      final String jobId = '${result['jobId'] ?? ''}';
      Map<String, dynamic> jobResponse = result;
      if (jobId.isNotEmpty) {
        try {
          jobResponse = await _service.getJob(jobId: jobId);
        } catch (_) {
          // 工作已建立時保留最小回應，稍後仍可用工作 ID 重新載入。
        }
      }
      if (!mounted) return;
      setState(() => _setJobResponse(jobResponse));
      for (var attempt = 0; attempt < 40; attempt += 1) {
        final String status = '${_job?['status'] ?? ''}';
        if (jobId.isEmpty || status == 'completed' || status == 'failed') {
          break;
        }
        if (Firebase.apps.isNotEmpty) {
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
        }
        final Map<String, dynamic> batch = await _service.runBatch(jobId);
        if (!mounted) return;
        setState(() => _setJobResponse(batch));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _runBatch() async {
    final String jobId = '${_job?['jobId'] ?? ''}';
    if (jobId.isEmpty || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
      }
      final Map<String, dynamic> result = await _service.runBatch(jobId);
      if (!mounted) return;
      setState(() => _setJobResponse(result));
      await _refreshJob();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
      await _refreshJob();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _verifyJob() async {
    final String jobId = '${_job?['jobId'] ?? ''}';
    if (jobId.isEmpty || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
      }
      final Map<String, dynamic> result = await _service.verify(jobId);
      if (!mounted) return;
      setState(() => _verification = result);
      await _refreshJob();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }



  String _trustedCount({
    required String status,
    required bool complete,
    required dynamic value,
  }) {
    if (_preview == null) return '尚未掃描';
    if (!_contractCompatible) return '版本不符';
    return switch (status) {
      'failed' => '掃描失敗',
      'not_scanned' || '' => '尚未掃描',
      'partial' => value == null ? '部分完成' : '至少 $value（部分完成）',
      'success' => complete && value != null ? '$value' : '無可用紀錄',
      _ => '尚未掃描',
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool mobile = MediaQuery.sizeOf(context).width < 700;
    final Widget content = Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('完整刪除店家'),
            Text(
              '${widget.shopName}｜${widget.shopId}',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '關閉',
            onPressed: _working ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
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
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 16 : 24,
                      16,
                      mobile ? 16 : 24,
                      24,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: _mainPage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFD7E0EA))),
          ),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              OutlinedButton(
                onPressed: _working ? null : () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              OutlinedButton.icon(
                onPressed: _working || _loading || _job != null ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('重新掃描'),
              ),
              if (_job == null)
                FilledButton.icon(
                  onPressed: _canCreateJob ? _createJob : null,
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text('確認永久刪除'),
                ),
            ],
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
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 840),
        child: content,
      ),
    );
  }

  Widget _mainPage() {
    final Map<String, dynamic>? preview = _preview;
    if (preview == null) {
      return const Text('尚未取得掃描結果。');
    }
    final Map<String, dynamic> scan = _map(preview['scan']);
    final Map<String, dynamic> shop = _map(preview['shop']);
    final Map<String, dynamic> firestore = _map(preview['firestore']);
    final Map<String, dynamic> storage = _map(preview['storage']);
    final Map<String, dynamic> ownership = _classification();
    final Map<String, dynamic> safeDelete = _map(ownership['safeDelete']);
    final Map<String, dynamic> manual = _map(ownership['manual']);
    final String firestoreCount = _trustedCount(
      status: '${firestore['status'] ?? 'not_scanned'}',
      complete: firestore['complete'] == true,
      value: firestore['shopTreeCount'],
    );
    final String storageCount = _trustedCount(
      status: '${storage['status'] ?? 'not_scanned'}',
      complete: storage['complete'] == true,
      value: storage['fileCount'],
    );
    final String releaseLabel = !_contractCompatible
        ? '版本不符'
        : '${storage['status'] ?? ''}' == 'failed'
        ? '掃描失敗'
        : storage['complete'] == true && safeDelete['complete'] == true
        ? _bytes(safeDelete['storageBytes'])
        : '無法估算';
    final String manualLabel = !_contractCompatible
        ? '版本不符'
        : manual['complete'] == true
        ? '${_number(manual['firestoreCount']) + _number(manual['storageCount'])}'
        : '數量未完整';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _title('店家'),
        const SizedBox(height: 8),
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
          ],
        ),
        const SizedBox(height: 18),
        _title('安全檢查'),
        const SizedBox(height: 8),
        Text(
          '掃描狀態：${_statusLabel('${scan['status'] ?? 'not_scanned'}')}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _warning(
          !_contractCompatible
              ? '後端預覽契約版本過舊，不能刪除。'
              : !_scanComplete
              ? '掃描未完成，不能刪除。'
              : !_consistencyComplete
              ? '掃描結果需要重新確認。掃描資料統計不一致，請重新掃描後再試。'
              : _cleanupAllowed
              ? '狀態：符合刪除條件'
              : '狀態：不可刪除，原因：${_cleanupBlockers.join('；')}',
        ),
        if (!_contractCompatible) ...<Widget>[
          const SizedBox(height: 12),
          _warning(
            '目前後端預覽契約版本過舊或缺少 classification 欄位。'
            '未知數量不會顯示為 0，也不會以空白冒充完成。'
            '請先部署相符的 previewShopDeletion 後重新掃描。',
          ),
        ],
        if (manualLabel != '0' && _scanComplete) ...<Widget>[
          const SizedBox(height: 8),
          Text('仍有未能確認歸屬的資料 $manualLabel 項，因此不能刪除。'),
        ],
        const SizedBox(height: 18),
        _title('預計清理'),
        const SizedBox(height: 8),
        _ResponsiveCards(
          children: <Widget>[
            _InfoCard(label: 'Firestore', value: firestoreCount),
            _InfoCard(label: 'Storage 實際已掃描檔案', value: storageCount),
            _InfoCard(label: '預估釋放', value: releaseLabel),
          ],
        ),
        const SizedBox(height: 18),
        _title('資料保護'),
        const SizedBox(height: 8),
        const Text(
          '將刪除此店家專屬資料與圖片，不會刪除顧客個人帳號、寵物原始資料及其他店家資料。',
        ),
        const SizedBox(height: 8),
        _technicalReport(scan),
        _confirmation(),
        if (_job != null) ...<Widget>[
          const SizedBox(height: 20),
          _progressSection(),
        ],
      ],
    );
  }

  Widget _technicalReport(Map<String, dynamic> scan) {
    final dynamic raw = scan['failures'];
    final List<Map<String, dynamic>> failures = raw is List
        ? raw.whereType<Map>().map((Map<dynamic, dynamic> item) {
            return Map<String, dynamic>.from(item);
          }).toList()
        : <Map<String, dynamic>>[];
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      title: const Text('查看技術掃描報告'),
      children: failures.isEmpty
          ? const <Widget>[ListTile(title: Text('沒有掃描失敗。'))]
          : failures.map((Map<String, dynamic> failure) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${failure['source'] ?? '掃描來源'}'),
                subtitle: Text(
                  '${failure['reason'] ?? failure['errorCode'] ?? '掃描失敗'}',
                ),
              );
            }).toList(),
    );
  }

  Widget _confirmation() {
    final bool canSend =
        !_working &&
        _job == null &&
        _contractCompatible &&
        _scanComplete &&
        _consistencyComplete &&
        _scanCurrent &&
        _cleanupAllowed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _title('確認刪除'),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _irreversible,
          onChanged: _job == null
              ? (bool? value) => setState(() => _irreversible = value == true)
              : null,
          title: const Text('我確認永久刪除此店家及其專屬資料'),
        ),
        const SizedBox(height: 8),
        const Text('驗證碼只會寄到目前登入最高管理員的已驗證 Email。'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: canSend ? _requestEmailCode : null,
          icon: const Icon(Icons.mark_email_unread_outlined),
          label: Text(_emailChallengeId.isEmpty ? '寄送驗證碼' : '重新寄送驗證碼'),
        ),
        if (_maskedEmail.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('驗證碼已寄至：$_maskedEmail'),
          ),
        TextField(
          controller: _emailCode,
          enabled: _job == null && _emailChallengeId.isNotEmpty,
          keyboardType: TextInputType.number,
          maxLength: 6,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: '六位數驗證碼'),
        ),
      ],
    );
  }

  Widget _progressSection() {
    final Map<String, dynamic>? job = _job;
    if (job == null) return const SizedBox.shrink();
    final String status = '${job['status'] ?? ''}';
    final bool complete = status == 'completed';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _title(complete ? '清理已完成' : '刪除工作尚未完成'),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: switch (status) {
            'completed' => 1,
            'running' => 0.6,
            'failed' => 0.4,
            _ => 0.15,
          },
        ),
        const SizedBox(height: 12),
        _ResponsiveCards(
          children: <Widget>[
            _InfoCard(label: '工作 ID', value: '${job['jobId'] ?? ''}'),
            _InfoCard(label: '狀態', value: status),
            _InfoCard(label: '目前階段', value: '${job['phase'] ?? ''}'),
            _InfoCard(
              label: '已刪 Firestore',
              value: '${job['deletedFirestore'] ?? 0}',
            ),
            _InfoCard(
              label: '已刪 Storage',
              value: '${job['deletedStorage'] ?? 0}',
            ),
            _InfoCard(label: '實際釋放容量', value: _bytes(job['deletedStorageBytes'])),
            _InfoCard(label: '失敗次數', value: '${job['failedCount'] ?? 0}'),
          ],
        ),
        if ('${job['lastError'] ?? ''}'.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _warning('${job['lastError']}'),
        ],
        if (_failures.isNotEmpty)
          for (final Map<String, dynamic> failure in _failures)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.error_outline, color: Colors.red),
              title: Text('${failure['message'] ?? ''}'),
            ),
        if (_verification case final Map<String, dynamic> verification) ...<Widget>[
          const SizedBox(height: 8),
          _warning(
            verification['complete'] == true
                ? '重新檢查通過，沒有發現應清理的殘留資料。'
                : '仍有殘留：${(verification['residual'] as List<dynamic>? ?? const <dynamic>[]).join('；')}',
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _working ? null : _refreshJob,
              icon: const Icon(Icons.refresh),
              label: const Text('重新載入進度'),
            ),
            if (!complete)
              FilledButton.icon(
                onPressed: _working ? null : _runBatch,
                icon: Icon(status == 'failed' ? Icons.replay : Icons.play_arrow),
                label: Text(status == 'failed' ? '安全重試此批次' : '執行下一批'),
              ),
            OutlinedButton.icon(
              onPressed: _working ? null : _verifyJob,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('重新檢查殘留'),
            ),
          ],
        ),
      ],
    );
  }

  int _number(dynamic value) => value is num ? value.toInt() : 0;




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

  Map<String, dynamic> _classification() {
    final Map<String, dynamic> current = _map(_preview?['classification']);
    return current.isNotEmpty ? current : _map(_preview?['ownership']);
  }


  Map<String, dynamic> _map(dynamic value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }



  String _bytes(dynamic value) {
    if (value is! num) return '無可用紀錄';
    final num bytes = value;
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

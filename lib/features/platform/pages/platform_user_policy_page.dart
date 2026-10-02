// 檔案名稱：lib/features/platform/pages/platform_user_policy_page.dart
// 功能說明：登入後必須閱讀並同意最新平台條款，關閉或登出不會寫入同意

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/auth_service.dart';
import 'package:petnest_saas/core/services/platform_policy_manage_service.dart';
import 'package:petnest_saas/core/services/platform_policy_service.dart';

class PlatformUserPolicyPage extends StatefulWidget {
  const PlatformUserPolicyPage({super.key, required this.onAgree});

  static const String policyKey = PlatformPolicyService.platformUserPolicyId;

  final Future<void> Function() onAgree;

  @override
  State<PlatformUserPolicyPage> createState() => _PlatformUserPolicyPageState();
}

class _PlatformUserPolicyPageState extends State<PlatformUserPolicyPage> {
  bool _hasReadToBottom = false;
  bool _loading = true;
  bool _accepting = false;
  String? _error;

  String _title = '平台會員條款';
  String _content = '';
  int _version = 0;
  String _publishedAt = '尚未記錄';

  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPolicy();
    _controller.addListener(() {
      if (!_controller.hasClients || _hasReadToBottom) return;
      if (_controller.position.pixels >=
          _controller.position.maxScrollExtent - 20) {
        setState(() => _hasReadToBottom = true);
      }
    });
  }

  Future<void> _loadPolicy() async {
    try {
      final Map<String, dynamic>? data = await PlatformPolicyManageService
          .instance
          .getPolicy(PlatformUserPolicyPage.policyKey);
      if (!mounted) return;
      final int version = publishedVersionOf(data);
      setState(() {
        _title = data?['title']?.toString().trim().isNotEmpty == true
            ? data!['title'].toString()
            : '平台會員條款';
        _content = data?['content']?.toString() ?? '';
        _version = version;
        _publishedAt = _formatDate(data?['publishedAt'] ?? data?['updatedAt']);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '無法讀取平台條款';
      });
    }
  }

  String _formatDate(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (date == null) return '尚未記錄';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _agree() async {
    if (_accepting || _version <= 0) return;
    setState(() => _accepting = true);
    try {
      await widget.onAgree();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('無法儲存同意紀錄：$error')));
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(_title),
          actions: <Widget>[
            TextButton(onPressed: _logout, child: const Text('登出')),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFFFFF7ED),
                    child: Text(
                      _version <= 0
                          ? '目前沒有已發布的平台條款。'
                          : '版本 v$_version　發布日期 $_publishedAt\n請閱讀完整內容後，按「我已閱讀並同意」。',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                  Expanded(
                    child: NotificationListener<ScrollMetricsNotification>(
                      onNotification: (ScrollMetricsNotification notice) {
                        if (notice.metrics.maxScrollExtent <= 0 &&
                            !_hasReadToBottom) {
                          setState(() => _hasReadToBottom = true);
                        }
                        return false;
                      },
                      child: SingleChildScrollView(
                        controller: _controller,
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error ??
                              (_content.trim().isEmpty
                                  ? '目前尚未設定平台會員條款內容。'
                                  : _content),
                          style: const TextStyle(fontSize: 15, height: 1.8),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed:
                              _version <= 0 ||
                                  !_hasReadToBottom ||
                                  _accepting ||
                                  _error != null
                              ? null
                              : _agree,
                          child: _accepting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('我已閱讀並同意'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// 檔案名稱：lib/features/platform/pages/platform_policy_editor_page.dart
// 功能說明：編輯平台條款草稿，發布時建立新版本，不覆寫已發布內容

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/platform_policy_manage_service.dart';
import 'package:petnest_saas/features/platform/pages/platform_policy_version_detail_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_policy_version_history_page.dart';

class PlatformPolicyEditorPage extends StatefulWidget {
  const PlatformPolicyEditorPage({
    super.key,
    required this.titleText,
    required this.policyKey,
  });

  final String titleText;
  final String policyKey;

  @override
  State<PlatformPolicyEditorPage> createState() =>
      _PlatformPolicyEditorPageState();
}

class _PlatformPolicyEditorPageState extends State<PlatformPolicyEditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  bool _loading = true;
  bool _savingDraft = false;
  bool _publishing = false;
  int _publishedVersion = 0;
  String _publishedTitle = '';
  String _publishedContent = '';
  String _publishedAt = '尚未記錄';

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    try {
      final Map<String, dynamic>? data = await PlatformPolicyManageService
          .instance
          .getPolicy(widget.policyKey);
      if (!mounted) return;
      final int version = publishedVersionOf(data);
      final String publishedTitle = data?['title']?.toString() ?? '';
      final String publishedContent = data?['content']?.toString() ?? '';
      final bool draft = hasPlatformPolicyDraft(data);
      setState(() {
        _publishedVersion = version;
        _publishedTitle = publishedTitle;
        _publishedContent = publishedContent;
        _publishedAt = _formatDate(data?['publishedAt'] ?? data?['updatedAt']);
        _titleController.text = draft
            ? (data?['draftTitle'] ?? publishedTitle).toString()
            : (publishedTitle.isEmpty ? widget.titleText : publishedTitle);
        _contentController.text = draft
            ? (data?['draftContent'] ?? '').toString()
            : publishedContent;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('無法讀取條款')));
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

  Future<void> _saveDraft() async {
    final String title = _titleController.text.trim();
    final String content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入標題與條款內容')));
      return;
    }
    setState(() => _savingDraft = true);
    try {
      await PlatformPolicyManageService.instance.saveDraft(
        policyKey: widget.policyKey,
        title: title,
        content: content,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存草稿，尚未發布')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$error')));
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> _publish() async {
    final String title = _titleController.text.trim();
    final String content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入標題與條款內容')));
      return;
    }
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('發布新版條款？'),
          content: Text(
            '發布後版本會成為 v${_publishedVersion + 1}。'
            '尚未確認此版本的使用者，需在下次登入或恢復 App 時重新確認。'
            '不會批次改寫會員資料，也不會覆寫已發布的舊版本。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('確認發布'),
            ),
          ],
        );
      },
    );
    if (confirm != true || !mounted) return;
    setState(() => _publishing = true);
    try {
      final int next = await PlatformPolicyManageService.instance
          .publishNewVersion(
            policyKey: widget.policyKey,
            title: title,
            content: content,
          );
      if (!mounted) return;
      setState(() {
        _publishedVersion = next;
        _publishedTitle = title;
        _publishedContent = content;
      });
      await _loadPolicy();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已發布新版 v$next')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('發布失敗：$error')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(title: Text(widget.titleText)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final bool busy = _savingDraft || _publishing;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: Text(widget.titleText)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _PublishedCard(
            version: _publishedVersion,
            title: _publishedTitle.isEmpty ? widget.titleText : _publishedTitle,
            publishedAt: _publishedAt,
            onView: _publishedVersion <= 0
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PlatformPolicyVersionDetailPage(
                          titleText: widget.titleText,
                          data: <String, dynamic>{
                            'title': _publishedTitle,
                            'content': _publishedContent,
                            'version': _publishedVersion,
                            'status': 'published',
                            'publishedAt': _publishedAt,
                          },
                        ),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PlatformPolicyVersionHistoryPage(
                      policyKey: widget.policyKey,
                      titleText: widget.titleText,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('版本紀錄'),
            ),
          ),
          const SizedBox(height: 16),
          const Text('草稿', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            '儲存草稿不會改變目前生效版本。確認發布後才會建立新版本。',
            style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: '條款標題',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            minLines: 16,
            maxLines: 28,
            decoration: InputDecoration(
              labelText: '條款內容',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: busy ? null : _saveDraft,
              child: _savingDraft
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('儲存草稿'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: busy ? null : _publish,
              child: _publishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('發布新版'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublishedCard extends StatelessWidget {
  const _PublishedCard({
    required this.version,
    required this.title,
    required this.publishedAt,
    required this.onView,
  });

  final int version;
  final String title;
  final String publishedAt;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final bool published = version > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('目前已發布版本', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(published ? title : '尚未發布'),
          const SizedBox(height: 4),
          Text(
            published ? '版本 v$version　發布日期 $publishedAt　生效中' : '目前沒有生效版本',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          if (onView != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onView, child: const Text('查看目前版本')),
            ),
        ],
      ),
    );
  }
}

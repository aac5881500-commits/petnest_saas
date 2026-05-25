// lib/features/platform/pages/platform_policy_editor_page.dart
// 📝 平台條款編輯頁
// 功能：編輯平台條款內容、儲存草稿與發布新版

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/platform_policy_manage_service.dart';
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

class _PlatformPolicyEditorPageState
    extends State<PlatformPolicyEditorPage> {
  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController _contentController =
      TextEditingController();

  bool _loading = true;
  bool _saving = false;
  int _version = 1;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    final data = await PlatformPolicyManageService.instance.getPolicy(
      widget.policyKey,
    );

    if (!mounted) return;

    setState(() {
      _titleController.text =
          data?['title']?.toString() ?? widget.titleText;
      _contentController.text = data?['content']?.toString() ?? '';
      _version = data?['version'] is int ? data!['version'] : 1;
      _loading = false;
    });
  }

  Future<void> _savePolicy({required bool publishNewVersion}) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入標題與條款內容')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final nextVersion = publishNewVersion ? _version + 1 : _version;

      await PlatformPolicyManageService.instance.savePolicy(
        policyKey: widget.policyKey,
        title: title,
        content: content,
        version: nextVersion,
      );

      if (!mounted) return;

      setState(() {
        _version = nextVersion;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            publishNewVersion ? '已發布新版 v$nextVersion' : '已儲存條款',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
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
        appBar: AppBar(
          title: Text(widget.titleText),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text(widget.titleText),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.amber.shade200,
              ),
            ),
            child: const Text(
              '發布新版條款後，會員或店家可能需要重新同意新版條款。',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 16),

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

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.layers_outlined),
                const SizedBox(width: 8),
                Text(
                  '目前版本：v$_version',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlatformPolicyVersionHistoryPage(
            policyKey: widget.policyKey,
            titleText: widget.titleText,
          ),
        ),
      );
    },
    icon: const Icon(Icons.history),
    label: const Text('查看歷史版本'),
  ),
),

const SizedBox(height: 16),

          TextField(
            controller: _contentController,
            minLines: 18,
            maxLines: 30,
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
            child: OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () {
                      _savePolicy(publishNewVersion: false);
                    },
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? '儲存中...' : '儲存不升版'),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving
    ? null
    : () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('發布新版條款？'),
              content: Text(
                '發布後版本會從 v$_version 變成 v${_version + 1}，使用者可能需要重新同意新版條款。',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('確認發布'),
                ),
              ],
            );
          },
        );

        if (confirm != true) return;

        _savePolicy(publishNewVersion: true);
      },
              icon: const Icon(Icons.publish_outlined),
              label: Text(_saving ? '發布中...' : '發布新版'),
            ),
          ),
        ],
      ),
    );
  }
}
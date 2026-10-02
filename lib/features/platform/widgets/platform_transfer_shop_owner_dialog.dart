// 檔案名稱：lib/features/platform/widgets/platform_transfer_shop_owner_dialog.dart
// 功能說明：平台根管理員以 Email 交接唯一店主，前任退出該店後台

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/services/shop_member_permission_service.dart';

const Color _kBlue = Color(0xFF1565C0);
const String _kTransferSuccess = '店主已轉移，前任店主的後台權限已移除。';

enum _HandoffAction { lookup, transfer, temporary, previous }

class PlatformTransferShopOwnerDialog extends StatefulWidget {
  const PlatformTransferShopOwnerDialog({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.currentOwnerUid,
    required this.previousOwnerUid,
  });

  final String shopId;
  final String shopName;
  final String currentOwnerUid;
  final String previousOwnerUid;

  @override
  State<PlatformTransferShopOwnerDialog> createState() =>
      _PlatformTransferShopOwnerDialogState();
}

class _TransferTarget {
  const _TransferTarget({
    required this.uid,
    required this.name,
    required this.email,
  });

  final String uid;
  final String name;
  final String email;
}

class _PlatformTransferShopOwnerDialogState
    extends State<PlatformTransferShopOwnerDialog> {
  static final RegExp _basicEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  late final TextEditingController _emailController;
  _HandoffAction? _active;
  String? _error;
  String? _success;
  String? _lookupEmail;
  _TransferTarget? _account;
  late String _currentUid;
  late String _previousUid;
  String? _currentName;
  String? _currentEmail;
  bool _profileLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUid = widget.currentOwnerUid.trim();
    _previousUid = widget.previousOwnerUid.trim();
    _emailController = TextEditingController();
    _emailController.addListener(_onEmailChanged);
    _loadCurrentOwner();
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    if (!mounted) return;
    if (_account == null && _error == null && _lookupEmail == null) return;
    final String current = _emailController.text.trim().toLowerCase();
    if (current == _lookupEmail) return;
    setState(() {
      _account = null;
      _error = null;
      _lookupEmail = null;
    });
  }

  String _displayName(Map<String, dynamic> data) {
    final String name = (data['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final String displayName = (data['displayName'] ?? '').toString().trim();
    if (displayName.isNotEmpty) return displayName;
    return '未設定名稱';
  }

  Future<void> _loadCurrentOwner() async {
    await _reloadShop(showSuccess: false);
  }

  Future<void> _reloadShop({required bool showSuccess}) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> shopSnap =
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(widget.shopId)
              .get();
      final Map<String, dynamic> shop = shopSnap.data() ?? <String, dynamic>{};
      final String ownerUid = (shop['ownerUid'] ?? _currentUid)
          .toString()
          .trim();
      final String previousUid = (shop['previousOwnerUid'] ?? _previousUid)
          .toString()
          .trim();
      String? name;
      String? email;
      if (ownerUid.isNotEmpty) {
        final DocumentSnapshot<Map<String, dynamic>> userSnap =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(ownerUid)
                .get();
        final Map<String, dynamic>? data = userSnap.data();
        if (data != null) {
          name = _displayName(data);
          final String stored = (data['email'] ?? '').toString().trim();
          email = stored.isEmpty ? null : stored;
        }
      }
      if (!mounted) return;
      setState(() {
        _currentUid = ownerUid;
        _previousUid = previousUid;
        _currentName = name;
        _currentEmail = email;
        _profileLoading = false;
        if (showSuccess) {
          _success = _kTransferSuccess;
          _account = null;
          _lookupEmail = null;
          _error = null;
          _emailController.clear();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profileLoading = false;
        if (showSuccess) _success = _kTransferSuccess;
      });
    }
  }

  Future<void> _lookup() async {
    if (_active != null) return;
    final String normalized = _emailController.text.trim().toLowerCase();
    if (normalized.isEmpty) {
      setState(() {
        _account = null;
        _lookupEmail = null;
        _error = '請輸入新店主登入信箱';
      });
      return;
    }
    if (!_basicEmail.hasMatch(normalized)) {
      setState(() {
        _account = null;
        _lookupEmail = null;
        _error = 'Email 格式不正確，請重新輸入';
      });
      return;
    }

    setState(() {
      _active = _HandoffAction.lookup;
      _error = null;
      _success = null;
      _account = null;
    });
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
          .instance
          .collection('users')
          .where('email', isEqualTo: normalized)
          .get();
      if (!mounted) return;
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> matches = snap
          .docs
          .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final String email = (doc.data()['email'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            return email == normalized;
          })
          .toList();
      if (matches.isEmpty) {
        setState(() {
          _active = null;
          _lookupEmail = normalized;
          _account = null;
          _error = '找不到此 Email 對應的 PetNest 登入帳號，請確認對方已完成註冊。';
        });
        return;
      }
      if (matches.length > 1) {
        setState(() {
          _active = null;
          _lookupEmail = normalized;
          _account = null;
          _error = '此 Email 對應多個帳號，為安全起見無法轉移，請先處理帳號資料。';
        });
        return;
      }
      final QueryDocumentSnapshot<Map<String, dynamic>> doc = matches.single;
      final Map<String, dynamic> data = doc.data();
      final String storedEmail = (data['email'] ?? '').toString().trim();
      setState(() {
        _active = null;
        _lookupEmail = normalized;
        _account = _TransferTarget(
          uid: doc.id,
          name: _displayName(data),
          email: storedEmail.isEmpty ? normalized : storedEmail,
        );
        _error = doc.id == _currentUid ? '此帳號已經是目前店主' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _active = null;
        _lookupEmail = normalized;
        _account = null;
        _error = '查詢帳號失敗，請稍後再試';
      });
    }
  }

  Future<bool> _ask({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _submit(String uid, _HandoffAction action) async {
    setState(() {
      _active = action;
      _error = null;
      _success = null;
    });
    try {
      await ShopMemberPermissionService.instance.transferShopOwner(
        shopId: widget.shopId,
        newOwnerUid: uid,
      );
      if (!mounted) return;
      setState(() => _active = null);
      await _reloadShop(showSuccess: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _active = null;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _confirmTransfer() async {
    final _TransferTarget? target = _account;
    if (target == null || target.uid == _currentUid || _active != null) return;
    final bool ok = await _ask(
      title: '確認轉移店主？',
      message:
          '新店主：${target.name}／${target.email}\n'
          '前任店主將立即失去本店所有後台與員工權限。',
      confirmLabel: '確認轉移',
    );
    if (!ok || !mounted) return;
    await _submit(target.uid, _HandoffAction.transfer);
  }

  Future<void> _confirmPrevious() async {
    if (_active != null || _previousUid.isEmpty) return;
    final bool ok = await _ask(
      title: '切回上一任',
      message: '上一任店主會成為唯一店主。目前交出的帳號會立即失去本店所有後台與員工權限，不會改為員工。',
      confirmLabel: '確認切回',
    );
    if (!ok || !mounted) return;
    await _submit(_previousUid, _HandoffAction.previous);
  }

  Future<void> _confirmMe(String myUid) async {
    if (_active != null || myUid.isEmpty) return;
    final bool ok = await _ask(
      title: '暫時轉給我',
      message: '原店主會立即失去本店所有後台與員工權限。此平台帳號只是暫時接手，之後再轉出時也會退出本店後台。',
      confirmLabel: '確認接手',
    );
    if (!ok || !mounted) return;
    await _submit(myUid, _HandoffAction.temporary);
  }

  Future<void> _copyUid(String uid) async {
    await Clipboard.setData(ClipboardData(text: uid));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已複製')));
  }

  @override
  Widget build(BuildContext context) {
    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool compact = MediaQuery.sizeOf(context).width < 700;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final _TransferTarget? account = _account;
    final bool canTransfer =
        account != null && account.uid != _currentUid && _active == null;
    final bool showChangeCard = account != null && account.uid != _currentUid;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Dialog(
        insetPadding: compact
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 0 : 20),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? double.infinity : 600,
            maxHeight: compact ? screenHeight : screenHeight * 0.92,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 24,
              compact ? 12 : 24,
              compact ? 16 : 24,
              compact ? 12 : 20,
            ),
            child: Column(
              children: <Widget>[
                _Header(
                  shopName: widget.shopName,
                  onClose: _active == null
                      ? () => Navigator.of(context).pop(false)
                      : null,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: <Widget>[
                      _CurrentOwnerCard(
                        loading: _profileLoading,
                        name: _currentName,
                        email: _currentEmail,
                        uid: _currentUid,
                        onCopy: _currentUid.isEmpty
                            ? null
                            : () => _copyUid(_currentUid),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '新店主帳號',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _EmailLookup(
                        controller: _emailController,
                        busy: _active == _HandoffAction.lookup,
                        enabled: _active == null,
                        onLookup: _lookup,
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (_success != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          _success!,
                          style: const TextStyle(
                            color: Color(0xFF166534),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (account != null) ...<Widget>[
                        const SizedBox(height: 12),
                        _SelectedAccountCard(
                          account: account,
                          onCopy: () => _copyUid(account.uid),
                        ),
                      ],
                      if (showChangeCard) ...<Widget>[
                        const SizedBox(height: 12),
                        const _ChangeNotice(),
                      ],
                      const SizedBox(height: 8),
                      _OtherTools(
                        previousAvailable: _previousUid.isNotEmpty,
                        locked: _active != null,
                        temporaryBusy: _active == _HandoffAction.temporary,
                        previousBusy: _active == _HandoffAction.previous,
                        onTemporary: myUid.isEmpty
                            ? null
                            : () => _confirmMe(myUid),
                        onPrevious: _confirmPrevious,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: _active == null
                          ? () => Navigator.of(context).pop(false)
                          : null,
                      child: const Text('取消'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: canTransfer ? _confirmTransfer : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE5E7EB),
                        minimumSize: const Size(148, 44),
                      ),
                      child: _active == _HandoffAction.transfer
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('確認轉移店主'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.shopName, required this.onClose});

  final String shopName;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final String name = shopName.trim().isEmpty ? '未命名店家' : shopName.trim();
    return Row(
      children: <Widget>[
        const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFFEAF3FF),
          child: Icon(Icons.storefront_outlined, color: _kBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '轉移店主',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '關閉',
          onPressed: onClose,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _CurrentOwnerCard extends StatelessWidget {
  const _CurrentOwnerCard({
    required this.loading,
    required this.name,
    required this.email,
    required this.uid,
    required this.onCopy,
  });

  final bool loading;
  final String? name;
  final String? email;
  final String uid;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final String title = loading
        ? '帳號資料載入中'
        : (name == null || name!.trim().isEmpty ? '尚未取得帳號名稱' : name!.trim());
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
          const Text(
            '目前店主',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (email != null && email!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(email!, style: const TextStyle(color: Color(0xFF4B5563))),
          ],
          if (uid.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            _ShortUidLine(uid: uid, onCopy: onCopy),
          ],
          const SizedBox(height: 8),
          const Text(
            '完成交接後，這個帳號會立即失去本店所有後台與員工權限。',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailLookup extends StatelessWidget {
  const _EmailLookup({
    required this.controller,
    required this.busy,
    required this.enabled,
    required this.onLookup,
  });

  final TextEditingController controller;
  final bool busy;
  final bool enabled;
  final VoidCallback onLookup;

  @override
  Widget build(BuildContext context) {
    final Widget button = FilledButton(
      onPressed: enabled ? onLookup : null,
      style: FilledButton.styleFrom(
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size(96, 48),
      ),
      child: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('查詢帳號'),
    );
    final Widget field = TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: enabled ? (_) => onLookup() : null,
      decoration: const InputDecoration(
        hintText: '輸入已註冊的帳號 Email',
        prefixIcon: Icon(Icons.mail_outline),
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[field, const SizedBox(height: 8), button],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: field),
            const SizedBox(width: 8),
            button,
          ],
        );
      },
    );
  }
}

class _SelectedAccountCard extends StatelessWidget {
  const _SelectedAccountCard({required this.account, required this.onCopy});

  final _TransferTarget account;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final String letter = account.name.isEmpty
        ? '?'
        : account.name.substring(0, 1);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: const Color(0xFFDBEAFE),
            child: Text(
              letter,
              style: const TextStyle(
                color: _kBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '已選取帳號',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kBlue,
                  ),
                ),
                Text(
                  account.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  account.email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                  ),
                ),
                _ShortUidLine(uid: account.uid, onCopy: onCopy),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeNotice extends StatelessWidget {
  const _ChangeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('交接後的權限變更', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text('新帳號：成為本店唯一店主'),
          SizedBox(height: 2),
          Text('目前店主：移除本店所有後台權限'),
          SizedBox(height: 2),
          Text('一般會員資料與歷史資料：不受影響'),
        ],
      ),
    );
  }
}

class _OtherTools extends StatelessWidget {
  const _OtherTools({
    required this.previousAvailable,
    required this.locked,
    required this.temporaryBusy,
    required this.previousBusy,
    required this.onTemporary,
    required this.onPrevious,
  });

  final bool previousAvailable;
  final bool locked;
  final bool temporaryBusy;
  final bool previousBusy;
  final VoidCallback? onTemporary;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text(
          '其他交接工具',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              OutlinedButton(
                onPressed: locked ? null : onTemporary,
                child: temporaryBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('暫時轉給我'),
              ),
              const SizedBox(width: 8),
              const Text(
                '僅限平台協助處理',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: !previousAvailable || locked ? null : onPrevious,
              child: previousBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('切回上一任'),
            ),
          ),
          if (!previousAvailable) ...<Widget>[
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '找不到可安全切回的上一任店主',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ShortUidLine extends StatelessWidget {
  const _ShortUidLine({required this.uid, required this.onCopy});

  final String uid;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            'UID：${_shortUid(uid)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ),
        IconButton(
          tooltip: '複製 UID',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: onCopy,
          icon: const Icon(Icons.copy, size: 16, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }
}

String _shortUid(String uid) {
  if (uid.length <= 10) return uid;
  return '${uid.substring(0, 4)}…${uid.substring(uid.length - 4)}';
}

// 檔案名稱：lib/features/admin/pages/admin_point_redemption_list_page.dart
// 功能說明：櫃台實體商品交付工作台。搜尋領取碼或會員、核對後完成交付。

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/models/point_redemption_model.dart';
import 'package:petnest_saas/core/services/point_redemption_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

const double _desktopBreakpoint = 1000;
const double _contentMaxWidth = 1320;

class AdminPointRedemptionListPage extends StatefulWidget {
  const AdminPointRedemptionListPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<AdminPointRedemptionListPage> createState() =>
      _AdminPointRedemptionListPageState();
}

class _AdminPointRedemptionListPageState
    extends State<AdminPointRedemptionListPage> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _pendingScrollController = ScrollController();

  String? _focusId;
  PointRedemptionModel? _lookupCache;
  String? _codeNotice;

  bool _isSearching = false;
  bool _isPickingUp = false;
  bool _isCancelling = false;
  bool _isMarkingExpired = false;
  int _lookupSerial = 0;

  bool _loadingPermission = true;
  bool _hasPermission = false;
  Object? _loggedStreamError;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loadingPermission = false;
        _hasPermission = false;
      });
      return;
    }

    try {
      final Map<String, dynamic>? memberData = await ShopService.instance
          .getUserMemberInShop(shopId: widget.shopId, uid: user.uid);
      final bool hasPermission = ShopService.instance.hasPermission(
        memberData,
        ShopPermissionKeys.managePointRedemptions,
      );

      if (!mounted) return;
      setState(() {
        _loadingPermission = false;
        _hasPermission = hasPermission;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPermission = false;
        _hasPermission = false;
      });
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _pendingScrollController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _logStreamError(Object error) {
    if (identical(_loggedStreamError, error)) return;
    _loggedStreamError = error;
    debugPrint('streamShopRedemptions failed: $error');
  }

  void _onQueryChanged(String value) {
    setState(() {
      _codeNotice = null;
    });
  }

  void _clearQuery() {
    _queryController.clear();
    setState(() {
      _codeNotice = null;
      _focusId = null;
      _lookupCache = null;
    });
  }

  void _clearVerification() {
    setState(() {
      _focusId = null;
      _lookupCache = null;
    });
  }

  void _selectRedemption(PointRedemptionModel item) {
    setState(() {
      _focusId = item.id;
      _lookupCache = item;
    });
    _scrollPendingToTop();
  }

  void _scrollPendingToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pendingScrollController.hasClients) return;
      _pendingScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  List<PointRedemptionModel> _applyQuery(List<PointRedemptionModel> items) {
    final String raw = _queryController.text.trim().toLowerCase();
    if (raw.isEmpty) return items;

    final String compact = raw.replaceAll(' ', '');
    final String phoneQuery = compact.replaceAll('-', '');
    final String codeQuery = phoneQuery.toUpperCase().toLowerCase();

    return items.where((PointRedemptionModel item) {
      final String name = item.memberName.trim().toLowerCase().replaceAll(
        ' ',
        '',
      );
      final String phone = item.memberPhone
          .trim()
          .toLowerCase()
          .replaceAll(' ', '')
          .replaceAll('-', '');
      final String code = item.pickupCode
          .trim()
          .toLowerCase()
          .replaceAll(' ', '')
          .replaceAll('-', '');

      return name.contains(compact) ||
          phone.contains(phoneQuery) ||
          code.contains(codeQuery);
    }).toList();
  }

  PointRedemptionModel? _resolveFocus(List<PointRedemptionModel> items) {
    final String? focusId = _focusId;
    if (focusId == null || focusId.isEmpty) return null;

    PointRedemptionModel? resolved;
    for (final PointRedemptionModel item in items) {
      if (item.id == focusId) {
        resolved = item;
        break;
      }
    }
    resolved ??= _lookupCache?.id == focusId ? _lookupCache : null;
    if (resolved == null) return null;
    if (resolved.status == PointRedemptionStatus.pickedUp ||
        resolved.status == PointRedemptionStatus.cancelled ||
        resolved.status == PointRedemptionStatus.expired) {
      return null;
    }
    return resolved;
  }

  Future<void> _lookupCode(BuildContext searchContext) async {
    final String code = _queryController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showSnack('請先輸入領取碼、會員姓名或手機號碼');
      return;
    }
    if (_isSearching) return;

    final bool codeLike = _looksLikePickupCode(code);
    if (codeLike && _queryController.text != code) {
      _queryController.value = TextEditingValue(
        text: code,
        selection: TextSelection.collapsed(offset: code.length),
      );
    }

    final int serial = ++_lookupSerial;
    final TabController? tabs = DefaultTabController.maybeOf(searchContext);
    setState(() {
      _isSearching = true;
      _codeNotice = null;
    });

    try {
      final PointRedemptionModel? found = await PointRedemptionService.instance
          .findPendingByPickupCode(shopId: widget.shopId, pickupCode: code);

      if (!mounted || serial != _lookupSerial) return;
      if (_queryController.text.trim().toUpperCase() != code) return;

      setState(() {
        if (found == null) {
          _codeNotice = codeLike ? '找不到可領取的商品，可能是領取碼錯誤、商品已領取、已取消或已過期。' : null;
          if (codeLike) {
            _focusId = null;
            _lookupCache = null;
          }
        } else {
          _codeNotice = null;
          _focusId = found.id;
          _lookupCache = found;
        }
      });

      if (found != null) {
        tabs?.animateTo(0);
        _scrollPendingToTop();
      }
    } catch (error, stackTrace) {
      debugPrint('findPendingByPickupCode failed: $error');
      debugPrint('$stackTrace');
      if (!mounted || serial != _lookupSerial) return;
      setState(() {
        _codeNotice = '搜尋領取碼失敗，請稍後再試';
        _focusId = null;
        _lookupCache = null;
      });
    } finally {
      if (mounted && serial == _lookupSerial) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _confirmPickup(PointRedemptionModel redemption) async {
    if (_isPickingUp) return;

    if (redemption.hasExpired || !redemption.canPickup) {
      _showSnack(redemption.hasExpired ? '此商品已超過領取期限，無法完成交付' : '此商品目前無法交付');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _PickupConfirmDialog(redemption: redemption);
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isPickingUp = true;
    });

    try {
      await PointRedemptionService.instance.markAsPickedUp(
        shopId: widget.shopId,
        redemptionId: redemption.id,
      );

      if (!mounted) return;

      _queryController.clear();
      setState(() {
        _codeNotice = null;
        _focusId = null;
        _lookupCache = null;
      });
      _showSnack('已完成交付');
    } catch (error, stackTrace) {
      debugPrint('markAsPickedUp failed: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      _showSnack('完成交付失敗，請重新整理後再試');
    } finally {
      if (mounted) {
        setState(() {
          _isPickingUp = false;
        });
      }
    }
  }

  Future<void> _cancelRedemption(PointRedemptionModel redemption) async {
    if (_isCancelling) return;

    final TextEditingController reasonController = TextEditingController();
    bool refundPoints = true;

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setDialogState,
              ) {
                return AlertDialog(
                  title: const Text('取消商品兌換'),
                  content: SizedBox(
                    width: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '商品：${_displayReward(redemption)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text('會員：${_displayName(redemption)}'),
                        const SizedBox(height: 16),
                        TextField(
                          controller: reasonController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: '取消原因',
                            hintText: '例如：會員主動取消兌換',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('退回兌換點數'),
                          subtitle: Text(
                            refundPoints
                                ? '將退回 ${redemption.pointsCost} 點給會員'
                                : '取消後不會退回點數',
                          ),
                          value: refundPoints,
                          onChanged: (bool value) {
                            setDialogState(() {
                              refundPoints = value;
                            });
                          },
                        ),
                        if (!refundPoints)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '注意：選擇不退點後，會員使用的 '
                              '${redemption.pointsCost} 點不會返還。',
                              style: TextStyle(color: Colors.orange.shade900),
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text('返回'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final String reason = reasonController.text.trim();
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('請填寫取消原因')),
                          );
                          return;
                        }
                        Navigator.of(dialogContext).pop(<String, dynamic>{
                          'reason': reason,
                          'refundPoints': refundPoints,
                        });
                      },
                      child: const Text('確認取消'),
                    ),
                  ],
                );
              },
        );
      },
    );

    reasonController.dispose();

    if (result == null || !mounted) return;

    final String reason = (result['reason'] as String?)?.trim() ?? '';
    final bool shouldRefundPoints = result['refundPoints'] == true;
    if (reason.isEmpty) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      await PointRedemptionService.instance.cancelRedemption(
        shopId: widget.shopId,
        redemptionId: redemption.id,
        reason: reason,
        refundPoints: shouldRefundPoints,
      );

      if (!mounted) return;

      setState(() {
        if (_focusId == redemption.id) {
          _focusId = null;
          _lookupCache = null;
        }
      });

      _showSnack(shouldRefundPoints ? '兌換已取消，點數已退回會員' : '兌換已取消，本次未退回點數');
    } catch (error, stackTrace) {
      debugPrint('cancelRedemption failed: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      _showSnack('取消兌換失敗，請稍後再試');
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  Future<void> _markAsExpired(PointRedemptionModel redemption) async {
    if (_isMarkingExpired) return;

    if (!redemption.hasExpired) {
      _showSnack('此商品尚未超過領取期限');
      return;
    }

    if (redemption.status != PointRedemptionStatus.pendingPickup) {
      _showSnack('只有待領取商品可以標記過期');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('確認標記過期'),
          content: Text(
            '商品：${_displayReward(redemption)}\n'
            '會員：${_displayName(redemption)}\n'
            '領取碼：${_displayCode(redemption)}\n\n'
            '標記過期後，會員將無法再領取此商品。\n'
            '目前不會自動退回點數。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('返回'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('確認標記過期'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isMarkingExpired = true;
    });

    try {
      await PointRedemptionService.instance.markAsExpired(
        shopId: widget.shopId,
        redemptionId: redemption.id,
      );

      if (!mounted) return;

      setState(() {
        if (_focusId == redemption.id) {
          _focusId = null;
          _lookupCache = null;
        }
      });
      _showSnack('商品已標記為過期');
    } catch (error, stackTrace) {
      debugPrint('markAsExpired failed: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      _showSnack('標記過期失敗，請稍後再試');
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingExpired = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPermission) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('權限限制')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('你沒有實體商品核銷權限', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final String shopId = widget.shopId.trim();
    if (shopId.isEmpty) {
      return const Scaffold(body: Center(child: Text('找不到目前店家資料')));
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(title: const Text('實體商品領取')),
        body: _RedemptionWorkbench(
          shopId: shopId,
          queryController: _queryController,
          pendingScrollController: _pendingScrollController,
          searching: _isSearching,
          pickingUp: _isPickingUp,
          cancelling: _isCancelling,
          markingExpired: _isMarkingExpired,
          codeNotice: _codeNotice,
          applyQuery: _applyQuery,
          resolveFocus: _resolveFocus,
          onQueryChanged: _onQueryChanged,
          onSearch: _lookupCode,
          onClearQuery: _clearQuery,
          onSelect: _selectRedemption,
          onClearFocus: _clearVerification,
          onPickup: _confirmPickup,
          onCancel: _cancelRedemption,
          onMarkExpired: _markAsExpired,
          onStreamError: _logStreamError,
        ),
      ),
    );
  }
}

class _RedemptionWorkbench extends StatelessWidget {
  const _RedemptionWorkbench({
    required this.shopId,
    required this.queryController,
    required this.pendingScrollController,
    required this.searching,
    required this.pickingUp,
    required this.cancelling,
    required this.markingExpired,
    required this.codeNotice,
    required this.applyQuery,
    required this.resolveFocus,
    required this.onQueryChanged,
    required this.onSearch,
    required this.onClearQuery,
    required this.onSelect,
    required this.onClearFocus,
    required this.onPickup,
    required this.onCancel,
    required this.onMarkExpired,
    required this.onStreamError,
  });

  final String shopId;
  final TextEditingController queryController;
  final ScrollController pendingScrollController;
  final bool searching;
  final bool pickingUp;
  final bool cancelling;
  final bool markingExpired;
  final String? codeNotice;
  final List<PointRedemptionModel> Function(List<PointRedemptionModel> items)
  applyQuery;
  final PointRedemptionModel? Function(List<PointRedemptionModel> items)
  resolveFocus;
  final ValueChanged<String> onQueryChanged;
  final Future<void> Function(BuildContext context) onSearch;
  final VoidCallback onClearQuery;
  final ValueChanged<PointRedemptionModel> onSelect;
  final VoidCallback onClearFocus;
  final ValueChanged<PointRedemptionModel> onPickup;
  final ValueChanged<PointRedemptionModel> onCancel;
  final ValueChanged<PointRedemptionModel> onMarkExpired;
  final ValueChanged<Object> onStreamError;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PointRedemptionModel>>(
      stream: PointRedemptionService.instance.streamShopRedemptions(
        shopId: shopId,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<PointRedemptionModel>> snapshot,
          ) {
            if (snapshot.hasError) {
              onStreamError(snapshot.error ?? 'unknown');
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '實體商品紀錄讀取失敗，請重新整理後再試',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<PointRedemptionModel> all = snapshot.data!;
            final List<PointRedemptionModel> pendingAll = all
                .where(_isOpenPending)
                .toList();
            final List<PointRedemptionModel> pickedAll = all
                .where(
                  (PointRedemptionModel item) =>
                      item.status == PointRedemptionStatus.pickedUp,
                )
                .toList();
            final List<PointRedemptionModel> cancelledAll = all
                .where(
                  (PointRedemptionModel item) =>
                      item.status == PointRedemptionStatus.cancelled,
                )
                .toList();
            final List<PointRedemptionModel> expiredAll = all
                .where(_isExpiredBucket)
                .toList();
            final int dueSoonCount = pendingAll.where(_isDueSoon).length;
            final int deliveredTodayCount = pickedAll
                .where(_isDeliveredToday)
                .length;
            final bool queried = queryController.text.trim().isNotEmpty;
            final PointRedemptionModel? focus = resolveFocus(all);

            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double viewport = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : _contentMaxWidth;
                final double contentWidth = viewport > _contentMaxWidth
                    ? _contentMaxWidth
                    : viewport;
                final double height = constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : 640;
                final bool desktop = viewport >= _desktopBreakpoint;

                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: contentWidth,
                    height: height,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Material(
                          color: Colors.white,
                          child: TabBar(
                            isScrollable: !desktop,
                            tabAlignment: desktop
                                ? TabAlignment.fill
                                : TabAlignment.start,
                            tabs: <Widget>[
                              Tab(text: '待領取 ${pendingAll.length}'),
                              Tab(text: '已領取 ${pickedAll.length}'),
                              Tab(text: '已取消 ${cancelledAll.length}'),
                              Tab(text: '已過期 ${expiredAll.length}'),
                            ],
                          ),
                        ),
                        _PickupWorkbenchHeader(
                          pendingCount: pendingAll.length,
                          dueSoonCount: dueSoonCount,
                          deliveredTodayCount: deliveredTodayCount,
                          controller: queryController,
                          searching: searching,
                          notice: codeNotice,
                          onChanged: onQueryChanged,
                          onSearch: onSearch,
                          onClear: onClearQuery,
                        ),
                        Expanded(
                          child: TabBarView(
                            children: <Widget>[
                              _PendingWorkbench(
                                desktop: desktop,
                                items: applyQuery(pendingAll),
                                focus: focus,
                                queried: queried,
                                pickingUp: pickingUp,
                                cancelling: cancelling,
                                scrollController: pendingScrollController,
                                onSelect: onSelect,
                                onPickup: onPickup,
                                onCancel: onCancel,
                                onClearFocus: onClearFocus,
                              ),
                              _HistoryList(
                                kind: _HistoryKind.pickedUp,
                                items: applyQuery(pickedAll),
                                filtered: queried,
                                emptyTitle: '目前沒有已領取紀錄',
                                markingExpired: markingExpired,
                                onMarkExpired: onMarkExpired,
                              ),
                              _HistoryList(
                                kind: _HistoryKind.cancelled,
                                items: applyQuery(cancelledAll),
                                filtered: queried,
                                emptyTitle: '目前沒有已取消紀錄',
                                markingExpired: markingExpired,
                                onMarkExpired: onMarkExpired,
                              ),
                              _HistoryList(
                                kind: _HistoryKind.expired,
                                items: applyQuery(expiredAll),
                                filtered: queried,
                                emptyTitle: '目前沒有已過期紀錄',
                                markingExpired: markingExpired,
                                onMarkExpired: onMarkExpired,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
    );
  }
}

class _PickupWorkbenchHeader extends StatelessWidget {
  const _PickupWorkbenchHeader({
    required this.pendingCount,
    required this.dueSoonCount,
    required this.deliveredTodayCount,
    required this.controller,
    required this.searching,
    required this.notice,
    required this.onChanged,
    required this.onSearch,
    required this.onClear,
  });

  final int pendingCount;
  final int dueSoonCount;
  final int deliveredTodayCount;
  final TextEditingController controller;
  final bool searching;
  final String? notice;
  final ValueChanged<String> onChanged;
  final Future<void> Function(BuildContext context) onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool hasText = controller.text.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wideStats = constraints.maxWidth >= 860;
        final bool inlineSearch = constraints.maxWidth >= 640;
        final Widget titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '櫃台快速領取',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '輸入領取碼、會員姓名或手機號碼，快速核對後完成交付。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        );
        final Widget stats = _StatWrap(
          pendingCount: pendingCount,
          dueSoonCount: dueSoonCount,
          deliveredTodayCount: deliveredTodayCount,
        );
        final Widget field = TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: onChanged,
          onSubmitted: (_) {
            onSearch(context);
          },
          decoration: InputDecoration(
            hintText: '輸入領取碼、會員姓名或手機號碼',
            prefixIcon: const Icon(Icons.person_search_outlined),
            suffixIcon: hasText
                ? IconButton(
                    tooltip: '清除',
                    onPressed: onClear,
                    icon: const Icon(Icons.clear),
                  )
                : null,
            filled: true,
            fillColor: scheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        );
        final Widget searchButton = FilledButton.icon(
          onPressed: searching ? null : () => onSearch(context),
          icon: searching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
          label: const Text('搜尋'),
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (wideStats)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: titleBlock),
                        const SizedBox(width: 16),
                        stats,
                      ],
                    )
                  else ...<Widget>[
                    titleBlock,
                    const SizedBox(height: 12),
                    stats,
                  ],
                  const SizedBox(height: 14),
                  if (inlineSearch)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: field),
                        const SizedBox(width: 8),
                        searchButton,
                      ],
                    )
                  else ...<Widget>[
                    field,
                    const SizedBox(height: 8),
                    searchButton,
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '可直接貼上領取碼；使用掃碼槍時，先點選此欄位再掃描，掃碼槍會自動輸入並送出。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (notice != null && notice!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: scheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                notice!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatWrap extends StatelessWidget {
  const _StatWrap({
    required this.pendingCount,
    required this.dueSoonCount,
    required this.deliveredTodayCount,
  });

  final int pendingCount;
  final int dueSoonCount;
  final int deliveredTodayCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _MiniStat(label: '待領取 $pendingCount 筆'),
        _MiniStat(label: '即將到期 $dueSoonCount 筆', highlight: dueSoonCount > 0),
        _MiniStat(label: '今日已交付 $deliveredTodayCount 筆'),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final Color foreground = highlight
        ? Colors.orange.shade900
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final Color background = highlight
        ? Colors.orange.shade50
        : Colors.grey.shade100;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PendingWorkbench extends StatelessWidget {
  const _PendingWorkbench({
    required this.desktop,
    required this.items,
    required this.focus,
    required this.queried,
    required this.pickingUp,
    required this.cancelling,
    required this.scrollController,
    required this.onSelect,
    required this.onPickup,
    required this.onCancel,
    required this.onClearFocus,
  });

  final bool desktop;
  final List<PointRedemptionModel> items;
  final PointRedemptionModel? focus;
  final bool queried;
  final bool pickingUp;
  final bool cancelling;
  final ScrollController scrollController;
  final ValueChanged<PointRedemptionModel> onSelect;
  final ValueChanged<PointRedemptionModel> onPickup;
  final ValueChanged<PointRedemptionModel> onCancel;
  final VoidCallback onClearFocus;

  @override
  Widget build(BuildContext context) {
    if (desktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(flex: 42, child: _buildDesktopList()),
            const SizedBox(width: 12),
            Expanded(flex: 58, child: _buildSidePanel()),
          ],
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        if (focus != null) ...<Widget>[
          _PickupVerificationPanel(
            redemption: focus!,
            pickingUp: pickingUp,
            onDeliver: () => onPickup(focus!),
            onClear: onClearFocus,
          ),
          const SizedBox(height: 12),
        ],
        if (items.isEmpty && focus == null)
          _pendingEmpty(hasFocus: false)
        else
          for (int index = 0; index < items.length; index++) ...<Widget>[
            _buildTile(items[index]),
            if (index != items.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _buildDesktopList() {
    if (items.isEmpty) {
      return Center(child: _pendingEmpty(hasFocus: focus != null));
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: items.length,
      separatorBuilder: (BuildContext context, int index) {
        return const SizedBox(height: 8);
      },
      itemBuilder: (BuildContext context, int index) {
        return _buildTile(items[index]);
      },
    );
  }

  Widget _buildSidePanel() {
    final PointRedemptionModel? current = focus;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: width),
            child: current == null
                ? const _VerifyGuide()
                : _PickupVerificationPanel(
                    redemption: current,
                    pickingUp: pickingUp,
                    onDeliver: () => onPickup(current),
                    onClear: onClearFocus,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildTile(PointRedemptionModel item) {
    return _PendingRedemptionTile(
      redemption: item,
      selected: focus?.id == item.id,
      pickingUp: pickingUp,
      cancelling: cancelling,
      onSelect: () => onSelect(item),
      onDeliver: () => onPickup(item),
      onCancel: () => onCancel(item),
    );
  }

  Widget _pendingEmpty({required bool hasFocus}) {
    if (hasFocus) {
      return const _EmptyView(
        icon: Icons.fact_check_outlined,
        title: '請依右側核對卡確認',
        message: '這筆商品未列在待領取清單，請使用核對卡確認狀態。',
      );
    }
    if (queried) {
      return const _EmptyView(
        icon: Icons.search_off,
        title: '找不到符合的待領取紀錄',
        message: '可嘗試完整手機號碼或領取碼',
      );
    }
    return const _EmptyView(
      icon: Icons.inventory_2_outlined,
      title: '目前沒有待領取商品',
      message: '會員兌換的實體商品會顯示在這裡，店員可用領取碼完成交付。',
    );
  }
}

class _VerifyGuide extends StatelessWidget {
  const _VerifyGuide();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.fact_check_outlined, size: 36, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              '選擇一筆待領取商品，或使用上方搜尋領取碼',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _PickupVerificationPanel extends StatelessWidget {
  const _PickupVerificationPanel({
    required this.redemption,
    required this.pickingUp,
    required this.onDeliver,
    required this.onClear,
  });

  final PointRedemptionModel redemption;
  final bool pickingUp;
  final VoidCallback onDeliver;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool blocked = redemption.hasExpired || !redemption.canPickup;
    final String? inventory = _inventoryLabel(redemption);
    final String note = redemption.fulfillmentNote.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE7F6EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9FCBB4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '已找到待領取商品',
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF146C43),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _RewardImage(imageUrl: redemption.rewardImageUrl, size: 88),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _displayReward(redemption),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ExpiryStatus(redemption: redemption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _FactRow(label: '會員姓名', value: _displayName(redemption)),
            _FactRow(label: '會員電話', value: _displayPhone(redemption)),
            _FactRow(label: '領取碼', value: _displayCode(redemption), mono: true),
            _FactRow(label: '領取期限', value: _expireText(redemption.expireAt)),
            _FactRow(label: '兌換點數', value: '${redemption.pointsCost} 點'),
            if (note.isNotEmpty) _FactRow(label: '領取說明', value: note),
            if (inventory != null) _FactRow(label: '庫存', value: inventory),
            if (blocked) ...<Widget>[
              const SizedBox(height: 4),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    redemption.hasExpired ? '此商品已超過領取期限，無法完成交付' : '此商品目前無法交付',
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: blocked || pickingUp ? null : onDeliver,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: pickingUp
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(pickingUp ? '交付中…' : '核對完成，交付商品'),
            ),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: onClear,
                child: const Text('清除本次核對'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      fontFamily: 'monospace',
                      height: 1.2,
                    )
                  : theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingRedemptionTile extends StatelessWidget {
  const _PendingRedemptionTile({
    required this.redemption,
    required this.selected,
    required this.pickingUp,
    required this.cancelling,
    required this.onSelect,
    required this.onDeliver,
    required this.onCancel,
  });

  final PointRedemptionModel redemption;
  final bool selected;
  final bool pickingUp;
  final bool cancelling;
  final VoidCallback onSelect;
  final VoidCallback onDeliver;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool canDeliver = redemption.canPickup && !redemption.hasExpired;

    return Material(
      color: selected ? scheme.primaryContainer : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? scheme.primary : Colors.grey.shade300,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stacked = constraints.maxWidth < 560;
              final Widget details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _displayReward(redemption),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _memberSummary(redemption),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '領取碼 ${_displayCode(redemption)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ExpiryStatus(redemption: redemption),
                ],
              );
              final Widget deliverButton = FilledButton(
                onPressed: !canDeliver || pickingUp ? null : onDeliver,
                style: FilledButton.styleFrom(
                  minimumSize: Size(stacked ? double.infinity : 0, 40),
                ),
                child: const Text('確認交付'),
              );
              final Widget menu = PopupMenuButton<String>(
                tooltip: '更多操作',
                icon: const Icon(Icons.more_vert),
                onSelected: (String value) {
                  if (cancelling) return;
                  if (value == 'cancel') onCancel();
                },
                itemBuilder: (BuildContext context) {
                  return <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'cancel',
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.cancel_outlined,
                            size: 18,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '取消兌換',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _RewardImage(
                          imageUrl: redemption.rewardImageUrl,
                          size: 52,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: details),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(child: deliverButton),
                        menu,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  _RewardImage(imageUrl: redemption.rewardImageUrl, size: 52),
                  const SizedBox(width: 10),
                  Expanded(child: details),
                  const SizedBox(width: 8),
                  deliverButton,
                  menu,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _HistoryKind { pickedUp, cancelled, expired }

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.kind,
    required this.items,
    required this.filtered,
    required this.emptyTitle,
    required this.markingExpired,
    required this.onMarkExpired,
  });

  final _HistoryKind kind;
  final List<PointRedemptionModel> items;
  final bool filtered;
  final String emptyTitle;
  final bool markingExpired;
  final ValueChanged<PointRedemptionModel> onMarkExpired;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: _EmptyView(
          icon: Icons.receipt_long_outlined,
          title: filtered ? '找不到符合的紀錄' : emptyTitle,
          message: filtered ? '可嘗試完整手機號碼或領取碼' : null,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (BuildContext context, int index) {
        return const SizedBox(height: 8);
      },
      itemBuilder: (BuildContext context, int index) {
        final PointRedemptionModel item = items[index];
        final bool unmarked =
            item.status == PointRedemptionStatus.pendingPickup &&
            item.hasExpired;
        return _RedemptionHistoryTile(
          redemption: item,
          kind: kind,
          markingExpired: markingExpired,
          onMarkExpired: unmarked ? () => onMarkExpired(item) : null,
        );
      },
    );
  }
}

class _RedemptionHistoryTile extends StatelessWidget {
  const _RedemptionHistoryTile({
    required this.redemption,
    required this.kind,
    required this.markingExpired,
    required this.onMarkExpired,
  });

  final PointRedemptionModel redemption;
  final _HistoryKind kind;
  final bool markingExpired;
  final VoidCallback? onMarkExpired;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _RewardImage(imageUrl: redemption.rewardImageUrl, size: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _displayReward(redemption),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ..._facts(theme),
                  const SizedBox(height: 8),
                  _historyPills(),
                  if (onMarkExpired != null) ...<Widget>[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: markingExpired ? null : onMarkExpired,
                      child: const Text('正式標記為已過期'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _facts(ThemeData theme) {
    final List<Widget> lines = <Widget>[
      _historyLine('會員', _memberSummary(redemption), theme),
    ];

    switch (kind) {
      case _HistoryKind.pickedUp:
        lines.add(_historyLine('領取碼', _displayCode(redemption), theme));
        lines.add(
          _historyLine(
            '交付時間',
            redemption.pickedUpAt == null
                ? '未記錄交付時間'
                : _dateTimeText(redemption.pickedUpAt),
            theme,
          ),
        );
        final String operatorName = redemption.pickedUpBy.trim();
        if (operatorName.isNotEmpty) {
          lines.add(_historyLine('操作者', operatorName, theme));
        }
      case _HistoryKind.cancelled:
        if (redemption.cancelledAt != null) {
          lines.add(
            _historyLine('取消時間', _dateTimeText(redemption.cancelledAt), theme),
          );
        }
        lines.add(_historyLine('取消原因', _displayReason(redemption), theme));
      case _HistoryKind.expired:
        lines.add(_historyLine('領取碼', _displayCode(redemption), theme));
        lines.add(
          _historyLine('領取期限', _expireText(redemption.expireAt), theme),
        );
    }

    return lines;
  }

  Widget _historyLine(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text('$label：$value', style: theme.textTheme.bodyMedium),
    );
  }

  Widget _historyPills() {
    switch (kind) {
      case _HistoryKind.pickedUp:
        return const _StatusPill(
          label: '已領取',
          foreground: Color(0xFF146C43),
          background: Color(0xFFDDF3E6),
        );
      case _HistoryKind.cancelled:
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            const _StatusPill(
              label: '已取消',
              foreground: Color(0xFF4B5563),
              background: Color(0xFFE5E7EB),
            ),
            _StatusPill(
              label: redemption.pointsRefunded ? '點數已退回' : '點數未退回',
              foreground: redemption.pointsRefunded
                  ? const Color(0xFF146C43)
                  : const Color(0xFF9A3412),
              background: redemption.pointsRefunded
                  ? const Color(0xFFDDF3E6)
                  : const Color(0xFFFFEDD5),
            ),
          ],
        );
      case _HistoryKind.expired:
        final bool unmarked =
            redemption.status == PointRedemptionStatus.pendingPickup &&
            redemption.hasExpired;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            const _StatusPill(
              label: '逾期未領取',
              foreground: Color(0xFF991B1B),
              background: Color(0xFFFEE2E2),
            ),
            if (unmarked)
              const _StatusPill(
                label: '尚未完成系統標記',
                foreground: Color(0xFF9A3412),
                background: Color(0xFFFFEDD5),
              ),
          ],
        );
    }
  }
}

class _ExpiryStatus extends StatelessWidget {
  const _ExpiryStatus({required this.redemption});

  final PointRedemptionModel redemption;

  @override
  Widget build(BuildContext context) {
    final _ExpiryTone tone = _expiryTone(redemption);
    final String dateText = _dateTimeText(redemption.expireAt);
    switch (tone) {
      case _ExpiryTone.forever:
        return const _StatusPill(
          label: '永久有效',
          foreground: Color(0xFF4B5563),
          background: Color(0xFFE5E7EB),
        );
      case _ExpiryTone.today:
        return _toneWithDate(
          context,
          const _StatusPill(
            label: '今日到期',
            foreground: Color(0xFF9A3412),
            background: Color(0xFFFFEDD5),
          ),
          dateText,
        );
      case _ExpiryTone.soon:
        return _toneWithDate(
          context,
          const _StatusPill(
            label: '即將到期',
            foreground: Color(0xFF92400E),
            background: Color(0xFFFEF3C7),
          ),
          dateText,
        );
      case _ExpiryTone.later:
        return _toneWithDate(
          context,
          const _StatusPill(
            label: '期限內',
            foreground: Color(0xFF4B5563),
            background: Color(0xFFE5E7EB),
          ),
          dateText,
        );
      case _ExpiryTone.expired:
        return _toneWithDate(
          context,
          const _StatusPill(
            label: '已過期',
            foreground: Color(0xFF991B1B),
            background: Color(0xFFFEE2E2),
          ),
          dateText,
        );
    }
  }

  Widget _toneWithDate(BuildContext context, Widget pill, String dateText) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        pill,
        Text(dateText, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _RewardImage extends StatelessWidget {
  const _RewardImage({required this.imageUrl, this.size = 56});

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl.trim();
    if (url.isEmpty) {
      return _RewardFallback(size: size);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder:
            (BuildContext context, Widget child, ImageChunkEvent? progress) {
              if (progress == null) return child;
              return _RewardFallback(size: size, loading: true);
            },
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
              return _RewardFallback(size: size);
            },
      ),
    );
  }
}

class _RewardFallback extends StatelessWidget {
  const _RewardFallback({required this.size, this.loading = false});

  final double size;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: loading
          ? SizedBox(
              width: size * 0.32,
              height: size * 0.32,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.inventory_2_outlined,
              size: size * 0.42,
              color: Colors.grey.shade600,
            ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? detail = message?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 42, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (detail != null && detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickupConfirmDialog extends StatefulWidget {
  const _PickupConfirmDialog({required this.redemption});

  final PointRedemptionModel redemption;

  @override
  State<_PickupConfirmDialog> createState() => _PickupConfirmDialogState();
}

class _PickupConfirmDialogState extends State<_PickupConfirmDialog> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final PointRedemptionModel redemption = widget.redemption;
    final ThemeData theme = Theme.of(context);
    final String? inventory = _inventoryLabel(redemption);

    return AlertDialog(
      scrollable: true,
      title: const Text('確認交付商品'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('商品', style: theme.textTheme.labelLarge),
            const SizedBox(height: 2),
            Text(
              _displayReward(redemption),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text('會員', style: theme.textTheme.labelLarge),
            const SizedBox(height: 2),
            Text(_memberDialogLine(redemption)),
            const SizedBox(height: 12),
            Text('領取碼', style: theme.textTheme.labelLarge),
            const SizedBox(height: 2),
            Text(
              _displayCode(redemption),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            Text('領取期限', style: theme.textTheme.labelLarge),
            const SizedBox(height: 2),
            Text(_expireText(redemption.expireAt)),
            if (inventory != null) ...<Widget>[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('此商品已連動庫存。交付完成後，系統會依既有規則處理庫存，請勿另外手動扣庫存。'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _checked,
              onChanged: (bool? value) {
                setState(() {
                  _checked = value ?? false;
                });
              },
              title: const Text('我已核對會員身分與商品內容'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: const Text('返回'),
        ),
        FilledButton(
          onPressed: _checked
              ? () {
                  Navigator.of(context).pop(true);
                }
              : null,
          child: const Text('完成交付'),
        ),
      ],
    );
  }
}

enum _ExpiryTone { forever, later, soon, today, expired }

bool _isOpenPending(PointRedemptionModel item) {
  return item.status == PointRedemptionStatus.pendingPickup && !item.hasExpired;
}

bool _isExpiredBucket(PointRedemptionModel item) {
  return item.status == PointRedemptionStatus.expired ||
      (item.status == PointRedemptionStatus.pendingPickup && item.hasExpired);
}

bool _isDueSoon(PointRedemptionModel item) {
  final DateTime? expireAt = item.expireAt;
  if (expireAt == null || item.hasExpired) return false;
  final int days = _calendarDaysUntil(expireAt);
  return days >= 0 && days <= 3;
}

bool _isDeliveredToday(PointRedemptionModel item) {
  return item.status == PointRedemptionStatus.pickedUp &&
      _isLocalToday(item.pickedUpAt);
}

bool _looksLikePickupCode(String value) {
  final String compact = value.trim().toUpperCase().replaceAll(
    RegExp(r'[\s-]'),
    '',
  );
  if (!RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(compact)) return false;
  if (compact.length == 8) return true;
  return RegExp(r'[A-Z]').hasMatch(compact);
}

int _calendarDaysUntil(DateTime expireAt) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime local = expireAt.toLocal();
  final DateTime expireDay = DateTime(local.year, local.month, local.day);
  return expireDay.difference(today).inDays;
}

bool _isLocalToday(DateTime? value) {
  if (value == null) return false;
  final DateTime now = DateTime.now();
  final DateTime local = value.toLocal();
  return local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
}

_ExpiryTone _expiryTone(PointRedemptionModel item) {
  final DateTime? expireAt = item.expireAt;
  if (expireAt == null) return _ExpiryTone.forever;
  final int days = _calendarDaysUntil(expireAt);
  if (item.hasExpired || days < 0) return _ExpiryTone.expired;
  if (days == 0) return _ExpiryTone.today;
  if (days <= 3) return _ExpiryTone.soon;
  return _ExpiryTone.later;
}

String _displayReward(PointRedemptionModel item) {
  final String name = item.rewardName.trim();
  if (name.isEmpty) return '未命名商品';
  return name;
}

String _displayName(PointRedemptionModel item) {
  final String name = item.memberName.trim();
  if (name.isEmpty) return '未提供會員姓名';
  return name;
}

String _displayPhone(PointRedemptionModel item) {
  final String phone = item.memberPhone.trim();
  if (phone.isEmpty) return '未提供電話';
  return phone;
}

String _displayCode(PointRedemptionModel item) {
  final String code = item.pickupCode.trim();
  if (code.isEmpty) return '未提供';
  return code;
}

String _displayReason(PointRedemptionModel item) {
  final String reason = item.cancelReason.trim();
  if (reason.isEmpty) return '未填寫取消原因';
  return reason;
}

String _memberSummary(PointRedemptionModel item) {
  return '${_displayName(item)} · ${_displayPhone(item)}';
}

String _memberDialogLine(PointRedemptionModel item) {
  final String phone = item.memberPhone.trim();
  if (phone.isEmpty) return '${_displayName(item)}／未提供電話';
  return '${_displayName(item)}／$phone';
}

String? _inventoryLabel(PointRedemptionModel item) {
  if (!item.useCentralInventory) return null;
  final String name = item.inventoryItemName.trim();
  if (name.isEmpty) return '已連動中央庫存';
  final String quantity = _quantityText(item.inventoryQuantity);
  final String unit = item.inventoryUnit.trim();
  if (unit.isEmpty) return '已連動庫存：$name × $quantity';
  return '已連動庫存：$name × $quantity$unit';
}

String _quantityText(num value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

String _expireText(DateTime? value) {
  if (value == null) return '永久有效';
  return _dateTimeText(value);
}

String _dateTimeText(DateTime? value) {
  if (value == null) return '未記錄';
  final DateTime local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

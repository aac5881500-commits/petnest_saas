// 檔案名稱：lib/features/admin/widgets/settlement_next_action_view.dart
// 功能說明：手機底部與桌機右側的結算下一步。只轉呼叫既有 handler。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/admin/models/settlement_next_action.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/settlement_action_runner.dart';

class SettlementNextActionView extends StatefulWidget {
  const SettlementNextActionView({
    super.key,
    required this.action,
    required this.shopId,
    required this.bookingId,
    required this.data,
    this.onCheckout,
    this.onAdjust,
    this.bar = false,
  });

  static const Key slotKey = ValueKey<String>('settlement-next-action');

  final SettlementNextAction action;
  final String shopId;
  final String bookingId;
  final Map<String, dynamic> data;
  final Future<void> Function()? onCheckout;
  final Future<void> Function()? onAdjust;
  final bool bar;

  @override
  State<SettlementNextActionView> createState() =>
      _SettlementNextActionViewState();
}

class _SettlementNextActionViewState extends State<SettlementNextActionView> {
  bool _busy = false;

  SettlementActionRunner get _runner => SettlementActionRunner(
    shopId: widget.shopId,
    bookingId: widget.bookingId,
    data: widget.data,
  );

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _primary() {
    final SettlementNextAction action = widget.action;
    final int amount = action.amount ?? 0;
    switch (action.kind) {
      case SettlementNextActionKind.checkoutOrSettle:
        return widget.onCheckout?.call() ?? Future<void>.value();
      case SettlementNextActionKind.reviewCustomerProof:
        return _runner.reviewTransfer(context);
      case SettlementNextActionKind.confirmCashReceived:
        return _runner.collect(context, amount);
      case SettlementNextActionKind.confirmTransferReceived:
        return _runner.staffVerifyTransfer(context, amount);
      case SettlementNextActionKind.confirmRefund:
        return _runner.refund(context, amount);
      case SettlementNextActionKind.finalizeOrder:
        return _runner.lockNoTopUp(context);
      case SettlementNextActionKind.waitingCustomerPayment:
      case SettlementNextActionKind.none:
        return Future<void>.value();
    }
  }

  Future<void> _secondary(SettlementSecondaryAction action) {
    final int amount = widget.action.amount ?? 0;
    switch (action) {
      case SettlementSecondaryAction.adjust:
        if (widget.onAdjust != null) {
          return widget.onAdjust!.call();
        }
        return _runner.adjust(context);
      case SettlementSecondaryAction.switchMethod:
        return _runner.switchMethod(context, amount);
      case SettlementSecondaryAction.staffVerify:
        return _runner.staffVerifyTransfer(context, amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SettlementNextAction action = widget.action;
    if (!action.visible) {
      return const SizedBox.shrink();
    }
    final Widget body = _body(action);
    if (widget.bar) {
      return Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: body,
          ),
        ),
      );
    }
    return AdminBookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '下一步',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }

  Widget _body(SettlementNextAction action) {
    final List<SettlementSecondaryAction> extras = action.secondaries;
    final List<SettlementSecondaryAction> inline = extras
        .take(2)
        .toList(growable: false);
    final List<SettlementSecondaryAction> more = extras.length <= 2
        ? const <SettlementSecondaryAction>[]
        : extras.skip(2).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (action.title.isNotEmpty)
          Text(
            action.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        if (action.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              action.description,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
        if (action.hasPrimary) ...<Widget>[
          const SizedBox(height: 10),
          FilledButton(
            style: action.kind == SettlementNextActionKind.checkoutOrSettle
                ? FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  )
                : null,
            onPressed: !action.enabled || _busy ? null : () => _run(_primary),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(action.primaryLabel),
          ),
        ],
        if (inline.isNotEmpty || more.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              for (final SettlementSecondaryAction item in inline) ...<Widget>[
                if (item != inline.first) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => _secondary(item)),
                    child: Text(_secondaryLabel(item)),
                  ),
                ),
              ],
              if (more.isNotEmpty) ...<Widget>[
                const SizedBox(width: 8),
                PopupMenuButton<SettlementSecondaryAction>(
                  enabled: !_busy,
                  tooltip: '更多',
                  onSelected: (SettlementSecondaryAction value) {
                    _run(() => _secondary(value));
                  },
                  itemBuilder: (BuildContext context) {
                    return more
                        .map(
                          (SettlementSecondaryAction item) =>
                              PopupMenuItem<SettlementSecondaryAction>(
                                value: item,
                                child: Text(_secondaryLabel(item)),
                              ),
                        )
                        .toList();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Text('更多'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  String _secondaryLabel(SettlementSecondaryAction action) {
    switch (action) {
      case SettlementSecondaryAction.adjust:
        return '調整結算';
      case SettlementSecondaryAction.switchMethod:
        return '更換補款方式';
      case SettlementSecondaryAction.staffVerify:
        return '現場已核對入帳';
    }
  }
}

// 檔案名稱：lib/features/shop/widgets/booking/booking_points_redeem_section.dart
// 功能說明：下單頁優惠券下的點數折抵；可輸入部分點數或全部使用。結算頁不使用。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/models/point_setting_model.dart';
import 'package:petnest_saas/core/services/member_point_service.dart';
import 'package:petnest_saas/core/services/point_setting_service.dart';

class BookingPointsRedeemSection extends StatelessWidget {
  const BookingPointsRedeemSection({
    super.key,
    required this.shopId,
    required this.userId,
    required this.channel,
    required this.payableAfterCoupon,
    required this.requestedPoints,
    required this.onRequestedPointsChanged,
    this.onPreview,
    this.member,
    this.enabledOverride,
  });

  final String shopId;
  final String userId;
  final String channel;
  final int payableAfterCoupon;
  final int requestedPoints;
  final ValueChanged<int> onRequestedPointsChanged;
  final void Function(int pointAmountNtd, int pointsUsed)? onPreview;
  final Map<String, dynamic>? member;
  final bool? enabledOverride;

  bool get _walkIn => member != null && member!['isTempAdminMember'] == true;

  void _emitZero() {
    onRequestedPointsChanged(0);
    onPreview?.call(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    if (userId.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    if (_walkIn) {
      if (requestedPoints != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _emitZero());
      }
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          '此會員尚未註冊 App，無法使用或累積點數',
          style: TextStyle(color: Color(0xFFB45309)),
        ),
      );
    }
    return StreamBuilder<PointSettingModel>(
      stream: PointSettingService.instance.streamPointSetting(shopId),
      builder:
          (BuildContext context, AsyncSnapshot<PointSettingModel> settingSnap) {
            final PointSettingModel? setting = settingSnap.data;
            final bool channelOn =
                setting != null && setting.canSpendOn(channel);
            if (enabledOverride == false || setting == null || !channelOn) {
              if (requestedPoints != 0) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _emitZero(),
                );
              }
              return const SizedBox.shrink();
            }
            return StreamBuilder(
              stream: MemberPointService.instance.streamMemberPoint(
                shopId: shopId,
                userId: userId,
              ),
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                final int balance = snapshot.hasData
                    ? (snapshot.data.currentPoints as int)
                    : 0;
                return _BookingPointsRedeemEditor(
                  setting: setting,
                  balance: balance,
                  payableAfterCoupon: payableAfterCoupon,
                  requestedPoints: requestedPoints,
                  onRequestedPointsChanged: onRequestedPointsChanged,
                  onPreview: onPreview,
                );
              },
            );
          },
    );
  }
}

class _BookingPointsRedeemEditor extends StatefulWidget {
  const _BookingPointsRedeemEditor({
    required this.setting,
    required this.balance,
    required this.payableAfterCoupon,
    required this.requestedPoints,
    required this.onRequestedPointsChanged,
    this.onPreview,
  });

  final PointSettingModel setting;
  final int balance;
  final int payableAfterCoupon;
  final int requestedPoints;
  final ValueChanged<int> onRequestedPointsChanged;
  final void Function(int pointAmountNtd, int pointsUsed)? onPreview;

  @override
  State<_BookingPointsRedeemEditor> createState() =>
      _BookingPointsRedeemEditorState();
}

class _BookingPointsRedeemEditorState
    extends State<_BookingPointsRedeemEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.requestedPoints > 0;
    _controller = TextEditingController(
      text: _enabled && widget.requestedPoints > 0
          ? '${widget.requestedPoints}'
          : '',
    );
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
  }

  @override
  void didUpdateWidget(covariant _BookingPointsRedeemEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final PointSpendCap cap = _capFor(widget.requestedPoints);
    if (oldWidget.payableAfterCoupon != widget.payableAfterCoupon ||
        oldWidget.balance != widget.balance) {
      if (_enabled && cap.pointsUsed != widget.requestedPoints) {
        _controller.text = cap.pointsUsed > 0 ? '${cap.pointsUsed}' : '';
        WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  PointSpendCap _capFor(int requested) {
    return widget.setting.capSpend(
      requestedPoints: requested,
      balance: widget.balance,
      payableAfterCoupon: widget.payableAfterCoupon,
    );
  }

  int get _maxPoints {
    return _capFor(1 << 30).pointsUsed;
  }

  void _publish() {
    if (!_enabled) {
      widget.onRequestedPointsChanged(0);
      widget.onPreview?.call(0, 0);
      return;
    }
    final int typed = int.tryParse(_controller.text.trim()) ?? 0;
    final PointSpendCap cap = _capFor(typed);
    if (typed != cap.pointsUsed && _controller.text.trim().isNotEmpty) {
      _controller.value = TextEditingValue(
        text: cap.pointsUsed > 0 ? '${cap.pointsUsed}' : '',
        selection: TextSelection.collapsed(
          offset: cap.pointsUsed > 0 ? '${cap.pointsUsed}'.length : 0,
        ),
      );
    }
    widget.onRequestedPointsChanged(cap.pointsUsed);
    widget.onPreview?.call(cap.pointAmount, cap.pointsUsed);
  }

  void _useAll() {
    final int max = _maxPoints;
    setState(() {
      _enabled = max > 0;
      _controller.text = max > 0 ? '$max' : '';
    });
    _publish();
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.setting.pointName.trim().isEmpty
        ? '點'
        : widget.setting.pointName.trim();
    final int per = widget.setting.spendRatePointsPerNtd;
    final PointSpendCap live = _enabled
        ? _capFor(int.tryParse(_controller.text.trim()) ?? 0)
        : const PointSpendCap(pointAmount: 0, pointsUsed: 0);
    final int maxPoints = _maxPoints;
    final int maxNtd = maxPoints ~/ (per > 0 ? per : 1);
    final bool canUse = widget.balance > 0 && maxPoints > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('使用點數折抵'),
            subtitle: Text('目前可用餘額 ${widget.balance} $name'),
            value: _enabled && canUse,
            onChanged: !canUse
                ? null
                : (bool value) {
                    setState(() {
                      _enabled = value;
                      if (!value) {
                        _controller.clear();
                      } else if (_controller.text.trim().isEmpty &&
                          maxPoints > 0) {
                        _controller.text = '$maxPoints';
                      }
                    });
                    _publish();
                  },
          ),
          Text(
            '$per $name＝NT\$1。先套用優惠券再折抵。',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          if (_enabled && canUse) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: '本次使用點數',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(_publish),
                  ),
                ),
                TextButton(onPressed: _useAll, child: const Text('全部使用')),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '本次使用 ${live.pointsUsed} 點，折抵 NT\$${live.pointAmount}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '最多可使用 $maxPoints 點／最多可折抵 NT\$$maxNtd',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }
}

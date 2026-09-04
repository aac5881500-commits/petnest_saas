// lib/features/member/pages/member_point_detail_page.dart
// 🪙 會員店家點數詳細頁

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/member_point_log_model.dart';
import 'package:petnest_saas/core/models/member_point_model.dart';
import 'package:petnest_saas/core/models/point_setting_model.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/member_point_service.dart';
import 'package:petnest_saas/core/services/point_setting_service.dart';
import 'package:petnest_saas/core/widgets/point_module_visibility.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/member/pages/point_exchange_page.dart';
import 'package:petnest_saas/features/member/widgets/member_empty_state.dart';
import 'package:petnest_saas/features/member/widgets/member_filter_chips.dart';
import 'package:petnest_saas/features/member/widgets/member_list_helpers.dart';
import 'package:petnest_saas/features/member/widgets/member_page_scaffold.dart';
import 'package:petnest_saas/features/member/widgets/member_section_card.dart';
import 'package:petnest_saas/features/member/widgets/member_summary_card.dart';
import 'package:petnest_saas/features/member/widgets/member_ui_tokens.dart';

class MemberPointDetailPage extends StatelessWidget {
  const MemberPointDetailPage({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  final String shopId;
  final String shopName;

  @override
  Widget build(BuildContext context) {
    return ShopFrontendThemeScope(
      shopId: shopId,
      builder: (BuildContext context) {
        return _MemberPointDetailBody(shopId: shopId, shopName: shopName);
      },
    );
  }
}

class _MemberPointDetailBody extends StatefulWidget {
  const _MemberPointDetailBody({required this.shopId, required this.shopName});

  final String shopId;
  final String shopName;

  @override
  State<_MemberPointDetailBody> createState() => _MemberPointDetailPageState();
}

class _MemberPointDetailPageState extends State<_MemberPointDetailBody> {
  String _logFilter = MemberPointLogFilter.all;
  ({int points, DateTime date})? _expiryHint;

  Future<void> _showPointDescription() async {
    try {
      final PointSettingModel setting = await PointSettingService.instance
          .getPointSetting(widget.shopId);
      if (!mounted) {
        return;
      }
      final String description = setting.description.trim();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext bottomSheetContext) {
          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.72,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.shopName.trim().isEmpty
                          ? '點數制度說明'
                          : '${widget.shopName} 點數制度說明',
                      style: TextStyle(
                        fontSize: MemberUi.sectionSize,
                        fontWeight: FontWeight.w700,
                        color: MemberUi.of(context).text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SelectableText(
                          description.isNotEmpty
                              ? description
                              : _buildDefaultPointDescription(setting),
                          style: TextStyle(
                            height: 1.7,
                            color: MemberUi.of(context).text,
                            fontSize: MemberUi.bodySize,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: MemberUi.of(context).primary,
                        ),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                        child: const Text('我知道了'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (error, stack) {
      MemberUi.logError(error, stack);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(MemberUi.friendlyError(error))));
    }
  }

  String _buildDefaultPointDescription(PointSettingModel setting) {
    final List<String> rules = <String>['點數由店家依訂單消費或住宿晚數計算。'];
    if (setting.isAmountCalculation) {
      rules.add(
        setting.amountPerPoint > 0
            ? '每消費 NT\$${setting.amountPerPoint} 可獲得 1 ${setting.pointName}。'
            : '點數依實際消費金額計算。',
      );
    } else {
      rules.add('每住宿 1 晚可獲得 ${setting.pointsPerNight} ${setting.pointName}。');
    }
    if (setting.minimumOrderAmount > 0) {
      rules.add('單筆訂單消費滿 NT\$${setting.minimumOrderAmount} 才會獲得點數。');
    }
    if (setting.maximumPointsPerBooking > 0) {
      rules.add(
        '每筆訂單最多可獲得 ${setting.maximumPointsPerBooking} ${setting.pointName}。',
      );
    }
    if (setting.pointExpireDays > 0) {
      rules.add('點數有效期限為取得後 ${setting.pointExpireDays} 天。');
    } else {
      rules.add('點數目前沒有設定使用期限。');
    }
    if (setting.issueAfterCompleted) {
      rules.add('點數會在訂單完成後發放。');
    }
    if (!setting.allowPointsExchange) {
      rules.add('店家目前未開放點數兌換商品。');
    }
    rules.add('實際取得、使用與兌換規則，以店家當下公告及系統紀錄為準。');
    return rules.map((String rule) => '• $rule').join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final String title = widget.shopName.trim().isEmpty
        ? '我的點數'
        : '${widget.shopName.trim()}・我的點數';

    return MemberPageScaffold(
      title: title,
      actions: <Widget>[
        IconButton(
          tooltip: '點數制度說明',
          onPressed: _showPointDescription,
          icon: const Icon(Icons.info_outline),
        ),
      ],
      body: userId.isEmpty
          ? const MemberEmptyState(
              icon: Icons.lock_outline,
              title: '請先登入',
              message: '登入後即可查看店家點數。',
            )
          : MemberUi.constrain(
              StreamBuilder<MemberPointModel>(
                stream: MemberPointService.instance.streamMemberPoint(
                  shopId: widget.shopId,
                  userId: userId,
                ),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<MemberPointModel> snapshot,
                    ) {
                      if (snapshot.hasError) {
                        MemberUi.logError(snapshot.error!);
                        return MemberErrorState(
                          message: MemberUi.friendlyError(snapshot.error!),
                          onRetry: () => setState(() {}),
                        );
                      }
                      if (!snapshot.hasData &&
                          snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final MemberPointModel point =
                          snapshot.data ??
                          MemberPointModel.empty(
                            shopId: widget.shopId,
                            userId: userId,
                          );
                      return ListView(
                        padding: const EdgeInsets.all(MemberUi.pagePadding),
                        children: <Widget>[
                          _heroCard(point),
                          const SizedBox(height: 12),
                          PointModuleVisibility(
                            shopId: widget.shopId,
                            enabledChild: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => PointExchangePage(
                                        shopId: widget.shopId,
                                        shopName: widget.shopName,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: MemberUi.of(context).primary,
                                  foregroundColor: MemberUi.of(
                                    context,
                                  ).onPrimaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                icon: const Icon(Icons.card_giftcard_outlined),
                                label: const Text('前往點數商城'),
                              ),
                            ),
                            historyChild: MemberSectionCard(
                              child: Text(
                                '此店家目前已暫停點數制度。您原有的點數與紀錄仍會保留，店家重新啟用後即可繼續使用。',
                                style: TextStyle(
                                  color: MemberUi.of(context).warning,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            neverUsedChild: const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              SizedBox(
                                width: 220,
                                child: MemberSummaryCard(
                                  icon: Icons.add_circle_outline,
                                  label: '累積獲得',
                                  value: '${point.totalEarnedPoints}',
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: MemberSummaryCard(
                                  icon: Icons.remove_circle_outline,
                                  label: '已使用',
                                  value: '${point.totalUsedPoints}',
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: MemberSummaryCard(
                                  icon: Icons.schedule_outlined,
                                  label: '已過期',
                                  value: '${point.totalExpiredPoints}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '點數紀錄',
                            style: TextStyle(
                              fontSize: MemberUi.sectionSize,
                              fontWeight: FontWeight.w700,
                              color: MemberUi.of(context).text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          MemberFilterChips(
                            selectedId: _logFilter,
                            onSelected: (String id) {
                              setState(() {
                                _logFilter = id;
                              });
                            },
                            options: const <MemberFilterOption>[
                              MemberFilterOption(
                                id: MemberPointLogFilter.all,
                                label: '全部',
                              ),
                              MemberFilterOption(
                                id: MemberPointLogFilter.earned,
                                label: '獲得',
                              ),
                              MemberFilterOption(
                                id: MemberPointLogFilter.used,
                                label: '使用',
                              ),
                              MemberFilterOption(
                                id: MemberPointLogFilter.expired,
                                label: '過期',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          StreamBuilder<List<MemberPointLogModel>>(
                            stream: MemberPointService.instance
                                .streamMemberPointLogs(
                                  shopId: widget.shopId,
                                  userId: userId,
                                ),
                            builder:
                                (
                                  BuildContext context,
                                  AsyncSnapshot<List<MemberPointLogModel>>
                                  logSnapshot,
                                ) {
                                  if (logSnapshot.hasError) {
                                    MemberUi.logError(logSnapshot.error!);
                                    return MemberSectionCard(
                                      child: Text(
                                        MemberUi.friendlyError(
                                          logSnapshot.error!,
                                        ),
                                        style: TextStyle(
                                          color: MemberUi.of(context).muted,
                                        ),
                                      ),
                                    );
                                  }
                                  if (!logSnapshot.hasData) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  final List<MemberPointLogModel> logs =
                                      logSnapshot.data!;
                                  final ({int points, DateTime date})? expiry =
                                      MemberPointLogFilter.nearestExpiry(logs);
                                  if (expiry?.points != _expiryHint?.points ||
                                      expiry?.date != _expiryHint?.date) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) {
                                            return;
                                          }
                                          setState(() {
                                            _expiryHint = expiry;
                                          });
                                        });
                                  }
                                  final List<MemberPointLogModel> filtered =
                                      MemberPointLogFilter.apply(
                                        logs: logs,
                                        filter: _logFilter,
                                      );
                                  return Column(
                                    children: <Widget>[
                                      if (filtered.isEmpty)
                                        const MemberEmptyState(
                                          icon: Icons.receipt_long_outlined,
                                          title: '目前沒有點數紀錄',
                                          message: '完成住宿或參加店家活動後，紀錄會顯示在這裡。',
                                        )
                                      else
                                        MemberSectionCard(
                                          child: Column(
                                            children: <Widget>[
                                              for (
                                                int i = 0;
                                                i < filtered.length;
                                                i++
                                              ) ...<Widget>[
                                                _logRow(filtered[i]),
                                                if (i != filtered.length - 1)
                                                  Divider(
                                                    height: 16,
                                                    color: MemberUi.of(
                                                      context,
                                                    ).border,
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ),
                                    ],
                                  );
                                },
                          ),
                        ],
                      );
                    },
              ),
            ),
    );
  }

  Widget _heroCard(MemberPointModel point) {
    final theme = MemberUi.of(context);
    final Color onHero = theme.onPrimaryColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MemberUi.radius),
        gradient: theme.heroGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '目前可使用',
            style: TextStyle(
              color: onHero.withValues(alpha: 0.78),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${point.currentPoints}',
                style: TextStyle(
                  color: onHero,
                  fontSize: MemberUi.heroNumberSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('點', style: TextStyle(color: onHero, fontSize: 16)),
              ),
            ],
          ),
          if (_expiryHint != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '最近有 ${_expiryHint!.points} 點將於 ${_date(_expiryHint!.date)} 到期',
              style: TextStyle(color: onHero, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _logRow(MemberPointLogModel log) {
    final bool increase = log.points > 0;
    final String reason = log.reason.trim().isNotEmpty
        ? log.reason
        : log.type.label;
    return Row(
      children: <Widget>[
        CircleAvatar(
          backgroundColor: increase
              ? ShopFrontendTheme.successSoft
              : MemberUi.of(context).dangerSoft,
          child: Icon(
            increase ? Icons.add : Icons.remove,
            color: increase
                ? MemberUi.of(context).success
                : MemberUi.of(context).danger,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: MemberUi.bodySize,
                  color: MemberUi.of(context).text,
                ),
              ),
              Text(
                '${_dateTime(log.createdAt)}　餘額 ${log.balanceAfter} 點',
                style: TextStyle(
                  fontSize: MemberUi.captionSize,
                  color: MemberUi.of(context).muted,
                ),
              ),
            ],
          ),
        ),
        Text(
          increase ? '+${log.absolutePoints} 點' : '-${log.absolutePoints} 點',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: increase
                ? MemberUi.of(context).success
                : MemberUi.of(context).danger,
          ),
        ),
      ],
    );
  }

  String _date(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _dateTime(DateTime date) {
    return '${_date(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

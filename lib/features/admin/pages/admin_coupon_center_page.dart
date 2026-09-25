// 檔案名稱：lib/features/admin/pages/admin_coupon_center_page.dart
// 功能說明：店主優惠券中心。查看模板、發放紀錄與成效，不改訂單計價。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/coupon_template_model.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/navigation/admin_booking_route.dart';
import 'package:petnest_saas/core/services/coupon_template_service.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/features/admin/pages/admin_coupon_center_stats.dart';
import 'package:petnest_saas/features/admin/pages/admin_coupon_template_form_page.dart';
import 'package:petnest_saas/features/shop/widgets/discount_hub_host.dart';

class AdminCouponCenterPage extends StatefulWidget {
  const AdminCouponCenterPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<AdminCouponCenterPage> createState() {
    return _AdminCouponCenterPageState();
  }
}

class _AdminCouponCenterPageState extends State<AdminCouponCenterPage> {
  CouponCenterSection _section = CouponCenterSection.all;
  CouponRecordStatusFilter _status = CouponRecordStatusFilter.all;
  CouponRecordSourceFilter _source = CouponRecordSourceFilter.all;
  CouponRecordTimeFilter _time = CouponRecordTimeFilter.days30;
  String _couponName = '';
  String _busyTemplateId = '';
  final TextEditingController _keywordController = TextEditingController();
  final Map<String, String> _memberLabels = <String, String>{};
  final Set<String> _memberLoads = <String>{};

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  void _scheduleProfiles(List<MemberCouponModel> coupons) {
    final List<String> missing = <String>[];
    for (final MemberCouponModel coupon in coupons) {
      final String userId = coupon.userId.trim();
      if (userId.isEmpty ||
          _memberLabels.containsKey(userId) ||
          _memberLoads.contains(userId)) {
        continue;
      }
      missing.add(userId);
    }
    if (missing.isEmpty) {
      return;
    }
    _memberLoads.addAll(missing);
    _loadProfiles(missing);
  }

  Future<void> _loadProfiles(List<String> userIds) async {
    final List<String> unique = userIds.toSet().toList();
    try {
      for (var start = 0; start < unique.length; start += 10) {
        final int end = start + 10 > unique.length ? unique.length : start + 10;
        final List<String> chunk = unique.sublist(start, end);
        final QuerySnapshot<Map<String, dynamic>> snapshot =
            await FirebaseFirestore.instance
                .collection('user_profiles')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
        final Set<String> found = <String>{};
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          found.add(doc.id);
          _memberLabels[doc.id] = memberProfileLabel(doc.data());
        }
        for (final String userId in chunk) {
          if (!found.contains(userId)) {
            _memberLabels[userId] = memberProfileUnavailableLabel;
          }
        }
      }
    } catch (_) {
      for (final String userId in unique) {
        _memberLabels.putIfAbsent(userId, () => memberProfileUnavailableLabel);
      }
    } finally {
      _memberLoads.removeAll(unique);
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _memberLabel(MemberCouponModel coupon) {
    final String userId = coupon.userId.trim();
    if (userId.isEmpty) {
      return memberProfileUnavailableLabel;
    }
    return _memberLabels[userId] ?? '載入中';
  }

  Future<void> _openForm({CouponTemplateModel? template}) async {
    await presentDiscountEditor<void>(
      context: context,
      child: AdminCouponTemplateFormPage(
        shopId: widget.shopId,
        template: template,
      ),
    );
  }

  Future<void> _toggleTemplate(
    CouponTemplateModel template,
    bool enabled,
  ) async {
    if (_busyTemplateId.isNotEmpty) {
      return;
    }
    setState(() {
      _busyTemplateId = template.id;
    });
    try {
      await CouponTemplateService.instance.updateEnabled(
        shopId: widget.shopId,
        templateId: template.id,
        enabled: enabled,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyTemplateId = '';
        });
      }
    }
  }

  void _selectKpi(CouponRecordStatusFilter status) {
    setState(() {
      _section = CouponCenterSection.records;
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text('優惠券中心')),
      body: StreamBuilder<List<CouponTemplateModel>>(
        stream: CouponTemplateService.instance.streamTemplates(
          shopId: widget.shopId,
        ),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<CouponTemplateModel>> templateSnapshot,
            ) {
              return StreamBuilder<List<MemberCouponModel>>(
                stream: MemberCouponService.instance.streamShopCoupons(
                  widget.shopId,
                ),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<MemberCouponModel>> couponSnapshot,
                    ) {
                      final List<CouponTemplateModel> templates =
                          templateSnapshot.data ??
                          const <CouponTemplateModel>[];
                      final List<MemberCouponModel> coupons =
                          couponSnapshot.data ?? const <MemberCouponModel>[];
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _scheduleProfiles(coupons);
                        }
                      });
                      final DateTime now = DateTime.now();
                      final CouponCenterSummary summary = summarizeCouponCenter(
                        coupons: coupons,
                        templates: templates,
                        now: now,
                      );
                      return LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              final bool desktop = constraints.maxWidth >= 720;
                              return Column(
                                children: <Widget>[
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 1440,
                                        ),
                                        child: ListView(
                                          padding: EdgeInsets.fromLTRB(
                                            desktop ? 20 : 12,
                                            12,
                                            desktop ? 20 : 12,
                                            24,
                                          ),
                                          children: _body(
                                            desktop: desktop,
                                            templates: templates,
                                            coupons: coupons,
                                            summary: summary,
                                            now: now,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!desktop) _mobileCreateBar(),
                                ],
                              );
                            },
                      );
                    },
              );
            },
      ),
    );
  }

  List<Widget> _body({
    required bool desktop,
    required List<CouponTemplateModel> templates,
    required List<MemberCouponModel> coupons,
    required CouponCenterSummary summary,
    required DateTime now,
  }) {
    final bool showTemplates =
        _section == CouponCenterSection.all ||
        _section == CouponCenterSection.templates;
    final bool showRecords =
        _section == CouponCenterSection.all ||
        _section == CouponCenterSection.records;
    final bool showAnalytics =
        _section == CouponCenterSection.all ||
        _section == CouponCenterSection.analytics;
    return <Widget>[
      _header(desktop: desktop),
      const SizedBox(height: 10),
      _sectionChips(),
      const SizedBox(height: 12),
      _kpiGrid(desktop: desktop, summary: summary),
      if (showAnalytics) ...<Widget>[
        const SizedBox(height: 12),
        _analyticsCard(summary: summary),
      ],
      if (showTemplates) ...<Widget>[
        const SizedBox(height: 12),
        _templateSection(templates: templates, summary: summary),
      ],
      if (showRecords) ...<Widget>[
        const SizedBox(height: 12),
        _recordSection(desktop: desktop, coupons: coupons, now: now),
      ],
    ];
  }

  Widget _header({required bool desktop}) {
    final Widget copy = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '優惠券中心',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 4),
        Text(
          '管理優惠券模板、發放狀態與使用成效',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF4B5563),
            height: 1.35,
          ),
        ),
      ],
    );
    if (!desktop) {
      return copy;
    }
    return Row(
      children: <Widget>[
        Expanded(child: copy),
        FilledButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('製作優惠券'),
        ),
      ],
    );
  }

  Widget _mobileCreateBar() {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('製作優惠券'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _sectionChip('全部', CouponCenterSection.all),
        _sectionChip('模板', CouponCenterSection.templates),
        _sectionChip('已發放紀錄', CouponCenterSection.records),
        _sectionChip('成效分析', CouponCenterSection.analytics),
      ],
    );
  }

  Widget _sectionChip(String label, CouponCenterSection section) {
    return FilterChip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      selected: _section == section,
      showCheckmark: false,
      onSelected: (_) {
        setState(() {
          _section = section;
        });
      },
    );
  }

  Widget _kpiGrid({
    required bool desktop,
    required CouponCenterSummary summary,
  }) {
    final List<Widget> cards = <Widget>[
      _KpiCard(
        label: '已發放總數',
        value: '${summary.issued}',
        selected:
            _section == CouponCenterSection.records &&
            _status == CouponRecordStatusFilter.all,
        onTap: () => _selectKpi(CouponRecordStatusFilter.all),
      ),
      _KpiCard(
        label: '可使用',
        value: '${summary.usable}',
        selected: _status == CouponRecordStatusFilter.usable,
        onTap: () => _selectKpi(CouponRecordStatusFilter.usable),
      ),
      _KpiCard(
        label: '已使用',
        value: '${summary.used}',
        selected: _status == CouponRecordStatusFilter.used,
        onTap: () => _selectKpi(CouponRecordStatusFilter.used),
      ),
      _KpiCard(
        label: '即將到期／已過期',
        value: '${summary.expiringSoon}／${summary.expired}',
        selected: _status == CouponRecordStatusFilter.expiringOrExpired,
        onTap: () => _selectKpi(CouponRecordStatusFilter.expiringOrExpired),
      ),
    ];
    if (desktop) {
      return Row(
        children: cards
            .map(
              (Widget card) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: card,
                ),
              ),
            )
            .toList(),
      );
    }
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 78,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      children: cards,
    );
  }

  Widget _analyticsCard({required CouponCenterSummary summary}) {
    return _Panel(
      title: '成效分析',
      child: summary.issued == 0
          ? const _EmptyNote(
              title: '尚無發券紀錄',
              message: '發放優惠券後，這裡會顯示使用率、狀態比例與近 30 天成效。',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '使用率 ${summary.usageRateLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  minHeight: 6,
                  value: summary.issued == 0
                      ? 0
                      : summary.used / summary.issued,
                  borderRadius: BorderRadius.circular(99),
                ),
                const SizedBox(height: 12),
                const Text(
                  '狀態比例',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ...CouponCenterBucket.values.map((CouponCenterBucket bucket) {
                  final int count = summary.countOf(bucket);
                  final double value = summary.issued == 0
                      ? 0
                      : count / summary.issued;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _bucketColor(bucket),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: Text(
                            _bucketLabel(bucket),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            value: value,
                            color: _bucketColor(bucket),
                            backgroundColor: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$count',
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Text(
                  '最近 30 天',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _metric('新發放', summary.issuedLast30),
                    _metric('已使用', summary.usedLast30),
                    _metric('點數兌換取得', summary.pointsLast30),
                    _metric('店主手動發放', summary.manualLast30),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '使用最多的優惠券',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                if (summary.topCoupons.isEmpty)
                  const Text('尚無使用紀錄')
                else
                  ...summary.topCoupons.map(_rankRow),
              ],
            ),
    );
  }

  Widget _metric(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _rankRow(CouponUsageRank rank) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              rank.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '已發放 ${rank.issued}　已使用 ${rank.used}　${rank.rateLabel}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _templateSection({
    required List<CouponTemplateModel> templates,
    required CouponCenterSummary summary,
  }) {
    return _Panel(
      title: '模板',
      trailing: TextButton(
        onPressed: () => _openForm(),
        child: const Text('製作優惠券'),
      ),
      child: templates.isEmpty
          ? const _EmptyNote(
              title: '尚未建立優惠券模板',
              message: '製作模板後，可由店主手動發送、點數兌換或活動贈送給會員。',
            )
          : Column(
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '已停用模板不可再發放，已發出的優惠券仍有效。',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                    ),
                  ),
                ),
                ...templates.map((CouponTemplateModel template) {
                  final CouponTemplateUsage usage =
                      summary.templateUsage[template.id] ??
                      const CouponTemplateUsage(issued: 0, usable: 0, used: 0);
                  return _templateCard(template, usage);
                }),
              ],
            ),
    );
  }

  Widget _templateCard(
    CouponTemplateModel template,
    CouponTemplateUsage usage,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openForm(template: template),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Icon(_typeIcon(template.type), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      template.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      couponOfferLabel(
                        type: template.type,
                        discountValue: template.discountValue,
                        freeStayNights: template.freeStayNights,
                        serviceName: template.serviceName,
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已發放 ${usage.issued}　可使用 ${usage.usable}　已使用 ${usage.used}　使用率 ${usage.rateLabel}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  _badge(template.enabled),
                  Switch.adaptive(
                    value: template.enabled,
                    onChanged: _busyTemplateId == template.id
                        ? null
                        : (bool value) => _toggleTemplate(template, value),
                  ),
                  TextButton(
                    onPressed: () => _openForm(template: template),
                    child: const Text('編輯'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFE8F5E9) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        enabled ? '使用中' : '已停用',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: enabled ? const Color(0xFF2E7D32) : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _recordSection({
    required bool desktop,
    required List<MemberCouponModel> coupons,
    required DateTime now,
  }) {
    final List<String> names =
        coupons
            .map((MemberCouponModel coupon) => coupon.name.trim())
            .where((String name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final List<MemberCouponModel> records = filterCouponRecords(
      coupons: coupons,
      now: now,
      keyword: _keywordController.text,
      status: _status,
      source: _source,
      time: _time,
      couponName: names.contains(_couponName) ? _couponName : '',
      memberLabel: _memberLabel,
    );
    return _Panel(
      title: '已發放紀錄',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (desktop)
            _desktopFilters(names)
          else
            Row(
              children: <Widget>[
                Expanded(child: _keywordField()),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _openMobileFilters(names),
                  child: const Text('篩選'),
                ),
              ],
            ),
          const SizedBox(height: 10),
          if (records.isEmpty)
            const _EmptyNote(title: '沒有符合的發放紀錄', message: '調整篩選條件，或先發放優惠券。')
          else if (desktop)
            _recordTable(records, now)
          else
            ...records.map(
              (MemberCouponModel coupon) => _recordCard(coupon, now),
            ),
        ],
      ),
    );
  }

  Widget _desktopFilters(List<String> names) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(width: 220, child: _keywordField()),
        _filterMenu<CouponRecordStatusFilter>(
          value: _status,
          items: CouponRecordStatusFilter.values,
          label: _statusFilterLabel,
          onChanged: (CouponRecordStatusFilter value) {
            setState(() {
              _status = value;
            });
          },
        ),
        _filterMenu<CouponRecordSourceFilter>(
          value: _source,
          items: CouponRecordSourceFilter.values,
          label: _sourceFilterLabel,
          onChanged: (CouponRecordSourceFilter value) {
            setState(() {
              _source = value;
            });
          },
        ),
        _filterMenu<CouponRecordTimeFilter>(
          value: _time,
          items: CouponRecordTimeFilter.values,
          label: _timeFilterLabel,
          onChanged: (CouponRecordTimeFilter value) {
            setState(() {
              _time = value;
            });
          },
        ),
        _nameMenu(names),
      ],
    );
  }

  Widget _keywordField() {
    return TextField(
      controller: _keywordController,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        isDense: true,
        hintText: '搜尋優惠券、會員姓名或 email',
        prefixIcon: Icon(Icons.search, size: 18),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _filterMenu<T>({
    required T value,
    required List<T> items,
    required String Function(T value) label,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButton<T>(
      value: value,
      isDense: true,
      items: items.map((T item) {
        return DropdownMenuItem<T>(value: item, child: Text(label(item)));
      }).toList(),
      onChanged: (T? next) {
        if (next != null) {
          onChanged(next);
        }
      },
    );
  }

  Widget _nameMenu(List<String> names) {
    final String selected = names.contains(_couponName) ? _couponName : '';
    return DropdownButton<String>(
      value: selected,
      isDense: true,
      items: <DropdownMenuItem<String>>[
        const DropdownMenuItem<String>(value: '', child: Text('全部優惠券')),
        ...names.map((String name) {
          return DropdownMenuItem<String>(value: name, child: Text(name));
        }),
      ],
      onChanged: (String? value) {
        setState(() {
          _couponName = value ?? '';
        });
      },
    );
  }

  Future<void> _openMobileFilters(List<String> names) async {
    CouponRecordStatusFilter status = _status;
    CouponRecordSourceFilter source = _source;
    CouponRecordTimeFilter time = _time;
    String couponName = _couponName;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setLocal) {
                return Dialog(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 420,
                      maxHeight: 460,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView(
                        shrinkWrap: true,
                        children: <Widget>[
                          const Text(
                            '篩選',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<CouponRecordStatusFilter>(
                            initialValue: status,
                            isDense: true,
                            decoration: const InputDecoration(labelText: '狀態'),
                            items: CouponRecordStatusFilter.values.map((
                              CouponRecordStatusFilter item,
                            ) {
                              return DropdownMenuItem<CouponRecordStatusFilter>(
                                value: item,
                                child: Text(_statusFilterLabel(item)),
                              );
                            }).toList(),
                            onChanged: (CouponRecordStatusFilter? value) {
                              if (value == null) {
                                return;
                              }
                              setLocal(() {
                                status = value;
                              });
                            },
                          ),
                          DropdownButtonFormField<CouponRecordSourceFilter>(
                            initialValue: source,
                            isDense: true,
                            decoration: const InputDecoration(labelText: '來源'),
                            items: CouponRecordSourceFilter.values.map((
                              CouponRecordSourceFilter item,
                            ) {
                              return DropdownMenuItem<CouponRecordSourceFilter>(
                                value: item,
                                child: Text(_sourceFilterLabel(item)),
                              );
                            }).toList(),
                            onChanged: (CouponRecordSourceFilter? value) {
                              if (value == null) {
                                return;
                              }
                              setLocal(() {
                                source = value;
                              });
                            },
                          ),
                          DropdownButtonFormField<CouponRecordTimeFilter>(
                            initialValue: time,
                            isDense: true,
                            decoration: const InputDecoration(labelText: '時間'),
                            items: CouponRecordTimeFilter.values.map((
                              CouponRecordTimeFilter item,
                            ) {
                              return DropdownMenuItem<CouponRecordTimeFilter>(
                                value: item,
                                child: Text(_timeFilterLabel(item)),
                              );
                            }).toList(),
                            onChanged: (CouponRecordTimeFilter? value) {
                              if (value == null) {
                                return;
                              }
                              setLocal(() {
                                time = value;
                              });
                            },
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: names.contains(couponName)
                                ? couponName
                                : '',
                            isDense: true,
                            decoration: const InputDecoration(
                              labelText: '優惠券名稱',
                            ),
                            items: <DropdownMenuItem<String>>[
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('全部優惠券'),
                              ),
                              ...names.map((String name) {
                                return DropdownMenuItem<String>(
                                  value: name,
                                  child: Text(name),
                                );
                              }),
                            ],
                            onChanged: (String? value) {
                              setLocal(() {
                                couponName = value ?? '';
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _status = status;
                                  _source = source;
                                  _time = time;
                                  _couponName = couponName;
                                });
                                Navigator.of(context).pop();
                              },
                              child: const Text('套用'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
        );
      },
    );
  }

  Widget _recordTable(List<MemberCouponModel> records, DateTime now) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 56,
        columnSpacing: 16,
        columns: const <DataColumn>[
          DataColumn(label: Text('優惠券')),
          DataColumn(label: Text('會員')),
          DataColumn(label: Text('來源')),
          DataColumn(label: Text('發放日期')),
          DataColumn(label: Text('到期日')),
          DataColumn(label: Text('狀態')),
          DataColumn(label: Text('次數')),
          DataColumn(label: Text('使用訂單')),
        ],
        rows: records.map((MemberCouponModel coupon) {
          return DataRow(
            cells: <DataCell>[
              DataCell(Text('${coupon.name}\n${_offerOf(coupon)}')),
              DataCell(Text(_memberLabel(coupon))),
              DataCell(Text(couponSourceLabel(coupon.source))),
              DataCell(Text(formatCouponDay(coupon.createdAt))),
              DataCell(Text(couponExpiryLabel(coupon, now))),
              DataCell(Text(couponStatusLabel(coupon, now))),
              DataCell(Text('${coupon.usedCount}/${coupon.usageLimit}')),
              DataCell(_bookingButton(coupon)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _recordCard(MemberCouponModel coupon, DateTime now) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              coupon.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(_offerOf(coupon), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              '會員 ${_memberLabel(coupon)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '${couponSourceLabel(coupon.source)}　${formatCouponDay(coupon.createdAt)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '到期 ${couponExpiryLabel(coupon, now)}　${couponStatusLabel(coupon, now)}　${coupon.usedCount}/${coupon.usageLimit}',
              style: const TextStyle(fontSize: 12),
            ),
            _bookingButton(coupon),
          ],
        ),
      ),
    );
  }

  Widget _bookingButton(MemberCouponModel coupon) {
    final String label = couponBookingLabel(coupon.usedBookingId);
    if (label.isEmpty) {
      return const Text('—', style: TextStyle(fontSize: 12));
    }
    return TextButton(
      onPressed: () {
        AdminBookingRoute.open(
          context,
          bookingId: coupon.usedBookingId,
          shopId: widget.shopId,
        );
      },
      child: Text(label),
    );
  }

  String _offerOf(MemberCouponModel coupon) {
    return couponOfferLabel(
      type: coupon.type,
      discountValue: coupon.discountValue,
      freeStayNights: coupon.freeStayNights,
      serviceName: coupon.serviceName,
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.onTap,
    required this.selected,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF6F1FB) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? const Color(0xFF6A1B9A) : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _typeIcon(MemberCouponType type) {
  switch (type) {
    case MemberCouponType.fixedAmount:
      return Icons.payments_outlined;
    case MemberCouponType.percent:
      return Icons.percent;
    case MemberCouponType.freeStay:
      return Icons.hotel_outlined;
    case MemberCouponType.freeService:
      return Icons.room_service_outlined;
  }
}

Color _bucketColor(CouponCenterBucket bucket) {
  switch (bucket) {
    case CouponCenterBucket.usable:
      return const Color(0xFF2E7D32);
    case CouponCenterBucket.used:
      return const Color(0xFF1565C0);
    case CouponCenterBucket.reserved:
      return const Color(0xFFEF6C00);
    case CouponCenterBucket.expired:
      return const Color(0xFF757575);
    case CouponCenterBucket.revoked:
      return const Color(0xFFC62828);
  }
}

String _bucketLabel(CouponCenterBucket bucket) {
  switch (bucket) {
    case CouponCenterBucket.usable:
      return '可使用';
    case CouponCenterBucket.used:
      return '已使用';
    case CouponCenterBucket.reserved:
      return '保留中';
    case CouponCenterBucket.expired:
      return '已過期';
    case CouponCenterBucket.revoked:
      return '已撤銷';
  }
}

String _statusFilterLabel(CouponRecordStatusFilter value) {
  switch (value) {
    case CouponRecordStatusFilter.all:
      return '全部狀態';
    case CouponRecordStatusFilter.usable:
      return '可使用';
    case CouponRecordStatusFilter.reserved:
      return '保留中';
    case CouponRecordStatusFilter.used:
      return '已使用';
    case CouponRecordStatusFilter.expired:
      return '已過期';
    case CouponRecordStatusFilter.revoked:
      return '已撤銷';
    case CouponRecordStatusFilter.expiringOrExpired:
      return '即將到期／已過期';
  }
}

String _sourceFilterLabel(CouponRecordSourceFilter value) {
  switch (value) {
    case CouponRecordSourceFilter.all:
      return '全部來源';
    case CouponRecordSourceFilter.manual:
      return '店主發放';
    case CouponRecordSourceFilter.pointsExchange:
      return '點數兌換';
  }
}

String _timeFilterLabel(CouponRecordTimeFilter value) {
  switch (value) {
    case CouponRecordTimeFilter.days30:
      return '近 30 天';
    case CouponRecordTimeFilter.days90:
      return '近 90 天';
    case CouponRecordTimeFilter.all:
      return '全部時間';
  }
}

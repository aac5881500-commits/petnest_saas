// 檔案名稱：lib/features/shop/pages/policy_version_detail_page.dart
// 功能說明：依服務類型顯示當時同意的條款內容，不安親／住宿互用標題

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/shop_policy_history.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';

class PolicyVersionDetailPage extends StatelessWidget {
  const PolicyVersionDetailPage({
    super.key,
    required this.data,
    required this.serviceType,
  });

  final Map<String, dynamic> data;
  final String serviceType;

  String _formatTime(dynamic value) {
    if (value is! Timestamp) {
      return '-';
    }
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toDate());
  }

  Widget _section({required String title, required String content}) {
    if (content.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }

  List<Widget> _customSections(List<dynamic> items) {
    final List<Widget> out = <Widget>[];
    int index = 0;
    for (final dynamic raw in items) {
      String text = '';
      if (raw is Map) {
        final List<String> services = PolicyApplicableService.parse(
          raw['applicableServices'],
        );
        if (!PolicyApplicableService.appliesTo(services, serviceType)) {
          continue;
        }
        text = (raw['text'] ?? raw['content'] ?? '').toString();
      } else {
        text = raw?.toString() ?? '';
      }
      if (text.trim().isEmpty) {
        continue;
      }
      index += 1;
      out.add(_section(title: '額外條款 $index', content: text));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> filtered = ShopPolicyService.instance
        .filterPolicyForService(policy: data, serviceType: serviceType);
    final dynamic version = filtered['version'] ?? data['version'] ?? '-';
    final String updatedAt = _formatTime(data['updatedAt']);
    final String updatedByEmail = data['updatedByEmail']?.toString() ?? '-';
    final Map<String, dynamic> sections = Map<String, dynamic>.from(
      filtered['sections'] ?? {},
    );
    final Map<String, dynamic> enabled = Map<String, dynamic>.from(
      filtered['enabled'] ?? {},
    );
    final List<dynamic> custom1 =
        (filtered['customPoliciesPage1'] ?? []) as List<dynamic>;
    final List<dynamic> custom2 =
        (filtered['customPoliciesPage2'] ?? []) as List<dynamic>;

    String getText(String key) {
      if (enabled[key] == false) {
        return '';
      }
      return sections[key]?.toString() ?? '';
    }

    final String kindLabel = serviceType == PolicyApplicableService.daycare
        ? '安親'
        : '住宿';

    return Scaffold(
      appBar: AppBar(title: Text('$kindLabel條款版本 v$version')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const Icon(Icons.description),
              title: Text(
                '$kindLabel v$version',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('更新時間：$updatedAt\n更新者：$updatedByEmail'),
            ),
          ),
          Text(
            ShopPolicyHistory.page1Heading(serviceType),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (final String key in ShopPolicyHistory.page1Keys)
            _section(
              title: ShopPolicyHistory.sectionLabel(key, serviceType),
              content: getText(key),
            ),
          ..._customSections(custom1),
          const SizedBox(height: 20),
          Text(
            ShopPolicyHistory.page2Heading(serviceType),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (final String key in ShopPolicyHistory.page2Keys)
            _section(
              title: ShopPolicyHistory.sectionLabel(key, serviceType),
              content: getText(key),
            ),
          ..._customSections(custom2),
        ],
      ),
    );
  }
}

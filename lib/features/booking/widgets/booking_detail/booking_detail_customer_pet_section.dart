// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_customer_pet_section.dart
// 功能說明：入住資料：寵物摘要＋顧客／緊急聯絡人；可展開完整資料。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingDetailCustomerPetSection extends StatefulWidget {
  const BookingDetailCustomerPetSection({
    super.key,
    required this.data,
    this.view,
    this.showFullDetails = false,
  });

  final Map<String, dynamic> data;
  final BookingDetailViewData? view;
  final bool showFullDetails;

  @override
  State<BookingDetailCustomerPetSection> createState() =>
      _BookingDetailCustomerPetSectionState();
}

class _BookingDetailCustomerPetSectionState
    extends State<BookingDetailCustomerPetSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final BookingDetailViewData view =
        widget.view ??
        BookingDetailViewData.fromBooking(data: widget.data, docId: '');

    if (widget.showFullDetails) return _fullDetails(view);
    return BookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const BookingDetailSectionTitle('入住資料'),
          const SizedBox(height: 12),
          if (view.petInfos.isEmpty)
            Text(
              view.petNames.isEmpty ? '本次預約寵物將顯示於訂單資料中' : view.petNames,
              style: TextStyle(color: BookingDetailUi.of(context).muted),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: view.petInfos.map((BookingDetailPetInfo pet) {
                return SizedBox(
                  width: 88,
                  child: Column(
                    children: <Widget>[
                      BookingDetailSoftNetworkImage(
                        url: pet.photoUrl,
                        width: 64,
                        height: 64,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: BookingDetailUi.captionSize,
                          color: BookingDetailUi.of(context).text,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 10),
          Text(
            view.customerName,
            style: TextStyle(
              fontSize: BookingDetailUi.bodySize,
              fontWeight: FontWeight.w600,
              color: BookingDetailUi.of(context).text,
            ),
          ),
          if (view.customerPhone.isNotEmpty) _phone(view.customerPhone),
          if (view.emergencyName.isNotEmpty)
            Text(
              '緊急聯絡人：${view.emergencyName}${view.emergencyPhone.isEmpty ? '' : '　${view.emergencyPhone}'}',
              style: TextStyle(
                fontSize: BookingDetailUi.captionSize,
                color: BookingDetailUi.of(context).muted,
              ),
            ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: Row(
              children: <Widget>[
                Text(
                  '查看完整資料',
                  style: TextStyle(
                    color: BookingDetailUi.of(context).primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: BookingDetailUi.of(context).primary,
                ),
              ],
            ),
          ),
          if (_expanded) ...<Widget>[
            const SizedBox(height: 8),
            _row('顧客姓名', view.customerName),
            _row('電話', view.customerPhone, phone: true),
            if (view.address.isNotEmpty) _row('地址', view.address),
            if (view.emergencyName.isNotEmpty)
              _row('緊急聯絡人', view.emergencyName),
            if (view.emergencyPhone.isNotEmpty)
              _row('緊急聯絡人電話', view.emergencyPhone, phone: true),
            if (view.emergencyRelation.isNotEmpty)
              _row('關係', view.emergencyRelation),
            _row('本次預約寵物', view.petNames),
            for (final BookingDetailPetInfo pet in view.petInfos)
              if (pet.careSummary.isNotEmpty) _row(pet.name, pet.careSummary),
          ],
        ],
      ),
    );
  }

  Widget _fullDetails(BookingDetailViewData view) {
    final theme = BookingDetailUi.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BookingDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BookingDetailSectionTitle('本次預約的寵物'),
              const SizedBox(height: 12),
              if (view.petInfos.isEmpty)
                Text(view.petNames.isEmpty ? '這筆訂單未保存寵物資料。' : view.petNames),
              for (final pet in view.petInfos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BookingDetailSoftNetworkImage(
                        url: pet.photoUrl,
                        width: 48,
                        height: 48,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pet.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: theme.text,
                              ),
                            ),
                            if (pet.careSummary.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  pet.careSummary,
                                  style: TextStyle(
                                    height: 1.55,
                                    color: theme.muted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        BookingDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BookingDetailSectionTitle('預約與緊急聯絡資料'),
              const SizedBox(height: 14),
              _row('顧客姓名', view.customerName),
              _row('電話', view.customerPhone, phone: true),
              _row('地址', view.address),
              _row('緊急聯絡人', view.emergencyName),
              _row('關係', view.emergencyRelation),
              _row('緊急電話', view.emergencyPhone, phone: true),
              _row(
                '緊急備用電話',
                (view.emergency['phone2'] ?? '').toString(),
                phone: true,
              ),
              _row('緊急聯絡地址', (view.emergency['address'] ?? '').toString()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool phone = false}) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(
                fontSize: BookingDetailUi.captionSize,
                color: BookingDetailUi.of(context).muted,
              ),
            ),
          ),
          Expanded(child: phone ? _phone(value) : Text(value)),
        ],
      ),
    );
  }

  Widget _phone(String phone) {
    return InkWell(
      onTap: kIsWeb
          ? null
          : () async {
              final Uri uri = Uri(scheme: 'tel', path: phone);
              await launchUrl(uri);
            },
      child: Text(
        phone,
        style: TextStyle(
          color: kIsWeb
              ? BookingDetailUi.of(context).text
              : BookingDetailUi.of(context).primary,
        ),
      ),
    );
  }
}

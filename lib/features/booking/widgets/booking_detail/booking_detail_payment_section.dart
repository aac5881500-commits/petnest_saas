// lib/features/booking/widgets/booking_detail/booking_detail_payment_section.dart
// 💳 客戶端訂單詳細頁：付款方式區塊
// 功能：顯示付款方式、轉帳資訊、後五碼、轉帳截圖、送出付款資料

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BookingDetailPaymentSection extends StatelessWidget {
  const BookingDetailPaymentSection({
    super.key,
    required this.data,
    required this.depositStatus,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.last5Controller,
    required this.loading,
    required this.onUploadImage,
    required this.onSubmitDeposit,
    required this.onDeleteTransferImage,
  });

  final Map<String, dynamic> data;
  final String depositStatus;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final TextEditingController last5Controller;
  final bool loading;
  final VoidCallback onUploadImage;
  final VoidCallback onSubmitDeposit;
  final void Function(String imageUrl) onDeleteTransferImage;

  @override
  Widget build(BuildContext context) {
    return _sectionCard(
      title: '付款方式',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '付款方式',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data['paymentMethod'] == 'transfer'
                    ? '銀行轉帳'
                    : data['paymentMethod'] == 'cash'
                    ? '到店付款'
                    : '未設定',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (data['paymentMethod'] == 'transfer')
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      _showBankInfoDialog(context);
                    },
                    child: const Text('查看轉帳資訊'),
                  ),
                ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('訂金金額', style: TextStyle(color: Colors.grey)),
                  Text(
                    'NT\$ ${data['depositAmount'] ?? 0}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        if (data['paymentMethod'] == 'transfer') ...[
          _buildLast5Field(),
          const SizedBox(height: 12),
          _buildTransferImageBox(context),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLocked ? null : (loading ? null : onSubmitDeposit),
              child: Text(loading ? '送出中...' : '送出付款資料'),
            ),
          ),
        ],
      ],
    );
  }

  bool get _isLocked {
    return depositStatus == 'pending_review' ||
        depositStatus == 'pending' ||
        depositStatus == 'confirmed';
  }

  Widget _buildLast5Field() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '轉帳後五碼',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: last5Controller,
          enabled: !_isLocked,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            if (value.length > 5) {
              final fixed = value.substring(0, 5);

              WidgetsBinding.instance.addPostFrameCallback((_) {
                last5Controller.value = TextEditingValue(
                  text: fixed,
                  selection: TextSelection.collapsed(offset: fixed.length),
                  composing: TextRange.empty,
                );
              });
            }
          },
          decoration: InputDecoration(
            counterText: '',
            hintText: '例如：12345',
            helperText: '請輸入碼轉帳 後五碼',
            filled: true,
            fillColor: Colors.orange.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.orange.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.orange.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.deepOrange,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferImageBox(BuildContext context) {
    final imageUrl = (data['transferImageUrl'] ?? '').toString();

    return GestureDetector(
      onTap: _isLocked ? null : (loading ? null : onUploadImage),
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: imageUrl.isNotEmpty
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (!_isLocked)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: loading
                            ? null
                            : () => onDeleteTransferImage(imageUrl),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, size: 34, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('上傳轉帳截圖', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(
                    '支援 JPG / PNG',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
      ),
    );
  }

  void _showBankInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.blue.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance,
                    color: Colors.blue.shade700,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '轉帳資訊',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _bankInfoItem(title: '銀行', value: bankName),
              const SizedBox(height: 16),
              _bankInfoItem(title: '戶名', value: accountName),
              const SizedBox(height: 16),
              _bankInfoItem(title: '帳號', value: accountNumber),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '關閉',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bankInfoItem({required String title, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

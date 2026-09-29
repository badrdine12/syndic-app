import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../database/db_helper.dart';
import '../models/resident.dart';
import '../models/payment.dart';
import '../services/pdf_service.dart';
import '../services/whatsapp_service.dart';

class PaymentDialog extends StatefulWidget {
  final Resident resident;
  final String month;
  final VoidCallback onSuccess;

  const PaymentDialog({
    Key? key,
    required this.resident,
    required this.month,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  bool isProcessing = false;
  Payment? recordedPayment;

  Future<void> _confirmPayment() async {
    setState(() => isProcessing = true);

    final receiptNumber = await DBHelper.instance.generateReceiptNumber();
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());

    final payment = Payment(
      residentId: widget.resident.id!,
      month: widget.month,
      amount: AppConstants.monthlyFee,
      paymentDate: today,
      receiptNumber: receiptNumber,
    );

    await DBHelper.instance.insertPayment(payment);

    setState(() {
      recordedPayment = payment;
      isProcessing = false;
    });

    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(recordedPayment == null ? 'تسجيل أداء جديد' : 'تم تسجيل الأداء بنجاح'),
      content: recordedPayment == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('الاسم والنسب:', widget.resident.fullName),
                _buildInfoRow('رقم الشقة:', widget.resident.apartmentNumber),
                _buildInfoRow('الشهر المستحق:', widget.month),
                _buildInfoRow('المبلغ الواجب:', '${AppConstants.monthlyFee} ${AppConstants.currency}'),
                const SizedBox(height: 10),
                const Text(
                  'عند التأكيد سيتم تسجيل تاريخ اليوم وإنشاء رقم وصل تلقائياً.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 50),
                const SizedBox(height: 10),
                Text('رقم الوصل: ${recordedPayment!.receiptNumber}'),
                Text('التاريخ: ${recordedPayment!.paymentDate}'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('معاينة وتحميل وصل PDF'),
                  onPressed: () => PdfService.printOrShareReceipt(
                    resident: widget.resident,
                    payment: recordedPayment!,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.message),
                  label: const Text('فتح WhatsApp لإرسال الإشعار'),
                  onPressed: () => WhatsAppService.sendPaymentReceiptMessage(
                    resident: widget.resident,
                    payment: recordedPayment!,
                  ),
                ),
              ],
            ),
      actions: [
        if (recordedPayment == null) ...[
          TextButton(
            onPressed: isProcessing ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: isProcessing ? null : _confirmPayment,
            child: isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('تأكيد الأداء'),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ]
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
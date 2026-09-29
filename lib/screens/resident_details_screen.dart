import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../database/db_helper.dart';
import '../models/resident.dart';
import '../models/payment.dart';
import '../services/pdf_service.dart';
import '../services/whatsapp_service.dart';
import 'payment_dialog.dart';
import 'add_edit_resident_dialog.dart';

class ResidentDetailsScreen extends StatefulWidget {
  final Resident resident;

  const ResidentDetailsScreen({Key? key, required this.resident}) : super(key: key);

  @override
  State<ResidentDetailsScreen> createState() => _ResidentDetailsScreenState();
}

class _ResidentDetailsScreenState extends State<ResidentDetailsScreen> {
  late Resident currentResident;
  Map<String, Payment> residentPayments = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    currentResident = widget.resident;
    _loadResidentPayments();
  }

  Future<void> _loadResidentPayments() async {
    setState(() => isLoading = true);
    final payments = await DBHelper.instance.getPaymentsForResident(currentResident.id!);
    final updatedRes = await DBHelper.instance.getResidentById(currentResident.id!);

    Map<String, Payment> pMap = {};
    for (var p in payments) {
      pMap[p.month] = p;
    }

    setState(() {
      if (updatedRes != null) currentResident = updatedRes;
      residentPayments = pMap;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    int paidMonthsCount = residentPayments.length;
    int unpaidMonthsCount = AppConstants.monthsList.length - paidMonthsCount;
    double totalPaid = residentPayments.values.fold(0.0, (s, p) => s + p.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل الشقة ${currentResident.apartmentNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AddEditResidentDialog(
                  resident: currentResident,
                  onSuccess: () => _loadResidentPayments(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildResidentHeaderCard(totalPaid, paidMonthsCount, unpaidMonthsCount),
                  const SizedBox(height: 16),
                  const Text('جدول استحقاقات الأشهر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildMonthsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildResidentHeaderCard(double totalPaid, int paidCount, int unpaidCount) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    currentResident.apartmentNumber,
                    style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentResident.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('الهاتف: ${currentResident.phone.isEmpty ? "غير مسجل" : currentResident.phone}',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSubStat('الأشهر المؤداة', '$paidCount', Colors.green),
                _buildSubStat('الأشهر المتبقية', '$unpaidCount', Colors.red),
                _buildSubStat('المجموع المؤدى', '${totalPaid.toStringAsFixed(0)} DH', Colors.blue),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSubStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildMonthsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: AppConstants.monthsList.length,
      itemBuilder: (context, index) {
        final month = AppConstants.monthsList[index];
        final payment = residentPayments[month];
        final isPaid = payment != null;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isPaid ? Colors.green : Colors.red,
            ),
            title: Text('شهر: $month', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              isPaid
                  ? 'المبلغ: ${payment.amount} DH • بتاريخ: ${payment.paymentDate} • الوصل: ${payment.receiptNumber}'
                  : 'غير مدفوع (50 DH)',
            ),
            trailing: isPaid
                ? PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'pdf') {
                        PdfService.printOrShareReceipt(resident: currentResident, payment: payment);
                      } else if (action == 'share_pdf') {
                        PdfService.sharePdfFile(resident: currentResident, payment: payment);
                      } else if (action == 'whatsapp') {
                        WhatsAppService.sendPaymentReceiptMessage(resident: currentResident, payment: payment);
                      } else if (action == 'delete') {
                        _deleteSpecificPayment(month);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'pdf', child: Text('طباعة/معاينة الوصل')),
                      const PopupMenuItem(value: 'share_pdf', child: Text('مشاركة الوصل PDF')),
                      const PopupMenuItem(value: 'whatsapp', child: Text('فتح WhatsApp')),
                      const PopupMenuItem(value: 'delete', child: Text('إلغاء الأداء', style: TextStyle(color: Colors.red))),
                    ],
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => PaymentDialog(
                          resident: currentResident,
                          month: month,
                          onSuccess: () => _loadResidentPayments(),
                        ),
                      );
                    },
                    child: const Text('تسجيل 50 DH'),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _deleteSpecificPayment(String month) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: Text('هل أنت متأكد من رغبتك في إلغاء أداء شهر $month؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إلغاء الأداء'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DBHelper.instance.deletePayment(currentResident.id!, month);
      _loadResidentPayments();
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الشقة بالكامل'),
        content: Text('سيتم حذف الساكن "${currentResident.fullName}" وجميع أداءاته السابقة. هل توافق؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DBHelper.instance.deleteResident(currentResident.id!);
      if (mounted) Navigator.pop(context);
    }
  }
}
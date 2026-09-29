import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../database/db_helper.dart';
import '../models/resident.dart';
import '../models/payment.dart';
import '../services/excel_service.dart';
import '../services/pdf_service.dart';
import '../services/whatsapp_service.dart';
import 'resident_details_screen.dart';
import 'payment_dialog.dart';
import 'add_edit_resident_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedMonth = "08/2026";
  String filterStatus = "الجميع"; // الجميع, دفع, لم يدفع
  String searchQuery = "";

  List<Resident> allResidents = [];
  Map<int, Payment> currentMonthPayments = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final residents = await DBHelper.instance.getAllResidents();
    final payments = await DBHelper.instance.getPaymentsByMonth(selectedMonth);

    Map<int, Payment> paymentMap = {};
    for (var p in payments) {
      paymentMap[p.residentId] = p;
    }

    setState(() {
      allResidents = residents;
      currentMonthPayments = paymentMap;
      isLoading = false;
    });
  }

  List<Resident> get filteredResidents {
    return allResidents.where((resident) {
      final nameMatches = resident.fullName.toLowerCase().contains(searchQuery.toLowerCase());
      final aptMatches = resident.apartmentNumber.contains(searchQuery);
      final phoneMatches = resident.phone.contains(searchQuery);
      final searchMatches = nameMatches || aptMatches || phoneMatches;

      final isPaid = currentMonthPayments.containsKey(resident.id);

      if (!searchMatches) return false;

      if (filterStatus == "دفع") {
        return isPaid;
      } else if (filterStatus == "لم يدفع") {
        return !isPaid;
      }
      return true;
    }).toList();
  }

  double get totalCollected {
    return currentMonthPayments.values.fold(0.0, (sum, p) => sum + p.amount);
  }

  int get paidCount => currentMonthPayments.length;
  int get unpaidCount => allResidents.length - paidCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم السانديك'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'استيراد Excel',
            onPressed: () async {
              final msg = await ExcelService.importExcelFile();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'تصدير Excel',
            onPressed: () async {
              final msg = await ExcelService.exportExcelFile();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddResidentDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة شقة'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatsCards(),
                    const SizedBox(height: 16),
                    _buildSearchAndFilters(),
                    const SizedBox(height: 16),
                    _buildSectionHeader(),
                    const SizedBox(height: 10),
                    _buildResidentsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCard('إجمالي الشقق', '${allResidents.length}', Icons.apartment, Colors.blueGrey),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildCard('المداخيل المحصلة', '${totalCollected.toStringAsFixed(0)} DH', Icons.account_balance_wallet, Colors.teal),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildCard('الذين دفعوا', '$paidCount', Icons.check_circle, Colors.green),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildCard('غير المؤدين', '$unpaidCount', Icons.cancel, Colors.redAccent),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'بحث بالاسم، رقم الشقة، أو الهاتف...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (val) {
                setState(() => searchQuery = val);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedMonth,
                    decoration: const InputDecoration(labelText: 'الشهر', isDense: true),
                    items: AppConstants.monthsList.map((month) {
                      return DropdownMenuItem(value: month, child: Text(month));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedMonth = val);
                        _loadData();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: filterStatus,
                    decoration: const InputDecoration(labelText: 'الحالة', isDense: true),
                    items: ['الجميع', 'دفع', 'لم يدفع'].map((status) {
                      return DropdownMenuItem(value: status, child: Text(status));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => filterStatus = val);
                    },
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'لائحة السكان لشهر $selectedMonth (${filteredResidents.length})',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildResidentsList() {
    if (filteredResidents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: const Text('لا توجد بيانات مطابقة لخيارات البحث أو الفلتر.'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredResidents.length,
      itemBuilder: (context, index) {
        final resident = filteredResidents[index];
        final payment = currentMonthPayments[resident.id];
        final isPaid = payment != null;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ResidentDetailsScreen(resident: resident),
                ),
              ).then((_) => _loadData());
            },
            leading: CircleAvatar(
              backgroundColor: isPaid ? Colors.green.shade50 : Colors.red.shade50,
              child: Text(
                resident.apartmentNumber,
                style: TextStyle(
                  color: isPaid ? Colors.green.shade800 : Colors.red.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(resident.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              isPaid
                  ? 'تم الأداء: ${payment.paymentDate} • الوصل: ${payment.receiptNumber}'
                  : 'غير مدفوع (الواجب: 50 DH)',
              style: TextStyle(fontSize: 12, color: isPaid ? Colors.green : Colors.red),
            ),
            trailing: isPaid
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.blueGrey),
                        tooltip: 'طباعة/معاينة الوصل',
                        onPressed: () => PdfService.printOrShareReceipt(resident: resident, payment: payment),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.green),
                        tooltip: 'فتح WhatsApp',
                        onPressed: () => WhatsAppService.sendPaymentReceiptMessage(resident: resident, payment: payment),
                      ),
                    ],
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () => _openPaymentDialog(resident),
                    child: const Text('تسجيل أداء', style: TextStyle(fontSize: 12)),
                  ),
          ),
        );
      },
    );
  }

  void _openPaymentDialog(Resident resident) {
    showDialog(
      context: context,
      builder: (context) => PaymentDialog(
        resident: resident,
        month: selectedMonth,
        onSuccess: () => _loadData(),
      ),
    );
  }

  void _openAddResidentDialog() {
    showDialog(
      context: context,
      builder: (context) => AddEditResidentDialog(
        onSuccess: () => _loadData(),
      ),
    );
  }
}
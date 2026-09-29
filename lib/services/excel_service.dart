import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_constants.dart';
import '../database/db_helper.dart';
import '../models/resident.dart';
import '../models/payment.dart';

class ExcelService {
  static Future<String> importExcelFile() async {
    // الطريقة الرسمية في الإصدارات الحديثة لـ file_picker
    final pickedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (pickedFiles.isEmpty || pickedFiles.first.path == null) {
      return "تم إلغاء عملية الاستيراد.";
    }

    final filePath = pickedFiles.first.path!;
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    int residentsCount = 0;
    int paymentsCount = 0;

    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table];
      if (sheet == null) continue;

      int headerRowIndex = -1;
      int aptColIndex = -1;
      int nameColIndex = -1;
      Map<String, int> monthColMap = {};

      for (int i = 0; i < sheet.rows.length; i++) {
        var row = sheet.rows[i];
        for (int j = 0; j < row.length; j++) {
          final cellValue = row[j]?.value?.toString().trim() ?? '';
          if (cellValue.contains('الشقة')) {
            headerRowIndex = i;
            aptColIndex = j;
          } else if (cellValue.contains('الاسم')) {
            nameColIndex = j;
          }
        }
        if (headerRowIndex != -1) break;
      }

      if (headerRowIndex == -1) {
        headerRowIndex = 0;
        aptColIndex = 0;
        nameColIndex = 1;
      }

      var headerRow = sheet.rows[headerRowIndex];
      for (int col = 0; col < headerRow.length; col++) {
        String val = headerRow[col]?.value?.toString().trim() ?? '';
        for (var month in AppConstants.monthsList) {
          if (val.replaceAll(' ', '') == month.replaceAll(' ', '')) {
            monthColMap[month] = col;
          }
        }
      }

      for (int r = headerRowIndex + 1; r < sheet.rows.length; r++) {
        var row = sheet.rows[r];
        if (row.isEmpty) continue;

        String aptRaw = '';
        if (aptColIndex >= 0 && aptColIndex < row.length) {
          aptRaw = row[aptColIndex]?.value?.toString().trim() ?? '';
        }

        String name = '';
        if (nameColIndex >= 0 && nameColIndex < row.length) {
          name = row[nameColIndex]?.value?.toString().trim() ?? '';
        }

        if (name.isEmpty && aptRaw.isEmpty) continue;

        if (aptRaw.contains('.')) {
          double? parsed = double.tryParse(aptRaw);
          if (parsed != null) {
            aptRaw = parsed.toInt().toString();
          }
        }

        int residentId = await DBHelper.instance.insertResident(
          Resident(
            apartmentNumber: aptRaw,
            fullName: name.isNotEmpty ? name : 'شقة $aptRaw',
            phone: '',
          ),
        );
        residentsCount++;

        for (var entry in monthColMap.entries) {
          String month = entry.key;
          int colIdx = entry.value;

          if (colIdx < row.length) {
            var cell = row[colIdx];
            if (cell != null && cell.value != null) {
              String rawVal = cell.value.toString().trim();
              double? amount = double.tryParse(rawVal);

              if (amount != null && amount > 0) {
                String receiptNum = await DBHelper.instance.generateReceiptNumber();
                await DBHelper.instance.insertPayment(
                  Payment(
                    residentId: residentId,
                    month: month,
                    amount: amount,
                    paymentDate: "مستورد",
                    receiptNumber: receiptNum,
                  ),
                );
                paymentsCount++;
              }
            }
          }
        }
      }
      break;
    }

    return "تم استيراد $residentsCount شقة و $paymentsCount أداء بنجاح.";
  }

  static Future<String> exportExcelFile() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['الأداءات'];
    excel.delete('Sheet1');

    List<CellValue> headers = [
      TextCellValue("الشقة"),
      TextCellValue("الاسم و النسب"),
      TextCellValue("رقم الهاتف"),
      ...AppConstants.monthsList.map((m) => TextCellValue(m)),
    ];
    sheetObject.appendRow(headers);

    List<Resident> residents = await DBHelper.instance.getAllResidents();

    for (var resident in residents) {
      List<Payment> payments = await DBHelper.instance.getPaymentsForResident(resident.id!);
      Map<String, double> paymentMap = {
        for (var p in payments) p.month: p.amount
      };

      List<CellValue> row = [
        TextCellValue(resident.apartmentNumber),
        TextCellValue(resident.fullName),
        TextCellValue(resident.phone),
      ];

      for (var month in AppConstants.monthsList) {
        if (paymentMap.containsKey(month)) {
          row.add(DoubleCellValue(paymentMap[month]!));
        } else {
          row.add(TextCellValue(""));
        }
      }

      sheetObject.appendRow(row);
    }

    var fileBytes = excel.save();
    final directory = await getApplicationDocumentsDirectory();
    final fileName = "Syndic_Backup_${DateTime.now().millisecondsSinceEpoch}.xlsx";
    final filePath = "${directory.path}/$fileName";

    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    await Share.shareXFiles([XFile(filePath)], text: 'ملف النسخة الاحتياطية لبيانات الساكنة والأداءات');
    return "تم تصدير الملف بنجاح.";
  }
}
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/resident.dart';
import '../models/payment.dart';

class PdfService {
  static Future<Uint8List> generateReceiptPdf({
    required Resident resident,
    required Payment payment,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoMedium();
    final fontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey800, width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'وصل أداء واجب السكن',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Center(
                    child: pw.Text(
                      'إدارة شؤون الإقامة / السانديك',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  ),
                  pw.Divider(thickness: 1.5, color: PdfColors.blue800),
                  pw.SizedBox(height: 10),

                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'رقم الوصل: ${payment.receiptNumber}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                      ),
                      pw.Text(
                        'التاريخ: ${payment.paymentDate}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 15),

                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      children: [
                        _buildReceiptRow('الاسم والنسب:', resident.fullName),
                        pw.SizedBox(height: 8),
                        _buildReceiptRow('رقم الشقة:', resident.apartmentNumber),
                        pw.SizedBox(height: 8),
                        _buildReceiptRow('الشهر المؤدى عنه:', payment.month),
                        pw.SizedBox(height: 8),
                        _buildReceiptRow(
                          'المبلغ المؤدى:',
                          '${payment.amount.toStringAsFixed(2)} درهم',
                        ),
                        pw.SizedBox(height: 8),
                        _buildReceiptRow('الحالة:', 'تم الأداء بنجاح (مدفوع)'),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('توقيع / طابع السانديك:', style: const pw.TextStyle(fontSize: 11)),
                          pw.SizedBox(height: 40),
                          pw.Text('................................', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.green800, width: 2),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                        ),
                        child: pw.Text(
                          'خالص / PAYÉ',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800,
                          ),
                        ),
                      )
                    ],
                  ),
                  pw.Spacer(),
                  pw.Center(
                    child: pw.Text(
                      'شكراً لكم على حسن تعاونكم ووفائكم بأداء الواجبات في وقتها المحدد.',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildReceiptRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static Future<void> printOrShareReceipt({
    required Resident resident,
    required Payment payment,
  }) async {
    final pdfBytes = await generateReceiptPdf(resident: resident, payment: payment);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'وصل_أداء_${resident.apartmentNumber}_${payment.month.replaceAll('/', '_')}.pdf',
    );
  }

  static Future<void> sharePdfFile({
    required Resident resident,
    required Payment payment,
  }) async {
    final pdfBytes = await generateReceiptPdf(resident: resident, payment: payment);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'وصل_${resident.apartmentNumber}_${payment.month.replaceAll('/', '_')}.pdf',
    );
  }
}
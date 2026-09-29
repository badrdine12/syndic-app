import 'package:url_launcher/url_launcher.dart';
import '../models/resident.dart';
import '../models/payment.dart';

class WhatsAppService {
  static Future<void> sendPaymentReceiptMessage({
    required Resident resident,
    required Payment payment,
  }) async {
    String phone = resident.phone.trim().replaceAll(' ', '').replaceAll('-', '');

    // تحويل الأرقام المغربية إلى الصيغة الدولية (+212)
    if (phone.startsWith('0')) {
      phone = '212${phone.substring(1)}';
    } else if (phone.startsWith('+')) {
      phone = phone.substring(1);
    }

    final message = '''السلام عليكم،

تم تسجيل أداءكم بنجاح.

الاسم: ${resident.fullName}
الشقة: ${resident.apartmentNumber}
الشهر: ${payment.month}
المبلغ: ${payment.amount.toStringAsFixed(0)} DH
التاريخ: ${payment.paymentDate}
رقم الوصل: ${payment.receiptNumber}

شكراً لكم.''';

    final uri = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'تعذر فتح تطبيق WhatsApp. يرجى التأكد من تثبيته أو التحقق من صحة الرقم.';
    }
  }
}
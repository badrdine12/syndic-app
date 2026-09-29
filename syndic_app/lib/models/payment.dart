class Payment {
  final int? id;
  final int residentId;
  final String month;
  final double amount;
  final String paymentDate;
  final String receiptNumber;

  Payment({
    this.id,
    required this.residentId,
    required this.month,
    required this.amount,
    required this.paymentDate,
    required this.receiptNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'resident_id': residentId,
      'month': month,
      'amount': amount,
      'payment_date': paymentDate,
      'receipt_number': receiptNumber,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as int?,
      residentId: map['resident_id'] as int,
      month: map['month'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: map['payment_date'] as String,
      receiptNumber: map['receipt_number'] as String,
    );
  }
}
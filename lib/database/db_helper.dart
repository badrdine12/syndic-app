import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/resident.dart';
import '../models/payment.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('syndic_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE residents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        apartment_number TEXT NOT NULL,
        full_name TEXT NOT NULL,
        phone TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        resident_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        receipt_number TEXT NOT NULL,
        FOREIGN KEY (resident_id) REFERENCES residents (id) ON DELETE CASCADE,
        UNIQUE(resident_id, month)
      )
    ''');
  }

  // عمليات السكان
  Future<int> insertResident(Resident resident) async {
    final db = await instance.database;
    return await db.insert('residents', resident.toMap());
  }

  Future<List<Resident>> getAllResidents() async {
    final db = await instance.database;
    final result = await db.query(
      'residents',
      orderBy: 'CAST(apartment_number AS INTEGER) ASC, apartment_number ASC',
    );
    return result.map((map) => Resident.fromMap(map)).toList();
  }

  Future<Resident?> getResidentById(int id) async {
    final db = await instance.database;
    final result = await db.query('residents', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return Resident.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateResident(Resident resident) async {
    final db = await instance.database;
    return await db.update(
      'residents',
      resident.toMap(),
      where: 'id = ?',
      whereArgs: [resident.id],
    );
  }

  Future<int> deleteResident(int id) async {
    final db = await instance.database;
    await db.delete('payments', where: 'resident_id = ?', whereArgs: [id]);
    return await db.delete('residents', where: 'id = ?', whereArgs: [id]);
  }

  // عمليات الأداءات
  Future<int> insertPayment(Payment payment) async {
    final db = await instance.database;
    return await db.insert(
      'payments',
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deletePayment(int residentId, String month) async {
    final db = await instance.database;
    return await db.delete(
      'payments',
      where: 'resident_id = ? AND month = ?',
      whereArgs: [residentId, month],
    );
  }

  Future<List<Payment>> getPaymentsByMonth(String month) async {
    final db = await instance.database;
    final result = await db.query('payments', where: 'month = ?', whereArgs: [month]);
    return result.map((map) => Payment.fromMap(map)).toList();
  }

  Future<List<Payment>> getPaymentsForResident(int residentId) async {
    final db = await instance.database;
    final result = await db.query('payments', where: 'resident_id = ?', whereArgs: [residentId]);
    return result.map((map) => Payment.fromMap(map)).toList();
  }

  Future<Payment?> getPayment(int residentId, String month) async {
    final db = await instance.database;
    final result = await db.query(
      'payments',
      where: 'resident_id = ? AND month = ?',
      whereArgs: [residentId, month],
    );
    if (result.isNotEmpty) {
      return Payment.fromMap(result.first);
    }
    return null;
  }

  Future<String> generateReceiptNumber() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM payments');
    int count = Sqflite.firstIntValue(result) ?? 0;
    return (count + 1).toString().padLeft(6, '0');
  }

  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.delete('payments');
    await db.delete('residents');
  }
}
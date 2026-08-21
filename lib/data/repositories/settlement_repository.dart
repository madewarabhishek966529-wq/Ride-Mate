import 'package:sqflite/sqflite.dart';
import '../../domain/models/settlement_record.dart';

class SettlementRepository {
  final Database _db;

  SettlementRepository(this._db);

  Future<List<SettlementRecord>> getSettlementsForFriend(String friendId) async {
    final maps = await _db.query(
      'settlements',
      where: 'friendId = ?',
      whereArgs: [friendId],
      orderBy: 'date DESC',
    );
    return maps.map((m) => SettlementRecord.fromMap(m)).toList();
  }

  Future<List<SettlementRecord>> getAllSettlements() async {
    final maps = await _db.query('settlements', orderBy: 'date DESC');
    return maps.map((m) => SettlementRecord.fromMap(m)).toList();
  }

  Future<void> insertSettlement(SettlementRecord record) async {
    await _db.insert(
      'settlements',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

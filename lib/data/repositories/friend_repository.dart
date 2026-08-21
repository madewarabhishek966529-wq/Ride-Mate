import 'package:sqflite/sqflite.dart';
import '../../domain/models/friend.dart';

class FriendRepository {
  final Database _db;

  FriendRepository(this._db);

  Future<List<Friend>> getAllFriends() async {
    final maps = await _db.query('friends', orderBy: 'name ASC');
    return maps.map((m) => Friend.fromMap(m)).toList();
  }

  Future<Friend?> getFriendById(String id) async {
    final maps = await _db.query('friends', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Friend.fromMap(maps.first);
  }

  Future<void> insertFriend(Friend friend) async {
    await _db.insert(
      'friends',
      friend.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteFriend(String id) async {
    await _db.delete('friends', where: 'id = ?', whereArgs: [id]);
  }
}

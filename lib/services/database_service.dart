import 'dart:developer';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import 'auth_service.dart';

/// LOCAL storage using SQLite — matches the exact singleton pattern
/// taught in Practical 9 (mood_model.dart / database_service.dart).
/// Three tables: saved_locations, savings_goals, trip_logs.
///
/// Every row is now tagged with an `ownerId` (the logged-in user's
/// Supabase Auth ID, or the string 'guest' if nobody is logged in),
/// and every read/write is scoped to the CURRENT owner — this fixes
/// the bug where every account (and even no account at all) shared
/// the exact same local trip/goal/location data.
class DatabaseService {
  static final DatabaseService _databaseService = DatabaseService._internal();
  factory DatabaseService() => _databaseService;
  DatabaseService._internal();

  static Database? _database;
  final _authService = AuthService();

  /// The current data "owner" — the logged-in user's real account ID
  /// if signed in, or 'guest' if nobody is logged in (matches the
  /// "Skip for now" flow). This is what every row gets tagged with,
  /// and every query filters by.
  String get _ownerId => _authService.currentUser?.id ?? 'guest';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'driveorride.db');
    return await openDatabase(path, version: 3, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE trip_logs ADD COLUMN distanceKm REAL DEFAULT 0');
    }
    if (oldVersion < 3) {
      // Existing rows from before this fix are tagged 'guest' by
      // default, since we can't retroactively know who they belonged to.
      await db.execute("ALTER TABLE saved_locations ADD COLUMN ownerId TEXT DEFAULT 'guest'");
      await db.execute("ALTER TABLE savings_goals ADD COLUMN ownerId TEXT DEFAULT 'guest'");
      await db.execute("ALTER TABLE trip_logs ADD COLUMN ownerId TEXT DEFAULT 'guest'");
    }
  }

  void _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE saved_locations('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'label TEXT, '
          'address TEXT, '
          'lat REAL, '
          'lon REAL, '
          "ownerId TEXT DEFAULT 'guest')",
    );
    await db.execute(
      'CREATE TABLE savings_goals('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'name TEXT, '
          'targetAmount REAL, '
          'savedAmount REAL DEFAULT 0, '
          "ownerId TEXT DEFAULT 'guest')",
    );
    await db.execute(
      'CREATE TABLE trip_logs('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'route TEXT, '
          'mode TEXT, '
          'cost REAL, '
          'savedVsAlternative REAL, '
          'distanceKm REAL DEFAULT 0, '
          'createdOn DATETIME DEFAULT CURRENT_TIMESTAMP, '
          "ownerId TEXT DEFAULT 'guest')",
    );
    log('TABLES CREATED');
  }

  // ───────────── SAVED LOCATIONS — full CRUD, scoped per user ─────────────

  Future<List<SavedLocationModel>> getLocations() async {
    final db = await database;
    final data = await db.query('saved_locations', where: 'ownerId = ?', whereArgs: [_ownerId]);
    return List.generate(data.length, (i) => SavedLocationModel.fromJson(data[i]));
  }

  Future<void> insertLocation(SavedLocationModel loc) async {
    final db = await database;
    await db.rawInsert(
      'INSERT INTO saved_locations(label, address, lat, lon, ownerId) VALUES(?,?,?,?,?)',
      [loc.label, loc.address, loc.lat, loc.lon, _ownerId],
    );
    log('LOCATION INSERTED');
  }

  Future<void> updateLocation(SavedLocationModel loc) async {
    final db = await database;
    await db.update('saved_locations', loc.toMap(), where: 'id = ? AND ownerId = ?', whereArgs: [loc.id, _ownerId]);
    log('LOCATION UPDATED');
  }

  Future<void> deleteLocation(int id) async {
    final db = await database;
    await db.delete('saved_locations', where: 'id = ? AND ownerId = ?', whereArgs: [id, _ownerId]);
    log('LOCATION DELETED');
  }

  // ───────────── SAVINGS GOALS — full CRUD, scoped per user ─────────────

  Future<List<SavingsGoalModel>> getGoals() async {
    final db = await database;
    final data = await db.query('savings_goals', where: 'ownerId = ?', whereArgs: [_ownerId]);
    return List.generate(data.length, (i) => SavingsGoalModel.fromJson(data[i]));
  }

  Future<void> insertGoal(SavingsGoalModel goal) async {
    final db = await database;
    await db.rawInsert(
      'INSERT INTO savings_goals(name, targetAmount, savedAmount, ownerId) VALUES(?,?,?,?)',
      [goal.name, goal.targetAmount, goal.savedAmount, _ownerId],
    );
    log('GOAL INSERTED');
  }

  Future<void> updateGoal(SavingsGoalModel goal) async {
    final db = await database;
    await db.update('savings_goals', goal.toMap(), where: 'id = ? AND ownerId = ?', whereArgs: [goal.id, _ownerId]);
    log('GOAL UPDATED');
  }

  Future<void> deleteGoal(int id) async {
    final db = await database;
    await db.delete('savings_goals', where: 'id = ? AND ownerId = ?', whereArgs: [id, _ownerId]);
    log('GOAL DELETED');
  }

  // ───────────── TRIP LOGS — full CRUD, scoped per user ─────────────

  Future<List<TripLogModel>> getTrips() async {
    final db = await database;
    final data = await db.query('trip_logs', where: 'ownerId = ?', whereArgs: [_ownerId], orderBy: 'createdOn DESC');
    return List.generate(data.length, (i) => TripLogModel.fromJson(data[i]));
  }

  Future<void> insertTrip(TripLogModel trip) async {
    final db = await database;
    await db.rawInsert(
      'INSERT INTO trip_logs(route, mode, cost, savedVsAlternative, distanceKm, createdOn, ownerId) VALUES(?,?,?,?,?,?,?)',
      [trip.route, trip.mode, trip.cost, trip.savedVsAlternative, trip.distanceKm, trip.createdOn, _ownerId],
    );
    log('TRIP INSERTED');
  }

  Future<void> updateTrip(TripLogModel trip) async {
    final db = await database;
    await db.update('trip_logs', trip.toMap(), where: 'id = ? AND ownerId = ?', whereArgs: [trip.id, _ownerId]);
    log('TRIP UPDATED');
  }

  Future<void> deleteTrip(int id) async {
    final db = await database;
    await db.delete('trip_logs', where: 'id = ? AND ownerId = ?', whereArgs: [id, _ownerId]);
    log('TRIP DELETED');
  }

  Future<double> getTotalSaved() async {
    final trips = await getTrips();
    return trips.fold<double>(0.0, (double sum, t) => sum + t.savedVsAlternative);
  }

  /// Deletes ALL trip logs for the CURRENT user only — used for
  /// testing, so you can reset Track Savings without wiping other
  /// accounts' data.
  Future<void> clearAllTrips() async {
    final db = await database;
    await db.delete('trip_logs', where: 'ownerId = ?', whereArgs: [_ownerId]);
    log('ALL TRIPS CLEARED FOR CURRENT USER');
  }
}
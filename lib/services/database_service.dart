import 'dart:developer';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

/// LOCAL storage using SQLite — matches the exact singleton pattern
/// taught in Practical 9 (mood_model.dart / database_service.dart).
/// Three tables: saved_locations, savings_goals, trip_logs.
class DatabaseService {
  static final DatabaseService _databaseService = DatabaseService._internal();
  factory DatabaseService() => _databaseService;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'driveorride.db');
    return await openDatabase(path, version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE trip_logs ADD COLUMN distanceKm REAL DEFAULT 0');
    }
  }

  void _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE saved_locations('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'label TEXT, '
      'address TEXT, '
      'lat REAL, '
      'lon REAL)',
    );
    await db.execute(
      'CREATE TABLE savings_goals('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT, '
      'targetAmount REAL, '
      'savedAmount REAL DEFAULT 0)',
    );
    await db.execute(
      'CREATE TABLE trip_logs('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'route TEXT, '
      'mode TEXT, '
      'cost REAL, '
      'savedVsAlternative REAL, '
      'distanceKm REAL DEFAULT 0, '
      'createdOn DATETIME DEFAULT CURRENT_TIMESTAMP)',
    );
    log('TABLES CREATED');
  }

  // ───────────── SAVED LOCATIONS — full CRUD ─────────────

  Future<List<SavedLocationModel>> getLocations() async {
    final db = await database;
    final data = await db.query('saved_locations');
    return List.generate(data.length, (i) => SavedLocationModel.fromJson(data[i]));
  }

  Future<void> insertLocation(SavedLocationModel loc) async {
    final db = await database;
    await db.rawInsert(
      'INSERT INTO saved_locations(label, address, lat, lon) VALUES(?,?,?,?)',
      [loc.label, loc.address, loc.lat, loc.lon],
    );
    log('LOCATION INSERTED');
  }

  Future<void> updateLocation(SavedLocationModel loc) async {
    final db = await database;
    await db.update('saved_locations', loc.toMap(), where: 'id = ?', whereArgs: [loc.id]);
    log('LOCATION UPDATED');
  }

  Future<void> deleteLocation(int id) async {
    final db = await database;
    await db.delete('saved_locations', where: 'id = ?', whereArgs: [id]);
    log('LOCATION DELETED');
  }

  // ───────────── SAVINGS GOALS — full CRUD ─────────────

  Future<List<SavingsGoalModel>> getGoals() async {
    final db = await database;
    final data = await db.query('savings_goals');
    return List.generate(data.length, (i) => SavingsGoalModel.fromJson(data[i]));
  }

  Future<void> insertGoal(SavingsGoalModel goal) async {
    final db = await database;
    await db.rawInsert(
      'INSERT INTO savings_goals(name, targetAmount, savedAmount) VALUES(?,?,?)',
      [goal.name, goal.targetAmount, goal.savedAmount],
    );
    log('GOAL INSERTED');
  }

  Future<void> updateGoal(SavingsGoalModel goal) async {
    final db = await database;
    await db.update('savings_goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
    log('GOAL UPDATED');
  }

  Future<void> deleteGoal(int id) async {
    final db = await database;
    await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
    log('GOAL DELETED');
  }

  // ───────────── TRIP LOGS — full CRUD ─────────────

  Future<List<TripLogModel>> getTrips() async {
    final db = await database;
    final data = await db.query('trip_logs', orderBy: 'createdOn DESC');
    return List.generate(data.length, (i) => TripLogModel.fromJson(data[i]));
  }

  Future<void> insertTrip(TripLogModel trip) async {
    final db = await database;
    await db.rawInsert(
      'INSERT INTO trip_logs(route, mode, cost, savedVsAlternative, createdOn) VALUES(?,?,?,?,?)',
      [trip.route, trip.mode, trip.cost, trip.savedVsAlternative, trip.createdOn],
    );
    log('TRIP INSERTED');
  }

  Future<void> updateTrip(TripLogModel trip) async {
    final db = await database;
    await db.update('trip_logs', trip.toMap(), where: 'id = ?', whereArgs: [trip.id]);
    log('TRIP UPDATED');
  }

  Future<void> deleteTrip(int id) async {
    final db = await database;
    await db.delete('trip_logs', where: 'id = ?', whereArgs: [id]);
    log('TRIP DELETED');
  }

  Future<double> getTotalSaved() async {
    final trips = await getTrips();
    return trips.fold<double>(0.0, (double sum, t) => sum + t.savedVsAlternative);
  }
}

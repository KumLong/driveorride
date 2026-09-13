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
    return await openDatabase(path, version: 5, onCreate: _onCreate, onUpgrade: _onUpgrade);
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
    if (oldVersion < 4) {
      // Permanently remembers whether a goal's "Goal Achieved!" popup
      // has already been shown — fixes the bug where every completed
      // goal re-showed its celebration popup on every fresh app
      // launch, since that was previously tracked only in memory
      // (a static Set that resets every time the app restarts).
      await db.execute('ALTER TABLE savings_goals ADD COLUMN celebrated INTEGER DEFAULT 0');
    }
    if (oldVersion < 5) {
      await db.execute(
        "CREATE TABLE IF NOT EXISTS wallet("
            "ownerId TEXT PRIMARY KEY, "
            "balance REAL DEFAULT 50.0)",
      );
      await db.execute(
        "CREATE TABLE IF NOT EXISTS wallet_transactions("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, "
            "label TEXT, "
            "amount REAL, "
            "createdOn DATETIME DEFAULT CURRENT_TIMESTAMP, "
            "ownerId TEXT DEFAULT 'guest')",
      );
    }
  }

  void _onCreate(Database db, int version) async {
    await db.execute(
      "CREATE TABLE wallet("
          "ownerId TEXT PRIMARY KEY, "
          "balance REAL DEFAULT 50.0)",
    );
    await db.execute(
      "CREATE TABLE wallet_transactions("
          "id INTEGER PRIMARY KEY AUTOINCREMENT, "
          "label TEXT, "
          "amount REAL, "
          "createdOn DATETIME DEFAULT CURRENT_TIMESTAMP, "
          "ownerId TEXT DEFAULT 'guest')",
    );
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
          'celebrated INTEGER DEFAULT 0, '
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
      'INSERT INTO savings_goals(name, targetAmount, savedAmount, celebrated, ownerId) VALUES(?,?,?,?,?)',
      [goal.name, goal.targetAmount, goal.savedAmount, goal.celebrated ? 1 : 0, _ownerId],
    );
    log('GOAL INSERTED');
  }

  Future<void> updateGoal(SavingsGoalModel goal) async {
    final db = await database;
    await db.update('savings_goals', goal.toMap(), where: 'id = ? AND ownerId = ?', whereArgs: [goal.id, _ownerId]);
    log('GOAL UPDATED');
  }

  // NOTE: syncGoalSavings() was removed — it re-allocated your ENTIRE
  // lifetime total savings across goals every time this screen loaded,
  // which meant a brand-new goal could instantly jump to 100% using
  // savings that existed before it was ever created. Goal progress is
  // now built correctly instead: each trip credits every currently
  // ACTIVE goal individually at the moment it completes (see
  // trip_summary_screen.dart) — so a new goal genuinely starts at
  // RM0 and only grows from trips completed after its creation.

  Future<void> deleteGoal(int id) async {
    final db = await database;
    await db.delete('savings_goals', where: 'id = ? AND ownerId = ?', whereArgs: [id, _ownerId]);
    log('GOAL DELETED');
  }

  /// Mirrors syncMissingTripsFromRemote's exact pattern — pulls any
  /// goal that exists remotely but not locally (matched by NAME,
  /// since goals are mutable and don't share IDs between local
  /// SQLite and Supabase the way trips are matched by route+time).
  Future<int> syncMissingGoalsFromRemote(List<SavingsGoalModel> remoteGoals) async {
    final localGoals = await getGoals();
    final localNames = localGoals.map((g) => g.name).toSet();

    int addedCount = 0;
    for (final goal in remoteGoals) {
      if (!localNames.contains(goal.name)) {
        await insertGoal(goal);
        addedCount++;
      }
    }
    log('SYNCED $addedCount MISSING GOALS FROM REMOTE');
    return addedCount;
  }

  // ───────────── TRIP LOGS — full CRUD, scoped per user ─────────────

  /// [limit]/[offset] let a caller fetch just a page of trips directly
  /// from SQLite, instead of loading every trip into memory and
  /// truncating it in Dart afterward — this matters more as trip
  /// history grows over months of real use, keeping both Home's small
  /// preview and History's paginated list genuinely efficient.
  Future<List<TripLogModel>> getTrips({int? limit, int? offset}) async {
    final db = await database;
    final data = await db.query(
      'trip_logs',
      where: 'ownerId = ?',
      whereArgs: [_ownerId],
      orderBy: 'createdOn DESC',
      limit: limit,
      offset: offset,
    );
    return List.generate(data.length, (i) => TripLogModel.fromJson(data[i]));
  }

  /// Real count of this user's total trips — used by History's
  /// pagination to know when there's nothing more to load.
  Future<int> getTripCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM trip_logs WHERE ownerId = ?', [_ownerId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Real SQL-level SUM, avoiding loading every full trip record just
  /// to add up one field — used for the CO2-saved calculation, which
  /// needs the TRUE total across every transit trip, not just
  /// whatever's currently paginated into view on the History screen.
  Future<double> getTotalDistanceForMode(String mode) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(distanceKm) as total FROM trip_logs WHERE ownerId = ? AND mode = ?',
      [_ownerId, mode],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Lightweight — only the two fields actually needed for the
  /// savings-over-time chart (not full trip records with every
  /// field), across the TRUE full history, so the chart accurately
  /// reflects everything, not just a paginated subset.
  Future<List<Map<String, dynamic>>> getSavingsTimeline() async {
    final db = await database;
    return db.query(
      'trip_logs',
      columns: ['createdOn', 'savedVsAlternative'],
      where: 'ownerId = ?',
      whereArgs: [_ownerId],
      orderBy: 'createdOn ASC',
    );
  }

  /// Fills in any trips that exist in Supabase but are MISSING from
  /// this device's local SQLite — matched by route + exact timestamp
  /// (the same reliable matching used for delete-syncing), not just
  /// "is local empty".
  ///
  /// This replaces the earlier, simpler version which only ever ran
  /// when local storage was completely empty — meaning a trip added
  /// on Device A, then later opening the app on Device B (which
  /// already has SOME local trips from other testing), would never
  /// pull in that specific missing trip, since the "empty check"
  /// wouldn't trigger. This version checks every trip individually,
  /// so real gaps get filled regardless of what's already there.
  Future<int> syncMissingTripsFromRemote(List<TripLogModel> remoteTrips) async {
    final localTrips = await getTrips();
    final localKeys = localTrips.map((t) => '${t.route}|${t.createdOn}').toSet();

    int addedCount = 0;
    for (final trip in remoteTrips) {
      final key = '${trip.route}|${trip.createdOn}';
      if (!localKeys.contains(key)) {
        await insertTrip(trip);
        addedCount++;
      }
    }
    log('SYNCED $addedCount MISSING TRIPS FROM REMOTE');
    return addedCount;
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

  // ───────────── WALLET — balance + transactions, scoped per user ─────────────

  Future<double> getWalletBalance() async {
    final db = await database;
    final rows = await db.query('wallet', where: 'ownerId = ?', whereArgs: [_ownerId], limit: 1);
    if (rows.isEmpty) {
      await db.insert('wallet', {'ownerId': _ownerId, 'balance': 50.0});
      return 50.0;
    }
    return (rows.first['balance'] as num).toDouble();
  }

  /// Applies a balance change — positive for top-ups, negative for
  /// payments. Caller is responsible for checking sufficient funds
  /// first.
  Future<void> adjustWalletBalance(double delta) async {
    final db = await database;
    final current = await getWalletBalance();
    await db.update('wallet', {'balance': current + delta}, where: 'ownerId = ?', whereArgs: [_ownerId]);
    log('WALLET BALANCE UPDATED');
  }

  Future<List<WalletTransactionModel>> getWalletTransactions() async {
    final db = await database;
    final data = await db.query(
      'wallet_transactions',
      where: 'ownerId = ?',
      whereArgs: [_ownerId],
      orderBy: 'createdOn DESC',
    );
    return List.generate(data.length, (i) => WalletTransactionModel.fromJson(data[i]));
  }

  Future<void> insertWalletTransaction(WalletTransactionModel tx) async {
    final db = await database;
    await db.rawInsert(
      'INSERT INTO wallet_transactions(label, amount, createdOn, ownerId) VALUES(?,?,?,?)',
      [tx.label, tx.amount, tx.createdOn, _ownerId],
    );
    log('WALLET TRANSACTION INSERTED');
  }

  /// Deletes ALL trip logs for the CURRENT user only — used for
  /// testing, so you can reset Track Savings without wiping other
  /// accounts' data.
  Future<void> clearAllTrips() async {
    final db = await database;
    await db.delete('trip_logs', where: 'ownerId = ?', whereArgs: [_ownerId]);
    log('ALL TRIPS CLEARED FOR CURRENT USER');
  }

  /// Deletes EVERY local data type for the current account — trips,
  /// saved locations, savings goals, and wallet data — used for full
  /// account deletion. Only ever touches rows tagged with THIS
  /// account's ownerId, so other accounts' local data is never affected.
  Future<void> deleteAllLocalDataForCurrentUser() async {
    final db = await database;
    await db.delete('trip_logs', where: 'ownerId = ?', whereArgs: [_ownerId]);
    await db.delete('saved_locations', where: 'ownerId = ?', whereArgs: [_ownerId]);
    await db.delete('savings_goals', where: 'ownerId = ?', whereArgs: [_ownerId]);
    await db.delete('wallet_transactions', where: 'ownerId = ?', whereArgs: [_ownerId]);
    await db.delete('wallet', where: 'ownerId = ?', whereArgs: [_ownerId]);
    log('ALL LOCAL DATA DELETED FOR CURRENT USER');
  }
}
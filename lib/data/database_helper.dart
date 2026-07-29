import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Opens (and, on first launch, creates) the Tally SQLite database.
///
/// The whole app shares one [Database] instance through [instance], rather
/// than every screen opening its own connection.
class DatabaseHelper {
  DatabaseHelper._internal(this._dbFileName);

  static final DatabaseHelper instance = DatabaseHelper._internal('tally.db');

  /// A separate instance pointed at its own file, so tests don't share a
  /// database (and its lock) with each other or with the real app.
  @visibleForTesting
  factory DatabaseHelper.forTesting(String dbFileName) =>
      DatabaseHelper._internal(dbFileName);

  final String _dbFileName;

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }
    final opened = await _openDatabase();
    _database = opened;
    return opened;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbFileName);

    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE exercises (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            muscle_group TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE routines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE routine_exercises (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            routine_id INTEGER NOT NULL,
            exercise_id INTEGER NOT NULL,
            position INTEGER NOT NULL,
            FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE,
            FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE workouts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            routine_id INTEGER NOT NULL,
            started_at INTEGER NOT NULL,
            FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE sets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workout_id INTEGER NOT NULL,
            exercise_id INTEGER NOT NULL,
            set_number INTEGER NOT NULL,
            reps INTEGER NOT NULL,
            weight REAL NOT NULL,
            FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE,
            FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE CASCADE
          )
        ''');

        await _seedExercises(db);
      },
    );
  }

  Future<void> _seedExercises(Database db) async {
    // Real Push/Legs/Pull routines (from Hevy). Some
    // exercises (e.g. Hanging Leg Raise, Crunch (Machine)) appear in more
    // than one routine but are seeded once each — the catalog holds
    // distinct movements, not per-routine copies.
    const seedExercises = [
      // Push
      {'name': 'Chest Press (Machine)', 'muscle_group': 'Chest'},
      {'name': 'Chest Fly (Machine)', 'muscle_group': 'Chest'},
      {'name': 'Incline Bench Press (Dumbbell)', 'muscle_group': 'Chest'},
      {'name': 'Shoulder Press (Machine Plates)', 'muscle_group': 'Shoulders'},
      {'name': 'Lateral Raise (Dumbbell)', 'muscle_group': 'Shoulders'},
      {'name': 'Triceps Pushdown', 'muscle_group': 'Arms'},
      {'name': 'Triceps Extension (Cable)', 'muscle_group': 'Arms'},
      {'name': 'Incline Push Ups', 'muscle_group': 'Chest'},
      {'name': 'Crunch (Machine)', 'muscle_group': 'Core'},
      // Legs
      {'name': 'Squat (Machine)', 'muscle_group': 'Legs'},
      {'name': 'Leg Press (Machine)', 'muscle_group': 'Legs'},
      {'name': 'Lying Leg Curl (Machine)', 'muscle_group': 'Legs'},
      {'name': 'Leg Extension (Machine)', 'muscle_group': 'Legs'},
      {'name': 'Standing Calf Raise (Machine)', 'muscle_group': 'Legs'},
      {'name': 'Hanging Leg Raise', 'muscle_group': 'Core'},
      {'name': 'Side Bend', 'muscle_group': 'Core'},
      // Pull
      {'name': 'Pull Up', 'muscle_group': 'Back'},
      {'name': 'Lat Pulldown (Cable)', 'muscle_group': 'Back'},
      {'name': 'Seated Row (Machine)', 'muscle_group': 'Back'},
      {
        'name': 'Seated Cable Row - V Grip (Cable)',
        'muscle_group': 'Back',
      },
      {'name': 'Rear Delt Reverse Fly (Machine)', 'muscle_group': 'Shoulders'},
      {'name': 'Preacher Curl (Barbell)', 'muscle_group': 'Arms'},
      {'name': 'Hammer Curl (Dumbbell)', 'muscle_group': 'Arms'},
      {'name': 'Reverse Curl (Barbell)', 'muscle_group': 'Arms'},
    ];

    final batch = db.batch();
    for (final exercise in seedExercises) {
      batch.insert('exercises', exercise);
    }
    await batch.commit(noResult: true);
  }
}

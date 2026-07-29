import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tally/data/database_helper.dart';

const _dbFileName = 'database_helper_test.db';

void main() {
  // sqflite normally talks to the real platform's native SQLite via a
  // platform channel, which doesn't exist in a plain `flutter test` run.
  // sqflite_common_ffi swaps in a desktop SQLite implementation so the
  // same DatabaseHelper code can be exercised here without a
  // simulator/device.
  late DatabaseHelper databaseHelper;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // ffi persists to real disk, so start from a clean file rather than
    // whatever a previous run of this suite left behind.
    await databaseFactory.deleteDatabase(
      join(await getDatabasesPath(), _dbFileName),
    );
    // A file of its own, so this test's connection never contends with
    // other test files' connections over the same on-disk database.
    databaseHelper = DatabaseHelper.forTesting(_dbFileName);
  });

  test('opens the database and creates all five v1 tables', () async {
    final db = await databaseHelper.database;

    final tables = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ?',
      whereArgs: ['table'],
    );
    final tableNames = tables.map((row) => row['name']).toSet();

    expect(
      tableNames,
      containsAll(<String>[
        'exercises',
        'routines',
        'routine_exercises',
        'workouts',
        'sets',
      ]),
    );
  });

  test('enforces foreign keys', () async {
    final db = await databaseHelper.database;

    final result = await db.rawQuery('PRAGMA foreign_keys');
    expect(result.first['foreign_keys'], 1);
  });

  test('rejects a set referencing a workout that does not exist', () async {
    final db = await databaseHelper.database;

    expect(
      () => db.insert('sets', {
        'workout_id': 9999,
        'exercise_id': 9999,
        'set_number': 1,
        'reps': 5,
        'weight': 100.0,
      }),
      throwsA(anything),
    );
  });
}

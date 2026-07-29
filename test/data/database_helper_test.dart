import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tally/data/database_helper.dart';

void main() {
  // sqflite normally talks to the real platform's native SQLite via a
  // platform channel, which doesn't exist in a plain `flutter test` run.
  // sqflite_common_ffi swaps in a desktop SQLite implementation so the
  // same DatabaseHelper code can be exercised here without a
  // simulator/device.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('opens the database and creates all five v1 tables', () async {
    final db = await DatabaseHelper.instance.database;

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
    final db = await DatabaseHelper.instance.database;

    final result = await db.rawQuery('PRAGMA foreign_keys');
    expect(result.first['foreign_keys'], 1);
  });

  test('rejects a set referencing a workout that does not exist', () async {
    final db = await DatabaseHelper.instance.database;

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

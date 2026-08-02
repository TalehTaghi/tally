import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tally/data/database_helper.dart';
import 'package:tally/data/exercise_dao.dart';
import 'package:tally/data/routine_dao.dart';
import 'package:tally/models/routine.dart';

const _dbFileName = 'routine_dao_test.db';

void main() {
  late DatabaseHelper databaseHelper;
  late ExerciseDao exerciseDao;
  late RoutineDao routineDao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // A fresh file (and a fresh DatabaseHelper instance, so its cache
    // starts empty too) before every test, so tests can't see each
    // other's inserts.
    await databaseFactory.deleteDatabase(
      join(await getDatabasesPath(), _dbFileName),
    );
    databaseHelper = DatabaseHelper.forTesting(_dbFileName);
    exerciseDao = ExerciseDao(databaseHelper: databaseHelper);
    routineDao = RoutineDao(databaseHelper: databaseHelper);
  });

  test('Routine.toMap() and Routine.fromMap() round-trip', () {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    final routine = Routine(id: 1, name: 'Push Day', createdAt: createdAt);

    final roundTripped = Routine.fromMap(routine.toMap());

    expect(roundTripped.id, routine.id);
    expect(roundTripped.name, routine.name);
    expect(roundTripped.createdAt, createdAt);
  });

  test(
    'createRoutine links exercises to the routine in the given order',
    () async {
      final exercises = await exerciseDao.getAll();
      final firstId = exercises[0].id!;
      final secondId = exercises[1].id!;

      final routineId = await routineDao.createRoutine('Push Day', [
        secondId,
        firstId,
      ]);

      final linked = await routineDao.getExercisesForRoutine(routineId);

      expect(linked.map((e) => e.id).toList(), [secondId, firstId]);
    },
  );

  test('getAll returns routines newest first', () async {
    final db = await databaseHelper.database;
    // Insert directly with explicit timestamps so ordering isn't at the
    // mercy of how fast two DateTime.now() calls happen to run.
    await db.insert('routines', {
      'name': 'Older Routine',
      'created_at': 1000,
    });
    await db.insert('routines', {
      'name': 'Newer Routine',
      'created_at': 2000,
    });

    final routines = await routineDao.getAll();

    expect(routines.map((r) => r.name).toList(), [
      'Newer Routine',
      'Older Routine',
    ]);
  });

  test(
    'createRoutine is atomic: a failed link leaves no routine behind',
    () async {
      final exercises = await exerciseDao.getAll();
      final validId = exercises[0].id!;
      const nonExistentExerciseId = 999999;

      await expectLater(
        routineDao.createRoutine('Broken Routine', [
          validId,
          nonExistentExerciseId,
        ]),
        throwsA(anything),
      );

      final routines = await routineDao.getAll();
      expect(routines, isEmpty);
    },
  );

  test('addExerciseToRoutine appends after the existing exercises', () async {
    final exercises = await exerciseDao.getAll();
    final routineId = await routineDao.createRoutine('Push Day', [
      exercises[0].id!,
    ]);

    await routineDao.addExerciseToRoutine(routineId, exercises[1].id!);

    final linked = await routineDao.getExercisesForRoutine(routineId);
    expect(linked.map((e) => e.id).toList(), [
      exercises[0].id,
      exercises[1].id,
    ]);
  });

  test(
    'removeExerciseFromRoutine deletes the join row, not the exercise',
    () async {
      final exercises = await exerciseDao.getAll();
      final routineId = await routineDao.createRoutine('Push Day', [
        exercises[0].id!,
        exercises[1].id!,
      ]);

      await routineDao.removeExerciseFromRoutine(routineId, exercises[0].id!);

      final linked = await routineDao.getExercisesForRoutine(routineId);
      expect(linked.map((e) => e.id).toList(), [exercises[1].id]);

      final catalog = await exerciseDao.getAll();
      expect(catalog.map((e) => e.id), contains(exercises[0].id));
    },
  );

  test('updateExerciseOrder rewrites position to match the new order', () async {
    final exercises = await exerciseDao.getAll();
    final routineId = await routineDao.createRoutine('Push Day', [
      exercises[0].id!,
      exercises[1].id!,
      exercises[2].id!,
    ]);

    await routineDao.updateExerciseOrder(routineId, [
      exercises[2].id!,
      exercises[0].id!,
      exercises[1].id!,
    ]);

    final linked = await routineDao.getExercisesForRoutine(routineId);
    expect(linked.map((e) => e.id).toList(), [
      exercises[2].id,
      exercises[0].id,
      exercises[1].id,
    ]);
  });
}

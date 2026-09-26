import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tally/data/database_helper.dart';
import 'package:tally/data/exercise_dao.dart';
import 'package:tally/data/routine_dao.dart';
import 'package:tally/data/workout_dao.dart';
import 'package:tally/models/workout.dart';
import 'package:tally/models/workout_set.dart';

const _dbFileName = 'workout_dao_test.db';

void main() {
  late DatabaseHelper databaseHelper;
  late ExerciseDao exerciseDao;
  late RoutineDao routineDao;
  late WorkoutDao workoutDao;

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
    workoutDao = WorkoutDao(databaseHelper: databaseHelper);
  });

  test('WorkoutSet.toMap() and WorkoutSet.fromMap() round-trip', () {
    const set = WorkoutSet(
      id: 1,
      workoutId: 2,
      exerciseId: 3,
      setNumber: 2,
      reps: 8,
      weight: 62.5,
    );

    final roundTripped = WorkoutSet.fromMap(set.toMap());

    expect(roundTripped.id, set.id);
    expect(roundTripped.workoutId, set.workoutId);
    expect(roundTripped.exerciseId, set.exerciseId);
    expect(roundTripped.setNumber, set.setNumber);
    expect(roundTripped.reps, set.reps);
    expect(roundTripped.weight, 62.5);
    expect(roundTripped.weight, isA<double>());
  });

  test('Workout.toMap() and Workout.fromMap() round-trip', () {
    final startedAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    final workout = Workout(id: 1, routineId: 5, startedAt: startedAt);

    final roundTripped = Workout.fromMap(workout.toMap());

    expect(roundTripped.id, workout.id);
    expect(roundTripped.routineId, workout.routineId);
    expect(roundTripped.startedAt, startedAt);
  });

  test(
    'saveWorkout persists the session and every set, numbered per exercise',
    () async {
      final exercises = await exerciseDao.getAll();
      // Two-sets exercise and one-set exercise — deliberately not
      // assuming which one has the lower id, since getSetsForWorkout
      // orders by exercise_id (ascending), not insertion order.
      final twoSetExercise = exercises[0].id!;
      final oneSetExercise = exercises[1].id!;
      final routineId = await routineDao.createRoutine('Push Day', [
        twoSetExercise,
        oneSetExercise,
      ]);

      // setNumber is a placeholder (0) on every set — saveWorkout
      // assigns the real per-exercise numbering.
      final workoutId = await workoutDao.saveWorkout(
        Workout(
          routineId: routineId,
          startedAt: DateTime.now(),
          sets: [
            WorkoutSet(
              exerciseId: twoSetExercise,
              setNumber: 0,
              reps: 8,
              weight: 60,
            ),
            WorkoutSet(
              exerciseId: twoSetExercise,
              setNumber: 0,
              reps: 6,
              weight: 62.5,
            ),
            WorkoutSet(
              exerciseId: oneSetExercise,
              setNumber: 0,
              reps: 5,
              weight: 100,
            ),
          ],
        ),
      );

      final sets = await workoutDao.getSetsForWorkout(workoutId);

      expect(sets.length, 3);
      final expectedOrder = twoSetExercise < oneSetExercise
          ? [
              (twoSetExercise, 1),
              (twoSetExercise, 2),
              (oneSetExercise, 1),
            ]
          : [
              (oneSetExercise, 1),
              (twoSetExercise, 1),
              (twoSetExercise, 2),
            ];
      // Grouped by exercise, then ordered by set number within it.
      expect(sets.map((s) => (s.exerciseId, s.setNumber)).toList(), expectedOrder);

      final twoSetRows = sets.where((s) => s.exerciseId == twoSetExercise).toList();
      expect(twoSetRows[1].weight, 62.5);
      expect(twoSetRows[1].reps, 6);
    },
  );

  test('getAllWorkouts returns workouts newest first', () async {
    final exercises = await exerciseDao.getAll();
    final routineId = await routineDao.createRoutine('Push Day', [
      exercises[0].id!,
    ]);

    final db = await databaseHelper.database;
    // Insert directly with explicit timestamps so ordering isn't at the
    // mercy of how fast two DateTime.now() calls happen to run.
    await db.insert('workouts', {'routine_id': routineId, 'started_at': 1000});
    await db.insert('workouts', {'routine_id': routineId, 'started_at': 2000});

    final workouts = await workoutDao.getAllWorkouts();

    expect(
      workouts.map((w) => w.startedAt.millisecondsSinceEpoch).toList(),
      [2000, 1000],
    );
  });

  test(
    'saveWorkout is atomic: a forced failure leaves no workout behind',
    () async {
      final exercises = await exerciseDao.getAll();
      final routineId = await routineDao.createRoutine('Push Day', [
        exercises[0].id!,
      ]);
      const nonExistentExerciseId = 999999;

      await expectLater(
        workoutDao.saveWorkout(
          Workout(
            routineId: routineId,
            startedAt: DateTime.now(),
            sets: [
              WorkoutSet(
                exerciseId: exercises[0].id!,
                setNumber: 1,
                reps: 8,
                weight: 60,
              ),
              WorkoutSet(
                exerciseId: nonExistentExerciseId,
                setNumber: 1,
                reps: 8,
                weight: 60,
              ),
            ],
          ),
        ),
        throwsA(anything),
      );

      final workouts = await workoutDao.getAllWorkouts();
      expect(workouts, isEmpty);
    },
  );

  group('getLastTimeForExercise', () {
    test('returns null for an exercise that has never been logged', () async {
      final exercises = await exerciseDao.getAll();

      final lastTime = await workoutDao.getLastTimeForExercise(
        exercises[0].id!,
      );

      expect(lastTime, isNull);
    });

    test(
      'returns that exercise\'s sets from the newest workout containing it',
      () async {
        final exercises = await exerciseDao.getAll();
        final bench = exercises[0].id!;
        final squat = exercises[1].id!;
        final routineId = await routineDao.createRoutine('Mixed', [
          bench,
          squat,
        ]);

        // Oldest: bench only.
        await workoutDao.saveWorkout(
          Workout(
            routineId: routineId,
            startedAt: DateTime.fromMillisecondsSinceEpoch(1000),
            sets: [
              WorkoutSet(exerciseId: bench, setNumber: 0, reps: 5, weight: 50),
            ],
          ),
        );
        // Middle: bench and squat — this is "last time" for bench.
        await workoutDao.saveWorkout(
          Workout(
            routineId: routineId,
            startedAt: DateTime.fromMillisecondsSinceEpoch(2000),
            sets: [
              WorkoutSet(exerciseId: bench, setNumber: 0, reps: 8, weight: 60),
              WorkoutSet(exerciseId: squat, setNumber: 0, reps: 5, weight: 100),
              WorkoutSet(
                exerciseId: bench,
                setNumber: 0,
                reps: 6,
                weight: 62.5,
              ),
            ],
          ),
        );
        // Newest: squat only — must not count for bench.
        await workoutDao.saveWorkout(
          Workout(
            routineId: routineId,
            startedAt: DateTime.fromMillisecondsSinceEpoch(3000),
            sets: [
              WorkoutSet(exerciseId: squat, setNumber: 0, reps: 5, weight: 105),
            ],
          ),
        );

        final lastTime = await workoutDao.getLastTimeForExercise(bench);

        expect(lastTime, isNotNull);
        expect(lastTime!.startedAt.millisecondsSinceEpoch, 2000);
        expect(
          lastTime.sets.map((s) => (s.exerciseId, s.setNumber, s.reps, s.weight)),
          [(bench, 1, 8, 60.0), (bench, 2, 6, 62.5)],
        );

        final squatLastTime = await workoutDao.getLastTimeForExercise(squat);
        expect(squatLastTime!.startedAt.millisecondsSinceEpoch, 3000);
        expect(squatLastTime.sets.single.weight, 105.0);
      },
    );
  });
}

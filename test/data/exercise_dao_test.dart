import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tally/data/database_helper.dart';
import 'package:tally/data/exercise_dao.dart';
import 'package:tally/models/exercise.dart';

const _dbFileName = 'exercise_dao_test.db';

const _seededNames = [
  'Chest Fly (Machine)',
  'Chest Press (Machine)',
  'Crunch (Machine)',
  'Hammer Curl (Dumbbell)',
  'Hanging Leg Raise',
  'Incline Bench Press (Dumbbell)',
  'Incline Push Ups',
  'Lat Pulldown (Cable)',
  'Lateral Raise (Dumbbell)',
  'Leg Extension (Machine)',
  'Leg Press (Machine)',
  'Lying Leg Curl (Machine)',
  'Preacher Curl (Barbell)',
  'Pull Up',
  'Rear Delt Reverse Fly (Machine)',
  'Reverse Curl (Barbell)',
  'Seated Cable Row - V Grip (Cable)',
  'Seated Row (Machine)',
  'Shoulder Press (Machine Plates)',
  'Side Bend',
  'Squat (Machine)',
  'Standing Calf Raise (Machine)',
  'Triceps Extension (Cable)',
  'Triceps Pushdown',
];

void main() {
  late ExerciseDao dao;

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
    dao = ExerciseDao(databaseHelper: DatabaseHelper.forTesting(_dbFileName));
  });

  test('Exercise.toMap() and Exercise.fromMap() round-trip', () {
    const exercise = Exercise(id: 1, name: 'Bench Press', muscleGroup: 'Chest');

    final roundTripped = Exercise.fromMap(exercise.toMap());

    expect(roundTripped.id, exercise.id);
    expect(roundTripped.name, exercise.name);
    expect(roundTripped.muscleGroup, exercise.muscleGroup);
  });

  test('a fresh database is seeded with the expected exercises', () async {
    final exercises = await dao.getAll();

    expect(exercises.map((e) => e.name).toList(), _seededNames);
  });

  test('insert adds a new exercise alongside the seeded ones', () async {
    await dao.insert(const Exercise(name: 'Lat Pulldown', muscleGroup: 'Back'));
    final exercises = await dao.getAll();

    expect(exercises.length, _seededNames.length + 1);
    expect(exercises.map((e) => e.name), contains('Lat Pulldown'));
  });
}

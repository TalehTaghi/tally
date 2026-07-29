import '../models/exercise.dart';
import 'database_helper.dart';

/// Owns all SQL for the `exercises` table, so nothing above this layer
/// (screens, widgets) needs to know SQL exists.
class ExerciseDao {
  final DatabaseHelper _databaseHelper;

  ExerciseDao({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<int> insert(Exercise exercise) async {
    final db = await _databaseHelper.database;
    return db.insert('exercises', exercise.toMap());
  }

  Future<List<Exercise>> getAll() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('exercises', orderBy: 'name');
    return rows.map(Exercise.fromMap).toList();
  }
}

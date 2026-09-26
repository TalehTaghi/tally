import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/routine_dao.dart';
import '../data/workout_dao.dart';
import '../formatting.dart';
import '../models/exercise.dart';
import '../models/last_time.dart';
import '../models/routine.dart';
import '../models/workout.dart';
import '../models/workout_set.dart';

/// One editable set row in the draft: the two controllers behind its
/// reps and weight fields. Whoever creates a [_SetRow] owns it and must
/// call [dispose] once the row is gone.
class _SetRow {
  final reps = TextEditingController();
  final weight = TextEditingController();

  bool get isEmpty => reps.text.trim().isEmpty && weight.text.trim().isEmpty;

  /// Reps must be a whole number ≥ 1.
  int? get parsedReps {
    final value = int.tryParse(reps.text.trim());
    return value != null && value > 0 ? value : null;
  }

  /// Weight may be 0 (bodyweight moves like pull-ups). Accepts a comma as
  /// the decimal separator too, since some locales' keyboards type one.
  double? get parsedWeight {
    final value = double.tryParse(weight.text.trim().replaceAll(',', '.'));
    return value != null && value >= 0 ? value : null;
  }

  bool get isComplete => parsedReps != null && parsedWeight != null;

  void dispose() {
    reps.dispose();
    weight.dispose();
  }
}

class LogWorkoutScreen extends StatefulWidget {
  LogWorkoutScreen({
    super.key,
    required this.routine,
    RoutineDao? routineDao,
    WorkoutDao? workoutDao,
  })  : _routineDao = routineDao ?? RoutineDao(),
        _workoutDao = workoutDao ?? WorkoutDao();

  final Routine routine;
  final RoutineDao _routineDao;
  final WorkoutDao _workoutDao;

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  List<Exercise>? _exercises;
  bool _hasError = false;

  /// The draft workout: exercise id → its set rows, in the order entered.
  /// Nothing here touches the database until [_save].
  final Map<int, List<_SetRow>> _setRowsByExerciseId = {};

  /// exercise id → what you did last time, or null if it's never been
  /// logged. Read-only: shown as a hint, never copied into the draft.
  final Map<int, LastTime?> _lastTimeByExerciseId = {};

  /// Once the user has tried to save, invalid fields show their errors.
  bool _showErrors = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    for (final rows in _setRowsByExerciseId.values) {
      for (final row in rows) {
        row.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadExercises() async {
    try {
      final exercises = await widget._routineDao.getExercisesForRoutine(
        widget.routine.id!,
      );
      // One small query per exercise, all in flight at once.
      final lastTimes = await Future.wait(
        exercises.map(
          (exercise) => widget._workoutDao.getLastTimeForExercise(exercise.id!),
        ),
      );
      if (!mounted) return;
      setState(() {
        _exercises = exercises;
        for (var i = 0; i < exercises.length; i++) {
          _lastTimeByExerciseId[exercises[i].id!] = lastTimes[i];
        }
        // Start every exercise with one empty row, ready to type into.
        for (final exercise in exercises) {
          _setRowsByExerciseId[exercise.id!] = [_SetRow()];
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  void _addSet(int exerciseId) {
    setState(() {
      _setRowsByExerciseId[exerciseId]!.add(_SetRow());
    });
  }

  void _removeSet(int exerciseId, _SetRow row) {
    setState(() {
      _setRowsByExerciseId[exerciseId]!.remove(row);
    });
    // The row's TextFields are still mounted until the rebuild we just
    // scheduled runs, so wait for that frame before disposing their
    // controllers — disposing now would pull them out from under live
    // widgets.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  /// Error hints are computed during build, so once they're showing,
  /// rebuild on every keystroke to clear them as the user fixes a field.
  void _refreshErrors(String _) {
    if (_showErrors) setState(() {});
  }

  bool get _hasUnsavedInput => _setRowsByExerciseId.values.any(
        (rows) => rows.any((row) => !row.isEmpty),
      );

  Future<void> _save() async {
    final allRows = _setRowsByExerciseId.values.expand((rows) => rows);
    // Fully empty rows are skipped; a half-filled or invalid row blocks
    // the save rather than being silently dropped.
    final hasInvalidRow =
        allRows.any((row) => !row.isEmpty && !row.isComplete);
    final hasCompleteSet = allRows.any((row) => row.isComplete);

    if (hasInvalidRow || !hasCompleteSet) {
      setState(() => _showErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasInvalidRow
                ? 'Fix the highlighted sets before saving.'
                : 'Log at least one set before saving.',
          ),
        ),
      );
      return;
    }

    // The moment the draft becomes a real Workout: walk the exercises in
    // routine order and turn each complete row into a WorkoutSet.
    final sets = <WorkoutSet>[];
    for (final exercise in _exercises!) {
      final completeRows = _setRowsByExerciseId[exercise.id!]!
          .where((row) => row.isComplete)
          .toList();
      for (var i = 0; i < completeRows.length; i++) {
        sets.add(
          WorkoutSet(
            exerciseId: exercise.id!,
            setNumber: i + 1,
            reps: completeRows[i].parsedReps!,
            weight: completeRows[i].parsedWeight!,
          ),
        );
      }
    }

    setState(() => _isSaving = true);
    try {
      await widget._workoutDao.saveWorkout(
        Workout(
          routineId: widget.routine.id!,
          startedAt: DateTime.now(),
          sets: sets,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this workout.')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _confirmLeave() async {
    if (!_hasUnsavedInput) {
      Navigator.pop(context);
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard workout?'),
        content: const Text('The sets you entered will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep logging'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (discard == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // canPop: false intercepts every back action (app bar arrow, Android
    // back button) so _confirmLeave can decide. Navigator.pop() itself
    // isn't blocked by PopScope, which is how _save and _confirmLeave
    // still close the screen.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.routine.name),
          actions: [
            TextButton(
              onPressed: _exercises == null || _isSaving ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return const Center(child: Text('Could not load this routine.'));
    }

    final exercises = _exercises;
    if (exercises == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (exercises.isEmpty) {
      return const Center(
        child: Text('This routine has no exercises to log.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: exercises.length,
      itemBuilder: (context, index) => _buildExerciseCard(exercises[index]),
    );
  }

  /// e.g. "Last time (Aug 1): 60×8, 60×8, 62.5×6"
  String _lastTimeHint(LastTime? lastTime) {
    if (lastTime == null) {
      return 'No previous data';
    }
    final date = DateFormat.MMMd().format(lastTime.startedAt);
    final sets = lastTime.sets
        .map((set) => '${formatWeight(set.weight)}×${set.reps}')
        .join(', ');
    return 'Last time ($date): $sets';
  }

  Widget _buildExerciseCard(Exercise exercise) {
    final exerciseId = exercise.id!;
    final rows = _setRowsByExerciseId[exerciseId]!;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.name, style: Theme.of(context).textTheme.titleMedium),
            Text(
              _lastTimeHint(_lastTimeByExerciseId[exerciseId]),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (var i = 0; i < rows.length; i++)
              _buildSetRow(exerciseId, rows[i], setNumber: i + 1),
            TextButton.icon(
              onPressed: () => _addSet(exerciseId),
              icon: const Icon(Icons.add),
              label: const Text('Add set'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetRow(int exerciseId, _SetRow row, {required int setNumber}) {
    final showRowErrors = _showErrors && !row.isEmpty;

    // ObjectKey(row) ties this widget to *this* row object, so removing
    // set 2 of 3 drops set 2's fields rather than Flutter reusing them for
    // what was set 3 — like a stable `key` on a React list item.
    return Row(
      key: ObjectKey(row),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text('Set $setNumber'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: row.reps,
            onChanged: _refreshErrors,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Reps',
              errorText:
                  showRowErrors && row.parsedReps == null ? 'Required' : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: row.weight,
            onChanged: _refreshErrors,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
            ],
            decoration: InputDecoration(
              labelText: 'Weight',
              errorText:
                  showRowErrors && row.parsedWeight == null ? 'Required' : null,
            ),
          ),
        ),
        IconButton(
          padding: const EdgeInsets.only(top: 12),
          icon: const Icon(Icons.close),
          tooltip: 'Remove set',
          onPressed: () => _removeSet(exerciseId, row),
        ),
      ],
    );
  }
}

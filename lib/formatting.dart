import 'package:intl/intl.dart';

final _weightFormat = NumberFormat('0.##');

/// Shows weight without a pointless ".0" — 60.0 → "60", 62.5 → "62.5".
String formatWeight(double weight) => _weightFormat.format(weight);

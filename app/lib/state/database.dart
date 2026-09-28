import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/slip_database.dart';

/// Opened in main() before the first frame and passed in with
/// overrideWithValue, so every screen can use it without waiting.
final slipDatabaseProvider = Provider<SlipDatabase>(
    (ref) => throw UnimplementedError('The database is opened in main().'));

/// What the database held at launch; the notifiers start from this.
final startupDataProvider = Provider<StartupData>(
    (ref) => throw UnimplementedError('Startup data is loaded in main().'));

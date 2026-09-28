import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/slip_database.dart';
import 'state/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Load everything before the first frame (a few milliseconds for years of
  // receipts), so no screen ever has to show a loading state.
  final database = await SlipDatabase.open();
  final startup = await database.load();

  runApp(ProviderScope(
    overrides: [
      slipDatabaseProvider.overrideWithValue(database),
      startupDataProvider.overrideWithValue(startup),
    ],
    child: const SlipApp(),
  ));
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

class AppSettings {
  const AppSettings({
    this.showGst = true,
    this.autoCategorise = true,
    this.appLock = false,
  });

  final bool showGst;
  final bool autoCategorise;
  final bool appLock;

  AppSettings copyWith({bool? showGst, bool? autoCategorise, bool? appLock}) =>
      AppSettings(
        showGst: showGst ?? this.showGst,
        autoCategorise: autoCategorise ?? this.autoCategorise,
        appLock: appLock ?? this.appLock,
      );
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(startupDataProvider).settings;

  Future<void> setShowGst(bool value) => _save(state.copyWith(showGst: value));

  Future<void> setAutoCategorise(bool value) => _save(state.copyWith(autoCategorise: value));

  Future<void> _save(AppSettings next) async {
    await ref.read(slipDatabaseProvider).saveSettings(next);
    state = next;
  }
}

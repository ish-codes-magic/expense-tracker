import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  AppSettings build() => const AppSettings();

  void toggleShowGst() => state = state.copyWith(showGst: !state.showGst);
  void toggleAutoCategorise() => state = state.copyWith(autoCategorise: !state.autoCategorise);
  void toggleAppLock() => state = state.copyWith(appLock: !state.appLock);
}

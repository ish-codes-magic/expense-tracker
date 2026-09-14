import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettings {
  const AppSettings({
    this.showGst = true,
    this.autoCategorise = true,
    this.appLock = false,
    this.monthlyBudgetPaise = 2900000,
  });

  final bool showGst;
  final bool autoCategorise;
  final bool appLock;
  final int monthlyBudgetPaise;

  AppSettings copyWith({bool? showGst, bool? autoCategorise, bool? appLock, int? monthlyBudgetPaise}) =>
      AppSettings(
        showGst: showGst ?? this.showGst,
        autoCategorise: autoCategorise ?? this.autoCategorise,
        appLock: appLock ?? this.appLock,
        monthlyBudgetPaise: monthlyBudgetPaise ?? this.monthlyBudgetPaise,
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

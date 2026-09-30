import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip/state/app_lock.dart';
import 'package:slip/state/budgets.dart';
import 'package:slip/state/database.dart';
import 'package:slip/state/settings.dart';

/// When the lock should and shouldn't cover the app. A wrong answer here
/// either leaks receipts or locks people out, so it's pinned down by tests.
void main() {
  late DateTime now;

  ProviderContainer containerWith({required bool lockOn}) {
    final container = ProviderContainer(overrides: [
      startupDataProvider.overrideWithValue(
          (receipts: const [], budgets: defaultBudgets(), settings: AppSettings(appLock: lockOn))),
    ]);
    addTearDown(container.dispose);
    container.read(appLockProvider.notifier).clock = () => now;
    return container;
  }

  setUp(() => now = DateTime(2026, 9, 29, 12));

  test('starts locked only when app lock is on', () {
    expect(containerWith(lockOn: true).read(appLockProvider), isTrue);
    expect(containerWith(lockOn: false).read(appLockProvider), isFalse);
  });

  group('with app lock on and unlocked', () {
    late ProviderContainer container;
    late AppLockNotifier lock;

    setUp(() {
      container = containerWith(lockOn: true);
      lock = container.read(appLockProvider.notifier);
      lock.state = false;
    });

    test('a quick switch away does not lock', () {
      lock.appHidden();
      now = now.add(const Duration(seconds: 59));
      lock.appShown();
      expect(container.read(appLockProvider), isFalse);
    });

    test('a minute or more away locks', () {
      lock.appHidden();
      now = now.add(AppLockNotifier.relockAfter);
      lock.appShown();
      expect(container.read(appLockProvider), isTrue);
    });

    test('a long trip to the scanner or share sheet does not lock', () async {
      await lock.whileOutside(() async {
        lock.appHidden();
        now = now.add(const Duration(minutes: 10));
        lock.appShown();
      });
      expect(container.read(appLockProvider), isFalse);
    });
  });

  test('never locks when app lock is off', () {
    final container = containerWith(lockOn: false);
    final lock = container.read(appLockProvider.notifier);
    lock.appHidden();
    now = now.add(const Duration(hours: 1));
    lock.appShown();
    expect(container.read(appLockProvider), isFalse);
  });
}

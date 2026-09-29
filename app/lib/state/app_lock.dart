import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'settings.dart';

typedef Verification = ({bool verified, String? problem});

/// Whether the lock screen is covering the app.
///
/// With app lock on, Slip locks when it starts and when it comes back after
/// more than [relockAfter] in the background. Trips out to the scanner,
/// file picker or share sheet go through [whileOutside] and never lock.
final appLockProvider = NotifierProvider<AppLockNotifier, bool>(AppLockNotifier.new);

class AppLockNotifier extends Notifier<bool> {
  static const relockAfter = Duration(minutes: 1);

  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  final _auth = LocalAuthentication();
  DateTime? _hiddenAt;
  int _outsideTasks = 0;
  bool _verifying = false;

  @override
  bool build() => ref.read(settingsProvider).appLock;

  void appHidden() {
    if (_outsideTasks == 0 && !_verifying) _hiddenAt ??= clock();
  }

  void appShown() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null || !ref.read(settingsProvider).appLock) return;
    if (clock().difference(hiddenAt) >= relockAfter) state = true;
  }

  /// Runs [task], which opens another app's screen, without locking on return.
  Future<T> whileOutside<T>(Future<T> Function() task) async {
    _outsideTasks++;
    try {
      return await task();
    } finally {
      _outsideTasks--;
      _hiddenAt = null;
    }
  }

  Future<Verification> unlock() async {
    final result = await verify('Unlock Slip');
    if (result.verified) state = false;
    return result;
  }

  /// Shows Android's prompt: fingerprint or face, with the phone's PIN,
  /// pattern or password as a fallback so a failed sensor can't lock you out.
  Future<Verification> verify(String reason) async {
    if (_verifying) return (verified: false, problem: null);
    _verifying = true;
    try {
      final verified = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
      return (verified: verified, problem: null);
    } on LocalAuthException catch (error) {
      return (verified: false, problem: _describe(error.code));
    } finally {
      _verifying = false;
    }
  }

  /// A cancelled prompt isn't a problem worth a message.
  static String? _describe(LocalAuthExceptionCode code) => switch (code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.authInProgress =>
          null,
        LocalAuthExceptionCode.noCredentialsSet =>
          'Set a screen lock (PIN, pattern or fingerprint) in your phone settings first',
        LocalAuthExceptionCode.temporaryLockout || LocalAuthExceptionCode.biometricLockout =>
          'Too many attempts. Wait a moment, or use your phone PIN',
        _ => "Couldn't verify (${code.name})",
      };
}

/// Which app this build is. Set with --dart-define=SLIP_EDITION=free (and the
/// matching --flavor free); anything else is the AI edition.
enum Edition {
  /// "Slip": receipts are read by the AI reader, with the phone as fallback.
  ai,

  /// "Slip Free": the photo is kept, every field is typed in by hand, and
  /// nothing ever leaves the phone.
  free;

  static const current = String.fromEnvironment('SLIP_EDITION') == 'free' ? Edition.free : Edition.ai;
}

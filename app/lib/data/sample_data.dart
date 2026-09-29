import 'models.dart';

/// Early versions added 42 demo receipts to a new database, with ids starting
/// "sample-". New installs start empty; Settings can still remove the samples
/// from phones that got them.
bool isSampleReceipt(Receipt receipt) => receipt.id.startsWith('sample-');

import '../../database/app_database.dart';
import 'native_sms_channel.dart';

/// One-off historical backfill from `content://sms/inbox` into the
/// `sms_messages` table. Live capture of new SMS happens natively
/// (SmsReceiver.kt writes directly into the same SQLite file), so this only
/// needs to cover messages that arrived before the app was ever opened.
///
/// Dedupes against rows the native receiver may have already inserted, since
/// both paths can see the same message.
class SmsSyncService {
  SmsSyncService(this._db, this._nativeChannel);

  final AppDatabase _db;
  final NativeSmsChannel _nativeChannel;

  /// [since], when provided, only backfills messages received on or after
  /// that date - lets the user choose a sync depth (Last 7 days / This
  /// month / etc.) instead of always scanning the entire SMS history.
  Future<int> syncInboxHistory({DateTime? since}) async {
    final rawMessages = await _nativeChannel.readInbox(since: since);
    if (rawMessages.isEmpty) return 0;

    final existing = await _db.select(_db.smsMessages).get();
    final existingKeys = existing
        .map((row) => _dedupeKey(row.sender, row.messageBody, row.receivedAt))
        .toSet();

    var inserted = 0;
    await _db.batch((batch) {
      for (final raw in rawMessages) {
        final receivedAt = DateTime.fromMillisecondsSinceEpoch(raw.date);
        final key = _dedupeKey(raw.address, raw.body, receivedAt);
        if (existingKeys.contains(key)) continue;
        existingKeys.add(key);

        batch.insert(
          _db.smsMessages,
          SmsMessagesCompanion.insert(
            sender: raw.address,
            messageBody: raw.body,
            receivedAt: receivedAt,
          ),
        );
        inserted++;
      }
    });
    return inserted;
  }

  /// Rounds to the second: native inserts store unix seconds (Drift's
  /// DateTime column), while the content provider reports milliseconds.
  String _dedupeKey(String sender, String body, DateTime receivedAt) {
    final seconds = receivedAt.millisecondsSinceEpoch ~/ 1000;
    return '$sender|$body|$seconds';
  }
}

import 'package:flutter/services.dart';

class RawSmsMessage {
  const RawSmsMessage({
    required this.address,
    required this.body,
    required this.date,
  });

  final String address;
  final String body;

  /// Milliseconds since epoch, as returned by Android's SMS content provider.
  final int date;
}

/// Bridges to the native `content://sms/inbox` query implemented in
/// MainActivity.kt. Used for a one-off historical backfill; live capture of
/// new SMS is handled entirely natively by SmsReceiver.kt.
class NativeSmsChannel {
  static const _channel = MethodChannel('com.txnvault.txnvault/native');

  Future<List<RawSmsMessage>> readInbox() async {
    final result = await _channel.invokeMethod<List<Object?>>('readSmsInbox');
    if (result == null) return const [];
    return result
        .cast<Map<Object?, Object?>>()
        .map((row) => RawSmsMessage(
              address: row['address'] as String? ?? 'unknown',
              body: row['body'] as String? ?? '',
              date: row['date'] as int? ?? 0,
            ))
        .toList();
  }
}

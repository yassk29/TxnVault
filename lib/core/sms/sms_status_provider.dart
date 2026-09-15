import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../../shared/providers/date_filter_provider.dart';
import 'sms_providers.dart';

class SmsStatusCounts {
  const SmsStatusCounts({
    required this.parsed,
    required this.autopayReference,
    required this.ignored,
    required this.unmatched,
    required this.pending,
  });

  final int parsed;
  final int autopayReference;
  final int ignored;
  final int unmatched;
  final int pending;

  int get total => parsed + autopayReference + ignored + unmatched + pending;
}

/// Drives the Dashboard's SMS breakdown so "N captured, M parsed" never
/// leaves the difference unexplained - every message is accounted for as
/// parsed, an autopay reference event (mandate created/revoked - no money
/// moved), recognized-but-not-a-transaction (ignored), not yet recognized
/// (unmatched), or still queued (pending). Respects sharedDateFilterProvider so
/// the whole breakdown can be scoped to a date range - never silently
/// drops a message, only narrows which ones are being counted.
final smsStatusCountsProvider =
    StreamProvider.autoDispose<SmsStatusCounts>((ref) async* {
  final db = ref.watch(databaseProvider);
  final dateFilter = ref.watch(sharedDateFilterProvider);
  final (startDate, endDate) = dateFilter.resolveBounds();

  while (true) {
    // Dismissed messages (see dismissSmsMessage) are left out of the
    // breakdown entirely - the user has already reviewed and hidden them.
    final query = db.select(db.smsMessages)
      ..where((t) => t.isDismissed.equals(false));
    if (startDate != null) {
      query.where((t) => t.receivedAt.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.receivedAt.isSmallerThanValue(endDate));
    }
    final rows = await query.get();

    var parsed = 0, autopayReference = 0, ignored = 0, unmatched = 0, pending = 0;
    for (final row in rows) {
      if (!row.isParsed) {
        pending++;
      } else {
        switch (row.parseStatus) {
          case 'parsed':
            parsed++;
          case 'autopayReference':
            autopayReference++;
          case 'ignored':
            ignored++;
          case 'unmatched':
            unmatched++;
          default:
            pending++;
        }
      }
    }
    yield SmsStatusCounts(
      parsed: parsed,
      autopayReference: autopayReference,
      ignored: ignored,
      unmatched: unmatched,
      pending: pending,
    );
    await Future.delayed(const Duration(seconds: 3));
  }
});

/// Raw SMS filtered by parse_status (and the current date filter), newest
/// first - backs the review screen where a user can see exactly which
/// messages were ignored/unmatched and why, rather than just a bare count.
final smsMessagesByStatusProvider =
    FutureProvider.autoDispose.family<List<SmsMessage>, String>((ref, status) {
  final db = ref.watch(databaseProvider);
  final dateFilter = ref.watch(sharedDateFilterProvider);
  final (startDate, endDate) = dateFilter.resolveBounds();

  final query = db.select(db.smsMessages)
    ..where((t) => t.parseStatus.equals(status) & t.isDismissed.equals(false));
  if (startDate != null) {
    query.where((t) => t.receivedAt.isBiggerOrEqualValue(startDate));
  }
  if (endDate != null) {
    query.where((t) => t.receivedAt.isSmallerThanValue(endDate));
  }
  query.orderBy(
      [(t) => OrderingTerm(expression: t.receivedAt, mode: OrderingMode.desc)]);
  return query.get();
});

/// SMS the user dismissed from the review screen - hidden from the
/// breakdown/counts, but never deleted, so they can be reviewed and
/// restored here. Mirrors excludedTransactionsProvider.
final dismissedSmsMessagesProvider =
    FutureProvider.autoDispose<List<SmsMessage>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.smsMessages)
        ..where((t) => t.isDismissed.equals(true))
        ..orderBy(
            [(t) => OrderingTerm(expression: t.receivedAt, mode: OrderingMode.desc)]))
      .get();
});

/// Hides an SMS from the review screen and Dashboard counts without losing
/// its parse classification - reversible via [restoreSmsMessage].
Future<void> dismissSmsMessage(WidgetRef ref, int smsId) async {
  final db = ref.read(databaseProvider);
  await (db.update(db.smsMessages)..where((t) => t.id.equals(smsId)))
      .write(const SmsMessagesCompanion(isDismissed: Value(true)));
}

Future<void> restoreSmsMessage(WidgetRef ref, int smsId) async {
  final db = ref.read(databaseProvider);
  await (db.update(db.smsMessages)..where((t) => t.id.equals(smsId)))
      .write(const SmsMessagesCompanion(isDismissed: Value(false)));
}

/// Autopay/mandate lifecycle events (created, revoked) - reference-only,
/// never counted as transactions.
final autopayEventsProvider = FutureProvider.autoDispose<List<AutopayEvent>>((ref) {
  final db = ref.watch(databaseProvider);
  final dateFilter = ref.watch(sharedDateFilterProvider);
  final (startDate, endDate) = dateFilter.resolveBounds();

  final query = db.select(db.autopayEvents);
  if (startDate != null) {
    query.where((t) => t.eventDate.isBiggerOrEqualValue(startDate));
  }
  if (endDate != null) {
    query.where((t) => t.eventDate.isSmallerThanValue(endDate));
  }
  query.orderBy(
      [(t) => OrderingTerm(expression: t.eventDate, mode: OrderingMode.desc)]);
  return query.get();
});

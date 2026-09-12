import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap/bootstrap.dart';
import '../database/app_database.dart';
import 'listener/native_sms_channel.dart';
import 'listener/sms_permission_service.dart';
import 'listener/sms_sync_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) => getIt<AppDatabase>());

final smsPermissionServiceProvider =
    Provider<SmsPermissionService>((ref) => SmsPermissionService());

final nativeSmsChannelProvider =
    Provider<NativeSmsChannel>((ref) => NativeSmsChannel());

final smsSyncServiceProvider = Provider<SmsSyncService>((ref) {
  return SmsSyncService(
    ref.watch(databaseProvider),
    ref.watch(nativeSmsChannelProvider),
  );
});

/// Re-checked on demand via `ref.invalidate` after a permission request.
final smsPermissionStatusProvider = FutureProvider<bool>((ref) {
  return ref.watch(smsPermissionServiceProvider).isGranted();
});

/// Polls rather than using Drift's `.watch()`: SmsReceiver.kt writes into the
/// same SQLite file through its own native connection (not through Drift), so
/// Drift's change-notification-based stream would never see those inserts.
/// `.autoDispose` stops the polling loop once nothing is listening.
final smsMessagesProvider =
    StreamProvider.autoDispose<List<SmsMessage>>((ref) async* {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.smsMessages)
    ..orderBy([
      (t) => OrderingTerm(expression: t.receivedAt, mode: OrderingMode.desc),
    ]);
  while (true) {
    yield await query.get();
    await Future.delayed(const Duration(seconds: 3));
  }
});

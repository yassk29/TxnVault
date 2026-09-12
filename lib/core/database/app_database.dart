import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';

import 'tables/merchants_table.dart';
import 'tables/payment_methods_table.dart';
import 'tables/cards_table.dart';
import 'tables/transactions_table.dart';
import 'tables/refunds_table.dart';
import 'tables/transaction_events_table.dart';
import 'tables/sms_messages_table.dart';
import 'tables/categories_table.dart';
import 'tables/app_settings_table.dart';

part 'app_database.g.dart';

const _nativeChannel = MethodChannel('com.txnvault.txnvault/native');

@DriftDatabase(tables: [
  Merchants,
  PaymentMethods,
  Cards,
  Transactions,
  Refunds,
  TransactionEvents,
  SmsMessages,
  Categories,
  TransactionCategories,
  AppSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await customStatement(
              'CREATE INDEX idx_transaction_date ON transactions(transaction_date)');
          await customStatement(
              'CREATE INDEX idx_transaction_status ON transactions(status)');
          await customStatement(
              'CREATE INDEX idx_transaction_amount ON transactions(amount)');
          await customStatement(
              'CREATE INDEX idx_merchant_name ON merchants(name)');
          await customStatement(
              'CREATE INDEX idx_refund_status ON refunds(refund_status)');
        },
      );
}

/// The database file lives at the path Android's `SmsReceiver` also writes
/// to (`context.getDatabasePath(...)`), so incoming SMS captured natively -
/// even while the Flutter engine isn't running - land in the same file Drift
/// reads from. See android/.../SmsReceiver.kt.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final path = await _nativeChannel.invokeMethod<String>('getDatabasePath');
    return NativeDatabase.createInBackground(File(path!));
  });
}

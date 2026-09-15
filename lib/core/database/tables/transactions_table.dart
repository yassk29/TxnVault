import 'package:drift/drift.dart';

import 'merchants_table.dart';
import 'payment_methods_table.dart';
import 'cards_table.dart';

/// status: SUCCESS | FAILED | REFUND_REQUESTED | REFUND_INITIATED |
/// REFUND_RECEIVED | REFUND_DELAYED | REVERSAL_PENDING | REVERSED
///
/// direction: DEBIT | CREDIT. Added in schema v2 - real bank SMS include
/// plenty of incoming money (UPI received, cashback, P2P transfers) that
/// isn't a refund of any prior transaction, so direction has to be tracked
/// independently of the refund lifecycle.
///
/// smsReceivedAt: added in schema v3. Many bank templates only state a date,
/// no time-of-day, so transactionDate often defaults to midnight - sorting
/// by it puts same-day transactions in an arbitrary order and makes a fake
/// "12:00 AM" look like real precision. The SMS's actual receipt time always
/// has full precision and closely tracks real transaction time, so it's used
/// for ordering while transactionDate (date portion only) is what's shown.
///
/// category: SPEND | INCOME | REPAYMENT. Added in schema v4. direction says
/// which way money moved; category says what kind of movement it was - in
/// particular, paying off a credit card or loan bill is neither a purchase
/// nor income, so it's tracked separately rather than folded into whichever
/// direction it happens to be.
///
/// isExcluded: added in schema v5. Lets a user hide a transaction from the
/// History list and totals without deleting it - reversible, unlike
/// deletion, since a parser can be technically correct about a message
/// while the user still doesn't want it counted (e.g. a shared/business
/// card's spend showing up in a personal ledger).
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get externalTransactionId => text().nullable()();
  IntColumn get merchantId => integer().nullable().references(Merchants, #id)();
  IntColumn get paymentMethodId =>
      integer().nullable().references(PaymentMethods, #id)();
  IntColumn get cardId => integer().nullable().references(Cards, #id)();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  TextColumn get direction => text().withDefault(const Constant('DEBIT'))();
  DateTimeColumn get transactionDate => dateTime()();
  DateTimeColumn get smsReceivedAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get category => text().withDefault(const Constant('SPEND'))();
  BoolColumn get isExcluded => boolean().withDefault(const Constant(false))();
  TextColumn get status => text()();
  TextColumn get bankName => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get smsSource => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

import 'package:drift/drift.dart';

import 'transactions_table.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Many-to-many mapping between transactions and categories.
class TransactionCategories extends Table {
  IntColumn get transactionId => integer().references(Transactions, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();

  @override
  Set<Column> get primaryKey => {transactionId, categoryId};
}

import 'package:flutter/material.dart';

enum TransactionStatus {
  success,
  failed,
  refundRequested,
  refundInitiated,
  refundReceived,
  refundDelayed,
  reversalPending,
  reversed,
}

extension TransactionStatusX on TransactionStatus {
  String get label => switch (this) {
        TransactionStatus.success => 'Success',
        TransactionStatus.failed => 'Failed',
        TransactionStatus.refundRequested => 'Refund Requested',
        TransactionStatus.refundInitiated => 'Refund Initiated',
        TransactionStatus.refundReceived => 'Refund Received',
        TransactionStatus.refundDelayed => 'Refund Delayed',
        TransactionStatus.reversalPending => 'Reversal Pending',
        TransactionStatus.reversed => 'Reversed',
      };

  Color get color => switch (this) {
        TransactionStatus.success => Colors.green,
        TransactionStatus.refundReceived => Colors.green,
        TransactionStatus.refundRequested => Colors.orange,
        TransactionStatus.refundInitiated => Colors.orange,
        TransactionStatus.reversalPending => Colors.orange,
        TransactionStatus.refundDelayed => Colors.red,
        TransactionStatus.failed => Colors.red,
        TransactionStatus.reversed => Colors.blue,
      };
}

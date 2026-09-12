import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TxnVault')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Dashboard\n\nTotal Spend, Pending Refunds and Recent '
            'Transactions will appear here once SMS capture is wired up.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

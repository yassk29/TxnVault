import 'package:flutter/material.dart';

class RefundsScreen extends StatelessWidget {
  const RefundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refund Center')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              const Text('No pending refunds.'),
              const Text("You're all caught up."),
            ],
          ),
        ),
      ),
    );
  }
}

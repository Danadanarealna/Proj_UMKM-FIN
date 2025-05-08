import 'package:flutter/material.dart';

class UpdateTransactionScreen extends StatelessWidget {
  final List pendingTransactions;
  const UpdateTransactionScreen({super.key, required this.pendingTransactions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Transactions')),
      body: ListView.builder(
        itemCount: pendingTransactions.length,
        itemBuilder: (context, index) {
          final transaction = pendingTransactions[index];
          return ListTile(
            title: Text(transaction.id),
            subtitle: Text(transaction.amount),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => Navigator.pop(context, {'transaction': transaction, 'status': 'Done'}),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => Navigator.pop(context, {'transaction': transaction, 'status': 'Cancelled'}),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
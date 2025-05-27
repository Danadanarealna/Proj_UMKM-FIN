import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api.dart';
import 'main.dart';

class UpdateTransactionScreen extends StatefulWidget {
  final List<Transaction> pendingTransactions;
  const UpdateTransactionScreen({super.key, required this.pendingTransactions});

  @override
  State<UpdateTransactionScreen> createState() => _UpdateTransactionScreenState();
}

class _UpdateTransactionScreenState extends State<UpdateTransactionScreen> {
  Future<void> _updateStatus(Transaction transaction, String newStatus) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/transactions/${transaction.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'amount': transaction.amount,
          'type': transaction.type,
          'status': newStatus,
          'date': DateFormat('dd MMM yyyy').format(transaction.date),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context, {
            'success': true,
            'transactionId': transaction.id,
            'newStatus': newStatus
          });
        }
      } else {
        final error = jsonDecode(response.body)['message'] ?? 'Update failed';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Transactions')),
      body: ListView.builder(
        itemCount: widget.pendingTransactions.length,
        itemBuilder: (context, index) {
          final transaction = widget.pendingTransactions[index];
          return ListTile(
            title: Text(transaction.id.toString()),
            subtitle: Text('\$${transaction.amount.toString()}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _updateStatus(transaction, 'Done'),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _updateStatus(transaction, 'Cancelled'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
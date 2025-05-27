import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class DeleteTransactionScreen extends StatefulWidget {
  final List transactions;
  const DeleteTransactionScreen({super.key, required this.transactions});

  @override
  State<DeleteTransactionScreen> createState() => _DeleteTransactionScreenState();
}

class _DeleteTransactionScreenState extends State<DeleteTransactionScreen> {
  final TextEditingController _searchController = TextEditingController();
  List _searchResults = [];

  void _searchTransactions(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchResults = widget.transactions;
      } else {
        _searchResults = widget.transactions.where((transaction) {
          final formattedDate = DateFormat('dd MMM yyyy').format(transaction.date);
          return transaction.id.toString().contains(query) ||
              formattedDate.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _deleteTransaction(String transactionId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/transactions/$transactionId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          setState(() {
            _searchResults.removeWhere((t) => t.id == transactionId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction deleted successfully')),
          );
          Navigator.pop(context, true); // Return success flag
        }
      } else {
        final error = jsonDecode(response.body)['message'] ?? 'Deletion failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Transaction')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _searchTransactions,
              decoration: const InputDecoration(
                labelText: 'Search by ID or Date',
                suffixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final transaction = _searchResults[index];
                return ListTile(
                  title: Text(transaction.id.toString()),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(transaction.date)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteTransaction(transaction.id.toString()),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
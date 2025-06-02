import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'main.dart';

class DeleteTransactionScreen extends StatefulWidget {
  final List<Transaction> transactions;
  const DeleteTransactionScreen({super.key, required this.transactions});

  @override
  State<DeleteTransactionScreen> createState() => _DeleteTransactionScreenState();
}

class _DeleteTransactionScreenState extends State<DeleteTransactionScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Transaction> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchResults = List.from(widget.transactions);
    _searchResults.sort((a, b) => (b.userSequenceId ?? 0).compareTo(a.userSequenceId ?? 0));
  }


  void _searchTransactions(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchResults = List.from(widget.transactions);
        _searchResults.sort((a, b) => (b.userSequenceId ?? 0).compareTo(a.userSequenceId ?? 0));
      } else {
        _searchResults = widget.transactions.where((transaction) {
          final formattedDate = DateFormat('dd MMM yy').format(transaction.date);
          return (transaction.userSequenceId?.toString().contains(query) ?? false) ||
              formattedDate.toLowerCase().contains(query.toLowerCase()) ||
              (transaction.notes?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
              (transaction.paymentMethod?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
              transaction.type.toLowerCase().contains(query.toLowerCase());
        }).toList();
        _searchResults.sort((a, b) => (b.userSequenceId ?? 0).compareTo(a.userSequenceId ?? 0));
      }
    });
  }

  Future<void> _deleteTransaction(String transactionDatabaseId, int? transactionUserSequenceId) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete transaction with ID: ${transactionUserSequenceId ?? transactionDatabaseId}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) {
      return;
    }

    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication error. Please login again.'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/transactions/$transactionDatabaseId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (response.statusCode == 200 || response.statusCode == 204) {
          setState(() {
            widget.transactions.removeWhere((t) => t.id == transactionDatabaseId);
            _searchTransactions(_searchController.text);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction deleted successfully'), backgroundColor: Colors.green),
          );
        } else {
          final errorData = jsonDecode(response.body);
          String errorMessage = errorData['message'] ?? 'Deletion failed.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Transaction')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _searchTransactions,
              decoration: InputDecoration(
                labelText: 'Search by ID, Date, Type, Payment, or Notes',
                hintText: 'Enter ID, date (e.g. 02 Jun 24)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
            const Expanded(
              child: Center(
                child: Text('No transactions found matching your search.', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ),
            )
          else if (widget.transactions.isEmpty)
             const Expanded(
              child: Center(
                child: Text('No transactions available to delete.', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final transaction = _searchResults[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: transaction.isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        child: Icon(
                          transaction.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: transaction.isIncome ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'ID: ${transaction.userSequenceId?.toString() ?? "N/A"} - ${transaction.type}',
                        style: const TextStyle(fontWeight: FontWeight.w500)
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amount: \$${transaction.amount.abs().toStringAsFixed(2)}'),
                          Text('Date: ${DateFormat('dd MMM yy').format(transaction.date)}'),
                           if(transaction.paymentMethod != null) Text('Payment: ${transaction.paymentMethod}'),
                          if(transaction.notes != null && transaction.notes!.isNotEmpty) Text('Notes: ${transaction.notes}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                        tooltip: 'Delete Transaction',
                        onPressed: _isLoading ? null : () => _deleteTransaction(transaction.id, transaction.userSequenceId),
                      ),
                      isThreeLine: (transaction.paymentMethod != null || (transaction.notes != null && transaction.notes!.isNotEmpty)),
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

import 'package:flutter/material.dart';

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
      _searchResults = widget.transactions.where((transaction) {
        return transaction.id.toLowerCase().contains(query.toLowerCase()) ||
            transaction.date.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
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
                  title: Text(transaction.id),
                  subtitle: Text(transaction.date),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      Navigator.pop(context, transaction);
                    },
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
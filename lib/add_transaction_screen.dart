import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class AddTransactionScreen extends StatefulWidget {
  final bool isIncome;
  const AddTransactionScreen({super.key, required this.isIncome});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'Cash';
  String _selectedStatus = 'Pending';
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _amountController = TextEditingController();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: ['Cash', 'Credit'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedType = value!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              ListTile(
                title: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                items: ['Done', 'Pending'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedStatus = value!),
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                if (_formKey.currentState!.validate()) {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('token');

                try {
                  final response = await http.post(
                    Uri.parse('$apiBaseUrl/transactions'),
                    headers: {
                      'Authorization': 'Bearer $token',
                      'Content-Type': 'application/json'
                    },
                    body: jsonEncode({  'amount': widget.isIncome 
                          ? double.parse(_amountController.text)
                          : -double.parse(_amountController.text),
                      'type': _selectedType,
                      'status': _selectedStatus,
                      'date': DateFormat('dd MMM yyyy').format(_selectedDate),
                    }),
                  );
                  if (response.statusCode == 200 || response.statusCode == 201) {
                    if (mounted) Navigator.pop(context, true);
                  } else {
                    final error = jsonDecode(response.body)['message'] ?? 'Transaction failed';
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
              },
                child: const Text('Add Transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
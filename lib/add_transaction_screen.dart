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
  String _selectedPaymentMethod = 'Cash';
  String _selectedStatus = 'Pending';
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;


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

  Future<void> _submitTransaction() async {
    if (_formKey.currentState!.validate()) {
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

      String transactionType = widget.isIncome ? 'Income' : 'Expense';
      String notes = _notesController.text.trim();

      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/transactions'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'amount': widget.isIncome
                ? double.parse(_amountController.text)
                : -double.parse(_amountController.text),
            'type': transactionType, 
            'payment_method': _selectedPaymentMethod,
            'status': _selectedStatus,
            'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
            'notes': notes, 
          }),
        );

        if (mounted) {
           setState(() => _isLoading = false);
          if (response.statusCode == 200 || response.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$transactionType transaction added successfully!'), backgroundColor: Colors.green),
            );
            Navigator.pop(context, true);
          } else {
            final errorData = jsonDecode(response.body);
            String errorMessage = errorData['message'] ?? 'Failed to add transaction.';
            if (errorData['errors'] != null && errorData['errors'] is Map) {
                Map<String,dynamic> errors = errorData['errors'];
                if(errors.isNotEmpty){
                    errorMessage = errors.values.first[0];
                }
            }
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
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add ${widget.isIncome ? "Income" : "Expense"}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.attach_money_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Amount is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Invalid amount';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Amount must be positive';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                items: ['Cash', 'Credit', 'Bank Transfer', 'E-Wallet', 'Other'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  prefixIcon: Icon(Icons.payment_outlined),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text('Date: ${DateFormat('dd MMM yy').format(_selectedDate)}'),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                items: ['Done', 'Pending', 'Cancelled'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedStatus = value!),
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)
                ),
                child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                  : Text('Add ${widget.isIncome ? "Income" : "Expense"}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class AddDebtScreen extends StatefulWidget {
  const AddDebtScreen({super.key});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedDeadline = DateTime.now().add(const Duration(days: 30));
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context, bool isDeadline) async {
    final DateTime initial = isDeadline ? _selectedDeadline : _selectedDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != initial) {
      setState(() {
        if (isDeadline) {
          _selectedDeadline = picked;
        } else {
          _selectedDate = picked;
          if (_selectedDeadline.isBefore(_selectedDate)) {
            _selectedDeadline = _selectedDate.add(const Duration(days: 1));
          }
        }
      });
    }
  }

  Future<void> _submitDebt() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/debts'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'amount': double.parse(_amountController.text),
            'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
            'deadline': DateFormat('yyyy-MM-dd').format(_selectedDeadline),
            'notes': _notesController.text,
          }),
        );
        if (mounted) {
           setState(() => _isLoading = false);
          if (response.statusCode == 201) {
            Navigator.pop(context, true);
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Debt added successfully!'), backgroundColor: Colors.green),
            );
          } else {
            final error = jsonDecode(response.body)['message'] ?? jsonDecode(response.body)['errors']?.values?.first[0] ?? 'Failed to add debt';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
         if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Network error: $e'), backgroundColor: Colors.red),
           );
         }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Debt (Receivable)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount', prefixIcon: Icon(Icons.attach_money)),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Amount is required';
                  if (double.tryParse(value) == null) return 'Invalid amount';
                  if (double.parse(value) <= 0) return 'Amount must be positive';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date Incurred: ${DateFormat('dd MMM yyyy').format(_selectedDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, false),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Deadline: ${DateFormat('dd MMM yyyy').format(_selectedDeadline)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, true),
              ),
               if (_selectedDeadline.isBefore(_selectedDate))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('Deadline must be on or after the date incurred.', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes (Optional)', prefixIcon: Icon(Icons.notes)),
                maxLines: 3,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading || _selectedDeadline.isBefore(_selectedDate) ? null : _submitDebt,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                    : const Text('Add Debt'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

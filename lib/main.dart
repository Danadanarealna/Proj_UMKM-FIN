import 'package:flutter/material.dart';
import 'auth.dart';
import 'add_transaction_screen.dart';
import 'delete_transaction_screen.dart';
import 'update_transaction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'api.dart';
import 'dart:io';
import 'dart:async';

void main() {
  runApp(const FinanceDashboardApp());
}

class FinanceDashboardApp extends StatelessWidget {
  const FinanceDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC)),
      home: const AuthWrapper(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showIncome = true;
  String _selectedId = '';
  String _selectedAmount = '';
  String _selectedStatus = '';
  String _selectedDate = '';
  // late Future<List<Transaction>> _transactionsFuture;
  final _prefs = SharedPreferences.getInstance();
  String? _authToken;
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }


Future<void> _loadTransactions() async {
  if (mounted) setState(() => _isLoading = true);
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) {
      if (mounted) showAuthError(context);
      return;
    }

    final response = await http.get(
      Uri.parse('$apiBaseUrl/transactions'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      if (mounted) {
        setState(() {
          _transactions = data.map((t) => Transaction.fromJson(t)).toList();
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        showError(context, 
          'Server error: ${response.statusCode}\n${response.body}');
      }
    }
  } on FormatException catch (e) {
    if (mounted) showError(context, 'Data format error: ${e.message}');
  } on SocketException {
    if (mounted) showError(context, 'Network connection failed');
  } on TimeoutException {
    if (mounted) showError(context, 'Request timed out');
  } catch (e) {
    if (mounted) showError(context, 'Unexpected error: ${e.toString()}');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

// Add these helper methods
void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
}

void showAuthError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Authentication required')),
  );
}

  // Future<List<Transaction>> _fetchTransactions() async {
  //   final prefs = await _prefs;
  //   _authToken = prefs.getString('token');

  //   final response = await http.get(
  //     Uri.parse('$apiBaseUrl/transactions'),
  //     headers: {'Authorization': 'Bearer $_authToken'},
  //   );

  //   if (response.statusCode == 200) {
  //     final data = jsonDecode(response.body) as List;
  //     return data.map((t) => Transaction.fromJson(t)).toList();
  //   }
  //   return [];
  // }

double get _totalIncome => _transactions
    .where((t) => t.isIncome && (t.status == 'Done'))
    .fold(0.0, (sum, t) => sum + t.amount.abs());

double get _totalExpense => _transactions
    .where((t) => !t.isIncome && (t.status == 'Done'))
    .fold(0.0, (sum, t) => sum + t.amount.abs());

  void _updateSelectedTransaction(Transaction transaction) {
    setState(() {
      _selectedId = transaction.id;
      _selectedAmount = '${transaction.amount > 0 ? '+' : '-'} \$${transaction.amount.abs().toStringAsFixed(2)}';
      _selectedStatus = transaction.status;
      _selectedDate = DateFormat('dd MMM yyyy').format(transaction.date);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24).copyWith(bottom: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Halo,',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Username',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _ActionButton(
                            icon: Icons.add,
                            color: const Color(0xFF3B82F6),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AddTransactionScreen(isIncome: _showIncome),
                                ),
                              );
                              if (result != null) {
                                _loadTransactions();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.remove,
                            color: const Color(0xFFEF4444),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DeleteTransactionScreen(
                                    transactions: _transactions,
                                  ),
                                ),
                              );
                              if (result != null) {
                              _loadTransactions();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.check,
                            color: const Color(0xFF10B981),
                            onPressed: () async {
                                final pending = _transactions
                                .where((t) => t.status == 'Pending')
                                .toList();
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UpdateTransactionScreen(pendingTransactions: pending),
                                ),
                              );
                              if (result != null && result['transaction'] != null) {
                                _loadTransactions();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _showIncome = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _showIncome ? Colors.white : null,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _showIncome
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(25),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Income',
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${_totalIncome.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[500]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _showIncome = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_showIncome ? Colors.white : null,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !_showIncome
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(25),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Expense',
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${_totalExpense.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red[500]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Text(
                                  'List Transaction',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B)),
                              ),
                          ]),
                          ),
                          SizedBox(
                            height: 300,
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : _buildTransactionList(
                                    _transactions
                                        .where((t) => _showIncome ? t.isIncome : !t.isIncome)
                                        .toList(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Transaction Detail',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B)),
                            ),
                        ]),
                          const SizedBox(height: 16),
                          _DetailRow(
                            label: 'ID:',
                            value: _selectedId,
                            valueStyle: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: 'Amount:',
                            value: _selectedAmount,
                            valueStyle: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _selectedAmount.startsWith('+')
                                  ? Colors.green[500]
                                  : Colors.red[500]),
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: 'Status:',
                            valueWidget: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(_selectedStatus),
                                borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                _selectedStatus,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStatusTextColor(_selectedStatus)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: 'Date:',
                            value: _selectedDate,
                            valueStyle: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _BottomNavButton(
                    icon: Icons.home,
                    label: 'Home',
                    isActive: true,
                    onPressed: () {},
                  ),
                  _BottomNavButton(
                    icon: Icons.analytics,
                    label: 'Analysis',
                    isActive: false,
                    onPressed: () {},
                  ),
                  _BottomNavButton(
                    icon: Icons.person,
                    label: 'Profile',
                    isActive: false,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Updated transaction list builder
Widget _buildTransactionList(List<Transaction> transactions) {
  return ListView.builder(
    shrinkWrap: true,
    physics: const AlwaysScrollableScrollPhysics(),
    itemCount: transactions.length,
    itemBuilder: (context, index) {
      final transaction = transactions[index];
      return InkWell(
        onTap: () => _updateSelectedTransaction(transaction),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  transaction.id,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Expanded(
                child: Text(
                  '${transaction.isIncome ? '+' : '-'} \$${transaction.amount.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: transaction.isIncome 
                        ? Colors.green[500] 
                        : Colors.red[500],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(transaction.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    transaction.status,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusTextColor(transaction.status),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFFEF3C7);
      case 'Done':
        return const Color(0xFFD1FAE5);
      case 'Cancelled':
        return const Color(0xFFFEE2E2);
      default:
        return Colors.grey;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFD97706);
      case 'Done':
        return const Color(0xFF059669);
      case 'Cancelled':
        return const Color(0xFFB91C1C);
      default:
        return Colors.black;
    }
  }
}
class Transaction {
  final String id;
  final double amount;
  String status;
  final DateTime date;
  final String type;
  final bool isIncome;

  Transaction({
    required this.id,
    required this.amount,
    required this.status,
    required this.date,
    required this.type,
    required this.isIncome,
  });

factory Transaction.fromJson(Map<String, dynamic> json) {
  try {
    return Transaction(
      id: json['id'].toString(),
      amount: double.parse(json['amount'].toString()),
      status: json['status'],
      date: DateFormat('dd MMM yyyy', 'en_US').parse(json['date'].toString()),
      type: json['type'],
      isIncome: double.parse(json['amount'].toString()) > 0,
    );
  } catch (e) {
    print('Error parsing transaction date: ${json['date']}');
    print('Error details: $e');
    rethrow;
  }
}
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8)),
        child: Center(
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final TextStyle? valueStyle;

  const _DetailRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.valueStyle,
  }) : assert(value != null || valueWidget != null);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B)),
        ),if (value != null)
          Text(value!, style: valueStyle),
        if (valueWidget != null) valueWidget!,
      ],
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _BottomNavButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF64748B)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
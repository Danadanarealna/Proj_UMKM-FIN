import 'package:flutter/material.dart';
import 'auth.dart';

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
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
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
  String _selectedId = '#TRX001';
  String _selectedAmount = '+ \$2,500';
  String _selectedStatus = 'Done';
  String _selectedDate = '12 Jun 2023';

  void _updateSelectedTransaction(
    String id,
    String amount,
    String status,
    String date,
  ) {
    setState(() {
      _selectedId = id;
      _selectedAmount = amount;
      _selectedStatus = status;
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                            onPressed: () {},
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.remove,
                            color: const Color(0xFFEF4444),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.check,
                            color: const Color(0xFF10B981),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Toggle Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showIncome = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _showIncome ? Colors.white : null,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _showIncome
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Pemasukan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$4,500',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showIncome = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_showIncome ? Colors.white : null,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !_showIncome
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Pengeluaran',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$1,200',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red[500],
                                    ),
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
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Transactions Table
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
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
                                  'List Transaksi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 300,
                            child: _showIncome
                                ? _buildIncomeTransactions()
                                : _buildExpenseTransactions(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Transaction Details
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
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
                                'Detail Transaksi',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _DetailRow(
                            label: 'ID:',
                            value: _selectedId,
                            valueStyle: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: 'Jumlah:',
                            value: _selectedAmount,
                            valueStyle: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _selectedAmount.startsWith('+')
                                  ? Colors.green[500]
                                  : Colors.red[500],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: 'Status:',
                            valueWidget: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(_selectedStatus),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _selectedStatus,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStatusTextColor(_selectedStatus),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: 'Tanggal:',
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
            // Bottom Navigation
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1,
                  ),
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

  Widget _buildIncomeTransactions() {
    final incomeTransactions = [
      _Transaction('#TRX001', '+ \$2,500', 'Done'),
      _Transaction('#TRX002', '+ \$1,200', 'Pending'),
      _Transaction('#TRX003', '+ \$800', 'Cancelled'),
      _Transaction('#TRX004', '+ \$1,500', 'Done'),
      _Transaction('#TRX005', '+ \$750', 'Pending'),
      _Transaction('#TRX006', '+ \$1,000', 'Done'),
    ];

    return _buildTransactionList(incomeTransactions);
  }

  Widget _buildExpenseTransactions() {
    final expenseTransactions = [
      _Transaction('#TRX101', '- \$450', 'Done'),
      _Transaction('#TRX102', '- \$600', 'Pending'),
      _Transaction('#TRX103', '- \$150', 'Cancelled'),
      _Transaction('#TRX104', '- \$300', 'Done'),
      _Transaction('#TRX105', '- \$200', 'Pending'),
      _Transaction('#TRX106', '- \$500', 'Cancelled'),
    ];

    return _buildTransactionList(expenseTransactions);
  }

  Widget _buildTransactionList(List<_Transaction> transactions) {
    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return InkWell(
          onTap: () {
            final randomDay = (index % 28) + 1;
            _updateSelectedTransaction(
              transaction.id,
              transaction.amount,
              transaction.status,
              '$randomDay Jun 2023',
            );
          },
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
                    transaction.amount,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: transaction.amount.startsWith('+')
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

class _Transaction {
  final String id;
  final String amount;
  final String status;

  _Transaction(this.id, this.amount, this.status);
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
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
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
          style: const TextStyle(
            color: Color(0xFF64748B),
          ),
        ),
        if (value != null)
          Text(
            value!,
            style: valueStyle,
          ),
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
            color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'main.dart'; 

class AnalysisScreen extends StatefulWidget {
  final List<Transaction> allTransactions;
  final List<DebtModel> allDebts;
  final Future<void> Function() onRefresh;

  const AnalysisScreen({
    super.key,
    required this.allTransactions,
    required this.allDebts,
    required this.onRefresh,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  List<Transaction> get _pendingTransactions => widget.allTransactions
      .where((transaction) => transaction.status == 'Pending')
      .toList();
      
  List<DebtModel> get _pendingVerificationDebts => widget.allDebts
      .where((debt) => debt.status == 'pending_verification')
      .toList()..sort((a,b) => a.deadline.compareTo(b.deadline));


  double get _totalIncome => widget.allTransactions
      .where((t) => t.isIncome && t.status == 'Done')
      .fold(0.0, (sum, t) => sum + t.amount.abs());

  double get _totalExpense => widget.allTransactions
      .where((t) => !t.isIncome && t.status == 'Done')
      .fold(0.0, (sum, t) => sum + t.amount.abs());

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFFFFBEB); 
      case 'Done':
        return const Color(0xFFF0FDF4); 
      case 'Cancelled':
        return const Color(0xFFFEF2F2); 
      default:
        return Colors.grey.shade100;
    }
  }
  
  Color _getDebtStatusColor(String status) {
    switch (status) {
      case 'pending_verification': return const Color(0xFFFFFBEB); 
      case 'verified_income_recorded': return const Color(0xFFF0FDF4);
      case 'cancelled': return const Color(0xFFFEF2F2);
      default: return Colors.grey.shade100;
    }
  }


  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFB45309); 
      case 'Done':
        return const Color(0xFF15803D); 
      case 'Cancelled':
        return const Color(0xFFB91C1C); 
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getDebtStatusTextColor(String status) {
    switch (status) {
      case 'pending_verification': return const Color(0xFFB45309); 
      case 'verified_income_recorded': return const Color(0xFF15803D); 
      case 'cancelled': return const Color(0xFFB91C1C); 
      default: return Colors.grey.shade700;
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Analysis'),
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: theme.colorScheme.primary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFinancialOverviewCard(theme),
              const SizedBox(height: 24),
              _buildPendingTransactionsCard(theme),
              const SizedBox(height: 24),
              _buildPendingDebtsCard(theme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialOverviewCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Overview (Completed Transactions)',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryFigure(
                    "Total Income",
                    _totalIncome,
                    Icons.arrow_circle_down_rounded,
                    Colors.green.shade700,
                    theme,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryFigure(
                    "Total Expense",
                    _totalExpense,
                    Icons.arrow_circle_up_rounded,
                    Colors.red.shade700,
                    theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Income vs Expense',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildSimpleBarChart(_totalIncome, _totalExpense, theme),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Income', Colors.green.shade400, theme),
                const SizedBox(width: 24),
                _buildLegendItem('Expense', Colors.red.shade400, theme),
              ],
            ),
            const SizedBox(height: 20),
            _buildNetBalance(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryFigure(String title, double amount, IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(77))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: theme.textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleBarChart(double income, double expense, ThemeData theme) {
    double maxValue = (income > expense ? income : expense);
    if (maxValue == 0) maxValue = 1;

    double incomeBarHeight = income > 0 ? (income / maxValue * 150).clamp(10.0, 150.0) : 0;
    double expenseBarHeight = expense > 0 ? (expense / maxValue * 150).clamp(10.0, 150.0) : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth / 4.5;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildChartBar('Income', income, incomeBarHeight, barWidth, Colors.green.shade400, theme),
            _buildChartBar('Expense', expense, expenseBarHeight, barWidth, Colors.red.shade400, theme),
          ],
        );
      }
    );
  }

  Widget _buildChartBar(String label, double value, double height, double width, Color color, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '\$${value.toStringAsFixed(0)}',
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.grey[700]),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildNetBalance(ThemeData theme) {
    final netBalance = _totalIncome - _totalExpense;
    final bool isPositive = netBalance >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.withAlpha(26) : Colors.red.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Net Balance:',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: isPositive ? Colors.green.shade800 : Colors.red.shade800),
          ),
          Text(
            '\$${netBalance.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTransactionsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pending Transactions',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Chip(
                  label: Text('${_pendingTransactions.length} items'),
                  backgroundColor: _getStatusColor('Pending'),
                  labelStyle: TextStyle(color: _getStatusTextColor('Pending'), fontSize: 12, fontWeight: FontWeight.w500),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  visualDensity: VisualDensity.compact,
                )
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _pendingTransactions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30.0),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 50, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text('No pending transactions.', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _pendingTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _pendingTransactions[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: transaction.isIncome
                                ? Colors.green.withAlpha(26)
                                : Colors.red.withAlpha(26),
                            child: Icon(
                              transaction.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: transaction.isIncome ? Colors.green.shade600 : Colors.red.shade600,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'ID: ${transaction.userSequenceId ?? transaction.id.substring(0,8)}',
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
                          ),
                          subtitle: Text(
                            DateFormat('dd MMM, yy').format(transaction.date),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: Text(
                            '${transaction.isIncome ? '+' : '-'}\$${transaction.amount.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: transaction.isIncome ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (context, index) => Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[200]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingDebtsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pending Debts (Receivables)',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Chip(
                  label: Text('${_pendingVerificationDebts.length} items'),
                  backgroundColor: _getDebtStatusColor('pending_verification'),
                  labelStyle: TextStyle(color: _getDebtStatusTextColor('pending_verification'), fontSize: 12, fontWeight: FontWeight.w500),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  visualDensity: VisualDensity.compact,
                )
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _pendingVerificationDebts.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30.0),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.money_off_csred_outlined, size: 50, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text('No pending debts to verify.', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _pendingVerificationDebts.length,
                      itemBuilder: (context, index) {
                        final debt = _pendingVerificationDebts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.withAlpha(26),
                            child: Icon(
                              Icons.receipt_long_outlined,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Debt ID: ${debt.id}',
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
                          ),
                          subtitle: Text(
                            'Deadline: ${DateFormat('dd MMM, yy').format(debt.deadline)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: Text(
                            '\$${debt.amount.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (context, index) => Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[200]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

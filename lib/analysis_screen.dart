import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting if needed for display
import 'main.dart'; // Assuming Transaction class is here

// Import a charting library if you want more advanced charts.
// For this example, a simple custom bar chart is used.
// Example:
// import 'package:fl_chart/fl_chart.dart';

class AnalysisScreen extends StatefulWidget {
  final List<Transaction> allTransactions;
  final Future<void> Function() onRefresh;

  const AnalysisScreen({
    super.key,
    required this.allTransactions,
    required this.onRefresh,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  List<Transaction> get _pendingTransactions => widget.allTransactions
      .where((transaction) => transaction.status == 'Pending')
      .toList();

  // Calculate total income from 'Done' transactions
  double get _totalIncome => widget.allTransactions
      .where((t) => t.isIncome && t.status == 'Done')
      .fold(0.0, (sum, t) => sum + t.amount.abs());

  // Calculate total expense from 'Done' transactions
  double get _totalExpense => widget.allTransactions
      .where((t) => !t.isIncome && t.status == 'Done')
      .fold(0.0, (sum, t) => sum + t.amount.abs());

  // Helper to get status color for UI consistency
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFFFFBEB); // Lighter Yellow (Tailwind amber-50)
      case 'Done':
        return const Color(0xFFF0FDF4); // Lighter Green (Tailwind green-50)
      case 'Cancelled':
        return const Color(0xFFFEF2F2); // Lighter Red (Tailwind red-50)
      default:
        return Colors.grey.shade100;
    }
  }

  // Helper to get status text color
  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFB45309); // Darker Yellow/Orange (Tailwind amber-700)
      case 'Done':
        return const Color(0xFF15803D); // Darker Green (Tailwind green-700)
      case 'Cancelled':
        return const Color(0xFFB91C1C); // Darker Red (Tailwind red-700)
      default:
        return Colors.grey.shade700;
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
              'Financial Overview',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryFigure(
                    "Total Income (Done)",
                    _totalIncome,
                    Icons.arrow_circle_down_rounded,
                    Colors.green.shade700,
                    theme,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryFigure(
                    "Total Expense (Done)",
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
              'Income vs Expense (Completed Transactions)',
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3))
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
    if (maxValue == 0) maxValue = 1; // Avoid division by zero for proportions

    double incomeBarHeight = income > 0 ? (income / maxValue * 150).clamp(10.0, 150.0) : 0;
    double expenseBarHeight = expense > 0 ? (expense / maxValue * 150).clamp(10.0, 150.0) : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth / 4.5; // Adjust for spacing
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
        // Label is now part of the legend
        // const SizedBox(height: 6),
        // Text(label, style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey[600])),
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
        color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
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
              constraints: const BoxConstraints(maxHeight: 300), // Limit height for scrollability
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
                      shrinkWrap: true, // Important for ListView inside SingleChildScrollView with bounded height
                      itemCount: _pendingTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _pendingTransactions[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: transaction.isIncome
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            child: Icon(
                              transaction.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: transaction.isIncome ? Colors.green.shade600 : Colors.red.shade600,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'ID: ${transaction.id.length > 15 ? '${transaction.id.substring(0,8)}...' : transaction.id}',
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, fontFamily: 'monospace', color: Colors.grey),
                          ),
                          subtitle: Text(
                            DateFormat('dd MMM, yyyy').format(transaction.date),
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
                          // You might want to add an onTap to view/update the pending transaction
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

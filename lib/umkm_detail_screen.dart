import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'main.dart'; // For Transaction model and launchWhatsApp helper

class UmkmDetail {
  final int id;
  final String ownerName;
  final String email;
  final String umkmName;
  final String umkmContact;

  UmkmDetail({
    required this.id,
    required this.ownerName,
    required this.email,
    required this.umkmName,
    required this.umkmContact,
  });

  factory UmkmDetail.fromJson(Map<String, dynamic> json) {
    return UmkmDetail(
      id: json['id'] as int? ?? 0,
      ownerName: json['name']?.toString() ?? 'N/A',
      email: json['email']?.toString() ?? 'N/A',
      umkmName: json['umkm_name']?.toString() ?? 'Unnamed UMKM',
      umkmContact: json['umkm_contact']?.toString() ?? 'No Contact',
    );
  }
}

class FinancialSummary {
  final double totalIncome;
  final double totalExpense;
  final double netProfit;

  FinancialSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    return FinancialSummary(
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0.0,
      totalExpense: (json['total_expense'] as num?)?.toDouble() ?? 0.0,
      netProfit: (json['net_profit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class UmkmDetailScreen extends StatefulWidget {
  final int umkmId;
  final String umkmName; // Passed for AppBar title initially

  const UmkmDetailScreen({
    super.key,
    required this.umkmId,
    required this.umkmName,
  });

  @override
  State<UmkmDetailScreen> createState() => _UmkmDetailScreenState();
}

class _UmkmDetailScreenState extends State<UmkmDetailScreen> {
  UmkmDetail? _umkmDetail;
  FinancialSummary? _financialSummary;
  List<Transaction> _transactions = []; // 'Done' transactions for summary
  bool _isLoading = true;
  String? _errorMessage;
  String? _investorName; // To prefill WhatsApp message

  final TextEditingController _investmentAmountController = TextEditingController();
  final TextEditingController _appointmentDetailsController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _fetchUmkmDetails();
    _loadInvestorName();
  }

  Future<void> _loadInvestorName() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      final data = jsonDecode(userDataString);
      if (mounted) {
        setState(() {
          _investorName = data['name'];
        });
      }
    }
  }


  Future<void> _fetchUmkmDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Authentication required.";
      });
      // Potentially navigate to login
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/investor/umkms/${widget.umkmId}'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          setState(() {
            _umkmDetail = UmkmDetail.fromJson(data['umkm'] as Map<String, dynamic>);
            _financialSummary = FinancialSummary.fromJson(data['financial_summary'] as Map<String, dynamic>);
            final List<dynamic> transactionsData = data['transactions'] as List<dynamic>? ?? [];
            _transactions = transactionsData.map((t) => Transaction.fromJson(t as Map<String, dynamic>)).toList();
            _isLoading = false;
          });
        } else {
          final errorData = jsonDecode(response.body);
          setState(() {
            _isLoading = false;
            _errorMessage = errorData['message'] ?? "Failed to load UMKM details. Status: ${response.statusCode}";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error fetching UMKM details: ${e.toString()}";
        });
      }
    }
  }

  void _showInvestmentDialog() {
    _investmentAmountController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Invest in ${_umkmDetail?.umkmName ?? widget.umkmName}'),
          content: TextField(
            controller: _investmentAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Investment Amount (\$)',
              prefixText: '\$ ',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Submit Investment'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog first
                _submitInvestment();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitInvestment() async {
    final amountString = _investmentAmountController.text;
    if (amountString.isEmpty) {
      _showSnackbar('Investment amount cannot be empty.', isError: true);
      return;
    }
    final amount = double.tryParse(amountString);
    if (amount == null || amount <= 0) {
      _showSnackbar('Invalid investment amount.', isError: true);
      return;
    }

    setState(() => _isLoading = true); // Show loading indicator on screen potentially
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/investor/investments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'umkm_id': widget.umkmId,
          'amount': amount,
        }),
      );

      setState(() => _isLoading = false);
      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        _showSnackbar('Investment of \$${amount.toStringAsFixed(2)} initiated successfully!', isError: false);
        // Optionally, refresh data or update UI based on responseData['investment']
        _fetchUmkmDetails(); // Refresh to see if summary changes (though investment is 'pending')
      } else {
        final errorData = jsonDecode(response.body);
        _showSnackbar(errorData['message'] ?? 'Investment failed. Status: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('Error submitting investment: ${e.toString()}', isError: true);
    }
  }

  void _showAppointmentDialog() {
    _appointmentDetailsController.text = "Halo ${_umkmDetail?.ownerName ?? _umkmDetail?.umkmName ?? 'UMKM'}, saya ${_investorName ?? 'seorang investor'} tertarik untuk membahas lebih lanjut mengenai UMKM Anda.";
    if (_investmentAmountController.text.isNotEmpty) {
         _appointmentDetailsController.text += " Saya baru saja mengajukan investasi sebesar \$${_investmentAmountController.text}.";
    }


    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Request Appointment with ${_umkmDetail?.umkmName ?? widget.umkmName}'),
          content: SingleChildScrollView( // In case content is long
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 Text("A WhatsApp message will be prepared for you to send to ${_umkmDetail?.umkmContact ?? 'the UMKM'}. You can edit the message below before proceeding."),
                 const SizedBox(height: 16),
                 TextField(
                  controller: _appointmentDetailsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message for UMKM (via WhatsApp)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            )
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Prepare WhatsApp Message'),
              onPressed: () {
                Navigator.of(context).pop();
                _submitAppointmentRequestAndLaunchWhatsApp();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitAppointmentRequestAndLaunchWhatsApp() async {
    if (_umkmDetail == null || _umkmDetail!.umkmContact.isEmpty) {
      _showSnackbar('UMKM contact information is not available.', isError: true);
      return;
    }
    if (_appointmentDetailsController.text.isEmpty) {
      _showSnackbar('Appointment message cannot be empty.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final investmentAmount = _investmentAmountController.text.isNotEmpty
        ? double.tryParse(_investmentAmountController.text)
        : null;

    // Find the latest pending/active investment for this UMKM by this investor, if any
    // This is a simplified approach. A more robust way would be to pass the specific investment ID
    // if the appointment is directly related to a very recent investment.
    // For now, we'll assume the appointment is general or related to the amount in the text field.

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/investor/appointments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'umkm_id': widget.umkmId,
          // 'investment_id': null, // Link to a specific investment if applicable
          'appointment_details': "Investor: ${_investorName ?? 'N/A'}. UMKM: ${_umkmDetail?.umkmName}. Message: ${_appointmentDetailsController.text}",
          'contact_method': 'whatsapp',
          'contact_payload': _appointmentDetailsController.text, // This is the message for WhatsApp
        }),
      );
      setState(() => _isLoading = false);

      if (response.statusCode == 201) {
        _showSnackbar('Appointment request logged. Opening WhatsApp...', isError: false);
        // Launch WhatsApp
        // Sanitize phone number: remove non-digits, ensure country code if needed
        String umkmPhone = _umkmDetail!.umkmContact.replaceAll(RegExp(r'[^0-9+]'), '');
        if (umkmPhone.startsWith('0')) {
            umkmPhone = '62${umkmPhone.substring(1)}'; // Assuming Indonesian numbers, replace 0 with +62
        } else if (!umkmPhone.startsWith('+') && !umkmPhone.startsWith('62')) {
            umkmPhone = '62$umkmPhone'; // Add default country code if missing
        }


        await launchWhatsApp(
          phone: umkmPhone,
          message: _appointmentDetailsController.text,
        );
      } else {
        final errorData = jsonDecode(response.body);
        _showSnackbar(errorData['message'] ?? 'Failed to log appointment. Status: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('Error requesting appointment: ${e.toString()}', isError: true);
    }
  }


  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_umkmDetail?.umkmName ?? widget.umkmName),
      ),
      body: _buildBody(theme),
      bottomNavigationBar: _umkmDetail != null && !_isLoading ? _buildActionButtons(theme) : null,
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading && _umkmDetail == null) { // Initial loading
      return Center(child: CircularProgressIndicator(color: theme.colorScheme.secondary));
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.redAccent)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Retry"),
                onPressed: _fetchUmkmDetails,
                style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary, foregroundColor: Colors.white),
              )
            ],
          ),
        ),
      );
    }
    if (_umkmDetail == null) {
      return const Center(child: Text("UMKM data not available."));
    }

    return RefreshIndicator(
      onRefresh: _fetchUmkmDetails,
      color: theme.colorScheme.secondary,
      child: ListView( // Changed to ListView for simplicity, can be CustomScrollView if complex layouts needed
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildUmkmInfoCard(theme),
          const SizedBox(height: 20),
          _buildFinancialSummaryCard(theme),
          const SizedBox(height: 20),
          _buildTransactionsSection(theme),
          if (_isLoading) // Loading indicator for subsequent actions like invest/appoint
             Padding(
               padding: const EdgeInsets.symmetric(vertical: 20.0),
               child: Center(child: CircularProgressIndicator(color: theme.colorScheme.secondary)),
             ),
        ],
      ),
    );
  }

  Widget _buildUmkmInfoCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_umkmDetail!.umkmName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
            const SizedBox(height: 8),
            _buildDetailItem(icon: Icons.person_outline, label: "Owner", value: _umkmDetail!.ownerName, theme: theme),
            _buildDetailItem(icon: Icons.email_outlined, label: "Email", value: _umkmDetail!.email, theme: theme),
            _buildDetailItem(icon: Icons.phone_outlined, label: "Contact", value: _umkmDetail!.umkmContact, theme: theme, isContact: true),
          ],
        ),
      ),
    );
  }

   Widget _buildDetailItem({required IconData icon, required String label, required String value, required ThemeData theme, bool isContact = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.secondary.withOpacity(0.8)),
          const SizedBox(width: 12),
          Text("$label: ", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
          Expanded(child: Text(value, style: TextStyle(color: isContact ? theme.primaryColor : Colors.grey[800]), textAlign: TextAlign.end,)),
        ],
      ),
    );
  }


  Widget _buildFinancialSummaryCard(ThemeData theme) {
    if (_financialSummary == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Financial Summary (Completed Transactions)", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryFigure("Income", _financialSummary!.totalIncome, Colors.green.shade700, theme),
                _buildSummaryFigure("Expense", _financialSummary!.totalExpense, Colors.red.shade700, theme),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal:12, vertical: 10),
              decoration: BoxDecoration(
                color: _financialSummary!.netProfit >= 0
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    'Net Profit:',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\$${_financialSummary!.netProfit.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _financialSummary!.netProfit >= 0
                          ? Colors.green[800]
                          : Colors.red[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryFigure(String label, double value, Color color, ThemeData theme) {
    return Column(
      children: [
        Text(label, style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700])),
        const SizedBox(height: 4),
        Text(
          "\$${value.toStringAsFixed(2)}",
          style: theme.textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTransactionsSection(ThemeData theme) {
    if (_transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: Text("No 'Done' transactions to display for this UMKM.", style: TextStyle(color: Colors.grey[600]))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
          child: Text("Recent Completed Transactions", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // ListView inside another scroll view
          itemCount: _transactions.length > 5 ? 5 : _transactions.length, // Show max 5 or less
          itemBuilder: (context, index) {
            final transaction = _transactions[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                 leading: CircleAvatar(
                    backgroundColor: transaction.isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    child: Icon(transaction.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: transaction.isIncome ? Colors.green.shade600 : Colors.red.shade600, size: 20),
                  ),
                title: Text(
                  'ID: ${transaction.id.length > 15 ? '${transaction.id.substring(0,8)}...' : transaction.id}', // Display part of UUID
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey),
                ),
                subtitle: Text(DateFormat('dd MMM, yyyy').format(transaction.date)),
                trailing: Text(
                  '${transaction.isIncome ? '+' : '-'}\$${transaction.amount.abs().toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: transaction.isIncome ? Colors.green.shade700 : Colors.red.shade700, fontSize: 15),
                ),
              ),
            );
          },
        ),
         if (_transactions.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton(
              onPressed: () {
                // TODO: Navigate to a screen showing all transactions for this UMKM
                 _showSnackbar("Full transaction list view not yet implemented.", isError: true);
              },
              child: Text("View All ${_transactions.length} Transactions...", style: TextStyle(color: theme.colorScheme.secondary)),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 0, blurRadius: 5)
        ]
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.monetization_on_outlined),
              label: const Text("Invest"),
              onPressed: _isLoading ? null : _showInvestmentDialog,
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              label: const Text("Appointment"),
              onPressed: _isLoading ? null : _showAppointmentDialog,
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import 'api.dart';
import 'auth.dart';
import 'investor_dashboard_screen.dart';
import 'app_state.dart';

import 'add_transaction_screen.dart';
import 'delete_transaction_screen.dart';
import 'update_transaction_screen.dart';
import 'analysis_screen.dart';
import 'profile_screen.dart';

enum SortCriteria {
  dateAscending,
  dateDescending,
  amountAscending,
  amountDescending,
  status,
  sequenceIdAscending,
  sequenceIdDescending,
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState().loadUserSession();
  runApp(FinanceDashboardApp());
}

class FinanceDashboardApp extends StatelessWidget {
  final AppState appState = AppState();

  FinanceDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UMKM Finance & Investor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        primarySwatch: Colors.indigo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: Colors.indigo,
          secondary: Colors.teal,
          surface: const Color(0xFFF8FAFC),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey[800],
          elevation: 0.5,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
          iconTheme: IconThemeData(color: Colors.grey[700]),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Colors.indigo,
          unselectedItemColor: Colors.grey[500],
          backgroundColor: Colors.white,
          elevation: 1.0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.indigo.shade300, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          hintStyle: TextStyle(color: Colors.grey[500]),
          labelStyle: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
          prefixIconColor: Colors.grey[600],
        ),
        cardTheme: CardTheme(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        ),
      ),
      home: _getInitialScreen(),
    );
  }

  Widget _getInitialScreen() {
    if (appState.isLoggedIn) {
      if (appState.userType == 'umkm') {
        return const DashboardScreen();
      } else if (appState.userType == 'investor') {
        return const InvestorDashboardScreen();
      }
    }
    return const AuthWrapper();
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  List<Transaction> _allTransactions = [];
  bool _isLoading = true;
  String _userName = "UMKM User";
  String _userEmail = "";
  String _umkmName = "";
  String _umkmContact = "";
  bool _isUmkmInvestable = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadUserData();
    await _fetchTransactions();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      final data = jsonDecode(userDataString);
      if (mounted) {
        setState(() {
          _userName = data['name'] ?? 'UMKM User';
          _userEmail = data['email'] ?? '';
          _umkmName = data['umkm_name'] ?? '';
          _umkmContact = data['contact'] ?? '';
          _isUmkmInvestable = data['is_investable'] as bool? ?? false;
        });
      }
    } else {
      await _fetchCurrentUser();
    }
  }

  Future<void> _fetchCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      _showAuthError();
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/user'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (mounted) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          await prefs.setString('user_data', jsonEncode(data));
          setState(() {
            _userName = data['name'] ?? _userName;
            _userEmail = data['email'] ?? _userEmail;
            _umkmName = data['umkm_name'] ?? _umkmName;
            _umkmContact = data['contact'] ?? _umkmContact;
            _isUmkmInvestable = data['is_investable'] as bool? ?? false;
          });
        } else {
          _showAuthError();
        }
      }
    } catch (e) {
      if (mounted) _showError('Failed to fetch user details: ${e.toString()}');
    }
  }

  Future<void> _fetchTransactions() async {
    if (mounted) setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (mounted) _showAuthError();
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/transactions'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 20));

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          setState(() {
            _allTransactions = data.map((t) => Transaction.fromJson(t)).toList();
            _isLoading = false;
          });
        } else {
          _showError('Failed to load transactions: ${response.statusCode}\n${response.body}');
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) _showError('An unexpected error occurred: ${e.toString()}');
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 3)),
    );
  }

  void _showAuthError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Authentication error. Please log in again.')),
    );
    AppState().clearUserSession().then((_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (Route<dynamic> route) => false,
      );
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      try {
        await http.post(
          Uri.parse('$apiBaseUrl/logout'),
          headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
        );
      } catch (e) {
        // Error during API logout
      }
    }
    await AppState().clearUserSession();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // CORRECTED SIGNATURE AND IMPLEMENTATION for _onUmkmProfileUpdated
  void _onUmkmProfileUpdated(String newUmkmName, String newContact, String newOwnerName, bool newIsInvestable) async {
    setState(() {
      _umkmName = newUmkmName;
      _umkmContact = newContact;
      _userName = newOwnerName;
      _isUmkmInvestable = newIsInvestable; // Update the state
    });
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      Map<String, dynamic> userData = jsonDecode(userDataString);
      userData['name'] = newOwnerName;
      userData['umkm_name'] = newUmkmName;
      userData['contact'] = newContact;
      userData['is_investable'] = newIsInvestable; // Save the updated value
      await prefs.setString('user_data', jsonEncode(userData));
    }
    // Optionally, call _fetchCurrentUser() or _loadUserData() if you want to re-verify with backend,
    // but for now, just updating local state and SharedPreferences.
    // await _loadUserData(); // This would re-fetch and re-set state including isInvestable
  }

  Widget _buildBody() {
    final List<Widget> screens = [
      HomeScreen(
        key: ValueKey('home_${_allTransactions.length}_$_isLoading'),
        username: _userName,
        transactions: _allTransactions,
        onRefresh: _fetchTransactions,
        isLoading: _isLoading,
      ),
      AnalysisScreen(
        key: ValueKey('analysis_${_allTransactions.length}'),
        allTransactions: _allTransactions,
        onRefresh: _fetchTransactions,
      ),
      ProfileScreen(
        key: ValueKey('profile_$_umkmName$_umkmContact$_userName$_isUmkmInvestable'),
        username: _userName,
        email: _userEmail,
        umkmName: _umkmName,
        umkmContact: _umkmContact,
        isInvestable: _isUmkmInvestable, // Pass the correct state variable
        onLogout: _handleLogout,
        onProfileUpdated: _onUmkmProfileUpdated,
        onRefresh: _loadUserData,
      ),
    ];
    if (_isLoading && _selectedIndex == 0 && _allTransactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return IndexedStack(index: _selectedIndex, children: screens);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: 'Analysis'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class Transaction {
  final String id;
  final int? userSequenceId;
  final double amount;
  final String status;
  final DateTime date;
  final String type;
  final bool isIncome;

  Transaction({
    required this.id,
    this.userSequenceId,
    required this.amount,
    required this.status,
    required this.date,
    required this.type,
    required this.isIncome,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      if (json['date'] != null && json['date'].toString().contains(' ')) {
        parsedDate = DateFormat('dd MMM yy', 'en_US').parseStrict(json['date']);
      } else {
        parsedDate = DateTime.parse(json['date']);
      }
    } catch (e) {
      parsedDate = DateTime.now();
    }
    return Transaction(
      id: json['id']?.toString() ?? '',
      userSequenceId: json['user_sequence_id'] as int?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Unknown',
      date: parsedDate,
      type: json['type']?.toString() ?? 'Unknown',
      isIncome: ((json['amount'] as num?)?.toDouble() ?? 0.0) > 0,
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String username;
  final List<Transaction> transactions;
  final Future<void> Function() onRefresh;
  final bool isLoading;

  const HomeScreen({
    super.key,
    required this.username,
    required this.transactions,
    required this.onRefresh,
    required this.isLoading,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showIncome = true;
  String _selectedGlobalId = '';
  String _selectedDisplayId = '';
  String _selectedAmount = '';
  String _selectedStatus = '';
  String _selectedDate = '';
  SortCriteria _sortCriteria = SortCriteria.sequenceIdDescending;

  List<Transaction> get _filteredAndSortedTransactions {
    List<Transaction> filtered = widget.transactions
        .where((t) => _showIncome ? t.isIncome : !t.isIncome)
        .toList();

    switch (_sortCriteria) {
      case SortCriteria.dateAscending:
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case SortCriteria.dateDescending:
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortCriteria.amountAscending:
        filtered.sort((a, b) => a.amount.abs().compareTo(b.amount.abs()));
        break;
      case SortCriteria.amountDescending:
        filtered.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
        break;
      case SortCriteria.status:
        filtered.sort((a, b) => a.status.compareTo(b.status));
        break;
      case SortCriteria.sequenceIdAscending:
        filtered.sort((a,b) => (a.userSequenceId ?? 0).compareTo(b.userSequenceId ?? 0));
        break;
      case SortCriteria.sequenceIdDescending:
      default:
         filtered.sort((a,b) => (b.userSequenceId ?? 0).compareTo(a.userSequenceId ?? 0));
        break;
    }
    return filtered;
  }

  double get _totalIncome => widget.transactions
      .where((t) => t.isIncome && (t.status == 'Done'))
      .fold(0.0, (sum, t) => sum + t.amount.abs());

  double get _totalExpense => widget.transactions
      .where((t) => !t.isIncome && (t.status == 'Done'))
      .fold(0.0, (sum, t) => sum + t.amount.abs());

  void _updateSelectedTransaction(Transaction transaction) {
    setState(() {
      _selectedGlobalId = transaction.id;
      _selectedDisplayId = transaction.userSequenceId?.toString() ?? 'N/A';
      _selectedAmount =
          '${transaction.amount > 0 ? '+' : '-'} \$${transaction.amount.abs().toStringAsFixed(2)}';
      _selectedStatus = transaction.status;
      _selectedDate = DateFormat('dd MMM yy').format(transaction.date);
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return const Color(0xFFFFFBEB);
      case 'Done': return const Color(0xFFF0FDF4);
      case 'Cancelled': return const Color(0xFFFEF2F2);
      default: return Colors.grey.shade100;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Pending': return const Color(0xFFB45309);
      case 'Done': return const Color(0xFF15803D);
      case 'Cancelled': return const Color(0xFFB91C1C);
      default: return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selamat Datang,', style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey[600])),
            Text(widget.username, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          _ActionButton(
            icon: Icons.add_circle_outline,
            tooltip: 'Add Transaction',
            color: theme.colorScheme.primary,
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTransactionScreen(isIncome: _showIncome),
                ),
              );
              if (result == true) widget.onRefresh();
            },
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.delete_sweep_outlined,
            tooltip: 'Delete Transaction',
            color: theme.colorScheme.error,
            onPressed: () async {
              if (widget.transactions.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No transactions to delete.')),
                );
                return;
              }
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeleteTransactionScreen(transactions: widget.transactions),
                ),
              );
              if (result == true) widget.onRefresh();
            },
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.playlist_add_check_circle_outlined,
            tooltip: 'Verify Transactions',
            color: Colors.green.shade600,
            onPressed: () async {
              final pending = widget.transactions.where((t) => t.status == 'Pending').toList();
              if (pending.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No pending transactions to verify.')),
                );
                return;
              }
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UpdateTransactionScreen(pendingTransactions: pending),
                ),
              );
              if (result != null && result is Map && result['success'] == true) {
                widget.onRefresh();
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: theme.colorScheme.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Card(
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _showIncome = true),
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: _showIncome ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                                ),
                                child: Column(children: [
                                  Text('Income', style: TextStyle(fontWeight: FontWeight.w500, color: _showIncome ? theme.colorScheme.primary : Colors.grey[700])),
                                  const SizedBox(height: 4),
                                  Text('\$${_totalIncome.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _showIncome ? theme.colorScheme.primary : Colors.green[700])),
                                ]),
                              ),
                            ),
                          ),
                          Container(width: 1, height: 60, color: Colors.grey.shade300),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _showIncome = false),
                              borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: !_showIncome ? theme.colorScheme.error.withOpacity(0.1) : Colors.transparent,
                                  borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                                ),
                                child: Column(children: [
                                  Text('Expense', style: TextStyle(fontWeight: FontWeight.w500, color: !_showIncome ? theme.colorScheme.error : Colors.grey[700])),
                                  const SizedBox(height: 4),
                                  Text('\$${_totalExpense.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: !_showIncome ? theme.colorScheme.error : Colors.red[700])),
                                ]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_selectedGlobalId.isNotEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Transaction Detail', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _selectedGlobalId = ''), visualDensity: VisualDensity.compact)
                                ],
                              ),
                              const Divider(height: 20),
                              _DetailRow(label: 'ID:', value: _selectedDisplayId),
                              _DetailRow(label: 'Amount:', value: _selectedAmount, valueStyle: TextStyle(fontWeight: FontWeight.w600, color: _selectedAmount.startsWith('+') ? Colors.green[700] : Colors.red[700])),
                              _DetailRow(label: 'Date:', value: _selectedDate),
                              _DetailRow(
                                label: 'Status:',
                                valueWidget: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: _getStatusColor(_selectedStatus), borderRadius: BorderRadius.circular(20)),
                                  child: Text(_selectedStatus, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _getStatusTextColor(_selectedStatus))),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_selectedGlobalId.isNotEmpty) const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent Transactions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                        PopupMenuButton<SortCriteria>(
                          onSelected: (SortCriteria criteria) => setState(() => _sortCriteria = criteria),
                          icon: Icon(Icons.sort_rounded, color: Colors.grey[700]),
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<SortCriteria>>[
                            const PopupMenuItem<SortCriteria>(value: SortCriteria.sequenceIdDescending, child: Text('Sort by ID (Newest)')),
                            const PopupMenuItem<SortCriteria>(value: SortCriteria.sequenceIdAscending, child: Text('Sort by ID (Oldest)')),
                            const PopupMenuItem<SortCriteria>(value: SortCriteria.dateDescending, child: Text('Sort by Date (Newest)')),
                            const PopupMenuItem<SortCriteria>(value: SortCriteria.dateAscending, child: Text('Sort by Date (Oldest)')),
                            const PopupMenuItem<SortCriteria>(value: SortCriteria.amountDescending, child: Text('Sort by Amount (High-Low)')),
                            const PopupMenuItem<SortCriteria>(value: SortCriteria.amountAscending, child: Text('Sort by Amount (Low-High)')),
                            const PopupMenuItem<SortCriteria>(value: SortCriteria.status, child: Text('Sort by Status')),
                          ],
                          tooltip: "Sort Transactions",
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            widget.isLoading && widget.transactions.isEmpty
                ? SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)))
                : _filteredAndSortedTransactions.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text('No transactions found.', style: TextStyle(fontSize: 17, color: Colors.grey[600])),
                                Text(_showIncome ? 'Try adding an income transaction.' : 'Try adding an expense transaction.', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final transaction = _filteredAndSortedTransactions[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              child: Card(
                                child: InkWell(
                                  onTap: () => _updateSelectedTransaction(transaction),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: transaction.isIncome ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                          child: Icon(transaction.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: transaction.isIncome ? Colors.green.shade700 : Colors.red.shade700, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'ID: ${transaction.userSequenceId ?? 'N/A'}',
                                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(DateFormat('dd MMM yy, hh:mm a').format(transaction.date), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${transaction.isIncome ? '+' : '-'} \$${transaction.amount.abs().toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: transaction.isIncome ? Colors.green.shade700 : Colors.red.shade700),
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(color: _getStatusColor(transaction.status), borderRadius: BorderRadius.circular(15)),
                                              child: Text(transaction.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _getStatusTextColor(transaction.status))),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: _filteredAndSortedTransactions.length,
                        ),
                      ),
            SliverToBoxAdapter(child: const SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Center(child: Icon(icon, size: 22, color: Colors.white)),
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
  final bool isMonospace;

  const _DetailRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.valueStyle,
    this.isMonospace = false,
    super.key,
  }) : assert(value != null || valueWidget != null);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: value != null
                  ? Text(value!, textAlign: TextAlign.end, style: valueStyle ?? TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: isMonospace ? 'monospace' : null))
                  : valueWidget!,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> launchWhatsApp({required String phone, required String message}) async {
  String url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } else {
    throw 'Could not launch $url';
  }
}

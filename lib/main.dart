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
import 'add_debt_screen.dart';


enum SortCriteria {
  dateAscending,
  dateDescending,
  amountAscending,
  amountDescending,
  status,
  sequenceIdAscending,
  sequenceIdDescending,
}

enum DebtSortCriteria {
  deadlineAscending,
  deadlineDescending,
  amountAscending,
  amountDescending,
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
          secondary: const Color.fromARGB(255, 62, 13, 139),
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
  List<DebtModel> _allDebts = [];
  bool _isLoadingTransactions = true;
  bool _isLoadingDebts = true;

  String _userName = "UMKM User";
  String _userEmail = "";
  String _umkmName = "";
  String _umkmContact = "";
  bool _isUmkmInvestable = false;
  String? _umkmDescription;
  String? _umkmProfileImageUrl;


  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadUserData();
    await Future.wait([
      _fetchTransactions(),
      _fetchDebts(),
    ]);
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      final data = jsonDecode(userDataString);
      if (mounted) {
        _updateStateWithUserData(data);
      }
    } else {
      await _fetchCurrentUser();
    }
  }
  
  void _updateStateWithUserData(Map<String, dynamic> data) {
     setState(() {
        _userName = data['name'] ?? 'UMKM User';
        _userEmail = data['email'] ?? '';
        _umkmName = data['umkm_name'] ?? '';
        _umkmContact = data['contact'] ?? '';
        _isUmkmInvestable = data['is_investable'] as bool? ?? false;
        _umkmDescription = data['umkm_description'];
        _umkmProfileImageUrl = data['umkm_profile_image_url'];
      });
  }


  Future<void> _fetchCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if(mounted) {
        _showAuthError();
      }
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
          _updateStateWithUserData(data);
        } else {
          _showAuthError();
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to fetch user details: ${e.toString()}');
      }
    }
  }

  Future<void> _fetchTransactions() async {
    if (mounted) {
      setState(() => _isLoadingTransactions = true);
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (mounted) {
        _showAuthError();
      }
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
          });
        } else {
          _showError('Failed to load transactions: ${response.statusCode}\n${response.body}');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('An unexpected error occurred while fetching transactions: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingTransactions = false);
      }
    }
  }

  Future<void> _fetchDebts() async {
    if (mounted) {
      setState(() => _isLoadingDebts = true);
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (mounted) {
        _showAuthError();
      }
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/debts'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 20));

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          setState(() {
            _allDebts = data.map((d) => DebtModel.fromJson(d)).toList();
          });
        } else {
          _showError('Failed to load debts: ${response.statusCode}\n${response.body}');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('An unexpected error occurred while fetching debts: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDebts = false);
      }
    }
  }


  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 3)),
    );
  }

  void _showAuthError() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Authentication error. Please log in again.')),
    );
    await AppState().clearUserSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
      (Route<dynamic> route) => false,
    );
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

  void _onUmkmProfileUpdated(String newUmkmName, String newUmkmContact, String newOwnerName, bool newIsInvestable, String? newDescription, String? newImageUrl) async {
    setState(() {
      _umkmName = newUmkmName;
      _umkmContact = newUmkmContact;
      _userName = newOwnerName;
      _isUmkmInvestable = newIsInvestable;
      _umkmDescription = newDescription;
      _umkmProfileImageUrl = newImageUrl;
    });
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      Map<String, dynamic> userData = jsonDecode(userDataString);
      userData['name'] = newOwnerName;
      userData['umkm_name'] = newUmkmName;
      userData['contact'] = newUmkmContact;
      userData['is_investable'] = newIsInvestable;
      userData['umkm_description'] = newDescription;
      userData['umkm_profile_image_url'] = newImageUrl;
      await prefs.setString('user_data', jsonEncode(userData));
      AppState().setUserData(userData);
    }
  }

  Widget _buildBody() {
    final bool isLoading = _isLoadingTransactions || _isLoadingDebts;
    final List<Widget> screens = [
      HomeScreen(
        key: ValueKey('home_${_allTransactions.length}_${_allDebts.length}_$isLoading'),
        username: _userName,
        transactions: _allTransactions,
        debts: _allDebts,
        onRefreshAll: _loadInitialData,
        isLoading: isLoading,
      ),
      AnalysisScreen(
        key: ValueKey('analysis_${_allTransactions.length}_${_allDebts.length}'),
        allTransactions: _allTransactions,
        allDebts: _allDebts,
        onRefresh: _loadInitialData,
      ),
      ProfileScreen(
        key: ValueKey('profile_$_umkmName$_umkmContact$_userName$_isUmkmInvestable$_umkmDescription$_umkmProfileImageUrl'),
        username: _userName,
        email: _userEmail,
        umkmName: _umkmName,
        umkmContact: _umkmContact,
        isInvestable: _isUmkmInvestable,
        umkmDescription: _umkmDescription,
        umkmProfileImageUrl: _umkmProfileImageUrl,
        onLogout: _handleLogout,
        onProfileUpdated: _onUmkmProfileUpdated,
        onRefresh: _loadUserData,
      ),
    ];
    if (isLoading && _selectedIndex == 0 && _allTransactions.isEmpty && _allDebts.isEmpty) {
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
class DebtModel {
  final int id;
  final double amount;
  final DateTime date;
  final DateTime deadline;
  final String status;
  final String? notes;
  final int? relatedTransactionId;

  DebtModel({
    required this.id,
    required this.amount,
    required this.date,
    required this.deadline,
    required this.status,
    this.notes,
    this.relatedTransactionId,
  });

  factory DebtModel.fromJson(Map<String, dynamic> json) {
    return DebtModel(
      id: json['id'] as int,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      deadline: DateTime.parse(json['deadline']),
      status: json['status'] as String,
      notes: json['notes'] as String?,
      relatedTransactionId: json['related_transaction_id'] as int?,
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
  final String? paymentMethod; // Added paymentMethod
  final String? notes;
  final bool isIncome;

  Transaction({
    required this.id,
    this.userSequenceId,
    required this.amount,
    required this.status,
    required this.date,
    required this.type,
    this.paymentMethod, // Added paymentMethod
    this.notes,
    required this.isIncome,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['date']);
    } catch (e) {
      try {
         parsedDate = DateFormat('dd MMM yy', 'en_US').parseStrict(json['date']);
      } catch (e2) {
        parsedDate = DateTime.now();
      }
    }
    return Transaction(
      id: json['id']?.toString() ?? '',
      userSequenceId: json['user_sequence_id'] as int?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Unknown',
      date: parsedDate,
      type: json['type']?.toString() ?? 'Unknown',
      paymentMethod: json['payment_method'] as String?, // Added paymentMethod
      notes: json['notes'] as String?,
      isIncome: ((json['amount'] as num?)?.toDouble() ?? 0.0) > 0 && (json['type']?.toString().toLowerCase() != 'expense'),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String username;
  final List<Transaction> transactions;
  final List<DebtModel> debts;
  final Future<void> Function() onRefreshAll;
  final bool isLoading;

  const HomeScreen({
    super.key,
    required this.username,
    required this.transactions,
    required this.debts,
    required this.onRefreshAll,
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
  String _selectedNotes = '';
  String _selectedPaymentMethod = ''; // Added for detail view

  SortCriteria _sortCriteria = SortCriteria.sequenceIdDescending;
  DebtSortCriteria _debtSortCriteria = DebtSortCriteria.deadlineAscending;


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
         filtered.sort((a,b) => (b.userSequenceId ?? 0).compareTo(a.userSequenceId ?? 0));
        break;
      
    }
    return filtered;
  }
  
  List<DebtModel> get _sortedDebts {
    List<DebtModel> pendingDebts = widget.debts.where((d) => d.status == 'pending_verification').toList();
    switch(_debtSortCriteria) {
      case DebtSortCriteria.deadlineDescending:
        pendingDebts.sort((a,b) => b.deadline.compareTo(a.deadline));
        break;
      case DebtSortCriteria.amountAscending:
        pendingDebts.sort((a,b) => a.amount.compareTo(b.amount));
        break;
      case DebtSortCriteria.amountDescending:
        pendingDebts.sort((a,b) => b.amount.compareTo(a.amount));
        break;
      case DebtSortCriteria.deadlineAscending:
        pendingDebts.sort((a,b) => a.deadline.compareTo(b.deadline));
        break;
      
    }
    return pendingDebts;
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
      _selectedNotes = transaction.notes ?? 'No notes';
      _selectedPaymentMethod = transaction.paymentMethod ?? 'N/A'; // Added
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
      case 'Pending': return const Color(0xFFB45309);
      case 'Done': return const Color(0xFF15803D);
      case 'Cancelled': return const Color(0xFFB91C1C);
      default: return Colors.grey.shade700;
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

  Future<void> _verifyDebt(int debtId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    http.Response? responseFromApi;
    String? caughtError;

    if (token == null) {
      caughtError = 'Authentication error.';
    } else {
      if(mounted){ 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verifying debt ID: $debtId...'), duration: const Duration(seconds: 2)),
        );
      }
      try {
        responseFromApi = await http.patch(
          Uri.parse('$apiBaseUrl/debts/$debtId/verify'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      } catch (e) {
        caughtError = 'Error verifying debt: $e';
      }
    }

    if (!mounted) return;

    if (caughtError != null) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(caughtError), backgroundColor: Colors.red),
      );
      return;
    }

    if (responseFromApi != null) {
      if (responseFromApi.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debt verified and income recorded!'), backgroundColor: Colors.green),
        );
        widget.onRefreshAll();
      } else {
        final errorData = jsonDecode(responseFromApi.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to verify debt: ${errorData['message'] ?? responseFromApi.statusCode}'), backgroundColor: Colors.red),
        );
      }
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
            Text('Welcome,', style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey[600])),
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
              if (result == true && mounted) widget.onRefreshAll();
            },
          ),
          const SizedBox(width: 8),
           _ActionButton(
            icon: Icons.post_add_outlined,
            tooltip: 'Add Debt (Receivable)',
            color: Colors.orange.shade700,
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddDebtScreen()),
              );
              if (result == true && mounted) widget.onRefreshAll();
            },
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.delete_sweep_outlined, 
            tooltip: 'Delete Transaction',
            color: theme.colorScheme.error,
            onPressed: () async {
              if (widget.transactions.isEmpty) {
                 if(mounted){
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No transactions to delete.')),
                    );
                 }
                return;
              }
              
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeleteTransactionScreen(transactions: _filteredAndSortedTransactions), 
                ),
              );
              if (result == true && mounted) widget.onRefreshAll();
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
                 if(mounted){
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No pending transactions to verify.')),
                    );
                 }
                return;
              }
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UpdateTransactionScreen(pendingTransactions: pending),
                ),
              );
              if (result != null && result is Map && result['success'] == true && mounted) {
                widget.onRefreshAll();
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefreshAll,
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
                                  color: _showIncome ? theme.colorScheme.primary.withAlpha(26) : Colors.transparent,
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
                                  color: !_showIncome ? theme.colorScheme.error.withAlpha(26) : Colors.transparent,
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
                              _DetailRow(label: 'Payment Method:', value: _selectedPaymentMethod), // Added
                               _DetailRow(label: 'Notes:', value: _selectedNotes),
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
            widget.isLoading && widget.transactions.isEmpty && widget.debts.isEmpty
                ? SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)))
                : _filteredAndSortedTransactions.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0).copyWith(top:0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text('No transactions found for this category.', style: TextStyle(fontSize: 17, color: Colors.grey[600])),
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
                                          backgroundColor: transaction.isIncome ? Colors.green.withAlpha(38) : Colors.red.withAlpha(38),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                 child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Pending Debts (Receivables)', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                        PopupMenuButton<DebtSortCriteria>(
                          onSelected: (DebtSortCriteria criteria) => setState(() => _debtSortCriteria = criteria),
                          icon: Icon(Icons.sort_rounded, color: Colors.grey[700]),
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<DebtSortCriteria>>[
                            const PopupMenuItem<DebtSortCriteria>(value: DebtSortCriteria.deadlineAscending, child: Text('Sort by Deadline (Soonest)')),
                            const PopupMenuItem<DebtSortCriteria>(value: DebtSortCriteria.deadlineDescending, child: Text('Sort by Deadline (Latest)')),
                            const PopupMenuItem<DebtSortCriteria>(value: DebtSortCriteria.amountDescending, child: Text('Sort by Amount (High-Low)')),
                            const PopupMenuItem<DebtSortCriteria>(value: DebtSortCriteria.amountAscending, child: Text('Sort by Amount (Low-High)')),
                          ],
                          tooltip: "Sort Debts",
                        ),
                      ],
                    ),
              )
            ),
             widget.isLoading && widget.debts.isEmpty
                ? SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: CircularProgressIndicator(color: theme.colorScheme.primary))))
                : _sortedDebts.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.money_off_csred_outlined, size: 60, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text('No pending debts to display.', style: TextStyle(fontSize: 17, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final debt = _sortedDebts[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.orange.withAlpha(38),
                                        child: Icon(Icons.receipt_long, color: Colors.orange.shade700, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Debt ID: ${debt.id}',
                                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                            ),
                                            const SizedBox(height: 2),
                                            Text('Deadline: ${DateFormat('dd MMM yy').format(debt.deadline)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                             if (debt.notes != null && debt.notes!.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text('Notes: ${debt.notes}', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),  maxLines: 1, overflow: TextOverflow.ellipsis,),
                                            ]
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '\$${debt.amount.toStringAsFixed(2)}',
                                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.orange.shade800),
                                          ),
                                          const SizedBox(height: 2),
                                           Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(color: _getDebtStatusColor(debt.status), borderRadius: BorderRadius.circular(15)),
                                              child: Text(debt.status.replaceAll('_', ' ').capitalizeFirstLetter(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _getDebtStatusTextColor(debt.status))),
                                            ),
                                        ],
                                      ),
                                      if (debt.status == 'pending_verification')
                                        IconButton(
                                          icon: Icon(Icons.check_circle_outline, color: Colors.green.shade600),
                                          tooltip: 'Verify & Record Income',
                                          onPressed: () => _verifyDebt(debt.id),
                                        )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: _sortedDebts.length,
                        ),
                      ),
            SliverToBoxAdapter(child: const SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}
extension StringExtension on String {
    String capitalizeFirstLetter() {
      if (isEmpty) {
        return this;
      }
      return "${this[0].toUpperCase()}${substring(1)}";
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

  const _DetailRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.valueStyle,
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
                  ? Text(value!, textAlign: TextAlign.end, style: valueStyle ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))
                  : valueWidget!,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> launchWhatsApp({required String phone, required String message}) async {
  String sanitizedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (sanitizedPhone.startsWith('0')) {
    sanitizedPhone = '62${sanitizedPhone.substring(1)}';
  } else if (!sanitizedPhone.startsWith('+') && !sanitizedPhone.startsWith('62')) {
    sanitizedPhone = '62$sanitizedPhone';
  }
  
  if (sanitizedPhone.startsWith('+') && sanitizedPhone.length > 1 && sanitizedPhone.substring(1).contains('+')) {
      sanitizedPhone = sanitizedPhone.substring(0,1) + sanitizedPhone.substring(1).replaceAll('+', '');
  } else if (!sanitizedPhone.startsWith('+')) {
      sanitizedPhone = sanitizedPhone.replaceAll('+', '');
  }


  final Uri whatsappUri = Uri(
    scheme: 'whatsapp',
    path: 'send',
    queryParameters: {
      'phone': sanitizedPhone,
      'text': message,
    },
  );

  final Uri httpsUri = Uri.parse("https://wa.me/$sanitizedPhone?text=${Uri.encodeComponent(message)}");


  try {
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri);
    } else if (await canLaunchUrl(httpsUri)) {
      await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $whatsappUri or $httpsUri';
    }
  } catch (e) {
    throw 'Could not launch WhatsApp: $e';
  }
}

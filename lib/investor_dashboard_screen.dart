import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api.dart';
import 'auth.dart'; 
import 'app_state.dart';
import 'umkm_list_screen.dart'; 
import 'investor_profile_screen.dart'; 

class InvestorDashboardScreen extends StatefulWidget {
  const InvestorDashboardScreen({super.key});

  @override
  State<InvestorDashboardScreen> createState() => _InvestorDashboardScreenState();
}

class _InvestorDashboardScreenState extends State<InvestorDashboardScreen> {
  int _selectedIndex = 0;
  String _investorName = "Investor";
  String _investorEmail = "";

  @override
  void initState() {
    super.initState();
    _loadInvestorData();
  }

  Future<void> _loadInvestorData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    final token = prefs.getString('token');

    if (userDataString != null) {
      final data = jsonDecode(userDataString);
      if (mounted) {
        setState(() {
          _investorName = data['name'] ?? 'Investor';
          _investorEmail = data['email'] ?? '';
        });
      }
    } else if (token != null) { // Fallback to fetch if only token exists
        await _fetchCurrentInvestor(token);
    } else {
        _showAuthError(); // No session data
    }
  }

  Future<void> _fetchCurrentInvestor(String token) async {
     try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/investor/user'), // Investor user endpoint
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (mounted) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', jsonEncode(data));
          setState(() {
            _investorName = data['name'] ?? _investorName;
            _investorEmail = data['email'] ?? _investorEmail;
          });
        } else {
          _showAuthError(); // Token might be invalid
        }
      }
    } catch (e) {
      if (mounted) _showError('Failed to fetch investor details: ${e.toString()}');
    }
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
                Uri.parse('$apiBaseUrl/investor/logout'), // Investor logout endpoint
                headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
            );
        } catch (e) {
            // print("Error during API logout for investor: $e");
        }
    }
    await AppState().clearUserSession();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()), // Go to main auth selection
        (Route<dynamic> route) => false,
      );
    }
  }

   void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
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


  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      UmkmListScreen(), // Pass necessary data if needed, e.g. investor token for actions
      InvestorProfileScreen(
        investorName: _investorName,
        investorEmail: _investorEmail,
        onLogout: _handleLogout,
        onRefresh: _loadInvestorData,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt_rounded),
            label: 'UMKM List',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle_rounded),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.secondary, // Use investor theme color
        unselectedItemColor: Colors.grey[500],
      ),
    );
  }
}

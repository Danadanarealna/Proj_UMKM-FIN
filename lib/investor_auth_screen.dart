import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api.dart';
import 'investor_dashboard_screen.dart'; 
import 'app_state.dart'; 


class InvestorAuthScreen extends StatefulWidget {
  const InvestorAuthScreen({super.key});

  @override
  State<InvestorAuthScreen> createState() => _InvestorAuthScreenState();
}

class _InvestorAuthScreenState extends State<InvestorAuthScreen> {
  bool _showLogin = true;
  bool _isLoading = false;

  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupNameController = TextEditingController(); // Investor Name
  final TextEditingController _signupPasswordController = TextEditingController();
  final TextEditingController _signupConfirmPasswordController = TextEditingController();

  bool _obscureLoginPassword = true;
  bool _obscureSignupPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupNameController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleLoginSignup() {
    setState(() {
      _showLogin = !_showLogin;
    });
  }

   void _toggleLoginPasswordVisibility() {
    setState(() {
      _obscureLoginPassword = !_obscureLoginPassword;
    });
  }

  void _toggleSignupPasswordVisibility() {
    setState(() {
      _obscureSignupPassword = !_obscureSignupPassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }


  Future<void> _handleInvestorLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showAlert('Please enter both email and password for investor login.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/investor/login'), // Investor endpoint
        body: jsonEncode({'email': email, 'password': password}),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      );
      if (mounted) {
        setState(() => _isLoading = false);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['access_token']);
          await prefs.setString('user_type', 'investor'); // Store user type
          await prefs.setString('user_data', jsonEncode(data['user']));

          AppState().setUserType('investor');

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const InvestorDashboardScreen()),
            );
          }
        } else {
          final errorData = jsonDecode(response.body);
          _showAlert(errorData['message'] ?? 'Investor Login failed.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showAlert('Connection error during investor login: ${e.toString()}');
      }
    }
  }

  Future<void> _handleInvestorSignup() async {
    final email = _signupEmailController.text.trim();
    final name = _signupNameController.text.trim();
    final password = _signupPasswordController.text.trim();
    final confirmPassword = _signupConfirmPasswordController.text.trim();

    if (email.isEmpty || name.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showAlert('Please fill in all fields for investor registration.');
      return;
    }
    if (password != confirmPassword) {
      _showAlert('Passwords do not match.');
      return;
    }
     if (password.length < 8) {
      _showAlert('Password must be at least 8 characters.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/investor/register'), // Investor endpoint
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (response.statusCode == 201) {
          _showAlert('Investor account created successfully! Please login.');
          _toggleLoginSignup();
        } else {
          final errorData = jsonDecode(response.body);
          String errorMessage = 'Investor Registration failed.';
           if (errorData['errors'] != null && errorData['errors'] is Map) {
                Map<String, dynamic> errors = errorData['errors'];
                if (errors.isNotEmpty) {
                    errorMessage = errors.values.first[0];
                }
            } else if (errorData['message'] != null) {
                errorMessage = errorData['message'];
            }
          _showAlert(errorMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showAlert('Connection error during investor registration: ${e.toString()}');
      }
    }
  }

  void _showAlert(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notice'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showLogin ? 'Investor Login' : 'Investor Registration'),
        leading: IconButton( // Add a back button
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              // Fallback if it's the first screen (though unlikely here)
              // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AuthWrapper()));
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
             child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _showLogin ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                firstChild: _buildInvestorLoginPage(),
                secondChild: _buildInvestorSignupPage(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvestorLoginPage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLogo(),
        const SizedBox(height: 24),
         Text(
          'Welcome, Investor!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Find promising UMKMs to invest in.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        _buildInputField(
          label: 'Email',
          icon: Icons.email_outlined,
          controller: _loginEmailController,
          hintText: 'your.investor@email.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          label: 'Password',
          controller: _loginPasswordController,
          obscureText: _obscureLoginPassword,
          onToggleVisibility: _toggleLoginPasswordVisibility,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleInvestorLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary, // Different color for investor
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Text('Login as Investor'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _toggleLoginSignup,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Theme.of(context).colorScheme.secondary),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Create Investor Account', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
        ),
      ],
    );
  }

  Widget _buildInvestorSignupPage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row( // Title is in AppBar now
        //   children: [
        //     IconButton(
        //       icon: const Icon(Icons.arrow_back),
        //       onPressed: _toggleLoginSignup,
        //     ),
        //     const SizedBox(width: 8),
        //     Text('Create Investor Account', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        //   ],
        // ),
        // const SizedBox(height: 24),
        _buildInputField(
          label: 'Full Name',
          icon: Icons.person_outline,
          controller: _signupNameController,
          hintText: 'e.g., Investor Name',
        ),
        const SizedBox(height: 16),
        _buildInputField(
          label: 'Email',
          icon: Icons.email_outlined,
          controller: _signupEmailController,
          hintText: 'your.investor@email.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          label: 'Password',
          controller: _signupPasswordController,
          obscureText: _obscureSignupPassword,
          onToggleVisibility: _toggleSignupPasswordVisibility,
        ),
         Padding(
          padding: const EdgeInsets.only(left: 16, top: 4, bottom: 8),
          child: Text('At least 8 characters.', style: Theme.of(context).textTheme.bodySmall),
        ),
        _buildPasswordField(
          label: 'Confirm Password',
          controller: _signupConfirmPasswordController,
          obscureText: _obscureConfirmPassword,
          onToggleVisibility: _toggleConfirmPasswordVisibility,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleInvestorSignup,
           style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Text('Register Investor Account'),
        ),
        const SizedBox(height: 16),
        // TextButton( // Handled by AppBar back button
        //   onPressed: _toggleLoginSignup,
        //   child: const Text('Already have an Investor account? Login'),
        // ),
      ],
    );
  }

   Widget _buildLogo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.insights_outlined, // Icon for investors
            size: 48,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 12),
         Text(
          'Investor Portal',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        )
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
     return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
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
          borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '$label cannot be empty';
        }
         if (label.toLowerCase().contains('email') && !value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: '••••••••',
        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey[600],
          ),
          onPressed: onToggleVisibility,
        ),
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
          borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
       validator: (value) {
        if (value == null || value.isEmpty) {
          return '$label cannot be empty';
        }
        if (value.length < 8) {
          return '$label must be at least 8 characters';
        }
        return null;
      },
    );
  }
}

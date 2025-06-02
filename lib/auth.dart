import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api.dart';
import 'main.dart';
import 'investor_auth_screen.dart';
import 'app_state.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showLogin = true;
  bool _isLoading = false;

  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupUsernameController = TextEditingController();
  final TextEditingController _signupPasswordController = TextEditingController();
  final TextEditingController _signupConfirmPasswordController = TextEditingController();
  final TextEditingController _signupUmkmNameController = TextEditingController();
  final TextEditingController _signupUmkmContactController = TextEditingController();


  bool _obscureLoginPassword = true;
  bool _obscureSignupPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupUsernameController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    _signupUmkmNameController.dispose();
    _signupUmkmContactController.dispose();
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

  Future<void> _handleUmkmLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showAlert('Please enter both email and password for UMKM login.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/login'),
        body: jsonEncode({'email': email, 'password': password}),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['access_token']);
          await prefs.setString('user_type', 'umkm');
          await prefs.setString('user_data', jsonEncode(data['user']));


          AppState().setUserType('umkm');
          AppState().setToken(data['access_token']);
          AppState().setUserData(data['user']);


          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          }
        } else {
          final errorData = jsonDecode(response.body);
          _showAlert(errorData['message'] ?? 'UMKM Login failed. Please check your credentials.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showAlert('Connection error during UMKM login: ${e.toString()}');
      }
    }
  }

  Future<void> _handleUmkmSignup() async {
    final email = _signupEmailController.text.trim();
    final name = _signupUsernameController.text.trim();
    final password = _signupPasswordController.text.trim();
    final confirmPassword = _signupConfirmPasswordController.text.trim();
    final umkmBusinessName = _signupUmkmNameController.text.trim();
    final umkmContact = _signupUmkmContactController.text.trim();


    if (email.isEmpty || name.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showAlert('Please fill in Owner Name, Email, Password, and Confirm Password.');
      return;
    }
    if (password != confirmPassword) {
      _showAlert('Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      _showAlert('Password must be at least 6 characters.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/register'),
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': confirmPassword,
          'umkm_name': umkmBusinessName.isNotEmpty ? umkmBusinessName : null,
          'contact': umkmContact.isNotEmpty ? umkmContact : null,
        }),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (response.statusCode == 201) {
          _showAlert('UMKM account created successfully! Please login.');
          _toggleLoginSignup();
        } else {
          final errorData = jsonDecode(response.body);
           String errorMessage = 'UMKM Registration failed.';
           if (errorData['errors'] != null && errorData['errors'] is Map) {
                Map<String, dynamic> errors = errorData['errors'];
                if (errors.isNotEmpty) {
                    errorMessage = errors.entries.first.value[0];
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
        _showAlert('Connection error during UMKM registration: ${e.toString()}');
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _showLogin ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                firstChild: _buildUmkmLoginPage(),
                secondChild: _buildUmkmSignupPage(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUmkmLoginPage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLogo(),
        const SizedBox(height: 24),
        Text(
          'UMKM Login',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        _buildInputField(
          label: 'Email',
          icon: Icons.email_outlined,
          controller: _loginEmailController,
          hintText: 'your@email.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          label: 'Password',
          controller: _loginPasswordController,
          obscureText: _obscureLoginPassword,
          onToggleVisibility: _toggleLoginPasswordVisibility,
          minLength: 6,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleUmkmLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Text('Login as UMKM'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _toggleLoginSignup,
           style: OutlinedButton.styleFrom(
            side: BorderSide(color: Theme.of(context).colorScheme.primary),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Create UMKM Account'),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        TextButton(
           onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const InvestorAuthScreen()),
            );
          },
          child: Text(
            'Login / Register as Investor',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildUmkmSignupPage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
         Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _toggleLoginSignup,
            ),
            const SizedBox(width: 8),
            Text('Create UMKM Account', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 24),
        _buildInputField(
          label: 'Owner Full Name *',
          icon: Icons.person_outline,
          controller: _signupUsernameController,
          hintText: 'e.g., Budi Santoso',
        ),
        const SizedBox(height: 16),
        _buildInputField(
          label: 'Email *',
          icon: Icons.email_outlined,
          controller: _signupEmailController,
          hintText: 'your@email.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
         _buildInputField(
          label: 'UMKM Business Name (Optional)',
          icon: Icons.storefront_outlined,
          controller: _signupUmkmNameController,
          hintText: 'e.g., Warung Budi Jaya',
        ),
        const SizedBox(height: 16),
        _buildInputField(
          label: 'UMKM Contact (Optional - Phone/WA)',
          icon: Icons.phone_outlined,
          controller: _signupUmkmContactController,
          hintText: 'e.g., 081234567890',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          label: 'Password *',
          controller: _signupPasswordController,
          obscureText: _obscureSignupPassword,
          onToggleVisibility: _toggleSignupPasswordVisibility,
          minLength: 6,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 4, bottom: 8),
          child: Text('At least 6 characters.', style: Theme.of(context).textTheme.bodySmall),
        ),
        _buildPasswordField(
          label: 'Confirm Password *',
          controller: _signupConfirmPasswordController,
          obscureText: _obscureConfirmPassword,
          onToggleVisibility: _toggleConfirmPasswordVisibility,
          minLength: 6,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleUmkmSignup,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Text('Register UMKM Account'),
        ),
      ],
    );
  }

 Widget _buildLogo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.store_mall_directory_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'UMKM Portal',
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
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: Theme.of(context).hintColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.0),
        ),
        filled: !enabled,
        fillColor: Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required int minLength,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: '••••••••',
        prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).hintColor),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Theme.of(context).hintColor,
          ),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
         enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
      ),
    );
  }
}

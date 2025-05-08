import 'package:flutter/material.dart';
import 'package:finance/main.dart';

void main() {
  runApp(const UMKMFinanceApp());
}

class UMKMFinanceApp extends StatelessWidget {
  const UMKMFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UMKM Finance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

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

  Future<void> _handleLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showAlert('Please enter both email and password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Dummy authentication
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });

    if (email == 'demo@umkm.com' && password == 'password123') {
       if (!mounted) return; // Check if the widget is still mounted
      // Successful login - navigate to dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      _showAlert('Invalid credentials. Try demo@umkm.com / password123');
    }
  }

  Future<void> _handleSignup() async {
    final email = _signupEmailController.text.trim();
    final username = _signupUsernameController.text.trim();
    final password = _signupPasswordController.text.trim();
    final confirmPassword = _signupConfirmPasswordController.text.trim();

    if (email.isEmpty || username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showAlert('Please fill in all fields');
      return;
    }

    if (password != confirmPassword) {
      _showAlert('Passwords do not match');
      return;
    }

    if (password.length < 8) {
      _showAlert('Password must be at least 8 characters');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate account creation
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
      _showLogin = true;
      _signupEmailController.clear();
      _signupUsernameController.clear();
      _signupPasswordController.clear();
      _signupConfirmPasswordController.clear();
    });

    _showAlert('Account created successfully! Please log in.');
  }

  void _showAlert(String message) {
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _showLogin ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: _buildLoginPage(),
            secondChild: _buildSignupPage(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPage() {
    return Column(
      children: [
        const SizedBox(height: 24),
        _buildLogo(),
        const SizedBox(height: 24),
        const Text(
          'UMKM FINANCE',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage your finances with ease',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 32),
        _buildInputField(
          label: 'Email',
          icon: Icons.email,
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
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Continue'),
        ),
        const SizedBox(height: 32),
        const Text("Don't have an account?"),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _toggleLoginSignup,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Theme.of(context).colorScheme.primary),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Sign Up',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupPage() {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _toggleLoginSignup,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            const Text(
              'Create Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildInputField(
          label: 'Email',
          icon: Icons.email,
          controller: _signupEmailController,
          hintText: 'your@email.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildInputField(
          label: 'Username',
          icon: Icons.person,
          controller: _signupUsernameController,
          hintText: 'financenerd',
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          label: 'Password',
          controller: _signupPasswordController,
          obscureText: _obscureSignupPassword,
          onToggleVisibility: _toggleSignupPasswordVisibility,
        ),
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'At least 8 characters',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          label: 'Confirm Password',
          controller: _signupConfirmPasswordController,
          obscureText: _obscureConfirmPassword,
          onToggleVisibility: _toggleConfirmPasswordVisibility,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSignup,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Create Account'),
        ),
        const SizedBox(height: 24),
        const Text.rich(
          TextSpan(
            text: 'By signing up, you agree to our ',
            children: [
              TextSpan(
                text: 'Terms',
                style: TextStyle(
                  color: Colors.indigo,
                  decoration: TextDecoration.underline,
                ),
              ),
              TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: TextStyle(
                  color: Colors.indigo,
                  decoration: TextDecoration.underline,
                ),
              ),
              TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.bar_chart,
        size: 36,
        color: Colors.white,
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: const TextStyle(color: Colors.grey),
                  ),
                  keyboardType: keyboardType,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.lock, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '••••••••',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggleVisibility,
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

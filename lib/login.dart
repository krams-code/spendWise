import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'signup.dart';
import 'forgotpassword.dart';

class SpendWiseLoginScreen extends StatefulWidget {
  const SpendWiseLoginScreen({super.key});

  @override
  State<SpendWiseLoginScreen> createState() => _SpendWiseLoginScreenState();
}

class _SpendWiseLoginScreenState extends State<SpendWiseLoginScreen> {
  bool _obscurePassword = true;
  bool _rememberDevice = false;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final Color primaryDarkGreen = const Color(0xFF0F3826);
  final Color inputBackgroundColor = const Color(0xFFF3F4F6);
  final Color textLightGray = const Color(0xFF6B7280);
  final Color borderLightGray = const Color(0xFFE5E7EB);

  Future<void> _loginWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Please fill in all fields");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // Navigate to Profile/Dashboard on success
    Navigator.pushReplacementNamed(context, '/overview');
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Login failed");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
  setState(() => _isLoading = true);
  try {
    // Use signInWithPopup for Flutter Web
    final GoogleAuthProvider googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.addScope('profile');

    final UserCredential userCredential = 
        await FirebaseAuth.instance.signInWithPopup(googleProvider);

    if (userCredential.user != null && mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }

  } catch (e) {
    debugPrint("Google Sign-In Error: $e"); // Check Debug Console for real error
    if (mounted) {
      _showError("Google Sign-In failed: ${e.toString()}");
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 412,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                children: [
                  // --- Logo Section ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryDarkGreen,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.account_balance, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'SpendWise',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: primaryDarkGreen,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- Main Login Card ---
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: primaryDarkGreen,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please enter your credentials to continue.',
                          style: TextStyle(fontSize: 14, color: textLightGray, height: 1.5),
                        ),
                        const SizedBox(height: 32),

                        // Email Input
                        _buildLabel('EMAIL ADDRESS'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _emailController,
                          hintText: 'name@firm.com',
                          prefixIcon: Icons.mail_outline,
                        ),
                        const SizedBox(height: 24),

                        // Password Input
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLabel('PASSWORD'),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SpendWiseForgotPasswordScreen()),
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryDarkGreen),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _passwordController,
                          hintText: '••••••••',
                          prefixIcon: Icons.lock_outline,
                          isPassword: true,
                        ),
                        const SizedBox(height: 20),

                        // Remember Device
                        Row(
                          children: [
                            SizedBox(
                              height: 20, width: 20,
                              child: Checkbox(
                                value: _rememberDevice,
                                onChanged: (value) => setState(() => _rememberDevice = value ?? false),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                side: BorderSide(color: borderLightGray, width: 1.5),
                                activeColor: primaryDarkGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('Remember this device', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Log In Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _loginWithEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryDarkGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isLoading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Google Sign In Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _loginWithGoogle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: inputBackgroundColor,
                              foregroundColor: Colors.black87,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Standard Google Icon representation
                                const Icon(Icons.g_mobiledata, color: Colors.blue, size: 30),
                                const SizedBox(width: 4),
                                const Text('Sign in with Google', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Sign Up Text
                        Center(
                          child: RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                              children: [
                                TextSpan(
                                  text: 'Sign Up',
                                  style: TextStyle(color: primaryDarkGreen, fontWeight: FontWeight.bold),
                                  recognizer: TapGestureRecognizer()..onTap = () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SpendWiseSignUpScreen()));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700, letterSpacing: 0.5));
  }

  Widget _buildTextField({required TextEditingController controller, required String hintText, required IconData prefixIcon, bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: inputBackgroundColor,
        prefixIcon: Icon(prefixIcon, color: Colors.grey.shade500, size: 22),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade500, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screens.dart';
import '../../widgets/app_theme_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String? email;
  const ForgotPasswordPage({Key? key, this.email}) : super(key: key);

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final PageController _pageController = PageController();
  final AuthService _authService = AuthService();
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.email != null) {
      _emailController.text = widget.email!;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      _currentStep++;
      _errorMessage = null;
    });
    _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleRequestOTP() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await _authService.requestOTP(email);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null) {
        if (_currentStep == 0) {
          _nextStep();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification code resent!'), backgroundColor: Color(0xFFB497FF)),
          );
        }
      } else {
        setState(() => _errorMessage = error);
      }
    }
  }

  Future<void> _handleVerifyOTP() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await _authService.verifyOTP(_emailController.text.trim(), code);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null) {
        _nextStep();
      } else {
        setState(() => _errorMessage = error);
      }
    }
  }

  Future<void> _handleResetPassword() async {
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (pass.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }
    if (pass != confirm) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await _authService.resetPasswordOTP(
      _emailController.text.trim(),
      _otpController.text.trim(),
      pass,
    );
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null) {
        _showSuccess();
      } else {
        setState(() => _errorMessage = error);
      }
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Color(0xFFB497FF), size: 60),
        content: Text(
          'Password updated successfully! You can now log in with your new password.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to login
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB497FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Back to Login', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
                _errorMessage = null;
              });
              _pageController.previousPage(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildEmailStep(),
          _buildOTPStep(),
          _buildPasswordStep(),
        ],
      ),
    );
  }

  Widget _buildStepWrapper({
    required String title,
    required String subtitle,
    required List<Widget> children,
    required String buttonLabel,
    required VoidCallback onButtonPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 40),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ...children,
          const Spacer(),
          ElevatedButton(
            onPressed: _isLoading ? null : onButtonPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB497FF),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    buttonLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEmailStep() {
    final bool isPreFilled = widget.email != null;
    return _buildStepWrapper(
      title: isPreFilled ? 'Reset Password' : 'Forgot Password?',
      subtitle: isPreFilled 
          ? 'Confirm your email address to receive a secure verification code.'
          : 'Don\'t worry! It happens. Please enter the email associated with your account.',
      buttonLabel: 'Send Code',
      onButtonPressed: _handleRequestOTP,
      children: [
        _buildTextField(
          controller: _emailController,
          hint: 'Enter your email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          readOnly: isPreFilled,
        ),
      ],
    );
  }

  Widget _buildOTPStep() {
    return _buildStepWrapper(
      title: 'OTP Verification',
      subtitle: 'Enter the 6-digit code we just sent to your email address.',
      buttonLabel: 'Verify Code',
      onButtonPressed: _handleVerifyOTP,
      children: [
        _buildTextField(
          controller: _otpController,
          hint: 'Enter 6-digit code',
          icon: Icons.lock_clock_outlined,
          keyboardType: TextInputType.number,
          maxLength: 6,
          centerText: true,
        ),
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : _handleRequestOTP,
            child: Text(
              'Didn\'t receive code? Resend',
              style: GoogleFonts.poppins(color: const Color(0xFFB497FF), fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return _buildStepWrapper(
      title: 'New Password',
      subtitle: 'Create a new, strong password that you don\'t use for other websites.',
      buttonLabel: 'Reset Password',
      onButtonPressed: _handleResetPassword,
      children: [
        _buildTextField(
          controller: _passwordController,
          hint: 'New Password',
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _confirmPasswordController,
          hint: 'Confirm Password',
          icon: Icons.lock_outline,
          isPassword: true,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    bool centerText = false,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2E2E2E),
        borderRadius: BorderRadius.circular(16),
        border: readOnly ? Border.all(color: Colors.white10) : null,
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        maxLength: maxLength,
        readOnly: readOnly,
        textAlign: centerText ? TextAlign.center : TextAlign.start,
        style: GoogleFonts.poppins(
          color: readOnly ? Colors.white38 : Colors.white,
        ),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}

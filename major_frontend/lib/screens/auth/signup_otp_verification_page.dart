import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screens.dart';

class SignupOtpVerificationScreen extends StatefulWidget {
  final String email;
  final String password;
  final String name;
  final String phone;

  const SignupOtpVerificationScreen({
    Key? key,
    required this.email,
    required this.password,
    required this.name,
    required this.phone,
  }) : super(key: key);

  @override
  State<SignupOtpVerificationScreen> createState() => _SignupOtpVerificationScreenState();
}

class _SignupOtpVerificationScreenState extends State<SignupOtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyAndCreate() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. Verify OTP
    final verifyError = await _authService.verifySignupOTP(widget.email, code);

    if (verifyError != null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = verifyError;
        });
      }
      return;
    }

    // 2. Original Signup
    final signupError = await _authService.signUpWithEmail(
      widget.email,
      widget.password,
      widget.name,
      widget.phone,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (signupError != null) {
      setState(() => _errorMessage = signupError);
    } else {
      // Success - Navigator.popUntil handles going back to home/wrapper
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _handleResendOTP() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final error = await _authService.sendSignupOTP(widget.email);
    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code resent!')),
        );
      } else {
        setState(() => _errorMessage = error);
      }
    }
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'Verify Email',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a 6-digit verification code to ${widget.email}. Enter it below to complete your sign up.',
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
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2E2E2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  letterSpacing: 10,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: GoogleFonts.poppins(color: Colors.white10, letterSpacing: 10),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _isLoading ? null : _handleResendOTP,
                child: Text(
                  'Didn\'t receive code? Resend',
                  style: GoogleFonts.poppins(color: const Color(0xFFB497FF), fontSize: 13),
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleVerifyAndCreate,
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
                      'Verify & Sign Up',
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
      ),
    );
  }
}

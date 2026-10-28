import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:major_frontend/services/notification_service.dart';
import '../../widgets/app_theme_widgets.dart';
import 'privacy_policy_screen.dart';
import 'forgot_password_page.dart';
import 'signup_otp_verification_page.dart';
import '../../services/config.dart' as app_config;
import 'package:country_picker/country_picker.dart';
import 'package:flutter/cupertino.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Global Profile Update Broadcast
  static final StreamController<void> _profileUpdateController =
      StreamController<void>.broadcast();
  static Stream<void> get profileUpdates => _profileUpdateController.stream;

  // Granular Premium Status Notifier
  static final ValueNotifier<bool> isPremiumUser = ValueNotifier<bool>(true);

  static void notifyProfileUpdate() {
    _profileUpdateController.add(null);
  }

  static void updatePremiumStatus(bool? status) {
    if (status != null && isPremiumUser.value != status) {
      isPremiumUser.value = status;
      print('AuthService: Premium status updated to: $status');
    }
  }

  static final String baseUrl = '${app_config.Config.baseUrl}/api/users';

  Future<String?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      String? syncError = await _syncUserWithBackend(result.user!);
      if (syncError != null) return syncError;
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An error occurred';
    }
  }

  Future<String?> signUpWithEmail(
    String email,
    String password,
    String name,
    String phone,
  ) async {
    try {
      UserCredential result = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 30));

      await result.user!
          .updateDisplayName(name)
          .timeout(const Duration(seconds: 10));

      String? syncError = await _syncUserWithBackend(
        result.user!,
        fullName: name,
        phone: phone,
      );
      if (syncError != null) {
        // Rollback Firebase User Creation if sync fails!
        try {
          await result.user!.delete();
        } catch (e) {
          print('AuthService: Failed to rollback Firebase user: $e');
        }
        return syncError;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      if (e is TimeoutException) {
        return 'Connection Timeout: Please check your internet and if SHA-1 is added to Firebase.';
      }
      return 'An error occurred: $e';
    }
  }

  Future<String?> signInWithGoogle() async {
    AuthCredential? credential;
    String? idToken;
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Sign in aborted by user';

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      idToken = googleAuth.idToken; // save for backend linking
      credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      String? syncError = await _syncUserWithBackend(result.user!);
      if (syncError != null) return syncError;
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential' && e.email != null && idToken != null) {
        // Frictionless: use backend to get custom token for the existing account
        return await _linkSocialViaBackend(idToken: idToken, provider: 'google', pendingCredential: credential);
      }
      if (e.code == 'credential-already-in-use' && credential != null) {
        try {
          final result = await _auth.signInWithCredential(credential);
          await _syncUserWithBackend(result.user!);
          return null;
        } catch (_) {}
      }
      return e.message ?? e.toString();
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signInWithFacebook() async {
    OAuthCredential? credential;
    String? fbAccessToken;
    try {
      final LoginResult loginResult = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'email'],
      );

      if (loginResult.status == LoginStatus.success) {
        fbAccessToken = loginResult.accessToken!.tokenString;
        credential = FacebookAuthProvider.credential(fbAccessToken);

        UserCredential result = await _auth.signInWithCredential(credential);
        String? syncError = await _syncUserWithBackend(result.user!);
        if (syncError != null) return syncError;
        return null;
      } else if (loginResult.status == LoginStatus.cancelled) {
        return 'Sign in aborted by user';
      } else {
        return 'Facebook login failed: ${loginResult.message}';
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential' && e.email != null && fbAccessToken != null) {
        // Frictionless: use backend to get custom token for the existing account
        return await _linkSocialViaBackend(idToken: fbAccessToken, provider: 'facebook', pendingCredential: credential);
      }
      if (e.code == 'credential-already-in-use' && credential != null) {
        try {
          final result = await _auth.signInWithCredential(credential);
          await _syncUserWithBackend(result.user!);
          return null;
        } catch (_) {}
      }
      return e.message ?? e.toString();
    } catch (e) {
      return e.toString();
    }
  }

  /// Frictionless account linking via backend:
  /// Sends the social token to our server, which verifies it and issues
  /// a custom Firebase token for the existing account (no password needed).
  Future<String?> _linkSocialViaBackend({
    required String idToken,
    required String provider,
    AuthCredential? pendingCredential,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/link-social'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken, 'provider': provider}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final customToken = data['customToken'] as String?;
        if (customToken == null) return 'Server error: no token returned';

        // Sign in with the custom token (maps to existing user's UID)
        final userCred = await _auth.signInWithCustomToken(customToken);

        // Optionally link the social credential so future direct sign-ins work too
        if (pendingCredential != null) {
          await _safeLinkCredential(userCred.user!, pendingCredential);
        }
        await _syncUserWithBackend(userCred.user!);
        return null; // success
      } else if (response.statusCode == 404) {
        // No existing account — proceed with normal social sign-in (creates new account)
        return null;
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Unknown error';
        return 'Sign-in failed: $err';
      }
    } catch (e) {
      return e.toString();
    }
  }

  /// Links a credential, ignoring "already linked" errors which are benign.
  Future<void> _safeLinkCredential(User user, AuthCredential credential) async {
    try {
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'credential-already-in-use' && e.code != 'provider-already-linked') {
        rethrow;
      }
    }
  }


  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('AuthService: No user in getUserProfile');
        return null;
      }

      final res = await app_config.Config.supabase
          .from('users')
          .select()
          .eq('firebaseUid', user.uid)
          .maybeSingle();

      if (res != null) {
        final profile = Map<String, dynamic>.from(res);
        profile['isPremium'] = true;
        updatePremiumStatus(true);
        return profile;
      }

      // If user profile not found, auto-sync and re-query
      await _syncUserWithBackend(user);
      final synced = await app_config.Config.supabase
          .from('users')
          .select()
          .eq('firebaseUid', user.uid)
          .maybeSingle();
      if (synced != null) {
        final profile = Map<String, dynamic>.from(synced);
        profile['isPremium'] = true;
        updatePremiumStatus(true);
        return profile;
      }
      return null;
    } catch (e) {
      print('AuthService: getUserProfile error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserProfileByUid(String uid) async {
    try {
      final res = await app_config.Config.supabase
          .from('users')
          .select()
          .eq('firebaseUid', uid)
          .maybeSingle();

      if (res != null) {
        final profile = Map<String, dynamic>.from(res);
        profile['isPremium'] = true;
        return profile;
      }
      return null;
    } catch (e) {
      print('AuthService: getUserProfileByUid error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getMatches() async {
    try {
      final user = _auth.currentUser;
      final res = await app_config.Config.supabase
          .from('users')
          .select()
          .neq('firebaseUid', user?.uid ?? '')
          .limit(30);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('AuthService: getMatches error: $e');
      return [];
    }
  }

  Future<String?> updateProfile(Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user logged in';

      final cleanData = Map<String, dynamic>.from(data);
      cleanData['updatedAt'] = DateTime.now().toIso8601String();
      cleanData['isPremium'] = true;

      await app_config.Config.supabase
          .from('users')
          .update(cleanData)
          .eq('firebaseUid', user.uid);

      notifyProfileUpdate();
      return null;
    } catch (e) {
      print('Update profile error: $e');
      return 'Update error: $e';
    }
  }

  Future<String?> _syncUserWithBackend(
    User user, {
    String? fullName,
    String? phone,
  }) async {
    try {
      // Check existing user to preserve setup status
      final existing = await app_config.Config.supabase
          .from('users')
          .select('is_setup_completed')
          .eq('firebaseUid', user.uid)
          .maybeSingle();

      final bool isAlreadySetup = existing != null &&
          (existing['is_setup_completed'] == true || existing['is_setup_completed'] == 1);

      await app_config.Config.supabase.from('users').upsert({
        'firebaseUid': user.uid,
        'fullName': fullName ?? user.displayName ?? 'Spottr Athlete',
        'email': user.email,
        'phone': phone,
        'isPremium': true,
        'planType': 'free_pro',
        'is_setup_completed': isAlreadySetup,
        if (existing == null) 'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, onConflict: 'firebaseUid');

      try {
        await NotificationService().updateTokenOnServer(user.uid);
      } catch (e) {
        print('Error updating FCM token during sync: $e');
      }

      return null;
    } catch (e) {
      print('Sync error: $e');
      return 'Sync error: $e';
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FacebookAuth.instance.logOut();
    await _auth.signOut();
  }

  Future<String?> setupPassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user logged in';

      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'This action requires recent authentication. Please log in again.';
      }
      return e.message;
    } catch (e) {
      return 'Error setting password: $e';
    }
  }

  Future<String?> uploadProfilePicture(String filePath) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user logged in';

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final ext = filePath.split('.').last;
      final fileName = '${user.uid}_avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await app_config.Config.supabase.storage.from('avatars').uploadBinary(fileName, bytes);
      final publicUrl = app_config.Config.supabase.storage.from('avatars').getPublicUrl(fileName);

      await app_config.Config.supabase.from('users').update({
        'profilePictureUrl': publicUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      }).eq('firebaseUid', user.uid);

      notifyProfileUpdate();
      return null;
    } catch (e) {
      print('Upload profile picture error: $e');
      return 'Upload error: $e';
    }
  }

  Future<String?> uploadCoverPhoto(String filePath) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user logged in';

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final ext = filePath.split('.').last;
      final fileName = '${user.uid}_cover_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await app_config.Config.supabase.storage.from('avatars').uploadBinary(fileName, bytes);
      final publicUrl = app_config.Config.supabase.storage.from('avatars').getPublicUrl(fileName);

      await app_config.Config.supabase.from('users').update({
        'coverPhotoUrl': publicUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      }).eq('firebaseUid', user.uid);

      notifyProfileUpdate();
      return null;
    } catch (e) {
      print('Upload cover photo error: $e');
      return 'Upload error: $e';
    }
  }

  Future<String?> getCurrentUserToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An error occurred';
    }
  }

  Future<String?> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user logged in';
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'This action requires recent authentication. Please log in again.';
      }
      return e.message;
    } catch (e) {
      return 'Error updating password: $e';
    }
  }

  // OTP-based Password Reset Methods
  Future<String?> requestOTP(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200) return null;
      final error = jsonDecode(response.body)['error'] ?? 'Failed to send OTP';
      return error;
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  Future<String?> verifyOTP(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );
      if (response.statusCode == 200) return null;
      final error = jsonDecode(response.body)['error'] ?? 'Invalid code';
      return error;
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  Future<String?> resetPasswordOTP(
    String email,
    String code,
    String newPassword,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'newPassword': newPassword,
        }),
      );
      if (response.statusCode == 200) return null;
      final error =
          jsonDecode(response.body)['error'] ?? 'Failed to reset password';
      return error;
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  // OTP-based Signup Methods
  Future<String?> sendSignupOTP(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200) return null;
      final error = jsonDecode(response.body)['error'] ?? 'Failed to send OTP';
      return error;
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  Future<String?> verifySignupOTP(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );
      if (response.statusCode == 200) return null;
      final error = jsonDecode(response.body)['error'] ?? 'Invalid code';
      return error;
    } catch (e) {
      return 'Connection error: $e';
    }
  }
}

// Sign In Screen
class SignInScreen extends StatefulWidget {
  final VoidCallback onShowSignUp;
  const SignInScreen({Key? key, required this.onShowSignUp}) : super(key: key);

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _handleSignIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);
    final error = await _authService.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    } else {
      // Success: Clear stack so AuthWrapper can show the correct screen
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _handleSocialSignIn(Future<String?> Function() signInMethod) async {
    setState(() => _isLoading = true);
    final error = await signInMethod();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null && !error.contains('aborted')) {
      if (!mounted) return;
      if (error.contains('key hash') || error.contains('Key hash')) {
        _showKeyHashDialog(error);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    } else if (error == null) {
      // Success
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _showKeyHashDialog(String error) {
    AppDialog.show(
      context: context,
      title: 'Facebook Configuration Error',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Please copy this error message (it contains the Key Hash) and add it to Facebook Developers > Android > Key Hashes:',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          SelectableText(
            error,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFB497FF),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Close',
            style: TextStyle(color: Color(0xFFB497FF)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        const Spacer(),
                        const Text(
                          'Sign in',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB794F6),
                          ),
                        ),
                        const SizedBox(height: 40),

                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            hintText: 'Email',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const PremiumLoading(
                                    color: Colors.white,
                                    size: 24,
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ForgotPasswordPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color(0xFFB794F6),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          'Sign in with',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _SocialButton(
                              assetPath: 'assets/images/google.png',
                              onPressed: _isLoading
                                  ? () {}
                                  : () => _handleSocialSignIn(
                                      _authService.signInWithGoogle,
                                    ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: widget.onShowSignUp,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: Color(0xFFB794F6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Sign Up Screen
class SignUpScreen extends StatefulWidget {
  final VoidCallback onShowSignIn;
  const SignUpScreen({Key? key, required this.onShowSignIn}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _countryCodeController = TextEditingController(
    text: '855',
  );
  final AuthService _authService = AuthService();
  late TapGestureRecognizer _privacyRecognizer;
  bool _isLoading = false;
  bool acceptPrivacy = false;
  Country _selectedCountry = Country(
    phoneCode: '855',
    countryCode: 'KH',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'Cambodia',
    example: '12345678',
    displayName: 'Cambodia',
    displayNameNoCountryCode: 'Cambodia',
    e164Key: '',
  );

  @override
  void initState() {
    super.initState();
    _privacyRecognizer = TapGestureRecognizer()..onTap = _showPrivacyPolicyPage;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _countryCodeController.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _showPrivacyPolicyPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
    );
  }

  void _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    // Password strength validation: Min 8 chars, at least one letter and one number
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters long'),
        ),
      );
      return;
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must contain both letters and numbers'),
        ),
      );
      return;
    }

    // Basic phone validation
    if (phone.length < 8 || phone.length > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    if (!acceptPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the privacy policy')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Send real OTP email via Vercel (spottrnoreply@gmail.com)
    final error = await _authService.sendSignupOTP(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SignupOtpVerificationScreen(
            email: email,
            password: password,
            name: name,
            phone: '+${_countryCodeController.text}$phone',
          ),
        ),
      );
    }
  }

  void _handleSocialSignIn(Future<String?> Function() signInMethod) async {
    setState(() => _isLoading = true);
    final error = await signInMethod();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null && !error.contains('aborted')) {
      if (error.contains('key hash') || error.contains('Key hash')) {
        _showKeyHashDialog(error);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    } else if (error == null) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _showKeyHashDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Facebook Configuration Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your app is missing a Key Hash. Please copy the hash below and add it to the Facebook Developer Console:',
            ),
            const SizedBox(height: 10),
            SelectableText(
              error,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        const Spacer(),
                        const Text(
                          'Sign up',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB794F6),
                          ),
                        ),
                        const SizedBox(height: 40),

                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Full Name',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            hintText: 'Email',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),

                        // Integrated Phone Number Input
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              // Flag Icon (Click to Scroll)
                              GestureDetector(
                                onTap: () {
                                  final countries = CountryService().getAll();
                                  int initialIndex = countries.indexWhere(
                                    (c) =>
                                        c.countryCode ==
                                        _selectedCountry.countryCode,
                                  );

                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: const Color(0xFF2A2A2A),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(24),
                                      ),
                                    ),
                                    builder: (context) => Container(
                                      height: 350,
                                      padding: const EdgeInsets.only(
                                        bottom: 20,
                                      ),
                                      child: Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Select Country',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text(
                                                    'Done',
                                                    style: GoogleFonts.poppins(
                                                      color: const Color(
                                                        0xFFB497FF,
                                                      ),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Divider(color: Colors.white12),
                                          Expanded(
                                            child: CupertinoTheme(
                                              data: const CupertinoThemeData(
                                                textTheme:
                                                    CupertinoTextThemeData(
                                                      pickerTextStyle:
                                                          TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 18,
                                                          ),
                                                    ),
                                              ),
                                              child: CupertinoPicker(
                                                scrollController:
                                                    FixedExtentScrollController(
                                                      initialItem:
                                                          initialIndex > -1
                                                          ? initialIndex
                                                          : 0,
                                                    ),
                                                itemExtent: 44,
                                                onSelectedItemChanged: (index) {
                                                  setState(() {
                                                    _selectedCountry =
                                                        countries[index];
                                                    _countryCodeController
                                                        .text = countries[index]
                                                        .phoneCode;
                                                  });
                                                },
                                                children: countries
                                                    .map(
                                                      (c) => Center(
                                                        child: Text(
                                                          '${c.flagEmoji}  ${c.name} (+${c.phoneCode})',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  _selectedCountry.flagEmoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '+',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              // Code Input (Type to Detect)
                              SizedBox(
                                width: 45,
                                child: TextField(
                                  controller: _countryCodeController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.start,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) {
                                    if (val.isNotEmpty) {
                                      final countries = CountryService()
                                          .getAll();
                                      final match = countries
                                          .where((c) => c.phoneCode == val)
                                          .toList();
                                      if (match.isNotEmpty) {
                                        setState(
                                          () => _selectedCountry = match.first,
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 1,
                                height: 24,
                                color: Colors.white24,
                              ),
                              const SizedBox(width: 12),
                              // Main Phone Number
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    hintText: 'Phone',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: acceptPrivacy,
                                onChanged: (value) {
                                  setState(() {
                                    acceptPrivacy = value ?? false;
                                  });
                                },
                                fillColor: MaterialStateProperty.resolveWith((
                                  states,
                                ) {
                                  if (states.contains(MaterialState.selected)) {
                                    return Colors.white;
                                  }
                                  return Colors.transparent;
                                }),
                                checkColor: Colors.black,
                                side: const BorderSide(
                                  color: Colors.grey,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            RichText(
                              text: TextSpan(
                                text: 'By continuing you accept our ',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: const TextStyle(
                                      color: Color(0xFFB794F6),
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: _privacyRecognizer,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'Sign up',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          'Sign up with',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _SocialButton(
                              assetPath: 'assets/images/google.png',
                              onPressed: _isLoading
                                  ? () {}
                                  : () => _handleSocialSignIn(
                                      _authService.signInWithGoogle,
                                    ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already an account? ',
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: widget.onShowSignIn,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Sign in',
                                style: TextStyle(
                                  color: Color(0xFFB794F6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String assetPath;
  final VoidCallback onPressed;

  const _SocialButton({required this.assetPath, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Image.asset(
        assetPath,
        width: 32,
        height: 32,
        fit: BoxFit.contain, // DON'T STRETCH
      ),
    );
  }
}

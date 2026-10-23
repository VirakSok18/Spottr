import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../auth/auth_screens.dart';
import '../auth/privacy_policy_screen.dart';
import 'notification_settings_screen.dart';
import 'dart:io';
import '../social/saved_posts_screen.dart';
import '../social/user_profile_screen.dart';
import '../social/blocked_users_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_settings_screen.dart';
import '../../widgets/app_theme_widgets.dart';
import 'help_screen.dart';
import '../auth/forgot_password_page.dart';
import 'premium_upgrade_screen.dart';
import 'manage_plan_screen.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfilePage({Key? key, required this.onLogout}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isActionLoading = false;
  StreamSubscription? _profileSubscription;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    
    // Listen for global profile updates (e.g., changes made from Swipe view)
    _profileSubscription = AuthService.profileUpdates.listen((_) {
      print('ProfilePage: Received profile update broadcast');
      _fetchProfile();
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    final data = await _authService.getUserProfile();
    setState(() {
      _userData = data;
      _isLoading = false;
    });
  }

  // Removed _pickAndUploadImage as it moved to ProfileSettingsScreen

  Future<void> _editField(String field, String initialValue, {bool isNumeric = false}) async {
    final TextEditingController controller = TextEditingController(text: initialValue);
    
    final result = await AppDialog.show<String>(
      context: context,
      title: 'Edit ${field.replaceAll('_', ' ')}',
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Enter new value',
          hintStyle: TextStyle(color: Colors.grey[600]),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFB497FF))),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFB497FF))),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save', style: TextStyle(color: Color(0xFFB497FF), fontWeight: FontWeight.bold)),
        ),
      ],
    );

    if (result != null && result != initialValue) {
      setState(() => _isActionLoading = true);
      Map<String, dynamic> updateData = {field: isNumeric ? int.tryParse(result) : result};
      final error = await _authService.updateProfile(updateData);
      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
      } else {
        await _fetchProfile();
      }
      setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1B1B1B),
        body: const Center(child: PremiumLoading(size: 50)),
      );
    }

    final name = _userData?['fullName'] ?? 'User';
    final email = _userData?['email'] ?? '';
    final profilePic = _userData?['profilePictureUrl'];
    final weight = _userData?['weight'] != null 
        ? (double.tryParse(_userData!['weight'].toString())?.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') ?? _userData!['weight'].toString()) 
        : '--';
    final age = _userData?['age']?.toString() ?? '--';
    final height = _userData?['height'] != null 
        ? (double.tryParse(_userData!['height'].toString())?.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') ?? _userData!['height'].toString()) 
        : '--';
    final weightUnit = _userData?['weight_unit']?.toString() ?? 'Kg';
    
    // Calculate Joined Days
    String joinedText = 'Joined For --';
    if (_userData?['createdAt'] != null) {
      try {
        DateTime createdAt = DateTime.parse(_userData?['createdAt']);
        int days = DateTime.now().difference(createdAt).inDays;
        joinedText = 'Joined For ${days == 0 ? "Today" : "$days days"}';
      } catch (e) {
        print('Error parsing createdAt: $e');
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Your profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Main Card
                _buildProfileHeader(name, email, profilePic, joinedText),
                
                const SizedBox(height: 20),
                
                // Go Premium or Manage Plan Button
                _userData?['isPremium'] == 1 || _userData?['isPremium'] == true
                  ? ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ManagePlanScreen(userData: _userData!)),
                        );
                      },
                      icon: const Icon(Icons.settings_suggest, color: Colors.white),
                      label: const Text('Manage Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E2E2E),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: const Color(0xFFFFC107).withOpacity(0.5)),
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PremiumUpgradeScreen()),
                        );
                      },
                      icon: const Icon(Icons.workspace_premium, color: Colors.white),
                      label: const Text('Go Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                
                const SizedBox(height: 24),
                
                // Information Grid
                const Text('Information', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildInfoSection(weight, age, height, weightUnit),
                
                const SizedBox(height: 24),
                
                // General Section
                const Text('General', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildMenuTile(Icons.person, 'Profile Settings', onTap: () {
                  if (_userData != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileSettingsScreen(
                          userData: _userData!,
                          onUpdate: _fetchProfile,
                        ),
                      ),
                    );
                  }
                }),
                _buildMenuTile(Icons.bookmark_outline, 'Favorite', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SavedPostsScreen()),
                  );
                }),
                _buildMenuTile(Icons.privacy_tip_outlined, 'Privacy Policy', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                  );
                }),
                _buildMenuTile(Icons.settings_outlined, 'Settings', onTap: () {
                  // Show Settings options including security
                  _showSettingsMenu();
                }),
                _buildMenuTile(Icons.help_outline, 'Help', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpScreen()),
                  );
                }),
                

                _buildMenuTile(Icons.block_outlined, 'Blocked Users', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BlockedUsersScreen()),
                  );
                }),
    
                const SizedBox(height: 32),
                
                // Logout Button
                ElevatedButton.icon(
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isActionLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: PremiumLoading(size: 50)),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String name, String email, String? profilePic, String joinedText) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2E2E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: const Color(0xFF1B1B1B),
            backgroundImage: (profilePic != null && profilePic.toString().isNotEmpty) ? NetworkImage(profilePic) : null,
            child: (profilePic == null || profilePic.toString().isEmpty) ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_userData?['isPremium'] == 1 || _userData?['isPremium'] == true) ...[
                      const SizedBox(width: 8),
                      _buildPremiumBadge(),
                    ],
                  ],
                ),
                Text(email, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(joinedText, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD700), // Gold Color
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.08), // Minimal visibility
            blurRadius: 3, // Tiny blur
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Text(
        'PREMIUM',
        style: GoogleFonts.poppins(
          color: const Color(0xFFFFD700),
          fontSize: 9,
          fontWeight: FontWeight.w300, // Skinny font
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2E2E2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildMenuTile(Icons.lock_outline, 'Security / Update Password', onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ForgotPasswordPage(
                    email: _userData?['email'],
                  ),
                ),
              );
            }),
            _buildMenuTile(Icons.notifications_none, 'Notifications', onTap: () {
              Navigator.pop(context); // Close the bottom sheet first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String weight, String age, String height, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2E2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInfoItem('$weight $unit', 'Weight'),
          _buildVerticalDivider(),
          _buildInfoItem('$age', 'Years Old'),
          _buildVerticalDivider(),
          _buildInfoItem('$height CM', 'Height'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFB794F6))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.white12);
  }

  Widget _buildMenuTile(IconData icon, String title, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2E2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: Colors.white),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white70),
          onTap: onTap,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_screens.dart';
import 'user_profile_screen.dart';
import 'chat_screen.dart';
import '../../widgets/app_theme_widgets.dart';
import '../../widgets/full_screen_ad_overlay.dart';
import '../home/profile_settings_screen.dart';

class SwipeDiscoveryView extends StatefulWidget {
  const SwipeDiscoveryView({Key? key}) : super(key: key);

  @override
  State<SwipeDiscoveryView> createState() => _SwipeDiscoveryViewState();
}

class _SwipeDiscoveryViewState extends State<SwipeDiscoveryView> {
  final AuthService _authService = AuthService();
  final PageController _pageController = PageController();
  List<Map<String, dynamic>> _matches = [];
  bool _isLoading = true;
  bool _isPremium = true;
  int _swipeCount = 0;
  StreamSubscription? _profileSubscription;

  @override
  void initState() {
    super.initState();
    _fetchMatches();

    // Listen for global profile updates (e.g., location changes)
    _profileSubscription = AuthService.profileUpdates.listen((_) {
      print('SwipeDiscoveryView: Received profile update broadcast');
      _fetchMatches();
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _myProfile;
  bool _isProfileComplete = false;

  Future<void> _fetchMatches() async {
    setState(() => _isLoading = true);
    
    // 1. Get my profile to check completeness
    final myProfile = await _authService.getUserProfile();
    _myProfile = myProfile;
    _isProfileComplete = _checkCompleteness(myProfile);

    // 2. Only fetch matches if I am complete
    if (_isProfileComplete) {
      final results = await _authService.getMatches();
      if (mounted) {
        setState(() {
          _matches = results;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _checkCompleteness(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    
    // Required fields: bio, age, location, looking_for, experience, height, weight, availability
    final bio = profile['bio']?.toString() ?? '';
    final age = profile['age'];
    final lat = profile['latitude'];
    final lon = profile['longitude'];
    final lookingFor = profile['looking_for']?.toString() ?? '';
    final experience = profile['experience'];
    final height = profile['height'];
    final weight = profile['weight'];
    
    // Availability check (must be a non-empty list)
    bool hasAvailability = false;
    final availRaw = profile['availability'];
    if (availRaw != null) {
      if (availRaw is String) {
        try { 
          final List list = jsonDecode(availRaw);
          hasAvailability = list.isNotEmpty;
        } catch (_) {}
      } else if (availRaw is List) {
        hasAvailability = availRaw.isNotEmpty;
      }
    }

    return bio.isNotEmpty && 
           age != null && 
           lat != null && 
           lon != null && 
           lookingFor.isNotEmpty && 
           experience != null && 
           height != null && 
           weight != null && 
           hasAvailability;
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: PremiumLoading(size: 60));
    }

    if (!_isProfileComplete) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline, color: Colors.white24, size: 80),
              const SizedBox(height: 24),
              Text(
                'Profile Incomplete',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'You must complete your profile (Bio, Age, Location, Experience, Body Info, and Availability) to use the swipe section and be discoverable by others.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (_myProfile != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileSettingsScreen(
                          userData: _myProfile!,
                          onUpdate: _fetchMatches,
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB497FF),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(
                  'Complete Profile',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_outlined, color: Colors.white24, size: 80),
            const SizedBox(height: 24),
            Text(
              'No matches in your area yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your location or ensuring your profile is complete (Bio, Experience, and Availability).',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _fetchMatches,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB497FF),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(
                'Search Again',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

    return ValueListenableBuilder<bool>(
      valueListenable: AuthService.isPremiumUser,
      builder: (context, isPremium, child) {
        return PageView.builder(
          controller: _pageController,
          itemCount: _matches.length,
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          onPageChanged: (index) {
            if (!isPremium) {
              _swipeCount++;
              if (_swipeCount >= 5) {
                _swipeCount = 0;
                _showAdOverlay();
              }
            }
          },
          itemBuilder: (context, index) {
            final item = _matches[index];
            return _buildUserCard(item);
          },
        );
      }
    );
  }

  void _showAdOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const FullScreenAdOverlay();
      },
    );
  }


  Widget _buildUserCard(Map<String, dynamic> user) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              // 1. Image Card - Flexible to ensure everything fits without scrolling
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFF2E2E2E),
                    image: (user['profilePictureUrl'] != null && user['profilePictureUrl'].toString().isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(user['profilePictureUrl']),
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                              stops: const [0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 24,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user['fullName'] ?? 'User'}, ${user['age'] ?? ''}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.white70, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${user['distance_km'] ?? '??'}km',
                                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Looking For Card
              _buildInfoSection('Looking for', user['looking_for'] ?? 'Workout Buddy'),
              const SizedBox(height: 12),

              // 3. About Me Card
              _buildInfoSection('About me', user['bio'] ?? 'No bio provided.'),
              const SizedBox(height: 12),

              // 4. Fitness & Body Info Card
              _buildFitnessInfoSection(user),
              const SizedBox(height: 12),

              // 5. Availability Card
              _buildAvailabilitySection(user),
              const SizedBox(height: 16),

              // 6. Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'View Profile',
                      Colors.white,
                      const Color(0xFFB497FF),
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SocialUserProfileScreen(
                              userUid: user['firebaseUid'],
                              userName: user['fullName'],
                              userAvatar: user['profilePictureUrl'],
                              userCover: user['coverPhotoUrl'],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      'Message',
                      const Color(0xFF8A2BE2),
                      Colors.white,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              otherUid: user['firebaseUid'],
                              otherName: user['fullName'],
                              otherAvatar: user['profilePictureUrl'],
                              otherCover: user['coverPhotoUrl'],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: const Color(0xFFB497FF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFitnessInfoSection(Map<String, dynamic> user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fitness & Body Info:',
            style: GoogleFonts.poppins(
              color: const Color(0xFFB497FF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.person_outline, user['gender'] ?? 'Not Set'),
          _buildDetailRow(Icons.fitness_center, '${user['experience'] ?? 0} Year${user['experience'] == 1 ? '' : 's'}'),
          _buildDetailRow(Icons.height, '${user['height'] != null ? (double.tryParse(user['height'].toString())?.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') ?? user['height']) : '--'} Cm'),
          _buildDetailRow(Icons.monitor_weight_outlined, '${user['weight'] != null ? (double.tryParse(user['weight'].toString())?.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') ?? user['weight']) : '--'} Kg'),
        ],
      ),
    );
  }

  Widget _buildAvailabilitySection(Map<String, dynamic> user) {
    List availability = [];
    Map<String, String> timeSpans = {};
    
    final availRaw = user['availability'];
    final timeSpansRaw = user['availability_time_spans'];
    
    if (availRaw != null) {
      if (availRaw is String) {
        try { availability = jsonDecode(availRaw); } catch (_) { availability = []; }
      } else if (availRaw is List) {
        availability = availRaw;
      }
    }

    if (timeSpansRaw != null) {
      if (timeSpansRaw is String) {
        try { 
          final decoded = jsonDecode(timeSpansRaw);
          if (decoded is Map) timeSpans = Map<String, String>.from(decoded);
        } catch (_) {}
      } else if (timeSpansRaw is Map) {
        timeSpans = Map<String, String>.from(timeSpansRaw);
      }
    }

    if (availability.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Availability:',
            style: GoogleFonts.poppins(
              color: const Color(0xFFB497FF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availability.map<Widget>((a) {
              final span = timeSpans[a.toString()];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF353535),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getIconForOption(a.toString()), color: Colors.white70, size: 14),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          a.toString(),
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        if (span != null)
                          Text(
                            span,
                            style: GoogleFonts.poppins(color: const Color(0xFFB497FF), fontSize: 9),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getIconForOption(String option) {
    switch (option) {
      case 'Morning': return Icons.wb_sunny_outlined;
      case 'Afternoon': return Icons.wb_cloudy_outlined;
      case 'Evening': return Icons.wb_twilight;
      case 'Night': return Icons.nightlight_round_outlined;
      default: return Icons.access_time;
    }
  }

  Widget _buildDetailRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color bgColor, Color textColor, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: bgColor == Colors.white ? const BorderSide(color: Colors.transparent) : BorderSide.none,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}

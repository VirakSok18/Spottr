import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../services/post_service.dart';
import '../../services/chat_service.dart';
import '../auth/auth_screens.dart';
import '../../widgets/post_widget.dart';
import 'chat_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SocialUserProfileScreen extends StatefulWidget {
  final String userUid;
  final String userName;
  final String? userAvatar;
  final String? userCover;

  const SocialUserProfileScreen({
    Key? key,
    required this.userUid,
    required this.userName,
    this.userAvatar,
    this.userCover,
  }) : super(key: key);

  @override
  State<SocialUserProfileScreen> createState() => _SocialUserProfileScreenState();
}

class _SocialUserProfileScreenState extends State<SocialUserProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PostService _postService = PostService();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  List<PostModel> _userPosts = [];
  bool _isLoadingPosts = true;
  bool _isLoadingProfile = true;
  Map<String, dynamic>? _chatStatus;
  Map<String, dynamic>? _userData;
  bool _isMe = false;
  StreamSubscription? _profileSubscription;

  @override
  void initState() {
    super.initState();
    final curUser = FirebaseAuth.instance.currentUser;
    _isMe = curUser?.uid == widget.userUid;
    _tabController = TabController(length: 2, vsync: this);
    
    // Set initial data if provided (prevents flickering)
    if (widget.userAvatar != null || widget.userCover != null) {
      _userData = {
        'profilePictureUrl': widget.userAvatar,
        'coverPhotoUrl': widget.userCover,
        'fullName': widget.userName,
      };
    }
    
    _fetchUserProfile();
    _fetchUserPosts();
    _fetchChatStatus();

    // Listen for global profile updates (e.g., location changes)
    _profileSubscription = AuthService.profileUpdates.listen((_) {
      if (_isMe) {
        print('SocialUserProfileScreen: Received profile update broadcast');
        _fetchUserProfile();
      }
    });
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoadingProfile = true;
      // Do NOT clear _userData here if we have initial data to prevent flickering
    });
    final data = await _authService.getUserProfileByUid(widget.userUid);
    if (mounted) {
      setState(() {
        _userData = data;
        _isLoadingProfile = false;
      });
    }
  }


  Future<void> _fetchChatStatus() async {
    if (_isMe) return;
    final status = await _chatService.getChatStatus(widget.userUid);
    if (mounted) {
      setState(() {
        _chatStatus = status;
      });
    }
  }

  Future<void> _fetchUserPosts() async {
    setState(() => _isLoadingPosts = true);
    final postsData = await _postService.getUserPosts(widget.userUid);
    if (mounted) {
      setState(() {
        _userPosts = postsData.map((json) => PostModel.fromJson(json)).toList();
        _isLoadingPosts = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _profileSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      body: NestedScrollView(
        key: const PageStorageKey('social_profile'),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: const Color(0xFF1B1B1B),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Cover Photo
                      (_userData != null && _userData!['coverPhotoUrl'] != null && _userData!['coverPhotoUrl'].toString().isNotEmpty)
                          ? CachedNetworkImage(
                              key: ValueKey(_userData!['coverPhotoUrl']),
                              imageUrl: _userData!['coverPhotoUrl'],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: const Color(0xFF2E2E2E)),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                              fadeInDuration: const Duration(milliseconds: 300),
                            )
                          : _isLoadingProfile 
                              ? Container(color: const Color(0xFF1B1B1B)) // Solid dark during initial load
                              : Container(color: const Color(0xFF1B1B1B)), // Black/Blank if no cover

                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black38, Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 64,
                        left: 16,
                        right: 16,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFB794F6), width: 3),
                                image: (widget.userAvatar != null && widget.userAvatar!.isNotEmpty)
                                    ? DecorationImage(
                                        image: NetworkImage(widget.userAvatar!),
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                      )
                                    : null,
                              ),
                              child: (widget.userAvatar == null || widget.userAvatar!.isEmpty)
                                  ? const Icon(Icons.person, color: Colors.grey, size: 40)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _userData?['fullName'] ?? widget.userName,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.check_circle, color: Color(0xFFB794F6), size: 18),
                                    ],
                                  ),
                                  Text(
                                    '@${(_userData?['fullName'] ?? widget.userName).toLowerCase().replaceAll(' ', '')}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_isMe)
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        otherUid: widget.userUid,
                                        otherName: widget.userName,
                                        otherAvatar: widget.userAvatar,
                                        isRequest: _chatStatus?['status'] == 'pending' && _chatStatus?['receiverUid'] == FirebaseAuth.instance.currentUser?.uid,
                                      ),
                                    ),
                                  ).then((_) => _fetchChatStatus()); // Refresh status on return
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Icon(
                                    _chatStatus?['status'] == 'pending' 
                                      ? (_chatStatus?['senderUid'] == FirebaseAuth.instance.currentUser?.uid ? Icons.hourglass_empty : Icons.mark_chat_unread_outlined) 
                                      : Icons.chat_bubble_outline, 
                                    color: _chatStatus?['status'] == 'pending' ? const Color(0xFFB794F6) : Colors.white, 
                                    size: 24,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    color: const Color(0xFF1B1B1B),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFFB794F6),
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                      tabs: [
                        const Tab(text: 'Profile'),
                        const Tab(text: 'Moments'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildProfileTab(),
            _buildMomentsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFB497FF)));
    }

    if (_userData == null) {
      return Center(
        child: Text(
          'Error loading profile',
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    // Parse Preferences and Availability
    List<dynamic> prefs = _parseJsonField(_userData!['preferences']);
    List<dynamic> availability = _parseJsonField(_userData!['availability']);

    return Builder(
      builder: (context) {
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildProfileCard(
                    'About me',
                    _userData!['bio'] ?? 'No bio yet.',
                  ),
                  const SizedBox(height: 16),
                  _buildProfileCard(
                    'Location',
                    (_userData!['location_privacy'] == 'distance' && !_isMe)
                        ? (_userData!['distance_km'] != null ? '${_userData!['distance_km']} km away' : 'Distance Hidden')
                        : (_userData!['location_label'] ?? 'Not Shared'),
                  ),
                  const SizedBox(height: 16),
                  _buildProfileCard(
                    'Fitness & Body Info:',
                    '',
                    customContent: _buildFitnessInfoContent(),
                  ),
                  const SizedBox(height: 16),
                  _buildProfileCard(
                    'Preferences',
                    '',
                    customContent: _buildTagWrap(prefs, 'No preferences set'),
                  ),
                  const SizedBox(height: 16),
                  _buildProfileCard(
                    'Schedule / Availability',
                    '',
                    customContent: _buildAvailabilityTags(availability, _userData!['availability_time_spans']),
                  ),
                  const SizedBox(height: 16),
                  _buildProfileCard(
                    'Looking For',
                    _userData!['looking_for'] ?? 'Not Selected',
                  ),
                  const SizedBox(height: 16),
                  _buildProfileCard(
                    'Training Level',
                    _userData!['training_level'] ?? 'Not Selected',
                  ),
                  const SizedBox(height: 16),
                  _buildProfileCard(
                    'Day Per Week',
                    _userData!['workout_frequency']?.toString() ?? 'Not Selected',
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        );
      }
    );
  }

  List<dynamic> _parseJsonField(dynamic field) {
    if (field == null) return [];
    if (field is String) {
      try {
        return jsonDecode(field);
      } catch (e) {
        return [];
      }
    }
    if (field is List) return field;
    return [];
  }

  Widget _buildProfileCard(String title, String content, {
    double contentFontSize = 14,
    Widget? customContent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2E2E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: const Color(0xFFB497FF),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (customContent != null)
            customContent
          else
            Text(
              content,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: contentFontSize,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFitnessInfoContent() {
    final experience = _userData!['experience'] != null ? '${_userData!['experience']} ${_userData!['experience'] == 1 ? 'Year' : 'Years'}' : 'Not Selected';
    final height = _userData!['height'] != null 
        ? '${double.tryParse(_userData!['height'].toString())?.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') ?? _userData!['height']}cm' 
        : '--cm';
    final weight = _userData!['weight'] != null 
        ? '${double.tryParse(_userData!['weight'].toString())?.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') ?? _userData!['weight']}kg' 
        : '--kg';
    final gender = _userData!['gender'] ?? 'Not Selected';
    final age = _userData!['age']?.toString() ?? 'Not Selected';

    return Column(
      children: [
        _buildInfoRow(Icons.person_outline, 'Gender', gender),
        _buildInfoRow(Icons.cake_outlined, 'Age', age),
        _buildInfoRow(Icons.history, 'Experience', experience),
        _buildInfoRow(Icons.height, 'Height', height),
        _buildInfoRow(Icons.monitor_weight_outlined, 'Weight', weight),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityTags(List<dynamic> items, dynamic timeSpansField) {
    if (items.isEmpty) {
      return Text('No schedule set', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13));
    }

    Map<String, String> timeSpans = {};
    if (timeSpansField != null) {
      if (timeSpansField is String) {
        try {
          final decoded = jsonDecode(timeSpansField);
          if (decoded is Map) timeSpans = Map<String, String>.from(decoded);
        } catch (_) {}
      } else if (timeSpansField is Map) {
        timeSpans = Map<String, String>.from(timeSpansField);
      }
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map<Widget>((item) {
        final span = timeSpans[item.toString()];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF353535),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForOption(item.toString()), color: Colors.white70, size: 14),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.toString(),
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (span != null)
                    Text(
                      span,
                      style: GoogleFonts.poppins(color: const Color(0xFFB497FF), fontSize: 10),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
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

  Widget _buildTagWrap(List<dynamic> items, String emptyMessage) {
    if (items.isEmpty) {
      return Text(emptyMessage, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13));
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map<Widget>((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF353535),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          item.toString(),
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
        ),
      )).toList(),
    );
  }

  Widget _buildMomentsTab() {
    return _buildPostsListTab(_isLoadingPosts, _userPosts, 'No posts yet', Icons.post_add);
  }



  Widget _buildPostsListTab(bool isLoading, List<PostModel> posts, String emptyMessage, IconData emptyIcon) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFB794F6)));
    }

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, color: Colors.grey, size: 64),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Builder(
      builder: (context) {
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  posts.map((post) => PostWidget(
                    post: post,
                    onLike: () => _handleLike(post),
                    onSave: () => _handleSave(post),
                  )).toList(),
                ),
              ),
            ),
          ],
        );
      }
    );
  }

  Future<void> _handleLike(PostModel post) async {
    final newState = await _postService.toggleLike(post.id);
    if (mounted) {
      setState(() {
        post.isLiked = newState;
        post.likesCount += newState ? 1 : -1;
      });
    }
  }

  Future<void> _handleSave(PostModel post) async {
    // PostWidget now handles the save internally.
    if (mounted) setState(() {});
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF1B1B1B),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

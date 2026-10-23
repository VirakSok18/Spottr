import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../services/post_service.dart';
import '../../widgets/post_widget.dart';
import '../../widgets/collection_widgets.dart';
import '../auth/auth_screens.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_screen.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../home/profile_settings_screen.dart';
import 'swipe_discovery_view.dart';
import '../../widgets/app_theme_widgets.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final PostService _postService = PostService();
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _currentUser;
  bool _isLoadingUser = true;
  bool _isLoadingPosts = true;
  bool _isUploading = false;
  
  List<PostModel> _posts = [];
  StreamSubscription? _profileSubscription;
  Key _swipeKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();

    // Listen for global profile updates (e.g., location changes)
    _profileSubscription = AuthService.profileUpdates.listen((_) {
      print('CommunityScreen: Received profile update broadcast');
      _loadData();
    });

    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  bool _isProfileComplete() {
    if (_currentUser == null) return false;
    
    final bio = _currentUser!['bio']?.toString() ?? '';
    final lookingFor = _currentUser!['looking_for']?.toString() ?? '';
    final locationLabel = _currentUser!['location_label']?.toString() ?? 'Not Set';
    final age = _currentUser!['age'];
    
    // Basic completion check: Bio, Looking For, and Location must be set
    return bio.isNotEmpty && lookingFor.isNotEmpty && locationLabel != 'Not Set' && age != null;
  }

  Future<void> _loadData() async {
    await Future.wait([
      _fetchUser(),
      _fetchPosts(),
    ]);
  }

  Future<void> _fetchUser() async {
    final profile = await _authService.getUserProfile();
    if (mounted) {
      setState(() {
        _currentUser = profile;
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _fetchPosts() async {
    if (mounted) setState(() => _isLoadingPosts = true);
    final postsData = await _postService.getFeed();
    if (mounted) {
      setState(() {
        _posts = postsData.map((json) => PostModel.fromJson(json)).toList();
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

  Future<void> _showCreatePostModal() async {
    await _fetchUser();
    final TextEditingController postController = TextEditingController();
    List<Map<String, dynamic>> selectedMediaList = []; // Array of {file: File, type: String}
    
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2E2E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 4, // Minimized padding to anchor elements to bottom
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ensure it only takes needed space
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: (_currentUser?['profilePictureUrl'] != null && _currentUser!['profilePictureUrl'].toString().isNotEmpty)
                      ? NetworkImage(_currentUser!['profilePictureUrl']) 
                      : null,
                    child: (_currentUser?['profilePictureUrl'] == null || _currentUser!['profilePictureUrl'].toString().isEmpty)
                      ? const Icon(Icons.person, color: Colors.grey) 
                      : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser?['fullName'] ?? 'User',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '@${(_currentUser?['fullName'] ?? 'user').toString().toLowerCase().replaceAll(' ', '')}',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: postController,
                autofocus: true,
                maxLines: 5,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'What\'s on your mind?',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
              if (selectedMediaList.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedMediaList.length,
                    itemBuilder: (context, index) {
                      final item = selectedMediaList[index];
                      final file = item['file'] as File;
                      final type = item['type'] as String;

                      return Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: type == 'image'
                                  ? Image.file(file, fit: BoxFit.cover, width: 120, height: 120)
                                  : Container(
                                      color: Colors.black,
                                      child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40)),
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setModalState(() => selectedMediaList.removeAt(index)),
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 64), // Pushes the line even lower
              const Divider(color: Colors.white12, thickness: 1),
              const SizedBox(height: 4), // Minimized gap to the row
              Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      final List<XFile>? images = await _picker.pickMultiImage();
                      if (images != null && images.isNotEmpty) {
                        setModalState(() {
                          for (var img in images) {
                            selectedMediaList.add({'file': File(img.path), 'type': 'image'});
                          }
                        });
                      }
                    },
                    icon: const Icon(Icons.image_outlined, color: Color(0xFFB794F6)),
                  ),
                  IconButton(
                    onPressed: () async {
                      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
                      if (video != null) {
                        // Check video duration
                        final controller = VideoPlayerController.file(File(video.path));
                        try {
                          await controller.initialize();
                          final duration = controller.value.duration;
                          await controller.dispose();

                          if (duration.inSeconds > 60) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Video is too long! Max length is 60 seconds.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                            return;
                          }
                        } catch (e) {
                          print('Error initializing video: $e');
                          await controller.dispose();
                        }

                        setModalState(() {
                          selectedMediaList.add({'file': File(video.path), 'type': 'video'});
                        });
                      }
                    },
                    icon: const Icon(Icons.videocam_outlined, color: Color(0xFFB794F6)),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      if (postController.text.isEmpty && selectedMediaList.isEmpty) return;
                      
                      Navigator.pop(context);
                      setState(() => _isUploading = true);

                      List<Map<String, dynamic>> uploadedMedia = [];

                      for (var mediaItem in selectedMediaList) {
                        final File file = mediaItem['file'];
                        print('CommunityScreen: Uploading media: ${file.path}');
                        final uploadResult = await _postService.uploadPostMedia(file.path);
                        if (uploadResult != null) {
                          uploadedMedia.add({
                            'url': uploadResult['url'],
                            'type': uploadResult['type'],
                          });
                          print('CommunityScreen: Upload success: ${uploadResult['url']}');
                        } else {
                          print('CommunityScreen: Media upload failed for ${file.path}');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to upload some media. Please check your connection.')),
                            );
                          }
                        }
                      }

                      final postData = await _postService.createPost(postController.text, media: uploadedMedia);
                      if (postData != null && mounted) {
                        setState(() {
                          _posts.insert(
                              0,
                              PostModel.fromJson({
                                ...postData,
                                'userName': _currentUser?['fullName'],
                                'userAvatar': _currentUser?['profilePictureUrl'],
                                'likesCount': 0,
                                'commentsCount': 0,
                                'isLiked': 0,
                                'isSaved': 0,
                                'media': uploadedMedia,
                              }));
                          _isUploading = false;
                        });
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to create post.')),
                          );
                        }
                        setState(() => _isUploading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB794F6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 2), // Absolute minimum bottom margin
            ],
          ),
        ),
      ),
    );
  }

  void _createNewPost(String content) async {
    final postData = await _postService.createPost(content);
    if (postData != null && mounted) {
      setState(() {
        _posts.insert(0, PostModel.fromJson({
          ...postData,
          'userName': _currentUser?['fullName'],
          'userAvatar': _currentUser?['profilePictureUrl'],
          'likesCount': 0,
          'commentsCount': 0,
          'isLiked': 0,
          'isSaved': 0,
        }));
      });
    }
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
    // PostWidget now handles the save and collection sheet internally.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B1B),
        elevation: 0,
        centerTitle: true,
        leading: const SizedBox(width: 56), // Placeholder to balance action button
        title: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFB794F6),
          indicatorWeight: 3,
          isScrollable: false,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(text: 'Community'),
            Tab(text: 'Swipe'),
          ],
        ),
        actions: [
          SizedBox(
            width: 56,
            child: Opacity(
              opacity: _tabController.index == 1 ? 1.0 : 0.0,
              child: IconButton(
                iconSize: 20,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _tabController.index == 1 
                  ? () => setState(() => _swipeKey = UniqueKey()) 
                  : null,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildCommunityFeed(),
              _buildSwipePage(),
            ],
          ),
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const PremiumLoading(color: Colors.white, size: 40),
                    const SizedBox(height: 16),
                    Text(
                      'Uploading...',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommunityFeed() {
    if (_isLoadingPosts && _posts.isEmpty) {
      return const Center(child: PremiumLoading(size: 60));
    }
    
    return RefreshIndicator(
      onRefresh: _fetchPosts,
      color: const Color(0xFFB794F6),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _posts.length + 1, // +1 for the input bar
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                const SizedBox(height: 16),
                _buildPostInput(),
                const SizedBox(height: 24),
              ],
            );
          }
          final post = _posts[index - 1];
          return PostWidget(
            post: post,
            onLike: () => _handleLike(post),
            onSave: () => _handleSave(post),
          );
        },
      ),
    );
  }

  Widget _buildPostInput() {
    return GestureDetector(
      onTap: _showCreatePostModal,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2E2E2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (_currentUser != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SocialUserProfileScreen(
                        userUid: FirebaseAuth.instance.currentUser!.uid,
                        userName: _currentUser?['fullName'] ?? 'User',
                        userAvatar: _currentUser?['profilePictureUrl'],
                        userCover: _currentUser?['coverPhotoUrl'],
                      ),
                    ),
                  );
                }
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[800],
                backgroundImage: (_currentUser?['profilePictureUrl'] != null && _currentUser!['profilePictureUrl'].toString().isNotEmpty)
                  ? NetworkImage(_currentUser!['profilePictureUrl']) 
                  : null,
                child: (_currentUser?['profilePictureUrl'] == null || _currentUser!['profilePictureUrl'].toString().isEmpty)
                  ? const Icon(Icons.person, color: Colors.grey) 
                  : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'what\'s on your mind?',
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
              ),
            ),
            const Icon(Icons.image_outlined, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipePage() {
    if (_isLoadingUser) {
      return const Center(child: PremiumLoading(size: 60));
    }

    if (!_isProfileComplete()) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFB794F6).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_pin_circle_outlined, color: Color(0xFFB794F6), size: 64),
            ),
            const SizedBox(height: 32),
            Text(
              'Finish Setting Up!',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Complete your profile (Bio, Location, and Fitness Info) to start matching with workout buddies.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileSettingsScreen(
                      userData: _currentUser ?? {},
                      onUpdate: _loadData,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB794F6),
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                'Complete Profile',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SwipeDiscoveryView(key: _swipeKey);
  }
}


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/post_service.dart';
import '../screens/social/user_profile_screen.dart';
import '../screens/social/video_player_screen.dart';
import '../screens/social/share_post_sheet.dart';
import '../../services/chat_service.dart';
import '../screens/social/inline_video_player.dart';
import '../widgets/collection_widgets.dart';
import '../screens/social/post_detail_screen.dart';
import '../screens/social/post_detail_screen.dart';

class PostModel {
  final int id;
  final String userUid;
  final String userName;
  final String userHandle;
  final String? userAvatar;
  final String? userCover;
  final DateTime createdAt;
  String content;
  final List<Map<String, dynamic>> media;
  int likesCount;
  int commentsCount;
  bool isLiked;
  bool isSaved;

  PostModel({
    required this.id,
    required this.userUid,
    required this.userName,
    required this.userHandle,
    this.userAvatar,
    this.userCover,
    required this.createdAt,
    required this.content,
    required this.media,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.isSaved = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['createdAt'] != null) {
      try {
        parsedDate = DateTime.parse(json['createdAt'].toString());
      } catch (_) {}
    }

    return PostModel(
      id: json['id'],
      userUid: json['userUid'] ?? '',
      userName: json['userName'] ?? 'User',
      userHandle: '@${(json['userName'] ?? 'user').toString().toLowerCase().replaceAll(' ', '')}',
      userAvatar: json['userAvatar'],
      userCover: json['userCover'],
      createdAt: parsedDate ?? DateTime.now(),
      content: json['content'] ?? '',
      media: json['media'] != null ? List<Map<String, dynamic>>.from(json['media']) : [],
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      isLiked: json['isLiked'] == 1 || json['isLiked'] == true || json['isLiked'] == "1",
      isSaved: json['isSaved'] == 1 || json['isSaved'] == true || json['isSaved'] == "1",
    );
  }

  String get timeFormatted {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    return DateFormat('MMM d').format(createdAt);
  }

  Map<String, dynamic> toExecutionMap() {
    return {
      'id': id,
      'name': content.isNotEmpty ? content.split('\n')[0] : 'Workout',
      'videoUrl': media.isNotEmpty ? media.first['url'] : '',
      'thumbnailUrl': media.isNotEmpty ? media.first['url'].toString().replaceAll(RegExp(r'\.(mp4|mov|avi|MP4|MOV|AVI)$'), '.jpg') : '',
      'description': content,
      'difficulty': 'Intermediate', // Default for social posts
    };
  }
}

class PostWidget extends StatelessWidget {
  final PostModel post;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final bool isDetailView;
  final PostService _postService = PostService();

  PostWidget({
    Key? key,
    required this.post,
    this.onLike = _noop,
    this.onSave = _noop,
    this.isDetailView = false,
  }) : super(key: key);

  static void _noop() {}

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _CommentsBottomSheet(postId: post.id, postService: _postService),
    );
  }

  Future<void> _handleLike(BuildContext context) async {
    // Optimistic update
    final wasLiked = post.isLiked;
    post.isLiked = !post.isLiked;
    post.likesCount += post.isLiked ? 1 : -1;
    (context as Element).markNeedsBuild(); // Refresh UI immediately (hacky but works for StatelessWidget here without full state conversion, typically would use ValueNotifier or StatefulWidget)
    
    // OR cleaner: We should really make PostWidget a StatefulWidget or make interaction stateless.
    // For now, since user wants "exactly same", and PostWidget is Stateless, expecting parent to rebuild.
    // But PostDetailScreen doesn't rebuild on callback unless we tell it.
    // Let's rely on onLike callback for PostDetailScreen too.
    if (onLike != _noop) {
      onLike();
      return;
    }

    // Default behavior if no interaction callback provided (e.g. self-managed detail view)
    // Actually PostDetailScreen should pass callbacks that setState.
    // Let's revert to relying on required callbacks or smart callbacks.
    final result = await _postService.toggleLike(post.id);
    if (result != post.isLiked) {
       // Revert if failed
       post.isLiked = result;
       post.likesCount += post.isLiked ? 1 : -1;
       (context as Element).markNeedsBuild();
    }
  }

  Future<void> _handleSave(BuildContext context) async {
    if (post.isSaved) {
      // Already saved, show collection management sheet
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => CollectionSelectionSheet(
          postId: post.id,
          postCover: post.media.isNotEmpty ? post.media.first['url'] : null,
        ),
      );

      if (result == 'unsave_globally') {
        // Toggle off globally
        post.isSaved = false;
        (context as Element).markNeedsBuild();
        final success_result = await _postService.toggleSave(post.id);
        if (success_result != post.isSaved) {
          post.isSaved = success_result;
          (context as Element).markNeedsBuild();
        }
        if (onSave != _noop) onSave();
      }
    } else {
      // Not saved, save it and show sheet
      post.isSaved = true;
      (context as Element).markNeedsBuild();
      
      final result = await _postService.toggleSave(post.id);
      if (result != post.isSaved) {
        post.isSaved = result;
        (context as Element).markNeedsBuild();
      } else {
        // Only show sheet if save was successful
        if (onSave != _noop) onSave();
        
        if (context.mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => CollectionSelectionSheet(
              postId: post.id,
              postCover: post.media.isNotEmpty ? post.media.first['url'] : null,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SocialUserProfileScreen(
                        userUid: post.userUid,
                        userName: post.userName,
                        userAvatar: post.userAvatar,
                        userCover: post.userCover,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[800],
                        image: (post.userAvatar != null && post.userAvatar!.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(post.userAvatar!),
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                              )
                            : null,
                      ),
                      child: (post.userAvatar == null || post.userAvatar!.isEmpty)
                          ? const Icon(Icons.person, color: Colors.grey, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              post.userName,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '• ${post.timeFormatted}',
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          post.userHandle,
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _buildAuthorMenu(context),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: isDetailView ? null : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailScreen(postId: post.id),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  post.content,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (post.media.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 250,
                    child: PageView.builder(
                      itemCount: post.media.length,
                      itemBuilder: (context, index) {
                        final item = post.media[index];
                        final mediaUrl = item['url'];
                        final mediaType = item['type'];

                        return Padding(
                          padding: EdgeInsets.only(right: post.media.length > 1 ? 8.0 : 0.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: mediaType == 'video'
                                ? InlineVideoPostPlayer(
                                    videoUrl: mediaUrl,
                                    thumbnailUrl: mediaUrl.toString().replaceAll(RegExp(r'\.(mp4|mov|avi|MP4|MOV|AVI)$'), '.jpg'),
                                    showPageIndicator: post.media.length > 1,
                                    pageProgress: '${index + 1}/${post.media.length}',
                                  )
                                : GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => VideoPlayerScreen(
                                            mediaUrl: mediaUrl,
                                            mediaType: 'image',
                                          ),
                                        ),
                                      );
                                    },
                                    child: Stack(
                                      children: [
                                        Image.network(
                                          mediaUrl,
                                          height: 250,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              height: 250,
                                              width: double.infinity,
                                              color: const Color(0xFF1F1F1F),
                                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                            );
                                          },
                                        ),
                                        if (post.media.length > 1)
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${index + 1}/${post.media.length}',
                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isDetailView ? () => _handleLike(context) : onLike,
                child: Row(
                  children: [
                    Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: post.isLiked ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(_formatCount(post.likesCount), style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showComments(context),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 20),
                    const SizedBox(width: 6),
                    Text(_formatCount(post.commentsCount), style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => SharePostSheet(post: post),
                  );
                },
                icon: const Icon(Icons.send_rounded, color: Colors.grey, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _handleSave(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Icon(
                    post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: post.isSaved ? const Color(0xFFB794F6) : Colors.grey,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white10),
        ],
      ),
    );
  }

  Widget _buildAuthorMenu(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAuthor = currentUser?.uid == post.userUid;

    if (!isAuthor) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.more_horiz, color: Colors.grey),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => _PostOptionsSheet(
            onEdit: () {
              Navigator.pop(context);
              _showEditBottomSheet(context);
            },
            onDelete: () {
              Navigator.pop(context);
              _showDeleteBottomSheet(context);
            },
          ),
        );
      },
    );
  }

  void _showEditBottomSheet(BuildContext outerContext) {
    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PostEditSheet(post: post, postService: _postService, onUpdate: () {
        (outerContext as Element).markNeedsBuild();
      }),
    );
  }

  void _showDeleteBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PostDeleteSheet(post: post, postService: _postService),
    );
  }
}

class _PostOptionsSheet extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PostOptionsSheet({
    Key? key,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B1B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: Colors.white),
            title: Text(
              'Edit Post',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            onTap: onEdit,
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: Text(
              'Delete Post',
              style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w500),
            ),
            onTap: onDelete,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PostEditSheet extends StatefulWidget {
  final dynamic post;
  final PostService postService;
  final VoidCallback onUpdate;
  const _PostEditSheet({Key? key, required this.post, required this.postService, required this.onUpdate}) : super(key: key);

  @override
  State<_PostEditSheet> createState() => _PostEditSheetState();
}

class _PostEditSheetState extends State<_PostEditSheet> {
  late TextEditingController _controller;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.post.content);
  }

  @override  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B1B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 12, left: 20, right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: (widget.post.userAvatar != null && widget.post.userAvatar!.isNotEmpty) ? NetworkImage(widget.post.userAvatar!) : null,
                      child: (widget.post.userAvatar == null || widget.post.userAvatar!.isEmpty) ? const Icon(Icons.person, color: Colors.grey) : null,
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SocialUserProfileScreen(
                              userUid: widget.post.userUid,
                              userName: widget.post.userName,
                              userAvatar: widget.post.userAvatar,
                              userCover: widget.post.userCover,
                            ),
                          ),
                        );
                      },
                      child: Text(widget.post.userName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 5,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'What\'s on your mind?',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
                const Divider(color: Colors.white12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: _isUpdating ? null : () async {
                        if (_controller.text.trim().isNotEmpty) {
                          setState(() => _isUpdating = true);
                          final updated = await widget.postService.updatePost(widget.post.id, _controller.text);
                          if (updated != null) {
                            widget.post.content = _controller.text;
                            widget.onUpdate();
                            if (mounted) Navigator.pop(context);
                          } else {
                            if (mounted) {
                              setState(() => _isUpdating = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to update post')),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB794F6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isUpdating 
                        ? const SizedBox(
                            height: 20, 
                            width: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isUpdating)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFB794F6)),
                    const SizedBox(height: 16),
                    Text(
                      'Updating post...',
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

}

class _PostDeleteSheet extends StatefulWidget {
  final dynamic post;
  final PostService postService;
  const _PostDeleteSheet({Key? key, required this.post, required this.postService}) : super(key: key);

  @override
  State<_PostDeleteSheet> createState() => _PostDeleteSheetState();
}

class _PostDeleteSheetState extends State<_PostDeleteSheet> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B1B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4, width: 40,
                  decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 24),
                Text('Delete Post?', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('This action cannot be undone. Are you sure you want to delete this post?', 
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isDeleting ? null : () => Navigator.pop(context),
                        child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isDeleting ? null : () async {
                          setState(() => _isDeleting = true);
                          final deleted = await widget.postService.deletePost(widget.post.id);
                          if (deleted) {
                            if (mounted) Navigator.pop(context);
                          } else {
                            if (mounted) {
                              setState(() => _isDeleting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to delete post')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isDeleting 
                          ? const SizedBox(
                              height: 20, 
                              width: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isDeleting)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Deleting post...',
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
}

class _CommentsBottomSheet extends StatefulWidget {
  final int postId;
  final PostService postService;

  const _CommentsBottomSheet({Key? key, required this.postId, required this.postService}) : super(key: key);

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<dynamic> _comments = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String _processingText = '';
  int? _replyToCommentId;
  String? _replyToUserName;
  
  // Track which comments have their replies expanded
  final Map<int, bool> _expandedReplies = {};

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    final data = await widget.postService.getComments(widget.postId);
    if (mounted) {
      setState(() {
        _comments = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _processingText = 'Posting comment...';
    });

    final newComment = await widget.postService.addComment(
      widget.postId, 
      _commentController.text,
      parentCommentId: _replyToCommentId,
    );
    
    if (newComment != null && mounted) {
      setState(() {
        _comments.add({
          ...newComment,
          'userName': newComment['userName'] ?? 'User',
          'userAvatar': newComment['userAvatar'] ?? '',
        });
        _commentController.clear();
        _isProcessing = false;
        _replyToCommentId = null;
        _replyToUserName = null;
      });
    } else {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment')),
        );
      }
    }
  }

  void _showCommentOptions(Map<String, dynamic> comment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2E2E2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.white),
            title: Text('Edit Comment', style: GoogleFonts.poppins(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _showEditCommentDialog(comment);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.redAccent),
            title: Text('Delete Comment', style: GoogleFonts.poppins(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteCommentConfirm(comment);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showEditCommentDialog(Map<String, dynamic> comment) {
    print('Opening Edit Dialog for comment: ${comment['id']}'); // Add this log
    final controller = TextEditingController(text: comment['content']);
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside while loading
      builder: (dialogContext) => StatefulBuilder( // Use StatefulBuilder for local state
        builder: (context, setDialogState) { // Rename setState to setDialogState
          bool isDialogLoading = false; 

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1F24),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Edit Comment', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            autofocus: true,
                            enabled: !isDialogLoading,
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Edit your comment...',
                              hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: isDialogLoading ? null : () async {
                            if (controller.text.trim().isEmpty) return;
                            
                            // 1. Set loading state inside dialog
                            setDialogState(() {
                              isDialogLoading = true;
                            });

                            // 2. Perform API call
                            final success = await widget.postService.updateComment(comment['id'], controller.text);
                            
                            // 3. Handle result
                            if (success) {
                              if (mounted) {
                                // Update parent state (the bottom sheet)
                                setState(() {
                                  final idx = _comments.indexWhere((c) => c['id'] == comment['id']);
                                  if (idx != -1) _comments[idx]['content'] = controller.text;
                                });
                                // Close dialog
                                Navigator.pop(dialogContext);
                              }
                            } else {
                              if (mounted) {
                                // Stop loading inside dialog if failed
                                setDialogState(() {
                                  isDialogLoading = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update comment')));
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFB794F6),
                              shape: BoxShape.circle,
                            ),
                            child: isDialogLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isDialogLoading ? null : () => Navigator.pop(dialogContext),
                    child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteCommentConfirm(Map<String, dynamic> comment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isDialogLoading = false;

          return Dialog(
            backgroundColor: const Color(0xFF1D1F24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 32),
                  ),
                  const SizedBox(height: 20),
                  Text('Delete Comment?', 
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('This will permanently remove this comment and all its replies. This action cannot be undone.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: isDialogLoading ? null : () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isDialogLoading ? null : () async {
                            setDialogState(() {
                              isDialogLoading = true;
                            });

                            final success = await widget.postService.deleteComment(comment['id']);
                            
                            if (success) {
                              if (mounted) {
                                // Update parent state
                                setState(() {
                                  List<int> idsToRemove = [comment['id']];
                                  int initialCount;
                                  do {
                                    initialCount = idsToRemove.length;
                                    for (var c in _comments) {
                                      if (c['parentCommentId'] != null && 
                                          idsToRemove.contains(c['parentCommentId']) && 
                                          !idsToRemove.contains(c['id'])) {
                                        idsToRemove.add(c['id']);
                                      }
                                    }
                                  } while (idsToRemove.length > initialCount);

                                  _comments.removeWhere((c) => idsToRemove.contains(c['id']));
                                });
                                // Close dialog
                                Navigator.pop(dialogContext);
                              }
                            } else {
                              if (mounted) {
                                setDialogState(() {
                                  isDialogLoading = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete branch')));
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: isDialogLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rootComments = _comments.where((c) => c['parentCommentId'] == null).toList();
    
    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4, width: 40,
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
              ),
              Text('Comments', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white12),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFB794F6)))
                    : rootComments.isEmpty
                        ? Center(child: Text('No comments yet', style: GoogleFonts.poppins(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: rootComments.length,
                            itemBuilder: (context, index) {
                              return _buildRecursiveComment(rootComments[index]);
                            },
                          ),
              ),
              if (_replyToUserName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.black26,
                  child: Row(
                    children: [
                      Text('Replying to $_replyToUserName', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() { _replyToCommentId = null; _replyToUserName = null; }),
                        child: const Icon(Icons.close, color: Colors.grey, size: 16),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1F24),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _focusNode,
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: _replyToUserName != null ? 'Reply to $_replyToUserName...' : 'Add a comment...',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _postComment,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFB794F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFB794F6)),
                  const SizedBox(height: 16),
                  Text(_processingText, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecursiveComment(Map<String, dynamic> comment, {int depth = 0}) {
    final replies = _comments.where((c) => c['parentCommentId'] == comment['id']).toList();
    final bool isExpanded = _expandedReplies[comment['id']] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentItem(comment, depth: depth),
        if (replies.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: 48.0 + (depth * 2)),
            child: GestureDetector(
              onTap: () => setState(() => _expandedReplies[comment['id']] = !isExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(height: 1, width: 20, color: Colors.white24),
                    const SizedBox(width: 8),
                    Text(
                      isExpanded ? 'Hide replies' : 'Show ${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                      style: GoogleFonts.poppins(color: const Color(0xFFB794F6), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (isExpanded)
          ...replies.map((reply) => _buildRecursiveComment(reply, depth: depth + 1)),
      ],
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment, {int depth = 0}) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAuthor = currentUser?.uid == comment['userUid'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visual Nesting Lines
            for (int i = 0; i < depth; i++)
              Container(
                width: 2,
                margin: const EdgeInsets.only(right: 18, left: 10),
                color: Colors.white.withOpacity(0.1),
              ),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => SocialUserProfileScreen(
                  userUid: comment['userUid'],
                  userName: comment['userName'] ?? 'User',
                  userAvatar: comment['userAvatar'],
                  userCover: comment['userCover'],
                ),
              )),
              child: CircleAvatar(
                radius: depth > 0 ? 12 : 16,
                backgroundColor: Colors.grey[800],
                backgroundImage: (comment['userAvatar'] != null && comment['userAvatar'].toString().isNotEmpty)
                    ? NetworkImage(comment['userAvatar'])
                    : null,
                child: (comment['userAvatar'] == null || comment['userAvatar'].toString().isEmpty)
                    ? Icon(Icons.person, size: depth > 0 ? 12 : 16, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(isAuthor ? 15 : 10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(isAuthor ? 20 : 10)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (context) => SocialUserProfileScreen(
                              userUid: comment['userUid'],
                              userName: comment['userName'] ?? 'User',
                              userAvatar: comment['userAvatar'],
                              userCover: comment['userCover'],
                            ),
                          )),
                          child: Text(comment['userName'] ?? 'User',
                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const Spacer(),
                        if (isAuthor)
                          GestureDetector(
                            onTap: () => _showCommentOptions(comment),
                            child: const Icon(Icons.more_horiz, color: Colors.grey, size: 16),
                          ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(comment['content'] ?? '',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, height: 1.3)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _replyToCommentId = comment['id'];
                            _replyToUserName = comment['userName'];
                            // Auto-expand parent to see the new reply later
                            _expandedReplies[comment['id']] = true;
                          });
                          _focusNode.requestFocus();
                        },
                        child: Text('Reply', style: GoogleFonts.poppins(color: const Color(0xFFB794F6), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatCommentDate(comment['createdAt']),
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  String _formatCommentDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.day}/${dt.month}';
    } catch (e) {
      return '';
    }
  }
}

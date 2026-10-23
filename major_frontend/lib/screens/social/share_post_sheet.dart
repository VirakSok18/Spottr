import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/chat_service.dart';
import '../../widgets/post_widget.dart' show PostModel;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SharePostSheet extends StatefulWidget {
  final PostModel post;

  const SharePostSheet({super.key, required this.post});

  @override
  State<SharePostSheet> createState() => _SharePostSheetState();
}

class _SharePostSheetState extends State<SharePostSheet> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _conversations = [];
  List<dynamic> _filteredConversations = [];
  bool _isLoading = true;
  final Set<String> _selectedUserUids = {};
  bool _isSending = false;
  bool _isCopied = false;
  Map<String, bool> _platformAvailability = {};

  @override
  void initState() {
    super.initState();
    _chatService.initSocket();
    _loadConversations();
    _checkAvailability();
    _searchController.addListener(_filterConversations);
  }

  Future<void> _checkAvailability() async {
    final Map<String, String> platforms = {
      'WhatsApp': 'whatsapp://send',
      'Facebook': 'fb://',
      'Instagram': 'instagram://app',
      'Messenger': 'fb-messenger://',
      'X / Twitter': 'twitter://',
    };

    for (var p in platforms.entries) {
      final available = await canLaunchUrl(Uri.parse(p.value));
      if (mounted) {
        setState(() => _platformAvailability[p.key] = available);
      }
    }
  }

  @override
  void dispose() {
    _chatService.disconnect();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final convs = await _chatService.getConversations();
    if (mounted) {
      setState(() {
        _conversations = convs;
        _filteredConversations = convs;
        _isLoading = false;
      });
    }
  }

  void _filterConversations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredConversations = _conversations.where((conv) {
        final name = (conv['fullName'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _sharePost() async {
    if (_selectedUserUids.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final postPreview = widget.post.content.isNotEmpty 
          ? widget.post.content 
          : (widget.post.media.isNotEmpty ? 'Shared a post' : '');
      
      final String mediaUrl = widget.post.media.isNotEmpty ? widget.post.media[0]['url'] : '';
      final String mediaType = widget.post.media.isNotEmpty ? widget.post.media[0]['type'] : 'image';

      for (var uid in _selectedUserUids) {
        _chatService.sendMessage(
          uid, 
          'Shared a post: ${widget.post.content}',
          mediaUrl: mediaUrl,
          mediaType: 'post', // Specialized type
          parentContent: postPreview,
          parentId: widget.post.id,
          parentMediaType: mediaType,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post shared successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share post.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _copyLink() {
    if (_isCopied) return;

    try {
      final String postLink = 'https://potatoesfries.app/post/${widget.post.id}';
      
      Clipboard.setData(ClipboardData(text: postLink)).then((_) {
        if (mounted) {
          setState(() => _isCopied = true);
          
          // Clear any existing snackbars first
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                   const Icon(Icons.check_circle, color: Colors.white, size: 20),
                   const SizedBox(width: 12),
                   Text(
                     'Post link copied!',
                     style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                   ),
                ],
              ),
              backgroundColor: const Color(0xFFB794F6),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          // Reset the "Copied" text after 2 seconds
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() => _isCopied = false);
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Clipboard error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to copy link: $e')),
        );
      }
    }
  }

  void _shareToExternal() {
    final String postText = widget.post.content;
    final String postLink = 'https://potatoesfries.app/post/${widget.post.id}';
    
    // For external sharing, include both content and the post link
    final String shareContent = postText.isNotEmpty 
        ? '$postText\n\nView post: $postLink' 
        : 'Check out this post on Potatoesfries: $postLink';

    Share.share(shareContent, subject: 'Post from Potatoesfries');
  }

  Future<void> _shareToSpecific(String platform) async {
    final String postText = widget.post.content;
    final String postLink = 'https://potatoesfries.app/post/${widget.post.id}';
    final shareText = postText.isNotEmpty ? '$postText\n\n$postLink' : postLink;
    
    try {
      Uri? uri;
      switch (platform) {
        case 'WhatsApp':
          uri = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(shareText)}");
          break;
        case 'Facebook':
        case 'Messenger':
          // Facebook/Messenger often prefer just the link for better preview
          uri = Uri.parse("fb-messenger://share?link=${Uri.encodeComponent(postLink)}");
          break;
        case 'Instagram':
          // Instagram is tricky, usually sharing the text/link to stories or feed requires specialized SDKs
          // but we can try the basic URL scheme
          uri = Uri.parse("instagram://sharesheet?text=${Uri.encodeComponent(shareText)}");
          break;
        case 'X / Twitter':
          uri = Uri.parse("twitter://post?message=${Uri.encodeComponent(shareText)}");
          break;
        default:
          _shareToExternal();
          return;
      }

      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to system share sheet if app not found or link failed
        _shareToExternal();
      }
    } catch (e) {
      debugPrint('Error sharing to $platform: $e');
      _shareToExternal();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // 1. Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Share',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. In-App Sharing (Search & Direct Messages)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Send to',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_selectedUserUids.isNotEmpty)
                  GestureDetector(
                    onTap: _isSending ? null : _sharePost,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB794F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _isSending 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              'Send (${_selectedUserUids.length})',
                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search people...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Color(0xFFB794F6)))
                : _filteredConversations.isEmpty
                    ? Center(
                        child: Text(
                          'No conversations found',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredConversations.length,
                        itemBuilder: (context, index) {
                          final conv = _filteredConversations[index];
                          final otherUid = conv['firebaseUid'];
                          final isSelected = _selectedUserUids.contains(otherUid);

                          return ListTile(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedUserUids.remove(otherUid);
                                } else {
                                  _selectedUserUids.add(otherUid);
                                }
                              });
                            },
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[800],
                                image: conv['profilePictureUrl'] != null
                                    ? DecorationImage(
                                        image: NetworkImage(conv['profilePictureUrl']),
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                      )
                                    : null,
                              ),
                              child: conv['profilePictureUrl'] == null
                                  ? const Icon(Icons.person, color: Colors.grey)
                                  : null,
                            ),
                            title: Text(
                              conv['fullName'] ?? 'User',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFB794F6) : Colors.white24,
                                  width: 2,
                                ),
                                color: isSelected ? const Color(0xFFB794F6) : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                          );
                        },
                      ),
          ),
          
          const Divider(color: Colors.white10, height: 1, thickness: 1),
          const SizedBox(height: 12),

          // 3. Social Row (Horizontal Shortcut Icons) - Dynamically Filtered
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (_platformAvailability['WhatsApp'] == true)
                  _buildSocialItem('WhatsApp', Icons.chat_bubble_outline, const Color(0xFF25D366), 'WhatsApp'),
                if (_platformAvailability['Facebook'] == true)
                  _buildSocialItem('Facebook', Icons.facebook, const Color(0xFF1877F2), 'Facebook'),
                if (_platformAvailability['Instagram'] == true)
                  _buildSocialItem('Instagram', Icons.camera_alt_outlined, const Color(0xFFE4405F), 'Instagram'),
                if (_platformAvailability['X / Twitter'] == true)
                  _buildSocialItem('X / Twitter', Icons.close, Colors.white, 'X / Twitter'),
                if (_platformAvailability['Messenger'] == true)
                  _buildSocialItem('Messenger', Icons.messenger_outline, const Color(0xFF0084FF), 'Messenger'),
                // Always show More button as fallback
                _buildSocialItem('More', Icons.more_horiz, Colors.grey, 'More'),
              ],
            ),
          ),
          
          const Divider(color: Colors.white10, height: 1, thickness: 1),

          // 4. Action List (Vertical Actions) - Moved to bottom
          Padding(
            padding: EdgeInsets.only(
              left: 8, 
              right: 8, 
              top: 8, 
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Column(
              children: [
                _buildActionItem(
                  _isCopied ? 'Copied!' : 'Copy link', 
                  _isCopied ? Icons.check : Icons.link, 
                  _copyLink,
                  iconColor: _isCopied ? const Color(0xFFB794F6) : Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(String label, IconData icon, VoidCallback onTap, {Color iconColor = Colors.white}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: Text(
          label,
          key: ValueKey(label),
          style: GoogleFonts.poppins(
            color: iconColor == Colors.white ? Colors.white : iconColor, 
            fontSize: 16,
            fontWeight: iconColor == Colors.white ? FontWeight.normal : FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialItem(String label, IconData icon, Color color, String platform) {
    return GestureDetector(
      onTap: () => platform == 'More' ? _shareToExternal() : _shareToSpecific(platform),
      child: Padding(
        padding: const EdgeInsets.only(right: 24),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

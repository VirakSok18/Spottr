import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:major_frontend/services/chat_service.dart';
import 'package:major_frontend/screens/social/chat_requests_screen.dart';
import 'package:major_frontend/screens/social/chat_screen.dart';
import 'package:major_frontend/screens/social/central_ai_coach_screen.dart';
import 'package:major_frontend/screens/social/user_profile_screen.dart';
import 'package:intl/intl.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ChatService _chatService = ChatService();
  List<dynamic> _conversations = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  int _requestCount = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Socket initialization is handled in main_navigation_wrapper.dart
    
    _fetchConversations();
    
    // Listen for incoming messages to update the list in real-time
    _chatService.messageStream.listen((message) {
      if (mounted) _fetchConversations();
    });

    // Listen for new requests to update indicator
    _chatService.requestStream.listen((_) {
      if (mounted) _fetchConversations();
    });
  }

  Future<void> _fetchConversations() async {
    final convos = await _chatService.getConversations();
    final requests = await _chatService.getRequests();
    if (mounted) {
      setState(() {
        _conversations = convos;
        _requestCount = requests.length;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // Socket disconnection is handled in main_navigation_wrapper.dart
    super.dispose();
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      
      if (now.difference(date).inDays == 0) {
        return DateFormat('h:mm a').format(date);
      } else if (now.difference(date).inDays < 7) {
        return DateFormat('E').format(date);
      } else {
        return DateFormat('MMM d').format(date);
      }
    } catch (e) {
      return '';
    }
  }

  String _getDisplayMessage(Map<String, dynamic> chat) {
    final lastMessage = chat['lastMessage'];
    final mediaType = chat['lastMediaType'];

    if (mediaType != null) {
      if (mediaType == 'image') return 'Sent a photo 📷';
      if (mediaType == 'video') return 'Sent a video 🎥';
      if (mediaType == 'post') return 'Shared a post 📎';
    }

    return lastMessage ?? 'New connection! Say hi 👋';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414), // Dark background matching design
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Message', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatRequestsScreen()))
                      .then((_) => _fetchConversations());
                },
                child: Text('Requests', style: GoogleFonts.poppins(color: const Color(0xFFB794F6), fontWeight: FontWeight.w600)),
              ),
              if (_requestCount > 0)
                Positioned(
                  right: 0,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9E77ED), 
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF141414), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      _requestCount.toString(),
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 10, 
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFB794F6)))
        : ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Search Bar (Visual only for now matching UI)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.poppins(color: Colors.white),
                  onChanged: (val) {
                    final query = val.trim().toLowerCase();
                    if (query.isEmpty) {
                      setState(() {
                         _isSearching = false;
                         _searchResults = [];
                      });
                      return;
                    }
                    setState(() {
                      _isSearching = true;
                      _searchResults = _conversations.where((chat) {
                        final name = (chat['fullName'] ?? '').toString().toLowerCase();
                        return name.contains(query);
                      }).toList();

                      // Include Gym Bot in results if it matches
                      if ('Gym Bot'.toLowerCase().contains(query)) {
                        _searchResults.insert(0, {
                          'fullName': 'Gym Bot',
                          'firebaseUid': 'bot',
                          'profilePictureUrl': '',
                          'isBot': true,
                        });
                      }
                    });
                  },
                  decoration: InputDecoration(
                    icon: const Icon(Icons.search, color: Colors.grey),
                    hintText: 'Search for people...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              if (_isSearching) ...[
                Text('Search Results', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                if (_searchResults.isEmpty)
                   Padding(padding: const EdgeInsets.all(8.0), child: Text('No results found', style: GoogleFonts.poppins(color: Colors.grey))),
                ..._searchResults.map((user) => _buildChatTile(
                  avatarUrl: user['profilePictureUrl'],
                  name: user['fullName'] ?? 'User',
                  message: user['isBot'] == true ? 'AI Coach' : 'View conversation',
                  time: '',
                  isBot: user['isBot'] == true,
                  onTap: () {
                     if (user['isBot'] == true) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CentralAICoachScreen()))
                          .then((_) {
                            _searchController.clear();
                            setState(() {
                              _isSearching = false;
                              _fetchConversations();
                            });
                          });
                        return;
                     }
                     Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          otherUid: user['firebaseUid'],
                          otherName: user['fullName'],
                          otherAvatar: user['profilePictureUrl'],
                          otherCover: user['coverPhotoUrl'],
                        )
                      )).then((_) {
                        _searchController.clear();
                        setState(() {
                          _isSearching = false;
                          _fetchConversations();
                        });
                      });
                  },
                  onAvatarTap: () {
                    if (user['isBot'] != true) { // Only navigate to profile for non-bots
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SocialUserProfileScreen(
                          userUid: user['firebaseUid'],
                          userName: user['fullName'],
                          userAvatar: user['profilePictureUrl'],
                          userCover: user['coverPhotoUrl'],
                        )
                      ));
                    }
                  },
                )).toList(),
                const SizedBox(height: 24),
              ] else ...[
                Text('AI Chat', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                
                // AI Chat Placeholder
                _buildChatTile(
                  name: 'Gym Bot',
                  message: 'Feel Free to ask any question, bro.',
                  time: 'Seen',
                  avatarUrl: '', // Use default icon
                  isBot: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CentralAICoachScreen()),
                    ).then((_) => _fetchConversations());
                  },
                ),

                const SizedBox(height: 24),
                Text('Your Messages', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),

                if (_conversations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('No messages yet', style: GoogleFonts.poppins(color: Colors.grey)),
                  ),

                ..._conversations.map((chat) {
                  final targetUid = chat['firebaseUid'];
                  return Dismissible(
                    key: Key(targetUid),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return await _showDeleteConfirmation(chat['fullName'] ?? 'User');
                    },
                    onDismissed: (direction) async {
                      final success = await _chatService.clearConversation(targetUid);
                      if (success) {
                        _fetchConversations();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Chat with ${chat['fullName']} deleted')),
                        );
                      }
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: _buildChatTile(
                      name: chat['fullName'] ?? 'User',
                      message: _getDisplayMessage(chat),
                      time: _formatTime(chat['lastMessageTime'] ?? chat['acceptedAt']),
                      avatarUrl: chat['profilePictureUrl'],
                      unreadCount: chat['unreadCount'] ?? 0,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            otherUid: targetUid,
                            otherName: chat['fullName'],
                            otherAvatar: chat['profilePictureUrl'],
                            otherCover: chat['coverPhotoUrl'],
                          )
                        )).then((_) => _fetchConversations());
                      },
                      onAvatarTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => SocialUserProfileScreen(
                            userUid: targetUid,
                            userName: chat['fullName'],
                            userAvatar: chat['profilePictureUrl'],
                            userCover: chat['coverPhotoUrl'],
                          )
                        ));
                      },
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
    );
  }

  Widget _buildChatTile({
    required String name,
    required String message,
    required String time,
    String? avatarUrl,
    bool isBot = false,
    int unreadCount = 0,
    required VoidCallback onTap,
    VoidCallback? onAvatarTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: isBot ? Colors.white : Colors.grey[800],
                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                    child: isBot 
                      ? const Icon(Icons.smart_toy_rounded, color: Colors.black, size: 30)
                      : (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Color(0xFFB794F6), shape: BoxShape.circle),
                      child: Text(unreadCount.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                      Text(time, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: unreadCount > 0 ? Colors.white : Colors.grey[400], 
                      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 14
                    )
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(String name) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: Text('Delete Chat', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete your chat with $name? This will remove all messages and the connection.', 
          style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
  }
}

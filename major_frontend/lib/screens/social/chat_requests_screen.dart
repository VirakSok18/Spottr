import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:major_frontend/services/chat_service.dart';
import 'package:major_frontend/screens/social/chat_screen.dart';
import 'package:intl/intl.dart';

class ChatRequestsScreen extends StatefulWidget {
  const ChatRequestsScreen({Key? key}) : super(key: key);

  @override
  State<ChatRequestsScreen> createState() => _ChatRequestsScreenState();
}

class _ChatRequestsScreenState extends State<ChatRequestsScreen> {
  final ChatService _chatService = ChatService();
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
    
    // Listen for new requests real-time
    _chatService.requestStream.listen((_) => _fetchRequests());
  }

  Future<void> _fetchRequests() async {
    final data = await _chatService.getRequests();
    if (mounted) {
      setState(() {
        _requests = data;
        _isLoading = false;
      });
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    
    if (now.difference(date).inDays == 0) {
      return DateFormat('h:mm a').format(date);
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('E').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Request', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFB794F6)))
          : _requests.isEmpty
              ? Center(child: Text('No requests', style: GoogleFonts.poppins(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    return InkWell(
                      onTap: () {
                        // Open chat in "Request Mode" (isRequest = true)
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            otherUid: req['firebaseUid'],
                            otherName: req['fullName'],
                            otherAvatar: req['profilePictureUrl'],
                            otherCover: req['coverPhotoUrl'],
                            isRequest: true, // IMPORTANT FLAG
                          )
                        )).then((_) => _fetchRequests());
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[800],
                              backgroundImage: (req['profilePictureUrl'] != null && req['profilePictureUrl'].isNotEmpty) 
                                  ? NetworkImage(req['profilePictureUrl']) 
                                  : null,
                              child: (req['profilePictureUrl'] == null || req['profilePictureUrl'].isEmpty) 
                                  ? const Icon(Icons.person, color: Colors.white) 
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(req['fullName'] ?? 'User', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                                      Text(_formatTime(req['requestTime']), style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    req['lastMessage'] ?? 'Sent a message request', 
                                    maxLines: 1, 
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13)
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

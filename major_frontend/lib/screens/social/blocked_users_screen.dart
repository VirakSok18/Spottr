import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/chat_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final ChatService _chatService = ChatService();
  List<dynamic> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    setState(() => _isLoading = true);
    final users = await _chatService.getBlockedUsers();
    if (mounted) {
      setState(() {
        _blockedUsers = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUnblock(String uid) async {
    final success = await _chatService.unblockUser(uid);
    if (success) {
      _fetchBlockedUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User unblocked')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Blocked Users',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _blockedUsers.isEmpty
              ? _buildEmptyState()
              : _buildBlockedUsersList(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFFB497FF)),
    );
  }

  Widget _buildBlockedUsersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _blockedUsers.length,
      itemBuilder: (context, index) {
        final user = _blockedUsers[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(dynamic user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2E2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF1B1B1B),
            backgroundImage: (user['profilePictureUrl'] != null && 
                             user['profilePictureUrl'].toString().isNotEmpty)
                ? NetworkImage(user['profilePictureUrl'])
                : null,
            child: (user['profilePictureUrl'] == null || 
                    user['profilePictureUrl'].toString().isEmpty)
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['fullName'] ?? 'User',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Restricted on ${_formatDate(user['blockedAt'])}',
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _handleUnblock(user['firebaseUid']),
            child: const Text(
              'Unblock',
              style: TextStyle(color: Color(0xFFB497FF), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No blocked users',
        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'Recent';
    try {
      final date = DateTime.parse(dateStr.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Recent';
    }
  }
}

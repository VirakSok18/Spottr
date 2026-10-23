import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';
import '../social/post_detail_screen.dart';
import '../social/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: Text('Delete Selected', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Delete ${_selectedIds.length} selected notifications?', style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    // Collect all notification IDs (including those inside clumps)
    List<String> idsToDelete = [];
    for (var id in _selectedIds) {
      if (id.startsWith('clump_')) {
        final clump = _notifications.firstWhere(
          (n) => n['id'].toString() == id,
          orElse: () => null,
        );
        if (clump != null && clump['messages'] != null) {
          for (var msg in clump['messages']) {
            idsToDelete.add(msg['id'].toString());
          }
        }
      } else {
        idsToDelete.add(id);
      }
    }

    setState(() => _isLoading = true);
    final success = await _notificationService.deleteMultipleNotifications(idsToDelete);
    
    if (mounted) {
      if (success) {
        setState(() {
          _notifications.removeWhere((n) => _selectedIds.contains(n['id'].toString()));
          _selectedIds.clear();
          _isSelectionMode = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications deleted')));
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete notifications')));
      }
    }
  }

  Future<void> _deleteSingle(dynamic notification) async {
    final String id = notification['id'].toString();
    List<String> idsToDelete = [];
    
    if (id.startsWith('clump_')) {
      for (var msg in notification['messages']) {
        idsToDelete.add(msg['id'].toString());
      }
    } else {
      idsToDelete.add(id);
    }

    final success = await _notificationService.deleteMultipleNotifications(idsToDelete);
    if (success && mounted) {
      setState(() {
        _notifications.removeWhere((n) => n['id'].toString() == id);
      });
    }
  }

  Future<bool> _showIndividualDeleteConfirm() async {
     return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: Text('Delete Notification', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this notification?', style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    ) ?? false;
  }

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final notifications = await _notificationService.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = _processNotifications(notifications);
        _isLoading = false;
      });
      // Mark all as read when screen is opened
      _notificationService.markAllAsRead();
    }
  }

  List<dynamic> _processNotifications(List<dynamic> raw) {
    if (raw.isEmpty) return [];
    
    final List<dynamic> clumped = [];
    
    for (int i = 0; i < raw.length; i++) {
      final current = raw[i];
      if (current['type'] != 'message') {
        clumped.add(current);
        continue;
      }
      
      final senderUid = current['senderUid'] ?? current['referenceId'];
      if (senderUid == null) {
        clumped.add(current);
        continue;
      }

      final currentTimestamp = DateTime.parse(current['createdAt']);
      List<dynamic> clump = [current];
      int nextIndex = i + 1;
      
      while (nextIndex < raw.length) {
        final next = raw[nextIndex];
        if (next['type'] != 'message') break;
        
        final nextSenderUid = next['senderUid'] ?? next['referenceId'];
        if (nextSenderUid != senderUid) break;
        
        final nextTimestamp = DateTime.parse(next['createdAt']);
        if (currentTimestamp.difference(nextTimestamp).inMinutes.abs() > 30) break;
        
        clump.add(next);
        nextIndex++;
      }
      
      if (clump.length > 1) {
        clumped.add({
          'isClump': true,
          'id': 'clump_${senderUid}_${current['createdAt']}',
          'type': 'message',
          'senderUid': senderUid,
          'senderName': current['senderName'] ?? current['title'] ?? 'User',
          'senderAvatar': current['senderAvatar'],
          'senderCover': current['senderCover'],
          'messages': clump,
          'createdAt': current['createdAt'],
          'isRead': clump.every((m) => m['isRead'] == true || m['isRead'] == 1),
        });
        i = nextIndex - 1; 
      } else {
        clumped.add(current);
      }
    }
    return clumped;
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: Text(
          'Clear Notifications',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to clear all your notifications? This cannot be undone.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllNotifications();
            },
            child: Text(
              'Clear All',
              style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllNotifications() async {
    setState(() {
      _isLoading = true;
    });
    
    final success = await _notificationService.clearNotifications();
    
    if (mounted) {
      if (success) {
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications cleared')),
        );
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to clear notifications')),
        );
      }
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) {
      return DateFormat('h:mm a').format(dt); // 7:30am
    } else if (date.difference(today).inDays > -7) {
      return DateFormat('E').format(dt); // Mon, Tue
    } else {
      return DateFormat('MMM d').format(dt); // Oct 24
    }
  }

  Widget _buildNotificationItem(dynamic notification) {
    final isClump = notification['isClump'] == true;
    final type = notification['type'];
    final time = _formatTime(notification['createdAt']);
    final bool isRead = notification['isRead'] == true || notification['isRead'] == 1;
    final String id = notification['id']?.toString() ?? '';
    final bool isSelected = _selectedIds.contains(id);

    String senderAvatar = notification['senderAvatar'] ?? '';
    
    // Determine leading widget
    Widget leadingWidget;
    
    if (type == 'like' || type == 'comment' || type == 'message' || type == 'chat_request' || type == 'match_accepted') {
       leadingWidget = CircleAvatar(
         radius: 26,
         backgroundColor: Colors.grey[900],
         backgroundImage: senderAvatar.isNotEmpty ? NetworkImage(senderAvatar) : null,
         child: senderAvatar.isEmpty ? const Icon(Icons.person, color: Colors.white70) : null,
       );

       // Add small badge icon
       IconData badgeIcon;
       Color badgeColor;
       if (type == 'like') {
         badgeIcon = Icons.favorite;
         badgeColor = Colors.redAccent;
       } else if (type == 'comment') {
         badgeIcon = Icons.chat_bubble;
         badgeColor = const Color(0xFFB794F6);
       } else if (type == 'chat_request') {
         badgeIcon = Icons.person_add;
         badgeColor = Colors.orangeAccent;
       } else if (type == 'match_accepted') {
         badgeIcon = Icons.check_circle;
         badgeColor = Colors.greenAccent;
       } else {
         badgeIcon = Icons.mail_outline;
         badgeColor = Colors.blueAccent;
       }

       leadingWidget = Stack(
         children: [
           leadingWidget,
           Positioned(
             right: 0,
             bottom: 0,
             child: Container(
               padding: const EdgeInsets.all(4),
               decoration: const BoxDecoration(
                 color: Color(0xFF1B1B1B),
                 shape: BoxShape.circle,
               ),
               child: Icon(
                 badgeIcon,
                 size: 14,
                 color: badgeColor,
               ),
             ),
           ),
         ],
       );
    } else {
       leadingWidget = Container(
         width: 52,
         height: 52,
         decoration: BoxDecoration(
           color: const Color(0xFFB794F6),
           shape: BoxShape.circle,
           boxShadow: [
             BoxShadow(
               color: const Color(0xFFB794F6).withOpacity(0.3),
               blurRadius: 8,
               spreadRadius: 1,
             ),
           ],
         ),
         child: ClipOval(
           child: Image.asset(
             'assets/images/app_logo.png',
             fit: BoxFit.cover,
           ),
         ),
       );
    }

    return Dismissible(
      key: Key(id),
      direction: _isSelectionMode ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteSingle(notification),
      confirmDismiss: (_) => _showIndividualDeleteConfirm(),
      child: InkWell(
        onLongPress: () {
          if (!_isSelectionMode) {
            setState(() {
              _isSelectionMode = true;
              _selectedIds.add(id);
            });
          }
        },
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(id);
            return;
          }

          if (!isRead) {
            if (isClump) {
              // Mark all clumped messages as read
              for (var msg in notification['messages']) {
                _notificationService.markAsRead(msg['id'].toString());
              }
            } else {
              _notificationService.markAsRead(notification['id'].toString());
            }
            setState(() {
              notification['isRead'] = true;
            });
          }

          // Navigation
          if (type == 'message' || type == 'chat_request' || type == 'match_accepted') {
            final targetUserId = notification['senderUid'] ?? notification['referenceId'];
            if (targetUserId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    otherUid: targetUserId.toString(),
                    otherName: notification['senderName'] ?? notification['title'] ?? 'User',
                    otherAvatar: notification['senderAvatar'],
                    otherCover: notification['senderCover'],
                    isRequest: type == 'chat_request',
                  ),
                ),
              );
            }
          } else if (type == 'like' || type == 'comment') {
            final targetPostId = notification['postId'] ?? notification['referenceId'];
            if (targetPostId != null) {
              try {
                final int postId = int.parse(targetPostId.toString());
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(postId: postId),
                  ),
                );
              } catch (e) {
                print("Error parsing post ID for navigation: $e");
              }
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            color: isSelected 
              ? const Color(0xFFB794F6).withOpacity(0.1)
              : (isRead ? Colors.transparent : const Color(0xFFB794F6).withOpacity(0.03)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 16, top: 14),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? const Color(0xFFB794F6) : Colors.grey,
                    size: 24,
                  ),
                ),
              leadingWidget,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            isClump 
                              ? "${notification['messages'].length} new messages from ${notification['senderName']}"
                              : (notification['title'] ?? 'Notification'),
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          time,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: isRead ? Colors.grey : const Color(0xFFB794F6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isClump 
                        ? (notification['messages'][0]['message'] ?? '')
                        : (notification['message'] ?? ''),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isRead)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFB794F6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Group notifications
    final todayNotifications = <dynamic>[];
    final weekNotifications = <dynamic>[];
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var n in _notifications) {
      if (n['createdAt'] == null) continue;
      final dt = DateTime.parse(n['createdAt']).toLocal();
      final date = DateTime(dt.year, dt.month, dt.day);
      
      if (date == today) {
        todayNotifications.add(n);
      } else {
        weekNotifications.add(n);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} Selected' : 'Notifications',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deleteSelected,
            )
          else if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _showClearAllDialog,
              child: Text(
                'Clear All',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFB794F6),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFB794F6)))
          : _notifications.isEmpty
              ? Center(
                  child: Text(
                    'No notifications yet',
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  color: const Color(0xFFB794F6),
                  backgroundColor: const Color(0xFF2C2C2E),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      if (todayNotifications.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Text(
                                'Today',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB794F6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '+${todayNotifications.length}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...todayNotifications.map((n) => _buildNotificationItem(n)),
                        const SizedBox(height: 24),
                      ],
                      if (weekNotifications.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'This Week',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...weekNotifications.map((n) => _buildNotificationItem(n)),
                      ],
                    ],
                  ),
                ),
    );
  }
}

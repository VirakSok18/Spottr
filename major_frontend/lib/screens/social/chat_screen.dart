import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:major_frontend/services/chat_service.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:major_frontend/screens/social/media_preview_screen.dart';
import 'package:major_frontend/screens/social/video_player_screen.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:major_frontend/screens/social/post_detail_screen.dart';
import 'package:major_frontend/screens/social/user_profile_screen.dart';
import '../../widgets/app_theme_widgets.dart';


class ChatScreen extends StatefulWidget {
  final String otherUid;
  final String? otherName;
  final String? otherAvatar;
  final String? otherCover;
  final bool isRequest; // If true, show Block/Delete/Accept buttons

  const ChatScreen({
    Key? key,
    required this.otherUid,
    this.otherName,
    this.otherAvatar,
    this.otherCover,
    this.isRequest = false,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  List<dynamic> _messages = [];
  bool _isRequest = false;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  bool _isOtherSeen = false;
  bool _isBlocked = false;
  bool _blockedByMe = false;
  Map<String, dynamic>? _replyingTo;
  final Map<String, double> _uploadProgress = {};
  bool _showScrollToBottom = false;

  Timer? _statusTimer;
  bool _isOnline = false;
  DateTime? _lastActive;
  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _isRequest = widget.isRequest;
    _chatService.initSocket(); // Ensure socket is ready locally
    _chatService.enterChat(widget.otherUid); // Notify backend we are in this chat
    _fetchMessages();
    _checkStatus();
    
    // Initial fetch of user status
    _chatService.getUserStatus(widget.otherUid);
    
    // Poll status every 30 seconds to keep "Active x min ago" fresh
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _chatService.getUserStatus(widget.otherUid);
    });

    // Listen for incoming messages to update the list in real-time
    _messageSubscription = _chatService.messageStream.listen((data) {
      if (data['type'] == 'delete') {
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m['id'].toString() == data['messageId'].toString());
          });
        }
        return;
      }

      if (data['senderUid'] == widget.otherUid || data['receiverUid'] == widget.otherUid) {
        if (mounted) {
          setState(() {
            final exists = _messages.any((m) => m['id'].toString() == data['id'].toString());
            if (!exists) {
              _messages.add(data);
            }
          });
          _scrollToBottom();
          if (data['senderUid'] == widget.otherUid) {
             _chatService.markAsRead(widget.otherUid);
          }
        }
      }
    });

    _chatService.requestStream.listen((data) {
      if (data['type'] == 'seen' && data['seenBy'] == widget.otherUid) {
        if (mounted) {
          setState(() {
            _isOtherSeen = true;
          });
        }
      }
    });

    // Listen for status updates
    _chatService.statusStream.listen((data) {
      if (data['uid'] == widget.otherUid && mounted) {
        setState(() {
          _isOnline = data['isOnline'] == true || data['isOnline'] == 1;
          _lastActive = data['lastActive'] != null ? DateTime.parse(data['lastActive']).toLocal() : null;
        });
      }
    });

    _itemPositionsListener.itemPositions.addListener(() {
      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;

      // In reversed list, index 0 is at the bottom.
      // Show button if the first visible item (lowest index) is not 0
      final minIndex = positions.map((p) => p.index).reduce((a, b) => a < b ? a : b);
      final show = minIndex > 0;
      
      if (show != _showScrollToBottom) {
        setState(() => _showScrollToBottom = show);
      }
    });

    _chatService.markAsRead(widget.otherUid);
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _messageSubscription?.cancel();
    _controller.dispose();
    _chatService.leaveChat(); // Notify backend we left
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final status = await _chatService.getChatStatus(widget.otherUid);
    if (mounted) {
      setState(() {
        _isBlocked = status['status'] == 'blocked';
        _blockedByMe = status['blockedByMe'] == true;
        
        // If status is pending and we ARE NOT the sender, it's a request we need to accept
        if (status['status'] == 'pending' && 
            status['senderUid'] != FirebaseAuth.instance.currentUser?.uid) {
          _isRequest = true;
        } else {
          _isRequest = false;
        }
      });
    }
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    final data = await _chatService.getMessages(widget.otherUid);
    if (mounted) {
      setState(() {
        _messages = data;
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    if (_messages.isEmpty) return;
    
    final scrollAction = () {
      if (_itemScrollController.isAttached) {
        _itemScrollController.scrollTo(
          index: 0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.fastOutSlowIn,
          alignment: 0,
        );
      }
    };

    if (immediate) {
      scrollAction();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollAction());
    }
  }

  void _jumpToMessage(int parentId) {
    final index = _messages.indexWhere((m) => m['id'] == parentId);
    if (index != -1) {
      // In reversed list, the index is (length - 1 - originalIndex)
      final reversedIndex = _messages.length - 1 - index;
      _itemScrollController.scrollTo(
        index: reversedIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1, // Show slightly from the top
      );
    }
  }

  void _sendMessage({String? content, String? mediaUrl, String? mediaType}) {
    final text = content ?? _controller.text.trim();
    if (text.isEmpty && mediaUrl == null) return;
    
    _chatService.sendMessage(
      widget.otherUid, 
      text, 
      mediaUrl: mediaUrl, 
      mediaType: mediaType,
      parentId: _replyingTo?['id'],
      parentContent: _replyingTo?['content'],
      parentMediaType: _replyingTo?['mediaType'],
    );
    
    if (content == null) _controller.clear();
    setState(() {
       _isOtherSeen = false; // Reset seen for new message
       _replyingTo = null; // Clear reply after sending
    });
  }

  void _onSwipeMessage(Map<String, dynamic> message) {
    setState(() {
      _replyingTo = message;
    });
  }

  Future<void> _pickMedia(bool isVideo) async {
    final XFile? file = isVideo 
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (file != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MediaPreviewScreen(
            file: file,
            isVideo: isVideo,
            onSend: (caption) async {
              final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
              final localMsg = {
                'id': tempId,
                'senderUid': FirebaseAuth.instance.currentUser?.uid,
                'content': caption,
                'mediaUrl': file.path,
                'mediaType': isVideo ? 'video' : 'image',
                'createdAt': DateTime.now().toUtc().toIso8601String(),
                'isSending': true,
                'parentId': _replyingTo?['id'],
                'parentContent': _replyingTo?['content'],
                'parentMediaType': _replyingTo?['mediaType'],
              };

              setState(() {
                _messages.add(localMsg);
                _uploadProgress[tempId] = 0.0;
              });
              _scrollToBottom();

              final result = await _chatService.uploadMedia(
                file.path, 
                isVideo,
                onProgress: (p) {
                  if (mounted) {
                    setState(() => _uploadProgress[tempId] = p);
                  }
                }
              );

              if (result != null && mounted) {
                // Remove temp message and send real one
                setState(() {
                  _messages.removeWhere((m) => m['id'] == tempId);
                  _uploadProgress.remove(tempId);
                });
                _sendMessage(
                  content: caption.isNotEmpty ? caption : null,
                  mediaUrl: result['url'], 
                  mediaType: result['type']
                );
              } else if (mounted) {
                // Handle error - mark as failed
                setState(() {
                  _uploadProgress.remove(tempId);
                  final idx = _messages.indexWhere((m) => m['id'] == tempId);
                  if (idx != -1) {
                    _messages[idx]['failed'] = true;
                  }
                });
              }
            },
          ),
        ),
      );
    }
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildPickerOption(Icons.image, 'Image', () {
              Navigator.pop(context);
              _pickMedia(false);
            }),
            _buildPickerOption(Icons.videocam, 'Video', () {
              Navigator.pop(context);
              _pickMedia(true);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFFB794F6).withOpacity(0.1),
            child: Icon(icon, color: const Color(0xFFB794F6), size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _handleRequestAction(String action) async {
    final success = await _chatService.respondToRequest(widget.otherUid, action);
    if (success) {
      if (action == 'accept') {
        setState(() => _isRequest = false);
      } else {
        if (mounted) Navigator.pop(context); // Close chat if blocked/deleted
      }
    }
  }

  String _getStatusText() {
    if (_isRequest) return ''; 
    if (_isOnline) return 'Active Now';
    if (_lastActive == null) return '';

    final diff = DateTime.now().difference(_lastActive!);
    if (diff.inMinutes < 1) return 'Active just now';
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Active ${diff.inDays}d ago';
    return 'Active on ${DateFormat('MMM d').format(_lastActive!)}';
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
    final isMe = msg['senderUid'] != widget.otherUid;
    final timeStr = _formatTime(msg['createdAt']);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              timeStr,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.reply, color: Colors.white),
            title: Text('Reply', style: GoogleFonts.poppins(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _onSwipeMessage(msg);
            },
          ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: Text('Unsend', style: GoogleFonts.poppins(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await _showConfirmDialog('Unsend Message', 'Are you sure you want to unsend this message? It will be removed for everyone.');
                if (confirm) {
                  await _chatService.unsendMessage(msg['id'], widget.otherUid);
                }
              },
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  bool _shouldShowDayHeader(int reversedIndex) {
    final index = _messages.length - 1 - reversedIndex;
    if (index == 0) return true;
    final currentMsg = _messages[index];
    final prevMsg = _messages[index - 1];
    final currentTime = DateTime.parse(currentMsg['createdAt']).toLocal();
    final prevTime = DateTime.parse(prevMsg['createdAt']).toLocal();
    return currentTime.year != prevTime.year || currentTime.month != prevTime.month || currentTime.day != prevTime.day;
  }

  bool _shouldShowSessionDivider(int reversedIndex) {
    final index = _messages.length - 1 - reversedIndex;
    if (index == 0) return false;
    final currentMsg = _messages[index];
    final prevMsg = _messages[index - 1];
    final currentTime = DateTime.parse(currentMsg['createdAt']).toLocal();
    final prevTime = DateTime.parse(prevMsg['createdAt']).toLocal();
    return currentTime.difference(prevTime).inHours >= 1 && currentTime.day == prevTime.day;
  }

  bool _shouldShowInlineTime(int reversedIndex) {
    final index = _messages.length - 1 - reversedIndex;
    if (index == 0) return false;
    final currentMsg = _messages[index];
    final prevMsg = _messages[index - 1];
    final currentTime = DateTime.parse(currentMsg['createdAt']).toLocal();
    final prevTime = DateTime.parse(prevMsg['createdAt']).toLocal();
    final senderChanged = currentMsg['senderUid'] != prevMsg['senderUid'];
    final timeGap = currentTime.difference(prevTime).inMinutes >= 5;
    if (_shouldShowDayHeader(reversedIndex) || _shouldShowSessionDivider(reversedIndex)) return false;
    return senderChanged || timeGap;
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('h:mm a').format(DateTime.parse(timestamp).toLocal());
  }

  String _formatDateSeparator(String timestamp) {
    final dt = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(dt.year, dt.month, dt.day);

    if (msgDate == today) {
      return 'TODAY';
    } else if (msgDate == yesterday) {
      return 'YESTERDAY';
    } else {
      return DateFormat('MMMM d, yyyy').format(dt).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SocialUserProfileScreen(
                  userUid: widget.otherUid,
                  userName: widget.otherName ?? 'User',
                  userAvatar: widget.otherAvatar,
                  userCover: widget.otherCover,
                ),
              ),
            );
          },
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: (widget.otherAvatar != null && widget.otherAvatar!.isNotEmpty) 
                        ? NetworkImage(widget.otherAvatar!) 
                        : null,
                    child: (widget.otherAvatar == null || widget.otherAvatar!.isEmpty) 
                        ? const Icon(Icons.person, color: Colors.white, size: 20) 
                        : null,
                  ),
                  if (_isOnline && !_isRequest)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1F1F1F), width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherName ?? 'User', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  if (!_isRequest)
                       Text(
                          _getStatusText(),
                          style: GoogleFonts.poppins(
                            color: _isOnline ? Colors.greenAccent : Colors.grey, 
                            fontSize: 10
                          )
                       ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (dialogContext) => _ChatOptionsSheet(
                  onClearChat: () async {
                    Navigator.pop(dialogContext);
                    final confirm = await _showConfirmDialog('Clear Chat', 'This will delete all messages in this conversation. This action cannot be undone.');
                    if (confirm) {
                      await _chatService.clearConversation(widget.otherUid);
                      _fetchMessages();
                    }
                  },
                  onBlockUser: () async {
                    Navigator.pop(dialogContext);
                    final confirm = await _showConfirmDialog('Block User', 'Are you sure you want to block this user? They won\'t be able to message you.');
                    if (confirm) {
                      await _chatService.blockUser(widget.otherUid);
                      if (mounted) Navigator.pop(context);
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: PremiumLoading(size: 60))
              : _messages.isEmpty 
                  ? _buildIntro()
                  : Stack(
                      children: [
                        ScrollablePositionedList.builder(
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                          padding: const EdgeInsets.all(16),
                          reverse: true, // Keeps messages pinned to keyboard
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[_messages.length - 1 - index];
                            final isMe = msg['senderUid'] != widget.otherUid;
                            final hasMedia = msg['mediaUrl'] != null;
                            final hasText = msg['content'] != null && msg['content'].toString().trim().isNotEmpty;

                            final showDayHeader = _shouldShowDayHeader(index);
                            final showSessionDivider = _shouldShowSessionDivider(index);
                            final showInlineTime = _shouldShowInlineTime(index);

                            bool isFirstInBlock = true;
                            bool isLastInBlock = true;

                            if (index < _messages.length - 1) {
                              final olderMsg = _messages[_messages.length - 1 - (index + 1)];
                              final olderTime = DateTime.parse(olderMsg['createdAt']).toLocal();
                              final currentTime = DateTime.parse(msg['createdAt']).toLocal();
                              if (olderMsg['senderUid'] == msg['senderUid'] && currentTime.difference(olderTime).inMinutes < 5) {
                                isFirstInBlock = false;
                              }
                            }

                            if (index > 0) {
                              final newerMsg = _messages[_messages.length - 1 - (index - 1)];
                              final newerTime = DateTime.parse(newerMsg['createdAt']).toLocal();
                              final currentTime = DateTime.parse(msg['createdAt']).toLocal();
                              if (newerMsg['senderUid'] == msg['senderUid'] && newerTime.difference(currentTime).inMinutes < 5) {
                                isLastInBlock = false;
                              }
                            }

                            return Column(
                              children: [
                                if (showDayHeader)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 32, bottom: 16),
                                      child: Text(
                                        _formatDateSeparator(msg['createdAt']),
                                        style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                      ),
                                    ),
                                  ),
                                if (showSessionDivider)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      child: Text(
                                        _formatTime(msg['createdAt']),
                                        style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                if (showInlineTime)
                                  Align(
                                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 12, bottom: 4, left: isMe ? 0 : 4, right: isMe ? 4 : 0),
                                      child: Text(
                                        _formatTime(msg['createdAt']),
                                        style: GoogleFonts.poppins(color: Colors.white24, fontSize: 10),
                                      ),
                                    ),
                                  ),
                                SwipeToReply(
                                  onReply: () => _onSwipeMessage(msg),
                                  child: GestureDetector(
                                    onLongPress: () => _showMessageOptions(msg),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        Align(
                                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                          child: Container(
                                            margin: EdgeInsets.only(bottom: isLastInBlock ? 8 : 2),
                                            padding: hasText 
                                                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                                                : EdgeInsets.zero,
                                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                            decoration: BoxDecoration(
                                              color: (hasText || !hasMedia) 
                                                  ? (isMe ? const Color(0xFF5B32A8) : const Color(0xFF2C2C2C))
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(isMe ? 16 : (isFirstInBlock ? 16 : 4)),
                                                topRight: Radius.circular(isMe ? (isFirstInBlock ? 16 : 4) : 16),
                                                bottomLeft: Radius.circular(isMe ? 16 : (isLastInBlock ? 16 : 4)),
                                                bottomRight: Radius.circular(isMe ? (isLastInBlock ? 16 : 4) : 16),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                              children: [
                                                if (msg['parentId'] != null)
                                                  GestureDetector(
                                                    onTap: () => _jumpToMessage(msg['parentId']),
                                                    child: Container(
                                                      margin: const EdgeInsets.only(bottom: 8),
                                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                                      decoration: const BoxDecoration(
                                                        border: Border(left: BorderSide(color: Color(0xFFB794F6), width: 2)),
                                                      ),
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(left: 8.0),
                                                        child: Text(
                                                          msg['parentContent'] ?? (msg['parentMediaType'] == 'image' ? 'photo' : 'video'),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12, fontStyle: FontStyle.italic),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  
                                                if (hasMedia && msg['mediaType'] != 'post')
                                                  Padding(
                                                    padding: EdgeInsets.only(bottom: hasText ? 8.0 : 0.0),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: GestureDetector(
                                                            onTap: () {
                                                              if (msg['isSending'] != true) {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (context) => VideoPlayerScreen(
                                                                      mediaUrl: msg['mediaUrl'],
                                                                      mediaType: msg['mediaType'],
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                            },
                                                            child: Stack(
                                                              alignment: Alignment.center,
                                                              children: [
                                                                msg['isSending'] == true
                                                                  ? (msg['mediaType'] == 'video'
                                                                      ? Container(
                                                                          width: 200,
                                                                          height: 200,
                                                                          color: const Color(0xFF1F1F1F),
                                                                          child: const Icon(Icons.videocam, color: Colors.white54, size: 40),
                                                                        )
                                                                      : Image.file(
                                                                          File(msg['mediaUrl']),
                                                                          fit: BoxFit.cover,
                                                                          width: 200,
                                                                          height: 200,
                                                                        ))
                                                                  : Image.network(
                                                                      msg['mediaType'] == 'video' 
                                                                        ? msg['mediaUrl'].toString().replaceAll(RegExp(r'\.(mp4|mov|avi|MP4|MOV|AVI)$'), '.jpg')
                                                                        : msg['mediaUrl'],
                                                                      fit: BoxFit.cover,
                                                                      width: 200, // Fixed width for media
                                                                      height: 200,
                                                                      loadingBuilder: (context, child, loadingProgress) {
                                                                        if (loadingProgress == null) return child;
                                                                        return Container(
                                                                          width: 200, 
                                                                          height: 200, 
                                                                          color: const Color(0xFF1F1F1F),
                                                                          child: const Center(child: PremiumLoading(size: 30))
                                                                        );
                                                                      },
                                                                    ),
                                                                if (msg['mediaType'] == 'video' && msg['isSending'] != true)
                                                                  const Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                                                              ],
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                if (msg['mediaType'] == 'post')
                                                  GestureDetector(
                                                    onTap: () {
                                                      final postId = msg['parentId'];
                                                      if (postId != null) {
                                                        try {
                                                            final int id = int.parse(postId.toString());
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) => PostDetailScreen(postId: id),
                                                              ),
                                                            );
                                                        } catch (e) {
                                                            print("Error parsing post ID: $e");
                                                        }
                                                      }
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.05),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: Colors.white12),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const Icon(Icons.share_rounded, color: Color(0xFFB794F6), size: 14),
                                                              const SizedBox(width: 8),
                                                              Text(
                                                                'Shared a post',
                                                                style: GoogleFonts.poppins(
                                                                  color: const Color(0xFFB794F6),
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 8),
                                                          if (msg['parentContent'] != null && msg['parentContent'].toString().isNotEmpty)
                                                            Text(
                                                              msg['parentContent'],
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                                                            ),
                                                          if (msg['mediaUrl'] != null && msg['mediaUrl'].toString().isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 8.0),
                                                              child: ClipRRect(
                                                                borderRadius: BorderRadius.circular(8),
                                                                child: Image.network(
                                                                  msg['parentMediaType'] == 'video'
                                                                    ? msg['mediaUrl'].toString().replaceAll(RegExp(r'\.(mp4|mov|avi|MP4|MOV|AVI)$'), '.jpg')
                                                                    : msg['mediaUrl'],
                                                                  height: 120,
                                                                  width: double.infinity,
                                                                  fit: BoxFit.cover,
                                                                ),
                                                              ),
                                                            ),
                                                          const SizedBox(height: 8),
                                                          Text(
                                                            'View Post',
                                                            style: GoogleFonts.poppins(
                                                              color: Colors.white54,
                                                              fontSize: 10,
                                                              decoration: TextDecoration.underline,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                if (msg['isSending'] == true)
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    child: Column(
                                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius: BorderRadius.circular(10),
                                                          child: SizedBox(
                                                            width: 140,
                                                            height: 4,
                                                            child: LinearProgressIndicator(
                                                              value: _uploadProgress[msg['id']] ?? 0,
                                                              backgroundColor: Colors.white10,
                                                              color: const Color(0xFFB794F6),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              'Sending...', 
                                                              style: GoogleFonts.poppins(
                                                                color: Colors.white.withOpacity(0.5), 
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.w500,
                                                              )
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              '${((_uploadProgress[msg['id']] ?? 0) * 100).toInt()}%',
                                                              style: GoogleFonts.poppins(
                                                                color: const Color(0xFFB794F6), 
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (hasText)
                                                  Text(
                                                    msg['content'],
                                                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (isMe && index == 0 && _isOtherSeen) // index 0 is bottom
                                           Padding(
                                             padding: const EdgeInsets.only(right: 4, bottom: 8),
                                             child: Text('Seen', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
                                           ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        // Scroll to Bottom Button
                        if (_showScrollToBottom)
                          Positioned(
                            bottom: 20,
                            right: 20,
                            child: GestureDetector(
                              onTap: () => _scrollToBottom(immediate: true),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1F1F1F),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.keyboard_double_arrow_down_rounded, color: Color(0xFFB794F6), size: 24),
                              ),
                            ),
                          ),
                      ],
                    ),
          ),
          
          // Input Bar or Blocked Indicator
          if (_isBlocked)
            _buildBlockedIndicator()
          else if (_isRequest)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Text(
                    'Chat Request',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'If you accept, they will also be able to message you and see your info.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => _handleRequestAction('block'),
                        child: Text('Block', style: GoogleFonts.poppins(color: Colors.redAccent)),
                      ),
                      TextButton(
                        onPressed: () => _handleRequestAction('reject'), // Map Delete to reject
                        child: Text('Delete', style: GoogleFonts.poppins(color: Colors.redAccent)),
                      ),
                      TextButton(
                        onPressed: () => _handleRequestAction('accept'),
                        child: Text('Accept', style: GoogleFonts.poppins(color: Color(0xFFB794F6), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            )
          else
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                color: const Color(0xFF1F1F1F),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingTo != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8, left: 10, right: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(12),
                          border: const Border(left: BorderSide(color: Color(0xFFB794F6), width: 4)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _replyingTo!['senderUid'] == FirebaseAuth.instance.currentUser?.uid ? 'You' : (widget.otherName ?? 'User'),
                                    style: GoogleFonts.poppins(color: const Color(0xFFB794F6), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  Text(
                                    _replyingTo!['content'] ?? (_replyingTo!['mediaType'] == 'image' ? 'photo' : 'video'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _replyingTo = null),
                              icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(onPressed: _showMediaPicker, icon: const Icon(Icons.add_circle, color: Colors.grey)),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2C),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _controller,
                              style: GoogleFonts.poppins(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Message...',
                                hintStyle: GoogleFonts.poppins(color: Colors.grey),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _sendMessage(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFB794F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Padding(
                                padding: EdgeInsets.only(left: 3), // Visually center the asymmetrical icon
                                child: Icon(Icons.send_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.white.withOpacity(0.05),
              backgroundImage: (widget.otherAvatar != null && widget.otherAvatar!.isNotEmpty) ? NetworkImage(widget.otherAvatar!) : null,
              child: (widget.otherAvatar == null || widget.otherAvatar!.isEmpty) ? const Icon(Icons.person, color: Colors.white, size: 40) : null,
            ),
            const SizedBox(height: 16),
            Text(
              widget.otherName ?? 'User',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Looking to train together? Send a message to start a chat request!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFB794F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB794F6).withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFB794F6), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Your first message will be a request.',
                    style: GoogleFonts.poppins(color: const Color(0xFFB794F6), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E2E2E),
        title: Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(content, style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Confirm', style: GoogleFonts.poppins(color: const Color(0xFFB794F6)))),
        ],
      ),
    ) ?? false;
  }
  Widget _buildBlockedIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F1F),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Center(
        child: Text(
          _blockedByMe ? 'You have blocked this user' : 'You cannot message this user',
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const SwipeToReply({Key? key, required this.child, required this.onReply}) : super(key: key);

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> {
  double _dragExtent = 0;
  static const double _replyThreshold = 60.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 0 || _dragExtent > 0) {
          setState(() {
            _dragExtent += details.delta.dx;
            if (_dragExtent < 0) _dragExtent = 0;
            if (_dragExtent > 100) _dragExtent = 100; // Limit drag
          });
        }
      },
      onHorizontalDragEnd: (details) {
        if (_dragExtent >= _replyThreshold) {
          widget.onReply();
        }
        setState(() => _dragExtent = 0);
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Transform.translate(
            offset: const Offset(-40, 0),
            child: Opacity(
              opacity: (_dragExtent / _replyThreshold).clamp(0.0, 1.0),
              child: const Padding(
                padding: EdgeInsets.only(left: 10.0),
                child: Icon(Icons.reply, color: Color(0xFFB794F6), size: 24),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            transform: Matrix4.translationValues(_dragExtent, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _ChatOptionsSheet extends StatelessWidget {
  final VoidCallback onClearChat;
  final VoidCallback onBlockUser;

  const _ChatOptionsSheet({
    Key? key,
    required this.onClearChat,
    required this.onBlockUser,
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
            leading: const Icon(Icons.clear_all, color: Colors.white),
            title: Text(
              'Clear Chat',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            onTap: onClearChat,
          ),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.redAccent),
            title: Text(
              'Block User',
              style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w500),
            ),
            onTap: onBlockUser,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'config.dart' as app_config;

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  RealtimeChannel? _realtimeChannel;

  // Unread count notifier
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  // Stream controllers for real-time updates
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  final _requestController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get requestStream => _requestController.stream;

  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  final _postInteractionController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get postInteractionStream => _postInteractionController.stream;

  void initSocket() {
    final user = _auth.currentUser;
    if (user == null) return;

    if (_realtimeChannel != null) return;

    try {
      _realtimeChannel = app_config.Config.supabase
          .channel('public:messages')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final map = Map<String, dynamic>.from(newRecord);
                if (map['receiverUid'] == user.uid || map['senderUid'] == user.uid) {
                  _messageController.add(map);
                  updateUnreadCount();
                }
              }
            },
          )
          .subscribe();

      updateUnreadCount();
    } catch (e) {
      print('ChatService: Error setting up realtime: $e');
    }
  }

  Future<void> updateUnreadCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final res = await app_config.Config.supabase
          .from('messages')
          .select('id')
          .eq('receiverUid', user.uid)
          .eq('isRead', false);

      final requests = await getRequests();
      unreadCount.value = res.length + requests.length;
    } catch (e) {
      print('ChatService: Error updating unread count: $e');
    }
  }

  void disconnect() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  void markAsRead(String otherUid) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await app_config.Config.supabase
          .from('messages')
          .update({'isRead': true})
          .eq('senderUid', otherUid)
          .eq('receiverUid', user.uid);

      updateUnreadCount();
    } catch (e) {
      print('ChatService: Error marking as read: $e');
    }
  }

  void getUserStatus(String uid) {
    _statusController.add({'uid': uid, 'isOnline': true});
  }

  void enterChat(String otherUid) {
    markAsRead(otherUid);
  }

  void leaveChat() {}

  Future<List<dynamic>> searchUsers(String query) async {
    try {
      final user = _auth.currentUser;
      final res = await app_config.Config.supabase
          .from('users')
          .select()
          .ilike('fullName', '%$query%')
          .neq('firebaseUid', user?.uid ?? '')
          .limit(20);
      return List<dynamic>.from(res);
    } catch (e) {
      print('ChatService: Error searching users: $e');
      return [];
    }
  }

  Future<List<dynamic>> getConversations() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final res = await app_config.Config.supabase
          .from('messages')
          .select()
          .or('senderUid.eq.${user.uid},receiverUid.eq.${user.uid}')
          .order('createdAt', ascending: false);

      final Map<String, Map<String, dynamic>> convos = {};
      for (var msg in res) {
        final otherUid = msg['senderUid'] == user.uid ? msg['receiverUid'] : msg['senderUid'];
        if (otherUid == null || otherUid.toString().isEmpty) continue;
        final key = otherUid.toString();

        if (!convos.containsKey(key)) {
          convos[key] = {
            'otherUid': key,
            'lastMessage': msg['content'] ?? (msg['mediaUrl'] != null ? '[Media]' : ''),
            'lastMessageTime': msg['createdAt'],
            'unreadCount': (msg['receiverUid'] == user.uid && msg['isRead'] != true) ? 1 : 0,
          };
        }
      }

      if (convos.isEmpty) return [];

      final otherUids = convos.keys.toList();
      final users = await app_config.Config.supabase
          .from('users')
          .select('firebaseUid, fullName, profilePictureUrl')
          .inFilter('firebaseUid', otherUids);

      final userMap = {for (var u in users) u['firebaseUid']: u};
      for (var entry in convos.entries) {
        final u = userMap[entry.key];
        entry.value['userName'] = u?['fullName'] ?? 'Athlete';
        entry.value['userAvatar'] = u?['profilePictureUrl'];
      }

      return convos.values.toList();
    } catch (e) {
      print('ChatService: Error fetching conversations: $e');
      return [];
    }
  }

  Future<List<dynamic>> getRequests() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final res = await app_config.Config.supabase
          .from('chat_requests')
          .select()
          .eq('receiverUid', user.uid)
          .eq('status', 'pending');
      return List<dynamic>.from(res);
    } catch (e) {
      print('ChatService: Error fetching requests: $e');
      return [];
    }
  }

  Future<List<dynamic>> getMessages(String otherUid) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final res = await app_config.Config.supabase
          .from('messages')
          .select()
          .or('and(senderUid.eq.${user.uid},receiverUid.eq.$otherUid),and(senderUid.eq.$otherUid,receiverUid.eq.${user.uid})')
          .order('createdAt', ascending: true);

      return List<dynamic>.from(res);
    } catch (e) {
      print('ChatService: Error fetching messages: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> uploadMedia(
    String filePath,
    bool isVideo, {
    Function(double)? onProgress,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final ext = filePath.split('.').last.toLowerCase();
      final fileName = '${user.uid}_chat_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await app_config.Config.supabase.storage.from('posts').uploadBinary(fileName, bytes);
      final publicUrl = app_config.Config.supabase.storage.from('posts').getPublicUrl(fileName);

      return {
        'url': publicUrl,
        'type': isVideo ? 'video' : 'image',
      };
    } catch (e) {
      print('ChatService: Error uploading media: $e');
      return null;
    }
  }

  Future<void> sendMessage(
    String receiverUid,
    String content, {
    String? mediaUrl,
    String? mediaType,
    int? parentId,
    String? parentContent,
    String? parentMediaType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final inserted = await app_config.Config.supabase.from('messages').insert({
        'senderUid': user.uid,
        'receiverUid': receiverUid,
        'content': content,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'parentId': parentId,
        'parentContent': parentContent,
        'parentMediaType': parentMediaType,
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
      }).select().single();

      _messageController.add(Map<String, dynamic>.from(inserted));
      updateUnreadCount();
    } catch (e) {
      print('ChatService: Error sending message: $e');
    }
  }

  Future<bool> blockUser(String targetUid) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await app_config.Config.supabase.from('blocks').insert({
        'blockerUid': user.uid,
        'blockedUid': targetUid,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> unblockUser(String targetUid) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await app_config.Config.supabase
          .from('blocks')
          .delete()
          .eq('blockerUid', user.uid)
          .eq('blockedUid', targetUid);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getBlockedUsers() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final res = await app_config.Config.supabase
          .from('blocks')
          .select('blockedUid')
          .eq('blockerUid', user.uid);
      return res.map((b) => b['blockedUid']).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> clearConversation(String targetUid) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await app_config.Config.supabase
          .from('messages')
          .delete()
          .or('and(senderUid.eq.${user.uid},receiverUid.eq.$targetUid),and(senderUid.eq.$targetUid,receiverUid.eq.${user.uid})');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> respondToRequest(String targetUid, String action) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await app_config.Config.supabase
          .from('chat_requests')
          .update({'status': action == 'accept' ? 'accepted' : 'rejected'})
          .eq('senderUid', targetUid)
          .eq('receiverUid', user.uid);

      updateUnreadCount();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getChatStatus(String otherUid) async {
    return {'status': 'accepted'};
  }

  Future<bool> unsendMessage(int messageId, String receiverUid) async {
    try {
      await app_config.Config.supabase.from('messages').delete().eq('id', messageId);
      _messageController.add({'type': 'delete', 'messageId': messageId});
      return true;
    } catch (e) {
      print('ChatService: Unsend Error: $e');
      return false;
    }
  }
}

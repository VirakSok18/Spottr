import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'config.dart' as app_config;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart' as dio;
import 'package:http/http.dart' as http;

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final String baseUrl = '${app_config.Config.baseUrl}/api';
  IO.Socket? socket;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final dio.Dio _dio = dio.Dio();

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
    if (socket != null && socket!.connected) return;

    final user = _auth.currentUser;
    if (user == null) return;

    socket = IO.io(app_config.Config.baseUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build());

    socket!.connect();

    socket!.onConnect((_) {
      print('Socket Connected');
      socket!.emit('join_user_room', user.uid);
      updateUnreadCount(); // Fetch initial count on connect
    });

    socket!.on('receive_message', (data) {
      _messageController.add(Map<String, dynamic>.from(data));
      updateUnreadCount(); // Update count on new message
    });

    socket!.on('new_request', (data) {
      _requestController.add(Map<String, dynamic>.from(data));
      updateUnreadCount(); // Update count on new request
    });

    socket!.on('messages_seen', (data) {
      _requestController.add({'type': 'seen', ...Map<String, dynamic>.from(data)});
      updateUnreadCount(); // Update count when messages are seen
    });

    socket!.on('user_status', (data) => _statusController.add(Map<String, dynamic>.from(data)));
    socket!.on('post_interaction', (data) => _postInteractionController.add(Map<String, dynamic>.from(data)));
    
    socket!.on('message_deleted', (data) {
      _messageController.add({'type': 'delete', ...Map<String, dynamic>.from(data)});
    });

    socket!.onDisconnect((_) => print('Socket Disconnected'));
  }

  Future<void> updateUnreadCount() async {
    try {
      final conversations = await getConversations();
      final requests = await getRequests();

      int count = 0;
      
      // Sum unread messages from conversations
      for (var chat in conversations) {
        if (chat['unreadCount'] != null) {
          count += (chat['unreadCount'] as num).toInt();
        }
      }

      // Add requests count (each request is an unread item)
      count += requests.length;

      unreadCount.value = count;
    } catch (e) {
      print('Error updating unread count: $e');
    }
  }

  void disconnect() {
    socket?.disconnect();
    socket = null;
  }

  void markAsRead(String otherUid) {
    if (socket == null || _auth.currentUser == null) return;
    socket!.emit('mark_as_read', {
      'senderUid': otherUid,
      'receiverUid': _auth.currentUser!.uid,
    });
    // Optimistically update or wait for server event? 
    // Usually 'messages_seen' event will trigger updateUnreadCount.
    // But we can also trigger a fetch shortly after to be sure.
    Future.delayed(const Duration(milliseconds: 500), updateUnreadCount);
  }

  void getUserStatus(String uid) {
    if (socket == null) return;
    socket!.emit('get_user_status', uid);
  }

  void enterChat(String otherUid) {
    if (socket == null) return;
    socket!.emit('enter_chat', otherUid);
  }

  void leaveChat() {
     if (socket == null) return;
     socket!.emit('leave_chat');
  }

  // API Calls

  Future<String?> _getToken() async {
    return _auth.currentUser?.getIdToken();
  }

  Future<List<dynamic>> searchUsers(String query) async {
    final token = await _getToken();
    if (token == null) return [];
    
    final response = await http.get(
      Uri.parse('$baseUrl/users/search?query=$query'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }

  Future<List<dynamic>> getConversations() async {
    final token = await _getToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }

  Future<List<dynamic>> getRequests() async {
    final token = await _getToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.parse('$baseUrl/chat/requests'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }

  Future<List<dynamic>> getMessages(String otherUid) async {
    final token = await _getToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.parse('$baseUrl/chat/messages/$otherUid'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>?> uploadMedia(String filePath, bool isVideo, {Function(double)? onProgress}) async {
    final token = await _getToken();
    if (token == null) return null;
    
    try {
      final fileName = filePath.split('/').last;
      final formData = dio.FormData.fromMap({
        'media': await dio.MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post(
        '$baseUrl/chat/upload',
        data: formData,
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress(sent / total);
          }
        },
      );

      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      print('Dio Upload Error: $e');
    }
    return null;
  }

  Future<void> sendMessage(String receiverUid, String content, {String? mediaUrl, String? mediaType, int? parentId, String? parentContent, String? parentMediaType}) async {
    final user = _auth.currentUser;
    if (user == null || socket == null) return;

    socket!.emit('send_message', {
      'senderUid': user.uid,
      'receiverUid': receiverUid,
      'content': content,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'parentId': parentId,
      'parentContent': parentContent,
      'parentMediaType': parentMediaType,
    });
  }

  Future<bool> blockUser(String targetUid) async {
    final token = await _getToken();
    if (token == null) return false;

    final response = await http.post(
      Uri.parse('$baseUrl/chat/block'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({'targetUid': targetUid}),
    );
    return response.statusCode == 200;
  }

  Future<bool> unblockUser(String targetUid) async {
    final token = await _getToken();
    if (token == null) return false;

    final response = await http.post(
      Uri.parse('$baseUrl/chat/unblock'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({'targetUid': targetUid}),
    );
    return response.statusCode == 200;
  }

  Future<List<dynamic>> getBlockedUsers() async {
    final token = await _getToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.parse('$baseUrl/chat/blocked-users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }

  Future<bool> clearConversation(String targetUid) async {
    final token = await _getToken();
    if (token == null) return false;

    final response = await http.post(
      Uri.parse('$baseUrl/chat/clear'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({'targetUid': targetUid}),
    );
    return response.statusCode == 200;
  }

  Future<bool> respondToRequest(String targetUid, String action) async {
    final token = await _getToken();
    if (token == null) return false;

    final response = await http.post(
      Uri.parse('$baseUrl/chat/request/respond'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({'targetUid': targetUid, 'action': action}),
    );
    // After responding (accept/reject), update count as request list changed
    updateUnreadCount();
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> getChatStatus(String otherUid) async {
    final token = await _getToken();
    if (token == null) return {'status': 'none'};

    final response = await http.get(
      Uri.parse('$baseUrl/chat/status/$otherUid'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return {'status': 'none'};
  }

  Future<bool> unsendMessage(int messageId, String receiverUid) async {
    final token = await _getToken();
    if (token == null) return false;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/chat/messages/$messageId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Broadcast via socket so everyone in chat sees it
        socket?.emit('unsend_message', {
          'messageId': messageId,
          'receiverUid': receiverUid,
          'senderUid': _auth.currentUser?.uid,
        });
        return true;
      }
    } catch (e) {
      print('Unsend Error: $e');
    }
    return false;
  }
}

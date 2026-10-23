import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:major_frontend/services/ai_chat_service.dart';
import 'package:major_frontend/screens/auth/auth_screens.dart'; // For AuthService
import 'package:intl/intl.dart';

class CentralAICoachScreen extends StatefulWidget {
  const CentralAICoachScreen({Key? key}) : super(key: key);

  @override
  State<CentralAICoachScreen> createState() => _CentralAICoachScreenState();
}

class _CentralAICoachScreenState extends State<CentralAICoachScreen> {
  final AIChatService _aiChatService = AIChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, String>> _messages = [];
  Map<String, dynamic> _userProfile = {};
  List<dynamic> _workoutHistory = [];
  bool _isLoading = true;
  bool _isTyping = false;
  int _messageCount = 0;
  int _maxMessages = 50;
  bool _showLimitPopup = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _authService.getUserProfile(),
        _aiChatService.getWorkoutHistory(),
        _aiChatService.getCoachHistory(),
      ]);

      if (mounted) {
        setState(() {
          _userProfile = (results[0] as Map<String, dynamic>?) ?? {};
          _workoutHistory = (results[1] as List<dynamic>?) ?? [];
          final history = (results[2] as List<Map<String, String>>?) ?? [];
          
          if (history.isEmpty) {
            _messages = [
              {
                'role': 'assistant',
                'content': 'Hey ${_userProfile['fullName'] ?? 'Athlete'}! I\'m your AI Fitness Coach. How can I help you smash your goals today? 🚀'
              }
            ];
          } else {
            _messages = history;
          }

          // Update premium status
          AuthService.updatePremiumStatus(_userProfile['isPremium'] == true || _userProfile['isPremium'] == 1);
          
          // Process usage info
          _fetchUsage();

          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error loading coach data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUsage() async {
    try {
      final usage = await _aiChatService.getUsageInfo();
      if (mounted) {
        setState(() {
          AuthService.updatePremiumStatus(usage['isPremium'] ?? false);
          final limits = usage['limits'] as List<dynamic>;
          final socialLimit = limits.firstWhere((l) => l['limitType'] == 'social_chat', orElse: () => {'messageCount': 0});
          _messageCount = socialLimit['messageCount'] as int;
          if (!AuthService.isPremiumUser.value && _messageCount >= _maxMessages) {
            _showLimitPopup = true;
          }
        });
      }
    } catch (e) {
      print('Error fetching usage for Gym Bot: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final userMsg = text.trim();
    if (userMsg.isEmpty || _isTyping) return;

    // Check usage limit first
    if (!AuthService.isPremiumUser.value && _messageCount >= _maxMessages) {
      setState(() {
        _showLimitPopup = true;
      });
      return;
    }

    _controller.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': userMsg});
      _isTyping = true;
      _messageCount++;
      if (!AuthService.isPremiumUser.value && _messageCount >= _maxMessages) {
        _showLimitPopup = true;
      }
    });
    _scrollToBottom();
    
    // Increment usage and save message
    _aiChatService.incrementUsage('social_chat');
    _aiChatService.saveCoachMessage('user', userMsg);

    try {
      final response = await _aiChatService.getGeneralCoachResponse(
        userProfile: _userProfile,
        workoutHistory: _workoutHistory,
        chatHistory: _messages.sublist(0, _messages.length - 1),
        userMessage: userMsg,
      );

      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': response});
          _isTyping = false;
        });
        _scrollToBottom();
        _aiChatService.saveCoachMessage('assistant', response);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': 'Sorry, I\'m having trouble connecting. Let\'s try again!'});
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.smart_toy_rounded, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Gym Bot', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                  ValueListenableBuilder<bool>(
                    valueListenable: AuthService.isPremiumUser,
                    builder: (context, isPremium, child) {
                      if (isPremium || _isLoading) return const SizedBox.shrink();
                      return Text(
                        '${_maxMessages - _messageCount}/$_maxMessages left',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFB794F6)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return _buildTypingIndicator();
                    }
                    final msg = _messages[index];
                    final isMe = msg['role'] == 'user';
                    return _buildMessageBubble(msg['content']!, isMe);
                  },
                ),
          ),
          if (!_showLimitPopup) _buildQuickActions(),
          if (_showLimitPopup) _buildLimitPopup(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String content, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
             const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white,
                child: Icon(Icons.smart_toy_rounded, color: Colors.black, size: 16),
             ),
             const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF7B4DFF) : const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                ),
              ),
              child: Text(
                content,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
           const CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white,
              child: Icon(Icons.smart_toy_rounded, color: Colors.black, size: 16),
           ),
           const SizedBox(width: 8),
           Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2C2C2C),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = ['Create a plan', 'Nutrition tips', 'Workout motivation', 'Form check'];
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              backgroundColor: const Color(0xFF2C2C2C),
              label: Text(actions[index], style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide.none,
              onPressed: () => _sendMessage(actions[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: const Color(0xFF1F1F1F),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  enabled: !_showLimitPopup,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: _showLimitPopup ? 'Limit reached' : 'Ask Gym Bot...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (val) => _showLimitPopup ? null : _sendMessage(val),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showLimitPopup ? null : _sendMessage(_controller.text),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _showLimitPopup ? Colors.white10 : const Color(0xFFB794F6),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 3), // Visually center the asymmetrical icon
                    child: Icon(Icons.send_rounded, color: _showLimitPopup ? Colors.white24 : Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitPopup() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3F47),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "You've reached your daily limit. Your messages will reset tomorrow!",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to Premium Upgrade logic
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: const Color(0xFFB794F6),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              "Upgrade to Premium",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

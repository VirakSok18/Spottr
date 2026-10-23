import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:major_frontend/services/ai_chat_service.dart';

class AICoachChatPanel extends StatefulWidget {
  final String exerciseName;
  final List<Map<String, String>> chatHistory;
  final Function(Map<String, String>) onMessageAdded;

  const AICoachChatPanel({
    Key? key,
    required this.exerciseName,
    required this.chatHistory,
    required this.onMessageAdded,
  }) : super(key: key);

  @override
  State<AICoachChatPanel> createState() => _AICoachChatPanelState();
}

class _AICoachChatPanelState extends State<AICoachChatPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIChatService _chatService = AIChatService();
  bool _isLoading = false;
  int _messageCount = 0;
  int _maxMessages = 30;
  bool _isPremium = false;
  bool _showLimitPopup = false;

  final List<String> _defaultQuestions = [
    "How do I do this properly?",
    "What are common mistakes?",
    "What muscles does this work?",
    "I can't do this yet, help?"
  ];

  @override
  void initState() {
    super.initState();
    _fetchUsage();
    // Initial welcome message if history is empty
    if (widget.chatHistory.isEmpty) {
      final welcome = {
        'role': 'assistant',
        'content': 'Hi! I\'m your AI Coach specialized in ${widget.exerciseName}. How can I help you with your form or technique today?'
      };
      widget.onMessageAdded(welcome);
    }
  }

  Future<void> _fetchUsage() async {
    final usage = await _chatService.getUsageInfo();
    if (mounted) {
      setState(() {
        _isPremium = usage['isPremium'] ?? false;
        final limits = usage['limits'] as List<dynamic>;
        final workoutLimit = limits.firstWhere((l) => l['limitType'] == 'workout_chat', orElse: () => {'messageCount': 0});
        _messageCount = workoutLimit['messageCount'] as int;
        if (!_isPremium && _messageCount >= _maxMessages) {
          _showLimitPopup = true;
        }
      });
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

  Future<void> _sendMessage([String? textValue]) async {
    final text = textValue ?? _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Check usage limit first
    if (!_isPremium && _messageCount >= _maxMessages) {
      setState(() {
        _showLimitPopup = true;
      });
      return;
    }

    setState(() {
      final userMsg = {'role': 'user', 'content': text};
      widget.onMessageAdded(userMsg);
      _isLoading = true;
      _messageCount++;
      _controller.clear();
      if (!_isPremium && _messageCount >= _maxMessages) {
        _showLimitPopup = true;
      }
    });
    _scrollToBottom();

    // Increment usage
    _chatService.incrementUsage('workout_chat');

    final response = await _chatService.getAIResponse(
      exerciseName: widget.exerciseName,
      chatHistory: widget.chatHistory.sublist(1, widget.chatHistory.length - 1), 
      userMessage: text,
    );

    if (mounted) {
      setState(() {
        widget.onMessageAdded({'role': 'assistant', 'content': response});
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
          child: Column(
            children: [
          // Handle/Header
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white12,
                  radius: 20,
                  child: Image.asset('assets/images/robot_ai.png', width: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'AI COACH',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!_isPremium)
                            Text(
                              '(${_maxMessages - _messageCount}/$_maxMessages left)',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        'Ask about ${widget.exerciseName}',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        softWrap: true,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          
          // Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: widget.chatHistory.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == widget.chatHistory.length) {
                  return _buildLoadingBubble();
                }
                final message = widget.chatHistory[index];
                final isUser = message['role'] == 'user';
                return _buildChatBubble(message['content']!, isUser);
              },
            ),
          ),

          // Suggestions
          if (!_isLoading && !_showLimitPopup) _buildSuggestions(),

          // Limit Popup Above Input Area
          if (_showLimitPopup) _buildLimitPopup(),
          
          // Input Area
          SafeArea(
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 10),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: GoogleFonts.poppins(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _showLimitPopup ? "Limit reached" : "Ask anything...",
                          hintStyle: GoogleFonts.poppins(color: Colors.white30),
                          border: InputBorder.none,
                          enabled: !_showLimitPopup,
                        ),
                        onSubmitted: (_) => _showLimitPopup ? null : _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showLimitPopup ? null : _sendMessage(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _showLimitPopup ? Colors.white10 : const Color(0xFFB794F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.send_rounded, color: _showLimitPopup ? Colors.white24 : Colors.white, size: 20),
                    ),
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

  Widget _buildSuggestions() {
    return Container(
      height: 50,
      padding: const EdgeInsets.only(bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _defaultQuestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () => _sendMessage(_defaultQuestions[index]),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  _defaultQuestions[index],
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white12,
              child: Image.asset('assets/images/robot_ai.png', width: 16),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser 
                  ? const LinearGradient(
                      colors: [Color(0xFFB794F6), Color(0xFF9F7AEA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
                color: isUser ? null : Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: Border.all(
                  color: isUser ? Colors.white24 : Colors.white10,
                  width: 0.5,
                ),
              ),
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 38), // Space for matching avatar side
        ],
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white12,
            child: Image.asset('assets/images/robot_ai.png', width: 16),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitPopup() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
              // Same behavior as the dialog's upgrade button
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

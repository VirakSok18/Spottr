import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home/home_screen.dart';
import 'home/profile_screen.dart';
import 'home/workouts_screen.dart';
import 'social/community_screen.dart';
import 'social/messages_screen.dart';
import '../services/chat_service.dart';

class MainNavigationWrapper extends StatefulWidget {
  final VoidCallback onLogout;
  const MainNavigationWrapper({Key? key, required this.onLogout}) : super(key: key);

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Initialize Chat Socket globally when app starts
    ChatService().initSocket();
    
    _screens = [
      HomeScreen(onLogout: widget.onLogout, onTabSwitch: _onItemTapped),
      const WorkoutsScreen(),
      const CommunityScreen(),
      const MessagesScreen(),
      ProfilePage(onLogout: widget.onLogout),
    ];
  }

  @override
  void dispose() {
    ChatService().disconnect();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Container(
          height: 75, // Reduced height to lower the background
          decoration: BoxDecoration(
            color: const Color(0xFF1D1F24),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5),
            ),
          ),
          padding: const EdgeInsets.only(top: 6, bottom: 2), // Reduced padding to lower the icons
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
              _buildNavItem(1, Icons.fitness_center_outlined, Icons.fitness_center, 'Workout'),
              _buildCenterNavItem(2, Icons.public),
              _buildNavItem(3, Icons.chat_bubble_outline, Icons.chat_bubble, 'Message'),
              _buildNavItem(4, Icons.person_outline, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    bool isSelected = _selectedIndex == index;
    Color color = isSelected ? const Color(0xFFB794F6) : Colors.grey;

    Widget iconWidget = Icon(
      isSelected ? selectedIcon : unselectedIcon,
      color: color,
      size: 28,
    );

    // Add badge for Message tab (index 3)
    if (index == 3) {
      iconWidget = ValueListenableBuilder<int>(
        valueListenable: ChatService().unreadCount,
        builder: (context, count, child) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              child!,
              if (count > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFB794F6),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
        child: iconWidget,
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterNavItem(int index, IconData icon) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: Color(0xFFB794F6),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // Notification preference states
  bool _pushEnabled = true;
  bool _messagesEnabled = true;
  bool _workoutRemindersEnabled = true;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // Load preferences from local storage
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushEnabled = prefs.getBool('notif_push_enabled') ?? true;
      _messagesEnabled = prefs.getBool('notif_messages_enabled') ?? true;
      _workoutRemindersEnabled = prefs.getBool('notif_workout_enabled') ?? true;
      _isLoading = false;
    });
  }

  // Save specific preference
  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1B1B1B),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFB497FF))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B1B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Control which notifications you receive from Spottr.',
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 32),
            
            _buildSectionHeader('General'),
            _buildSwitchTile(
              title: 'Push Notifications',
              subtitle: 'Allow Spottr to send you push notifications on this device.',
              value: _pushEnabled,
              onChanged: (val) {
                setState(() => _pushEnabled = val);
                _savePreference('notif_push_enabled', val);
              },
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('Activity'),
            
            _buildSwitchTile(
              title: 'Messages',
              subtitle: 'When you receive a direct message.',
              value: _messagesEnabled,
              onChanged: !_pushEnabled ? null : (val) {
                setState(() => _messagesEnabled = val);
                _savePreference('notif_messages_enabled', val);
              },
            ),
            _buildSwitchTile(
              title: 'Workout Reminders',
              subtitle: 'Reminders for your scheduled workouts.',
              value: _workoutRemindersEnabled,
              onChanged: !_pushEnabled ? null : (val) {
                setState(() => _workoutRemindersEnabled = val);
                _savePreference('notif_workout_enabled', val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: const Color(0xFFB497FF),
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool)? onChanged,
  }) {
    // If onChanged is null (disabled state due to master toggle being off), lower opacity
    final bool isDisabled = onChanged == null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: isDisabled ? Colors.white38 : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: isDisabled ? Colors.white24 : Colors.white60,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFB497FF),
            activeTrackColor: const Color(0xFFB497FF).withOpacity(0.5),
            inactiveThumbColor: Colors.grey[400],
            inactiveTrackColor: Colors.grey[800],
          ),
        ],
      ),
    );
  }
}

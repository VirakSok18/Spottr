import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'dart:convert';
import '../auth/auth_screens.dart';
import '../../services/config.dart' as app_config;
import 'workout_execution_screen.dart';
import 'workout_preview_screen.dart';

import 'weekly_victory_dialog.dart';

class PlanDetailScreen extends StatefulWidget {
  final dynamic plan;
  final bool isStructured;

  const PlanDetailScreen({
    Key? key, 
    required this.plan,
    this.isStructured = false,
  }) : super(key: key);

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  Set<int> completedDays = {};
  Set<int> claimedWeeks = {};
  bool _isLoading = true;

  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final planTitle = widget.plan['title'] ?? 'default_plan';
    
    // 1. Load from local cache for instant UI
    final prefs = await SharedPreferences.getInstance();
    final completedList = prefs.getStringList('completed_days_$planTitle') ?? [];
    final claimedList = prefs.getStringList('claimed_weeks_$planTitle') ?? [];
    
    if (mounted) {
      setState(() {
        completedDays = completedList.map((e) => int.parse(e)).toSet();
        claimedWeeks = claimedList.map((e) => int.parse(e)).toSet();
        _isLoading = false;
      });
    }

    // 2. Fetch from Supabase (Source of Truth)
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user != null) {
        final res = await app_config.Config.supabase
            .from('workout_day_progress')
            .select('dayNumber')
            .eq('firebaseUid', user.uid)
            .eq('planTitle', planTitle);

        final Set<int> backendSet = res.map<int>((e) => (e['dayNumber'] as num).toInt()).toSet();
        if (mounted) {
          setState(() {
            completedDays = backendSet;
          });
          await prefs.setStringList(
            'completed_days_$planTitle',
            completedDays.map((e) => e.toString()).toList(),
          );
        }
      }
    } catch (e) {
      print('PlanDetailScreen: Error loading progress from Supabase: $e');
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final planId = widget.plan['title'] ?? 'default_plan';
    
    await prefs.setStringList(
      'completed_days_$planId',
      completedDays.map((e) => e.toString()).toList(),
    );
     await prefs.setStringList(
      'claimed_weeks_$planId',
      claimedWeeks.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _saveDayProgressToBackend(int dayNumber) async {
    try {
      final planTitle = widget.plan['title'] ?? 'default_plan';
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await app_config.Config.supabase.from('workout_day_progress').upsert({
        'firebaseUid': user.uid,
        'planTitle': planTitle,
        'dayNumber': dayNumber,
        'completedAt': DateTime.now().toIso8601String(),
      });
      print('PlanDetailScreen: Successfully saved progress for day $dayNumber to Supabase');
    } catch (e) {
      print('PlanDetailScreen: Error saving progress to Supabase: $e');
    }
  }

  void _scrollToNextWeek(int currentWeekIndex) {
    double offset = (currentWeekIndex + 1) * 350.0; // Approx height
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _showWeeklyVictoryDialog(int weekNum) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WeeklyVictoryDialog(
        weekNum: weekNum,
        onContinue: () {
          Navigator.of(context).pop();
          setState(() {
            claimedWeeks.add(weekNum);
          });
          _saveProgress();
          _scrollToNextWeek(weekNum - 1); // weekNum is 1-based
        },
      ),
    );
  }


  String _extractYoutubeId(String url) {
    RegExp regExp = RegExp(
        r"(?:v=|\/|shorts\/)([0-9A-Za-z_-]{11}).*",
        caseSensitive: false,
        multiLine: false);
    Match? match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return '';
  }

  String _getThumbnailUrl(String url) {
    final id = _extractYoutubeId(url);
    if (id.isEmpty) return '';
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  String _getDayThumbnail(dynamic day, List<dynamic> allDays) {
    Set<String> usedThumbnails = {};
    int index = allDays.indexOf(day);
    
    for (int i = 0; i < index; i++) {
       final prevDay = allDays[i];
       final prevThumb = _pickThumbnail(prevDay, usedThumbnails);
       if (prevThumb.isNotEmpty) usedThumbnails.add(prevThumb);
    }

    return _pickThumbnail(day, usedThumbnails);
  }

  String _pickThumbnail(dynamic day, Set<String> used) {
    final exercises = day['exercises'] as List?;
    if (exercises == null || exercises.isEmpty) return '';
    for (var ex in exercises) {
       final thumb = _getThumbnailUrl(ex['videoUrl'] ?? ex['youtubeUrl'] ?? '');
       if (thumb.isNotEmpty && !used.contains(thumb)) return thumb;
    }
    return _getThumbnailUrl(exercises[0]['videoUrl'] ?? exercises[0]['youtubeUrl'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF8A2BE2))),
      );
    }

    final days = (widget.plan['days'] as List<dynamic>);

    if (widget.isStructured) {
      return _buildStructuredUI(days);
    } else {
      return _buildClassicUI(days);
    }
  }

  Widget _buildStructuredUI(List<dynamic> days) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.plan['title'].toString().toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Days List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                return _buildDayCard(day, days);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassicUI(List<dynamic> days) {
    final totalDays = days.length;
    final finishedDays = completedDays.length;
    final progress = totalDays > 0 ? finishedDays / totalDays : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // Header Image with Title
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.plan['imageUrl'] != null)
                  Image.asset(
                    widget.plan['imageUrl'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF222222)),
                  )
                else
                  Container(color: const Color(0xFF222222)),
                
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                        const Color(0xFF8A2BE2).withOpacity(0.3),
                        const Color(0xFF1A1A1A),
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  bottom: 70,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.plan['title'].toString().toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        '${widget.plan['days']?.length ?? 28} DAY',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                // Back Button
                Positioned(
                  top: 50,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          // Content with Curved Top
          Positioned.fill(
            top: 240,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  physics: const ClampingScrollPhysics(),
                  children: [
                    _buildProgressSection(finishedDays, totalDays, progress),
                    const SizedBox(height: 24),
                    _buildWeeklyTimeline(days),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(int finished, int total, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$finished / $total',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Days Finished',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  height: 8,
                  width: constraints.maxWidth * progress,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8A2BE2), Color(0xFFB794F6), Colors.white],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyTimeline(List<dynamic> days) {
    List<Widget> weekWidgets = [];
    int daysPerWeek = 7;
    int numWeeks = (days.length / daysPerWeek).ceil();

    for (int i = 0; i < numWeeks; i++) {
       int start = i * daysPerWeek;
       int end = (i + 1) * daysPerWeek;
       if (end > days.length) end = days.length;
       List<dynamic> weekDays = days.sublist(start, end);

       weekWidgets.add(_buildWeekRow(i + 1, weekDays));
    }

    return Column(children: weekWidgets);
  }

  Widget _buildWeekRow(int weekNum, List<dynamic> weekDays) {
    bool isWeekCompleted = weekDays.every((d) => d['isRestDay'] == true || completedDays.contains(d['day']));
    bool isAllPlanCompleted = completedDays.length == (widget.plan['days'] as List).length;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF8A2BE2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fitness_center, color: Colors.white, size: 16),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  'WEEK $weekNum',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildDaysGrid(weekDays.sublist(0, (weekDays.length < 4 ? weekDays.length : 4))),
                      const SizedBox(height: 12),
                      _buildDaysGridWithMedal(
                        weekDays.length > 4 ? weekDays.sublist(4) : [], 
                        isWeekCompleted, 
                        isAllPlanCompleted
                      ),
                      if (isWeekCompleted && !claimedWeeks.contains(weekNum) && weekNum < (widget.plan['days'].length / 7)) ...[
                         const SizedBox(height: 16),
                         SizedBox(
                           height: 40,
                           width: double.infinity,
                           child: ElevatedButton(
                             onPressed: () => _showWeeklyVictoryDialog(weekNum),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: const Color(0xFF8A2BE2),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                               padding: EdgeInsets.zero,
                             ),
                             child: Text(
                               'Continue',
                               style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                             ),
                           ),
                         ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysGrid(List<dynamic> rowDays) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int i = 0; i < rowDays.length; i++) ...[
          _buildDayBubble(rowDays[i]),
          if (i < rowDays.length - 1)
            const Icon(Icons.chevron_right, color: Colors.grey, size: 14),
        ]
      ],
    );
  }

  Widget _buildDaysGridWithMedal(List<dynamic> rowDays, bool completed, bool allPlan) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int i = 0; i < rowDays.length; i++) ...[
          _buildDayBubble(rowDays[i]),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 14),
        ],
        _buildMedal(completed, allPlan),
      ],
    );
  }

  Widget _buildMedal(bool weekCompleted, bool allPlan) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Center(
        child: Icon(
          Icons.emoji_events_rounded,
          color: weekCompleted 
            ? const Color(0xFFFFD700)
            : Colors.white.withOpacity(0.1),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildDayBubble(dynamic day) {
    int num = day['day'] ?? (widget.plan['days'].indexOf(day) + 1);
    bool isRest = day['isRestDay'] == true;
    bool finished = completedDays.contains(num);
    bool locked = !isRest && !finished && _isDayLocked(num);

    return GestureDetector(
      onTap: () => _onDayTap(day),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: finished
              ? const Color(0xFFB794F6)
              : (isRest 
                  ? Colors.grey.withOpacity(0.1) 
                  : (locked 
                      ? Colors.white.withOpacity(0.05)
                      : const Color(0xFFD9D9D9).withOpacity(0.1))),
          shape: BoxShape.circle,
          border: locked ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
        ),
        child: Center(
          child: locked 
              ? Icon(Icons.lock, color: Colors.white.withOpacity(0.3), size: 16)
              : Text(
                  isRest ? 'R' : '$num',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isRest ? Colors.grey : Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  bool _isDayLocked(int dayNumber) {
    if (widget.isStructured) return false; // Structured plans (everything else) are not locked
    if (dayNumber == 1) return false;
    
    final days = widget.plan['days'] as List<dynamic>;
    bool allPriorCompleted = true;
    for (var d in days) {
      int dNum = d['day'] ?? (days.indexOf(d) + 1);
      if (dNum >= dayNumber) break;
      
      bool isRest = d['isRestDay'] == true;
      if (!isRest && !completedDays.contains(dNum)) {
        allPriorCompleted = false;
        break;
      }
    }
    return !allPriorCompleted;
  }

  void _onDayTap(dynamic day) async {
    final dayNumber = day['day'] ?? ((widget.plan['days'] as List).indexOf(day) + 1);
    final isRestDay = day['isRestDay'] == true;
    final exercises = day['exercises'];

    if (isRestDay) return;
    
    if (_isDayLocked(dayNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete previous workouts to unlock this day! 🔒'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (exercises == null || exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No exercises for this day')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutPreviewScreen(
          plan: widget.plan,
          day: {
            'day': dayNumber,
            'title': day['title'] ?? 'Day $dayNumber',
            'exercises': exercises,
          },
        ),
      ),
    );

    if (result == true) {
      if (mounted) {
        setState(() {
          completedDays.add(dayNumber);
        });
        _saveProgress();
        _saveDayProgressToBackend(dayNumber);
      }
    }
  }

  Widget _buildDayCard(dynamic day, List<dynamic> allDays) {
    final dayNumber = day['day'] ?? (allDays.indexOf(day) + 1);
    final isRest = day['isRestDay'] == true;
    final finished = completedDays.contains(dayNumber);
    final locked = !isRest && !finished && _isDayLocked(dayNumber);
    final thumbnailUrl = _getDayThumbnail(day, allDays);
    
    // Subtitle logic
    String subtitle = day['routine'] ?? day['title'] ?? 'Workout Session';
    if (isRest) subtitle = 'Rest Day';

    return GestureDetector(
      onTap: () => _onDayTap(day),
      child: Container(
        height: 220,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF1E1E1E),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              if (thumbnailUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.white10),
                  errorWidget: (context, url, error) => Container(color: const Color(0xFF222222)),
                )
              else
                Container(color: const Color(0xFF222222)),

              // Overlay Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // Card Content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Difficulty Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB794F6).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.plan['difficulty']?.toString() ?? 'Medium',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Day Number
                    Text(
                      'Day $dayNumber',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    // Routine/Focus
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Lock Overlay
              if (locked)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Icon(
                      Icons.lock,
                      color: Colors.white.withOpacity(0.5),
                      size: 48,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:major_frontend/widgets/ai_coach_chat_panel.dart';
import 'dart:async';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:major_frontend/services/notification_service.dart';
import 'package:major_frontend/services/ai_chat_service.dart';
import '../../widgets/exercise_info_dialog.dart';
import 'workout_completion_screen.dart';

class WorkoutExecutionScreen extends StatefulWidget {
  final List<dynamic> exercises;
  final String dayTitle;
  final String workoutName;
  final int initialIndex;
  final String difficulty;
  final String? coverUrl;

  const WorkoutExecutionScreen({
    Key? key,
    required this.exercises,
    required this.dayTitle,
    required this.workoutName,
    this.initialIndex = 0,
    this.difficulty = 'Medium',
    this.coverUrl,
  }) : super(key: key);

  @override
  State<WorkoutExecutionScreen> createState() => _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends State<WorkoutExecutionScreen> with WidgetsBindingObserver {
  int currentIndex = 0;
  bool isPaused = false;
  int remainingSeconds = 30;
  Timer? _timer;
  bool isResting = false;
  int restSeconds = 20;
  bool isReady = true; // All exercises start with "Ready" state
  
  DateTime? _lastReminderScheduled; // To prevent rapid-fire scheduling
  bool _isExiting = false;

  Map<int, YoutubePlayerController> _controllers = {};
  final List<Map<String, String>> _aiChatHistory = []; // Add this
  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    currentIndex = widget.initialIndex;
    _preloadController(currentIndex);
    _preloadController(currentIndex + 1);
    _initExercise();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Debounce: Only schedule if we haven't scheduled in the last 5 seconds
      final now = DateTime.now();
      if (_lastReminderScheduled == null || 
          now.difference(_lastReminderScheduled!).inSeconds > 5) {
        
        print("App backgrounded - scheduling 10s reminder");
        _lastReminderScheduled = now;
        NotificationService().scheduleReminderOnBackend(delaySeconds: 10);
      }
    } else if (state == AppLifecycleState.resumed) {
      // Small reset if user comes back
      _lastReminderScheduled = null;
      NotificationService().cancelLocalReminder(999);
    }
  }

  void _preloadController(int index) {
    if (index < 0 || index >= widget.exercises.length) return;
    if (_controllers.containsKey(index)) return;

    final exercise = widget.exercises[index];
    String videoId = "";
    if (exercise['youtubeId'] != null && exercise['youtubeId'].toString().isNotEmpty) {
      videoId = exercise['youtubeId'];
    } else if (exercise['videoUrl'] != null && exercise['videoUrl'].contains('youtube.com')) {
      videoId = YoutubePlayer.convertUrlToId(exercise['videoUrl']) ?? "";
    }

    if (videoId.isNotEmpty) {
      final controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: true,
          loop: true,
          hideControls: true,
          disableDragSeek: true,
        ),
      );
      _controllers[index] = controller;
      print('Preloaded controller for exercise $index: $videoId');
    }
  }

  YoutubePlayerController? _getController(int index) {
    if (!_controllers.containsKey(index)) {
      _preloadController(index);
    }
    return _controllers[index];
  }

  void _initExercise() {
    final exercise = widget.exercises[currentIndex];
    bool isTimed = exercise['type'] == 'timed' || exercise['duration'] != null;
    
    // Ensure current and next are preloaded
    _preloadController(currentIndex);
    _preloadController(currentIndex + 1);

    // Cleanup old controllers (keep range [currentIndex - 1, currentIndex + 2])
    final keysToRemove = _controllers.keys.where((k) => k < currentIndex - 1 || k > currentIndex + 2).toList();
    for (var key in keysToRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
    }

    if (isTimed) {
      remainingSeconds = exercise['duration'] ?? 30;
    }
    
    setState(() {
      isReady = true;
      isPaused = false;
      isResting = false;
    });
    
    _timer?.cancel();
  }

  void _startTimer({required VoidCallback onComplete}) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused && !isReady) {
        setState(() {
          if (isResting) {
            if (restSeconds > 0) {
              restSeconds--;
            } else {
              _timer?.cancel();
              onComplete();
            }
          } else {
            if (remainingSeconds > 0) {
              remainingSeconds--;
            } else {
              _timer?.cancel();
              onComplete();
            }
          }
        });
      }
    });
  }

  void _goToRest() {
    if (currentIndex >= widget.exercises.length - 1) {
      _showCompletionDialog();
      return;
    }

    setState(() {
      isResting = true;
      restSeconds = 20;
      isReady = false;
      isPaused = false; // Reset pause state for rest timer
    });
    _getController(currentIndex)?.pause();
    _startTimer(onComplete: _nextExercise);
  }

  void _nextExercise() {
    if (currentIndex < widget.exercises.length - 1) {
      setState(() {
        currentIndex++;
      });
      _initExercise();
    } else {
      _showCompletionDialog();
    }
  }

  void _previousExercise() {
    if (currentIndex > 0) {
      _getController(currentIndex)?.pause();
      setState(() {
        currentIndex--;
      });
      _initExercise();
    }
  }

  void _handleExit([dynamic result]) {
    if (_isExiting) return;
    setState(() {
      _isExiting = true;
    });
    _timer?.cancel();
    _controllers.forEach((_, controller) {
      try {
        controller.pause();
      } catch (_) {}
    });
    Navigator.of(context).pop(result);
  }

  void _showCompletionDialog() {
    // Log workout to backend before showing completion screen
    AIChatService().logWorkout(
      workoutName: widget.workoutName,
      exercises: widget.exercises,
      duration: (DateTime.now().difference(_startTime)).inMinutes,
      caloriesBurned: (widget.exercises.length * 50), // Estimate
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutCompletionScreen(
          workoutName: widget.workoutName,
          exercisesCount: widget.exercises.length,
          intensity: widget.difficulty,
          coverUrl: widget.coverUrl,
          onFinish: () {
            Navigator.of(context).pop(true); // Return 'true' from WorkoutCompletionScreen
          },
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        _handleExit(true); // Return 'true' from WorkoutExecutionScreen to mark progress
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exercises.isEmpty) return const SizedBox();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExit(result);
      },
      child: Scaffold(
        backgroundColor: isResting ? const Color(0xFF8A2BE2) : const Color(0xFF1B1B1B),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopProgress(),
              Expanded(
                child: isResting ? _buildRestView() : _buildExecutionView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Row(
        children: List.generate(widget.exercises.length, (index) {
          bool isCompleted = index < currentIndex;
          bool isCurrent = index == currentIndex;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isCompleted || isCurrent 
                    ? Colors.white 
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildExecutionView() {
    final exercise = widget.exercises[currentIndex];

    return Stack(
      children: [
        // Main Visual Area
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0), // Lifted
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.white70, size: 28),
                    onPressed: () => _handleExit(),
                  ),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currentIndex < widget.exercises.length - 1 
                            ? widget.exercises[currentIndex + 1]['name'] 
                            : "Finish",
                          textAlign: TextAlign.end,
                          softWrap: true,
                          style: GoogleFonts.poppins(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 22, // Increased size for better hierarchy
                          ),
                        ),
                        Text(
                          'Next',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.5), 
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                         GestureDetector(
                           onTap: () => _showAICoachChat(exercise['name']),
                           child: _buildAIBotIcon(),
                         ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Dynamic spacing based on screen height to avoid overflow
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            _buildExerciseVideo(exercise),
            const Spacer(),
          ],
        ),
        
        // Bottom Dashboard
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.32, // Lowered for better space balance
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        exercise['name'],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => ExerciseInfoDialog(exercise: exercise),
                        );
                      },
                      child: const Icon(Icons.help_outline, color: Color(0xFF8A2BE2), size: 24),
                    ),
                  ],
                ),
                const Spacer(),
                _buildValueDisplay(exercise),
                const Spacer(),
                _buildControls(exercise),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseVideo(dynamic exercise) {
    final controller = _getController(currentIndex);
    if (controller != null && !_isExiting) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.28, // Dynamic height
        width: double.infinity,
        child: YoutubePlayer(
          key: ValueKey(exercise['youtubeId'] ?? exercise['id']),
          controller: controller,
          showVideoProgressIndicator: false,
          progressIndicatorColor: const Color(0xFF8A2BE2),
        ),
      );
    }

    // Fallback to GIF or static image
    String imageUrl = exercise['imageUrl'] ?? "";
    if (imageUrl.isEmpty && exercise['gifUrl'] != null) imageUrl = exercise['gifUrl'];
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.28,
      width: double.infinity,
      child: imageUrl.isNotEmpty 
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Color(0xFF8A2BE2))),
              errorWidget: (context, url, error) => const Icon(Icons.fitness_center, color: Colors.white, size: 100),
            )
          : const Icon(Icons.fitness_center, color: Colors.white, size: 100),
    );
  }

  Widget _buildValueDisplay(dynamic exercise) {
    bool isTimed = exercise['type'] == 'timed' || exercise['duration'] != null;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isTimed ? 'TIME REMAINING' : '${exercise['sets'] ?? 3} SETS',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black38,
            letterSpacing: 2,
          ),
        ),
        Text(
          isTimed ? _formatSeconds(remainingSeconds) : 'x ${exercise['reps'] ?? 30}',
          style: GoogleFonts.poppins(
            fontSize: 70,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            height: 1.1,
            letterSpacing: -2,
          ),
        ),
      ],
    );
  }

  String _formatSeconds(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildControls(dynamic exercise) {
    bool isTimed = exercise['type'] == 'timed' || exercise['duration'] != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 50, color: Colors.black),
          onPressed: _previousExercise,
        ),
        GestureDetector(
          onTap: () {
            final controller = _getController(currentIndex);
            if (isReady) {
              // Clicking Tick for the first time
              setState(() {
                isReady = false;
                isPaused = false;
              });
                // Robust start mechanism
                void tryPlay(int attempts) {
                  if (attempts <= 0 || !mounted || isPaused) return;
                  
                  final currentController = _getController(currentIndex);
                  if (currentController != null) {
                    currentController.play();
                    
                    // If not playing yet, try again in 300ms
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted && !currentController.value.isPlaying && !isPaused) {
                        currentController.pause(); // Reset nudge
                        currentController.play();
                        tryPlay(attempts - 1);
                      }
                    });
                  }
                }

                tryPlay(3); // Try up to 3 times to start the video

              if (isTimed) {
                _startTimer(onComplete: _goToRest);
              }
            } else {
              // After ready, it's a play/pause button that controls the video and timer
              setState(() {
                isPaused = !isPaused;
              });
              if (isPaused) {
                controller?.pause();
              } else {
                controller?.play();
              }
            }
          },
          child: Container(
            width: 140,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF8A2BE2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              isReady 
                  ? Icons.check_rounded // Initial tick
                  : (isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded), // Follow-up Play/Pause
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 50, color: Colors.black),
          onPressed: _goToRest,
        ),
      ],
    );
  }

  Widget _buildAIBotIcon() {
    return SizedBox(
      width: 40,
      height: 32,
      child: Image.asset(
        'assets/images/robot_ai.png',
        fit: BoxFit.contain,
      ),
    );
  }

  void _showAICoachChat(String exerciseName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return AICoachChatPanel(
              exerciseName: exerciseName,
              chatHistory: _aiChatHistory, // Pass history
              onMessageAdded: (message) {
                _aiChatHistory.add(message); // Maintain context
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRestView() {
    final nextExercise = currentIndex < widget.exercises.length - 1 
        ? widget.exercises[currentIndex + 1] 
        : null;

    String nextImage = "";
    if (nextExercise != null) {
      if (nextExercise['youtubeId'] != null && nextExercise['youtubeId'].toString().isNotEmpty) {
        nextImage = "https://img.youtube.com/vi/${nextExercise['youtubeId']}/0.jpg";
      } else {
        nextImage = nextExercise['imageUrl'] ?? nextExercise['gifUrl'] ?? "";
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const Spacer(),
          Text(
            'Rest',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _formatSeconds(restSeconds),
            style: GoogleFonts.poppins(
              fontSize: 80,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               _buildRestButton('+10s', () => setState(() => restSeconds += 10)),
               const SizedBox(width: 20),
               _buildRestButton('Skip', _nextExercise),
            ],
          ),
          const Spacer(),
          if (nextExercise != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEXT ${currentIndex + 2}/${widget.exercises.length}',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    nextExercise['name'],
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Center(
                      child: nextImage.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: nextImage,
                              fit: BoxFit.contain,
                            )
                          : const Icon(Icons.fitness_center, color: Colors.white, size: 60),
                    ),
                    Positioned(
                      top: 10,
                      right: 15,
                      child: Text(
                        '${nextExercise['sets'] ?? 3}x${nextExercise['reps'] ?? 30}',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRestButton(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.3),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
    );
  }
}

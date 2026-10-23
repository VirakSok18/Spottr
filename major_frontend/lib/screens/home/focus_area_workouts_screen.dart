import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/local_exercise_service.dart';
import '../../models/workout_models.dart';
import 'workout_execution_screen.dart';

class FocusAreaWorkoutsScreen extends StatefulWidget {
  final String focusArea;
  final String targetMuscle;
  final String filterType; // 'muscle', 'difficulty', 'equipment'

  const FocusAreaWorkoutsScreen({
    Key? key,
    required this.focusArea,
    required this.targetMuscle,
    this.filterType = 'muscle',
  }) : super(key: key);

  @override
  State<FocusAreaWorkoutsScreen> createState() => _FocusAreaWorkoutsScreenState();
}

class _FocusAreaWorkoutsScreenState extends State<FocusAreaWorkoutsScreen> {
  List<Exercise> exercises = [];
  bool isLoading = true;
  String searchQuery = "";
  String _selectedDifficulty = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    List<Exercise> results = [];
    
    if (widget.targetMuscle == 'all') {
      results = await LocalExerciseService.getAllExercises();
    } else {
      switch (widget.filterType) {
        case 'muscle':
          results = await LocalExerciseService.getExercisesByTarget(widget.targetMuscle);
          break;
        case 'difficulty':
          results = await LocalExerciseService.getExercisesByDifficulty(widget.targetMuscle);
          break;
        case 'equipment':
          results = await LocalExerciseService.getExercisesByEquipment(widget.targetMuscle);
          break;
        case 'location':
          results = await LocalExerciseService.getExercisesByLocation(widget.targetMuscle);
          break;
        case 'search':
          results = await LocalExerciseService.getAllExercises();
          break;
        default:
          results = await LocalExerciseService.getExercisesByTarget(widget.targetMuscle);
      }
    }

    if (mounted) {
      setState(() {
        exercises = results;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredExercises = exercises.where((e) {
      final matchesSearch = e.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          e.targetMuscle.toLowerCase().contains(searchQuery.toLowerCase());
      
      if (_selectedDifficulty == 'All') return matchesSearch;
      
      final diff = e.difficulty.toLowerCase();
      final target = _selectedDifficulty.toLowerCase();
      
      // Handle Expert/Advanced equivalence
      if (target == 'expert') {
        return matchesSearch && (diff == 'expert' || diff == 'advanced');
      }
      
      return matchesSearch && diff == target;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.focusArea.toUpperCase(),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          if (widget.filterType != 'difficulty')
            IconButton(
              icon: const Icon(Icons.filter_list, color: Color(0xFFB497FF)),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => _FilterOptionsSheet(
                    selectedDifficulty: _selectedDifficulty,
                    onSelect: (value) {
                      setState(() => _selectedDifficulty = value);
                    },
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search exercises...",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFB497FF), size: 20),
                  suffixIcon: searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => searchQuery = "");
                        },
                      )
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onChanged: (val) => setState(() => searchQuery = val),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8A2BE2)))
                : filteredExercises.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, color: Colors.white24, size: 60),
                            const SizedBox(height: 16),
                            Text(
                              searchQuery.isEmpty ? 'No exercises found' : 'No results for "$searchQuery"',
                              style: const TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        itemCount: filteredExercises.length,
                        separatorBuilder: (context, index) => Divider(
                          color: Colors.white.withOpacity(0.12),
                          thickness: 1,
                          height: 24,
                        ),
                        itemBuilder: (context, index) {
                          final exercise = filteredExercises[index];
                          return _buildExerciseListItem(exercise, index, filteredExercises);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseListItem(Exercise exercise, int index, List<Exercise> list) {
    final thumbUrl = exercise.youtubeId != null && exercise.youtubeId!.isNotEmpty
        ? "https://img.youtube.com/vi/${exercise.youtubeId}/hqdefault.jpg"
        : null;

    return Container(
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            // Slight delay to allow the ripple animation to be visible
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkoutExecutionScreen(
                      exercises: list.map((e) => e.toExecutionMap()).toList(),
                      dayTitle: widget.focusArea,
                      workoutName: exercise.name,
                      initialIndex: index,
                      difficulty: exercise.difficulty,
                      coverUrl: "https://img.youtube.com/vi/${exercise.youtubeId}/0.jpg",
                    ),
                  ),
                );
              }
            });
          },
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Padding(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 90,
                    height: 90,
                    color: Colors.black26,
                    child: thumbUrl != null
                        ? CachedNetworkImage(
                            imageUrl: thumbUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB794F6)),
                            ),
                            errorWidget: (context, url, error) => const Icon(Icons.fitness_center, color: Colors.white24),
                          )
                        : const Icon(Icons.fitness_center, color: Colors.white24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Exercise.capitalize(exercise.difficulty),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterOptionsSheet extends StatelessWidget {
  final String selectedDifficulty;
  final ValueChanged<String> onSelect;

  const _FilterOptionsSheet({
    Key? key,
    required this.selectedDifficulty,
    required this.onSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<String> options = ['All', 'Beginner', 'Intermediate', 'Expert'];
    
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
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
          const SizedBox(height: 16),
          ...options.map((choice) {
            final isSelected = selectedDifficulty == choice;
            return ListTile(
              title: Text(
                choice,
                style: GoogleFonts.poppins(
                  color: isSelected ? const Color(0xFFB497FF) : Colors.white,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              onTap: () {
                onSelect(choice);
                Navigator.pop(context);
              },
            );
          }).toList(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

// --- Base Styled Page Wrapper ---
class SelectionPageWrapper extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onDone;
  const SelectionPageWrapper({
    Key? key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.onDone,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B1B),
        elevation: 0,
        surfaceTintColor: const Color(0xFF1B1B1B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onDone,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Expanded(child: child),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Gender Selection ---
class GenderSelectionPage extends StatefulWidget {
  final String? initialValue;
  const GenderSelectionPage({Key? key, this.initialValue}) : super(key: key);

  @override
  State<GenderSelectionPage> createState() => _GenderSelectionPageState();
}

class _GenderSelectionPageState extends State<GenderSelectionPage> {
  late String _selected;
  final List<String> _genders = ['Man', 'Woman', 'Non Binary', 'Other'];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue ?? 'Man';
  }

  @override
  Widget build(BuildContext context) {
    return SelectionPageWrapper(
      title: 'My Gender',
      onDone: () => Navigator.pop(context, {'gender': _selected}),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 60),
        itemCount: _genders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final g = _genders[index];
          final isSelected = g == _selected;
          return GestureDetector(
            onTap: () => setState(() => _selected = g),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4A4A4A) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFFB497FF) : Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                g,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- Looking For Selection ---
class LookingForSelectionPage extends StatefulWidget {
  final String? initialValue;
  const LookingForSelectionPage({Key? key, this.initialValue}) : super(key: key);

  @override
  State<LookingForSelectionPage> createState() => _LookingForSelectionPageState();
}

class _LookingForSelectionPageState extends State<LookingForSelectionPage> {
  String? _selected;
  final List<Map<String, dynamic>> _options = [
    {'label': 'Workout Buddy', 'icon': Icons.fitness_center},
    {'label': 'Cardio Buddy', 'icon': Icons.directions_run},
    {'label': 'Sports Partner', 'icon': Icons.sports_basketball},
    {'label': 'Fitness Accountability', 'icon': Icons.chat_bubble_outline},
    {'label': 'General Fitness Buddy', 'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return SelectionPageWrapper(
      title: 'Looking For',
      subtitle: 'What Kind of Fitness Partner Are You Mainly Looking For?\nThis sets the focus for your matches.',
      onDone: () => Navigator.pop(context, {'looking_for': _selected}),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 60),
        itemCount: _options.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final opt = _options[index];
          final isSelected = opt['label'] == _selected;
          return GestureDetector(
            onTap: () => setState(() => _selected = opt['label']),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF252525),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFFB497FF) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                   Text(
                    opt['label'],
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(opt['icon'], color: const Color(0xFFB497FF), size: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- Preference Selection ---
class PreferenceSelectionPage extends StatefulWidget {
  final String? lookingFor;
  final List<String> initialPreferences;

  const PreferenceSelectionPage({
    Key? key,
    this.lookingFor,
    required this.initialPreferences,
  }) : super(key: key);

  @override
  State<PreferenceSelectionPage> createState() => _PreferenceSelectionPageState();
}

class _PreferenceSelectionPageState extends State<PreferenceSelectionPage> {
  late List<String> _selected;

  final Map<String, List<String>> _categories = {
    'Gym & Strength': ['Strength Training', 'Weight Training', 'Full Body', 'Machines', 'Bodyweight', 'HIIT', 'Free Weights'],
    'Sport': ['Basketball', 'Football', 'Tennis', 'Swimming', 'Cycling', 'Volleyball'],
    'Accountability': ['Daily Check-in', 'Meal Tracking', 'Goal Setting', 'Progress Photos'],
    'Cardio': ['Running', 'Jogging', 'Walking', 'Sprint', 'HIIT Cardio'],
    'General': ['Weight Loss', 'Flexibility', 'Post Partum', 'Senior Fitness'],
  };

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialPreferences);
  }

  String _getRecommendedCategory() {
    if (widget.lookingFor == null) return 'Gym & Strength';
    final lf = widget.lookingFor!.toLowerCase();
    if (lf.contains('workout') || lf.contains('strength')) return 'Gym & Strength';
    if (lf.contains('cardio')) return 'Cardio';
    if (lf.contains('sport')) return 'Sport';
    if (lf.contains('accountability')) return 'Accountability';
    return 'General';
  }

  @override
  Widget build(BuildContext context) {
    final hasLookingFor = widget.lookingFor != null;
    final recommended = hasLookingFor ? _getRecommendedCategory() : null;
    final sortedCategories = _categories.keys.toList();
    if (hasLookingFor) {
      sortedCategories.remove(recommended);
      sortedCategories.insert(0, recommended!);
    }

    return SelectionPageWrapper(
      title: 'Preference',
      onDone: () => Navigator.pop(context, {'preferences': _selected}),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < sortedCategories.length; i++) ...[
              _buildCategoryHeader(
                sortedCategories[i], 
                isRecommended: hasLookingFor && i == 0,
                isFirstOptional: (hasLookingFor && i == 1) || (!hasLookingFor && i == 0),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _categories[sortedCategories[i]]!.map((pref) {
                  final isSelected = _selected.contains(pref);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selected.remove(pref);
                        } else {
                          _selected.add(pref);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFB497FF).withOpacity(0.3) : const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFB497FF) : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        pref,
                        style: GoogleFonts.poppins(
                          color: isSelected ? const Color(0xFFB497FF) : Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title, {bool isRecommended = false, bool isFirstOptional = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isRecommended) ...[
          Text(
            'Recommended for you',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
        ] else if (isFirstOptional) ...[
            Text(
            'Optional Activities',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          title,
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// --- Training Level Selection (Grid Style) ---
class TrainingLevelSelectionPage extends StatefulWidget {
  final String? initialValue;
  const TrainingLevelSelectionPage({Key? key, this.initialValue}) : super(key: key);

  @override
  State<TrainingLevelSelectionPage> createState() => _TrainingLevelSelectionPageState();
}

class _TrainingLevelSelectionPageState extends State<TrainingLevelSelectionPage> {
  String? _selected;
  final List<String> _levels = ['Beginner', 'Irregular Training', 'Medium', 'Advanced'];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return SelectionPageWrapper(
      title: 'Training Level',
      subtitle: 'Helps Match You With People At A Similar Pace\n[Not About Skill — Just Comfort Level]',
      onDone: () => Navigator.pop(context, {'training_level': _selected}),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 60),
        itemCount: _levels.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final l = _levels[index];
          final isSelected = l == _selected;
          return GestureDetector(
            onTap: () => setState(() => _selected = l),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF252525),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFFB497FF) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Text(
                l,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- Experience Selection Page ---
class ExperienceSelectionPage extends StatefulWidget {
  final int? initialValue;
  const ExperienceSelectionPage({Key? key, this.initialValue}) : super(key: key);

  @override
  State<ExperienceSelectionPage> createState() => _ExperienceSelectionPageState();
}

class _ExperienceSelectionPageState extends State<ExperienceSelectionPage> {
  late int _selected;
  late FixedExtentScrollController _scrollController;
  final List<int> _years = List.generate(51, (index) => index);

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue ?? 1;
    _scrollController = FixedExtentScrollController(
      initialItem: _selected,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionPageWrapper(
      title: 'Fitness Experience',
      subtitle: 'How many years have you been training?',
      onDone: () => Navigator.pop(context, {'experience': _selected}),
      child: Column(
        children: [
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$_selected',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _selected == 1 ? 'Year' : 'Years',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            flex: 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Container(
                    width: 100,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB497FF),
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                ListWheelScrollView.useDelegate(
                  controller: _scrollController,
                  itemExtent: 70,
                  perspective: 0.005,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selected = _years[index];
                    });
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: _years.length,
                    builder: (context, index) {
                      final year = _years[index];
                      final isSelected = year == _selected;
                      return Center(
                        child: Text(
                          '$year',
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontSize: isSelected ? 40 : 28,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  right: 20,
                  child: const Icon(Icons.arrow_left, color: Colors.white, size: 40),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// --- Age Selection Page ---
class AgeSelectionPage extends StatefulWidget {
  final int? initialValue;
  const AgeSelectionPage({Key? key, this.initialValue}) : super(key: key);

  @override
  State<AgeSelectionPage> createState() => _AgeSelectionPageState();
}

class _AgeSelectionPageState extends State<AgeSelectionPage> {
  late int _selected;
  late FixedExtentScrollController _scrollController;
  final List<int> _ages = List.generate(88, (index) => index + 13); // 13 to 100

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue ?? 25;
    final initialIndex = _ages.indexOf(_selected);
    _scrollController = FixedExtentScrollController(
      initialItem: initialIndex != -1 ? initialIndex : 12, // Default to index for 25 if not found
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionPageWrapper(
      title: 'My Age',
      subtitle: 'How old are you?',
      onDone: () => Navigator.pop(context, {'age': _selected}),
      child: Column(
        children: [
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$_selected',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Years',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            flex: 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Container(
                    width: 100,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB497FF),
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                ListWheelScrollView.useDelegate(
                  controller: _scrollController,
                  itemExtent: 70,
                  perspective: 0.005,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selected = _ages[index];
                    });
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: _ages.length,
                    builder: (context, index) {
                      final age = _ages[index];
                      final isSelected = age == _selected;
                      return Center(
                        child: Text(
                          '$age',
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontSize: isSelected ? 40 : 28,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  right: 20,
                  child: const Icon(Icons.arrow_left, color: Colors.white, size: 40),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// --- Workout Frequency Selection (Days per week) ---
class FrequencySelectionPage extends StatefulWidget {
  final int initialValue;
  const FrequencySelectionPage({Key? key, required this.initialValue}) : super(key: key);

  @override
  State<FrequencySelectionPage> createState() => _FrequencySelectionPageState();
}

class _FrequencySelectionPageState extends State<FrequencySelectionPage> {
  late int _selected;
  late FixedExtentScrollController _scrollController;
  final List<int> _days = [1, 2, 3, 4, 5, 6, 7];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    _scrollController = FixedExtentScrollController(
      initialItem: _days.indexOf(_selected) != -1 ? _days.indexOf(_selected) : 2,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionPageWrapper(
      title: 'Workout Frequency',
      subtitle: 'How many days per week do you want to train?',
      onDone: () => Navigator.pop(context, {'workout_frequency': _selected}),
      child: Column(
        children: [
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$_selected',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _selected == 1 ? 'Day' : 'Days',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            flex: 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Container(
                    width: 100,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB497FF),
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                ListWheelScrollView.useDelegate(
                  controller: _scrollController,
                  itemExtent: 70,
                  perspective: 0.005,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selected = _days[index];
                    });
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: _days.length,
                    builder: (context, index) {
                      final day = _days[index];
                      final isSelected = day == _selected;
                      return Center(
                        child: Text(
                          '$day',
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontSize: isSelected ? 40 : 28,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  right: 20,
                  child: const Icon(Icons.arrow_left, color: Colors.white, size: 40),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// --- Availability Selection ---
// --- Availability Selection ---
class AvailabilitySelectionPage extends StatefulWidget {
  final List<String> initialAvailability;
  final Map<String, String> initialTimeSpans;

  const AvailabilitySelectionPage({
    Key? key, 
    required this.initialAvailability,
    this.initialTimeSpans = const {},
  }) : super(key: key);

  @override
  State<AvailabilitySelectionPage> createState() => _AvailabilitySelectionPageState();
}

class _AvailabilitySelectionPageState extends State<AvailabilitySelectionPage> {
  late List<String> _selected;
  late Map<String, String> _timeSpans;
  final List<String> _options = ['Morning', 'Afternoon', 'Evening', 'Night'];
  
  // Define allowed ranges for each period
  final Map<String, List<int>> _ranges = {
    'Morning': [5, 12],
    'Afternoon': [12, 17],
    'Evening': [17, 21],
    'Night': [21, 5], // 21:00 to 05:00
  };

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialAvailability);
    _timeSpans = Map.from(widget.initialTimeSpans);
    
    // Initialize default time spans if they don't exist
    for (var option in _options) {
      if (!_timeSpans.containsKey(option)) {
        final start = _ranges[option]![0];
        final end = _ranges[option]![1];
        _timeSpans[option] = '${start.toString().padLeft(2, '0')}:00 - ${end.toString().padLeft(2, '0')}:00';
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return SelectionPageWrapper(
      title: 'Availability',
      onDone: () => Navigator.pop(context, {
        'availability': _selected,
        'availability_time_spans': _timeSpans,
      }),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 20),
              itemCount: _options.length,
              itemBuilder: (context, index) {
                final option = _options[index];
                final isSelected = _selected.contains(option);
                return _buildOptionItem(option, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem(String option, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFFB497FF) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selected.remove(option);
                } else {
                  _selected.add(option);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFB497FF).withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    _getIconForOption(option),
                    color: isSelected ? const Color(0xFFB497FF) : Colors.grey,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    option,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Color(0xFFB497FF))
                  else
                    const Icon(Icons.circle_outlined, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (isSelected)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  Text(
                    'Select specific time span:',
                    style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  _buildTimeSpanPickers(option),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIconForOption(String option) {
    switch (option) {
      case 'Morning': return Icons.wb_sunny_outlined;
      case 'Afternoon': return Icons.wb_cloudy_outlined;
      case 'Evening': return Icons.wb_twilight;
      case 'Night': return Icons.nightlight_round_outlined;
      default: return Icons.access_time;
    }
  }

  Widget _buildTimeSpanPickers(String option) {
    final range = _ranges[option]!;
    final span = _timeSpans[option]!;
    final parts = span.split(' - ');
    final startStr = parts[0];
    final endStr = parts[1];
    
    final startHour = int.parse(startStr.split(':')[0]);
    final startMin = int.parse(startStr.split(':')[1]);
    final endHour = int.parse(endStr.split(':')[0]);
    final endMin = int.parse(endStr.split(':')[1]);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('From', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              _buildTimeWheelButton(option, true, startHour, startMin),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          child: const Text('-', style: TextStyle(color: Colors.grey, fontSize: 24)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('To', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              _buildTimeWheelButton(option, false, endHour, endMin),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeWheelButton(String option, bool isStart, int hour, int min) {
    return GestureDetector(
      onTap: () => _showTimePickerDialog(option, isStart, hour, min),
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showTimePickerDialog(String option, bool isStart, int currentHour, int currentMin) {
    final range = _ranges[option]!;
    
    // For Night range [21, 5], we need to generate hours 21, 22, 23, 0, 1, 2, 3, 4, 5
    List<int> hours = [];
    if (range[0] < range[1]) {
      for (int i = range[0]; i <= range[1]; i++) hours.add(i);
    } else {
      for (int i = range[0]; i <= 23; i++) hours.add(i);
      for (int i = 0; i <= range[1]; i++) hours.add(i);
    }

    int selectedHour = currentHour;
    int selectedMin = currentMin;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          height: 350,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select ${isStart ? "Start" : "End"} Time',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      _updateTime(option, isStart, selectedHour, selectedMin);
                      Navigator.pop(context);
                    },
                    child: Text('Done', style: GoogleFonts.poppins(color: const Color(0xFFB497FF), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  children: [
                    // Hour Wheel
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        itemExtent: 50,
                        perspective: 0.005,
                        diameterRatio: 1.2,
                        physics: const FixedExtentScrollPhysics(),
                        controller: FixedExtentScrollController(initialItem: hours.indexOf(currentHour)),
                        onSelectedItemChanged: (index) {
                          HapticFeedback.selectionClick();
                          selectedHour = hours[index];
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: hours.length,
                          builder: (context, index) {
                            return Center(
                              child: Text(
                                hours[index].toString().padLeft(2, '0'),
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 24),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const Text(':', style: TextStyle(color: Colors.white, fontSize: 24)),
                    // Minute Wheel
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        itemExtent: 50,
                        perspective: 0.005,
                        diameterRatio: 1.2,
                        physics: const FixedExtentScrollPhysics(),
                        controller: FixedExtentScrollController(initialItem: currentMin ~/ 5),
                        onSelectedItemChanged: (index) {
                          HapticFeedback.selectionClick();
                          selectedMin = index * 5;
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 12,
                          builder: (context, index) {
                            final m = index * 5;
                            return Center(
                              child: Text(
                                m.toString().padLeft(2, '0'),
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 24),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateTime(String option, bool isStart, int hour, int min) {
    setState(() {
      final span = _timeSpans[option]!;
      final parts = span.split(' - ');
      String start = parts[0];
      String end = parts[1];
      
      final timeStr = '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
      if (isStart) {
        start = timeStr;
      } else {
        end = timeStr;
      }
      
      _timeSpans[option] = '$start - $end';
    });
  }
}

// --- Reusable Ruler Selection Page ---
class RulerSelectionPage extends StatefulWidget {
  final String title;
  final double min;
  final double max;
  final double initialValue;
  final String unit;
  final bool isVertical;
  final bool isWeight; // Specific flag for weight UI
  final Map<String, dynamic> Function(double, String) onSave;

  const RulerSelectionPage({
    Key? key,
    required this.title,
    required this.min,
    required this.max,
    required this.initialValue,
    required this.unit,
    this.isVertical = false,
    this.isWeight = false,
    required this.onSave,
  }) : super(key: key);

  @override
  State<RulerSelectionPage> createState() => _RulerSelectionPageState();
}

class _RulerSelectionPageState extends State<RulerSelectionPage> {
  late double selectedValue;
  late FixedExtentScrollController _scrollController;
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  bool isKg = true;
  late double step;

  @override
  void initState() {
    super.initState();
    selectedValue = widget.initialValue;
    // Both weight and height use 0.1 steps now to match onboarding
    step = (widget.isWeight || widget.title.toLowerCase() == 'height') ? 0.1 : 1.0;
    isKg = widget.unit.toLowerCase() == 'kg';
    _scrollController = FixedExtentScrollController(
      initialItem: ((selectedValue - widget.min) / step).round(),
    );
    _textController = TextEditingController(text: selectedValue.toStringAsFixed((widget.isWeight || widget.title.toLowerCase() == 'height') ? 1 : 0).replaceAll(RegExp(r'\.0$'), ''));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionPageWrapper(
      title: 'What Is Your ${widget.title}?',
      onDone: () => Navigator.pop(context, widget.onSave(selectedValue, widget.isWeight ? (isKg ? 'kg' : 'lb') : widget.unit)),
      child: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        child: Column(
          children: [
            if (widget.isWeight) ...[
              const SizedBox(height: 20),
              _buildUnitToggle(),
            ],
            const Spacer(),
            if (widget.isWeight)
              _buildWeightInput()
            else
              _buildSimpleValueDisplay(),
            const SizedBox(height: 40),
            Expanded(
              flex: 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!widget.isVertical)
                    Positioned(
                      bottom: 40,
                      height: 80,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFB497FF),
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Container(
                        width: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB497FF),
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  _buildRuler(),
                  if (!widget.isVertical)
                    Positioned(
                      top: 60,
                      child: Column(
                        children: [
                          Container(width: 4, height: 60, color: Colors.yellow),
                          const Icon(Icons.arrow_drop_up, color: Colors.yellow, size: 30),
                        ],
                      ),
                    )
                  else
                    Positioned(
                      right: MediaQuery.of(context).size.width * 0.15,
                      child: const Icon(Icons.arrow_left, color: Colors.white, size: 40),
                    ),
                ],
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitToggle() {
    return Container(
      width: 250,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFB497FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isKg) {
                  setState(() {
                    isKg = true;
                    selectedValue = double.parse((selectedValue / 2.20462).toStringAsFixed(1));
                    _textController.text = selectedValue.toStringAsFixed(1);
                    _scrollController.jumpToItem(((selectedValue - widget.min) / step).round());
                  });
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isKg ? Colors.black.withOpacity(0.1) : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: Text('KG', style: GoogleFonts.poppins(fontWeight: isKg ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          ),
          Container(width: 1, height: 30, color: Colors.black.withOpacity(0.2)),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isKg) {
                  setState(() {
                    isKg = false;
                    selectedValue = double.parse((selectedValue * 2.20462).toStringAsFixed(1));
                    _textController.text = selectedValue.toStringAsFixed(1);
                    _scrollController.jumpToItem(((selectedValue - widget.min) / step).round());
                  });
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: !isKg ? Colors.black.withOpacity(0.1) : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: Text('LB', style: GoogleFonts.poppins(fontWeight: !isKg ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 200,
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 80, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            onChanged: (value) {
              final val = double.tryParse(value);
              if (val != null && val >= widget.min && val <= widget.max) {
                setState(() {
                  selectedValue = double.parse(val.toStringAsFixed(1));
                  _scrollController.jumpToItem(((selectedValue - widget.min) / step).round());
                });
              }
            },
          ),
        ),
        Text(isKg ? ' Kg' : ' Lb', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 24)),
      ],
    );
  }

  Widget _buildSimpleValueDisplay() {
    final showDecimals = widget.isWeight || widget.title.toLowerCase() == 'height';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          selectedValue.toStringAsFixed(showDecimals ? 1 : 0).replaceAll(RegExp(r'\.0$'), ''),
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 80, fontWeight: FontWeight.bold),
        ),
        Text(
          ' ${widget.unit}',
          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 24),
        ),
      ],
    );
  }

  Widget _buildRuler() {
    if (widget.isVertical) {
      return ListWheelScrollView.useDelegate(
        controller: _scrollController,
        itemExtent: 40,
        perspective: 0.003,
        diameterRatio: 2.5,
        onSelectedItemChanged: (index) {
          final val = widget.min + (index * step);
          HapticFeedback.selectionClick();
          setState(() {
            selectedValue = double.parse(val.toStringAsFixed(1));
            if (widget.isWeight && !_focusNode.hasFocus) {
              _textController.text = selectedValue.toStringAsFixed(1);
            }
          });
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: ((widget.max - widget.min) / step).round() + 1,
          builder: (context, index) {
            final val = widget.min + (index * step);
            final isSelected = (val - selectedValue).abs() < (step / 2);
            final isInteger = (val % 1.0).abs() < 0.001;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 80,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: isInteger ? Text(
                      '${val.toInt()}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontSize: 24,
                        fontWeight: FontWeight.normal,
                      ),
                    ) : const SizedBox(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Container(
                      width: isInteger ? 40 : 25,
                      height: 2,
                      color: isSelected ? Colors.yellow : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const SizedBox(width: 80),
              ],
            );
          },
        ),
      );
    }

    return RotatedBox(
      quarterTurns: -1,
      child: ListWheelScrollView.useDelegate(
        controller: _scrollController,
        itemExtent: 35,
        perspective: 0.005,
        diameterRatio: 3.0,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          final val = widget.min + (index * step);
          HapticFeedback.selectionClick();
          setState(() {
            selectedValue = double.parse(val.toStringAsFixed(1));
            if (widget.isWeight && !_focusNode.hasFocus) {
              _textController.text = selectedValue.toStringAsFixed(1);
            }
          });
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: ((widget.max - widget.min) / step).round() + 1,
          builder: (context, index) {
            final val = widget.min + (index * step);
            final isSelected = (val - selectedValue).abs() < (step / 2);
            final isInteger = (val % 1.0).abs() < 0.001;

            return RotatedBox(
              quarterTurns: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isInteger)
                    Text(
                      '${val.toInt()}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[600],
                        fontSize: isSelected ? 22 : 18,
                      ),
                    )
                  else
                    const SizedBox(height: 25),
                  const SizedBox(height: 8),
                  Container(
                    width: 2,
                    height: isInteger ? 40 : 15,
                    color: isSelected 
                        ? Colors.yellow 
                        : (isInteger ? Colors.white : Colors.white.withOpacity(0.3)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

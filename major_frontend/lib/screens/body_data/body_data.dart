import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import '../auth/auth_screens.dart';

// No longer need BodyDataFlow as a MaterialApp wrapper

// 1. Gender Selection Screen
class GenderSelectionScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onLogout;
  const GenderSelectionScreen({
    Key? key,
    required this.onComplete,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<GenderSelectionScreen> createState() => _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends State<GenderSelectionScreen> {
  String? selectedGender;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF1B1B1B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: widget.onLogout,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
                      Text(
                        'Back',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                "What's Your Gender",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please select your gender to help us customize your fitness journey and provide more accurate recommendations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const Expanded(
                child: Center(
                  child: SizedBox(), // Space for the centered options
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GenderOption(
                    icon: Icons.male,
                    label: 'Male',
                    isSelected: selectedGender == 'Male',
                    onTap: () => setState(() => selectedGender = 'Male'),
                  ),
                  const SizedBox(height: 40),
                  _GenderOption(
                    icon: Icons.female,
                    label: 'Female',
                    isSelected: selectedGender == 'Female',
                    onTap: () => setState(() => selectedGender = 'Female'),
                  ),
                ],
              ),
              const Expanded(child: SizedBox()),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: selectedGender != null
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AgeSelectionScreen(
                                gender: selectedGender!,
                                onComplete: widget.onComplete,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2BE2),
                    disabledBackgroundColor: const Color(0xFF8A2BE2).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          AnimatedScale(
            scale: isSelected ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFB497FF) : Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFB497FF) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 80,
                color: isSelected ? Colors.black : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: isSelected ? const Color(0xFFB497FF) : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

// 2. Age Selection Screen
class AgeSelectionScreen extends StatefulWidget {
  final String gender;
  final VoidCallback onComplete;
  const AgeSelectionScreen({
    Key? key, 
    required this.gender,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<AgeSelectionScreen> createState() => _AgeSelectionScreenState();
}

class _AgeSelectionScreenState extends State<AgeSelectionScreen> {
  late PageController _pageController;
  int selectedAge = 28;
  final int minAge = 18;
  final int maxAge = 100;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: selectedAge - minAge,
      viewportFraction: 0.2,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF1B1B1B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
                      Text(
                        'Back',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'How Old Are You?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your age helps us calculate your metabolic rate and adjust workout intensity for a safer, more effective experience.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '$selectedAge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Icon(
                Icons.arrow_drop_down,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB497FF),
                      ),
                    ),
                    Positioned(
                      left: (MediaQuery.of(context).size.width - 48) * 0.4,
                      child: Container(width: 2, height: 60, color: Colors.white),
                    ),
                    Positioned(
                      right: (MediaQuery.of(context).size.width - 48) * 0.4,
                      child: Container(width: 2, height: 60, color: Colors.white),
                    ),
                    PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        HapticFeedback.selectionClick();
                        SystemSound.play(SystemSoundType.click);
                        setState(() {
                          selectedAge = index + minAge;
                        });
                      },
                      itemCount: maxAge - minAge + 1,
                      itemBuilder: (context, index) {
                        final age = index + minAge;
                        final isSelected = age == selectedAge;
                        return Center(
                          child: Text(
                            '$age',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[600],
                              fontSize: isSelected ? 32 : 24,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WeightSelectionScreen(
                          gender: widget.gender,
                          age: selectedAge,
                          onComplete: widget.onComplete,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2BE2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// 3. Weight Selection Screen
class WeightSelectionScreen extends StatefulWidget {
  final String gender;
  final int age;
  final VoidCallback onComplete;
  const WeightSelectionScreen({
    Key? key,
    required this.gender,
    required this.age,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<WeightSelectionScreen> createState() => _WeightSelectionScreenState();
}
class _WeightSelectionScreenState extends State<WeightSelectionScreen> {
  double selectedWeight = 75.0;
  bool isKg = true;
  final double minWeight = 30.0;
  final double maxWeight = 300.0;
  final double step = 0.1;

  late FixedExtentScrollController _scrollController;
  late TextEditingController _weightController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController(
      initialItem: ((selectedWeight - minWeight) / step).round(),
    );
    _weightController = TextEditingController(text: selectedWeight.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _weightController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF1B1B1B),
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
                        Text(
                          'Back',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'What Is Your Weight?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sharing your weight helps us track your progress and provide precise calorie burn estimates for every session.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
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
                                selectedWeight = double.parse((selectedWeight / 2.20462).toStringAsFixed(1));
                                _weightController.text = selectedWeight.toStringAsFixed(1);
                                _scrollController.jumpToItem(((selectedWeight - minWeight) / step).round());
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isKg ? Colors.black.withOpacity(0.1) : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                            ),
                            alignment: Alignment.center,
                            child: const Text('KG', style: TextStyle(fontWeight: FontWeight.normal)),
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
                                selectedWeight = double.parse((selectedWeight * 2.20462).toStringAsFixed(1));
                                _weightController.text = selectedWeight.toStringAsFixed(1);
                                _scrollController.jumpToItem(((selectedWeight - minWeight) / step).round());
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: !isKg ? Colors.black.withOpacity(0.1) : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                            ),
                            alignment: Alignment.center,
                            child: const Text('LB', style: TextStyle(fontWeight: FontWeight.normal)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 180, // Increased height for "Full Ruler" feel
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background bar
                      Positioned(
                        bottom: 40,
                        height: 80,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFB497FF), // Reverted to solid purple
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                      // The Fast Ruler
                      RotatedBox(
                        quarterTurns: -1,
                        child: ListWheelScrollView.useDelegate(
                          controller: _scrollController,
                          itemExtent: 35, // Increased from 20 to accommodate horizontal numbers
                          perspective: 0.005,
                          diameterRatio: 3.0,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            final w = minWeight + (index * step);
                            final isInteger = (w % 1.0).abs() < 0.001;
                            if (isInteger) HapticFeedback.mediumImpact();
                            SystemSound.play(SystemSoundType.click);
                            setState(() {
                              selectedWeight = w;
                              if (!_focusNode.hasFocus) {
                                _weightController.text = w.toStringAsFixed(1);
                              }
                            });
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: ((maxWeight - minWeight) / step).round() + 1,
                            builder: (context, index) {
                              final w = minWeight + (index * step);
                              final isSelected = (w - selectedWeight).abs() < (step / 2);
                              final isInteger = (w % 1.0).abs() < 0.001;
                              final isHalf = (w * 2 % 1.0).abs() < 0.001 && !isInteger;

                              return RotatedBox(
                                quarterTurns: 1,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isInteger)
                                      Text(
                                        '${w.toInt()}',
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.grey[600],
                                          fontSize: isSelected ? 22 : 18,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 25), // Height to match horizontal text approx
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 2,
                                      height: isInteger ? 40 : (isHalf ? 25 : 15),
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
                      ),
                      // Center Indicator
                      Positioned(
                        top: 60,
                        child: Column(
                          children: [
                            Container(width: 4, height: 60, color: Colors.yellow),
                            const Icon(Icons.arrow_drop_up, color: Colors.yellow, size: 30),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    SizedBox(
                      width: 250,
                      child: TextField(
                        controller: _weightController,
                        focusNode: _focusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                        onChanged: (value) {
                          final val = double.tryParse(value);
                          if (val != null && val >= minWeight && val <= maxWeight) {
                            setState(() {
                              selectedWeight = val;
                              _scrollController.jumpToItem(((val - minWeight) / step).round());
                            });
                          }
                        },
                      ),
                    ),
                    Text(isKg ? ' Kg' : ' Lb', style: const TextStyle(color: Colors.grey, fontSize: 24)),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => HeightSelectionScreen(
                              gender: widget.gender,
                              age: widget.age,
                              weight: selectedWeight,
                              weightUnit: isKg ? 'kg' : 'lb',
                              onComplete: widget.onComplete,
                            ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8A2BE2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                    ],
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

// 4. Height Selection Screen
class HeightSelectionScreen extends StatefulWidget {
  final String gender;
  final int age;
  final double weight;
  final String weightUnit;
  final VoidCallback onComplete;
  const HeightSelectionScreen({
    Key? key,
    required this.gender,
    required this.age,
    required this.weight,
    required this.weightUnit,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<HeightSelectionScreen> createState() => _HeightSelectionScreenState();
}

class _HeightSelectionScreenState extends State<HeightSelectionScreen> {
  late FixedExtentScrollController _scrollController;
  double selectedHeight = 165.0;
  bool _isLoading = false;
  final double minHeight = 100.0;
  final double maxHeight = 250.0;
  final double step = 0.1;

  late TextEditingController _heightController;
  final FocusNode _heightFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController(
      initialItem: ((selectedHeight - minHeight) / step).round(),
    );
    _heightController = TextEditingController(text: selectedHeight.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heightController.dispose();
    _heightFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => _heightFocusNode.unfocus(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
                        Text(
                          'Back',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'What Is Your Height?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your height is essential for calculating your Body Mass Index (BMI) and personalizing your fitness plan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    SizedBox(
                      width: 250,
                      child: TextField(
                        controller: _heightController,
                        focusNode: _heightFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) {
                          final val = double.tryParse(value);
                          if (val != null && val >= minHeight && val <= maxHeight) {
                            setState(() {
                              selectedHeight = val;
                              _scrollController.jumpToItem(((val - minHeight) / step).round());
                            });
                          }
                        },
                      ),
                    ),
                    const Text(
                      ' Cm',
                      style: TextStyle(color: Colors.grey, fontSize: 24),
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
                          width: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB497FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 120,
                          height: 3,
                          color: Colors.yellow,
                        ),
                      ),
                      ListWheelScrollView.useDelegate(
                        controller: _scrollController,
                        itemExtent: 40,
                        perspective: 0.003,
                        diameterRatio: 2.5,
                        onSelectedItemChanged: (index) {
                          final h = minHeight + (index * step);
                          final isInteger = (h % 1.0).abs() < 0.001;
                          if (isInteger) HapticFeedback.mediumImpact();
                          SystemSound.play(SystemSoundType.click);
                          setState(() {
                            selectedHeight = h;
                            if (!_heightFocusNode.hasFocus) {
                              _heightController.text = h.toStringAsFixed(1);
                            }
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: ((maxHeight - minHeight) / step).round() + 1,
                          builder: (context, index) {
                            final h = minHeight + (index * step);
                            final isSelected = (h - selectedHeight).abs() < (step / 2);
                            final isInteger = (h % 1.0).abs() < 0.001;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: isInteger ? Text(
                                      '${h.toInt()}',
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
                      ),
                      Positioned(
                        right: (MediaQuery.of(context).size.width - 260) / 2 + 10,
                        child: const Icon(Icons.arrow_left, color: Colors.white, size: 40),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      setState(() => _isLoading = true);
                      final error = await AuthService().updateProfile({
                        'gender': widget.gender,
                        'age': widget.age,
                        'weight': widget.weight,
                        'weight_unit': widget.weightUnit,
                        'height': selectedHeight,
                      });
                      setState(() => _isLoading = false);
                      if (error == null) {
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => WorkoutLocationScreen(onComplete: widget.onComplete)),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8A2BE2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: Colors.white,
                          ),
                        ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// Screen 1: Where Will You Workout
class WorkoutLocationScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const WorkoutLocationScreen({Key? key, required this.onComplete}) : super(key: key);

  @override
  State<WorkoutLocationScreen> createState() => _WorkoutLocationScreenState();
}

class _WorkoutLocationScreenState extends State<WorkoutLocationScreen> {
  String selectedLocation = 'Home';
  Set<String> selectedEquipment = {'BodyWeight'};

  final List<Map<String, dynamic>> equipment = [
    {'name': 'BodyWeight', 'icon': '🏋️'},
    {'name': 'Leg Press\nMachine', 'icon': '🦵'},
    {'name': 'Dumbbell', 'icon': '💪'},
    {'name': 'Treadmills', 'icon': '🏃'},
    {'name': 'Resistance\nBand', 'icon': '🎯'},
    {'name': 'Powerrack', 'icon': '⚡'},
    {'name': 'Lat Pulldown\nMachine', 'icon': '🎪'},
    {'name': 'Barbell', 'icon': '🏋️'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_ios, size: 16),
                    SizedBox(width: 4),
                    Text('Back', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Where Will You Workout?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              
              // Subtitle
              const Text(
                'This help us create workout that fit your setup',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              
              // Equipment Images (3 cards with labels)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLocationCard('Home', 'assets/images/home_icon.png'),
                  _buildLocationCard('Gym', 'assets/images/gym_icon.png'),
                  _buildLocationCard('Hybrid', 'assets/images/hybrid_icon.png'),
                ],
              ),
              const SizedBox(height: 20),
              
              Center(
                child: Container(
                  width: double.infinity,
                  height: 1,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              
              // Equipment Selection Title
              const Center(
                child: Text(
                  'Add All Equipment You have access to:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Equipment Grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: equipment.length,
                  itemBuilder: (context, index) {
                    final item = equipment[index];
                    final isSelected = selectedEquipment.contains(item['name']);
                    
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (item['name'] == 'BodyWeight') return; // Cannot deselect BodyWeight
                          setState(() {
                            if (isSelected) {
                              selectedEquipment.remove(item['name']);
                            } else {
                              selectedEquipment.add(item['name']);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        splashColor: Colors.white.withOpacity(0.1),
                        highlightColor: Colors.white.withOpacity(0.05),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF8A2BE2) : const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF8A2BE2) : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    item['icon'],
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item['name'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 14, color: Color(0xFF8A2BE2))
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedEquipment.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select at least one equipment'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FocusAreaScreen(
                          workoutLocation: selectedLocation,
                          equipmentList: selectedEquipment.toList(),
                          onComplete: widget.onComplete,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2BE2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard(String title, String imagePath) {
    final isSelected = selectedLocation == title;
    return GestureDetector(
      onTap: () => setState(() => selectedLocation = title),
      child: Column(
        children: [
          Container(
            width: 102,
            height: 150, // Reduced height slightly to fit more options
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isSelected ? Border.all(color: const Color(0xFF8A2BE2), width: 3) : null,
              boxShadow: isSelected ? [
                BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 8, spreadRadius: 1)
              ] : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: isSelected ? const Color(0xFF8A2BE2) : Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Screen 2: Focus Area
class FocusAreaScreen extends StatefulWidget {
  final String workoutLocation;
  final List<String> equipmentList;
  final VoidCallback onComplete;

  const FocusAreaScreen({
    Key? key,
    required this.workoutLocation,
    required this.equipmentList,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<FocusAreaScreen> createState() => _FocusAreaScreenState();
}

class _FocusAreaScreenState extends State<FocusAreaScreen> {
  Set<String> selectedAreas = {};

  final List<Map<String, String>> focusAreas = [
    {'name': 'Full Body', 'image': 'assets/images/fullbody_1.png'},
    {'name': 'Arm', 'image': 'assets/images/arm_1.png'},
    {'name': 'Shoulder', 'image': 'assets/images/shoulder_1.png'},
    {'name': 'Back', 'image': 'assets/images/back_1.png'},
    {'name': 'Chest', 'image': 'assets/images/chest_1.png'},
    {'name': 'Cores', 'image': 'assets/images/core_1.png'},
    {'name': 'Leg', 'image': 'assets/images/leg_1.png'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_ios, size: 16),
                    SizedBox(width: 4),
                    Text('Back', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              const Center(
                child: Text(
                  'Focus Area',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Focus Area List
              Expanded(
                child: ListView.builder(
                  itemCount: focusAreas.length,
                  itemBuilder: (context, index) {
                    final area = focusAreas[index];
                      final isSelected = selectedAreas.contains(area['name']);
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedAreas.remove(area['name']);
                            } else {
                              if (selectedAreas.length < 3) {
                                selectedAreas.add(area['name']!);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('You can select up to 3 areas')),
                                );
                              }
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        splashColor: Colors.white.withOpacity(0.2),
                        highlightColor: Colors.white.withOpacity(0.1),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFB497FF) : const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFB497FF) : Colors.grey[800]!,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    area['image']!,
                                    width: 30,
                                    height: 30,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  area['name']!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 16, color: Colors.purple)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedAreas.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select at least one area')),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutFrequencyScreen(
                          workoutLocation: widget.workoutLocation,
                          equipmentList: widget.equipmentList,
                          focusAreas: selectedAreas.toList(),
                          onComplete: widget.onComplete,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2BE2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      color: Colors.white,
                    ),
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

// Screen 3: Workout Frequency
class WorkoutFrequencyScreen extends StatefulWidget {
  final String workoutLocation;
  final List<String> equipmentList;
  final List<String> focusAreas;
  final VoidCallback onComplete;

  const WorkoutFrequencyScreen({
    Key? key,
    required this.workoutLocation,
    required this.equipmentList,
    required this.focusAreas,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<WorkoutFrequencyScreen> createState() => _WorkoutFrequencyScreenState();
}

class _WorkoutFrequencyScreenState extends State<WorkoutFrequencyScreen> {
  double frequency = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_ios, size: 16),
                    SizedBox(width: 4),
                    Text('Back', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Title
              const Center(
                child: Text(
                  'How many day You\nwant to workout?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              
              // Calendar Icon
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/images/calendar.png',
                      width: 240,
                      height: 240,
                      fit: BoxFit.contain,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 40.0), // More padding for the new image
                      child: Text(
                        '${frequency.toInt()}',
                        style: const TextStyle(
                          fontSize: 85,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Frequency Text
              Center(
                child: Text(
                  '${frequency.toInt()} times / week',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              
              // Slider
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF8A2BE2).withOpacity(0.6),
                      inactiveTrackColor: const Color(0xFF8A2BE2).withOpacity(0.2),
                      thumbColor: Colors.white,
                      overlayColor: const Color(0xFF8A2BE2).withOpacity(0.2),
                      trackHeight: 12,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                        elevation: 4,
                      ),
                      tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
                      activeTickMarkColor: Colors.white.withOpacity(0.8),
                      inactiveTickMarkColor: Colors.white.withOpacity(0.4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Slider(
                        value: frequency,
                        min: 1,
                        max: 7,
                        divisions: 6,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            frequency = value;
                          });
                        },
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Less', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        Text('More', style: TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrainingLevelScreen(
                          workoutLocation: widget.workoutLocation,
                          equipmentList: widget.equipmentList,
                          focusAreas: widget.focusAreas,
                          workoutFrequency: frequency.toInt(),
                          onComplete: widget.onComplete,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2BE2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// Screen 4: Training Level
class TrainingLevelScreen extends StatefulWidget {
  final String workoutLocation;
  final List<String> equipmentList;
  final List<String> focusAreas;
  final int workoutFrequency;
  final VoidCallback onComplete;

  const TrainingLevelScreen({
    Key? key,
    required this.workoutLocation,
    required this.equipmentList,
    required this.focusAreas,
    required this.workoutFrequency,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<TrainingLevelScreen> createState() => _TrainingLevelScreenState();
}

class _TrainingLevelScreenState extends State<TrainingLevelScreen> {
  String selectedLevel = '';

  final List<Map<String, String>> levels = [
    {
      'title': 'Beginner',
      'subtitle': 'I want to start training',
    },
    {
      'title': 'Irregular training',
      'subtitle': 'I train 1-2 times a week',
    },
    {
      'title': 'Medium',
      'subtitle': 'I train 3-5 times a week',
    },
    {
      'title': 'Advanced',
      'subtitle': 'I train more than 5 times a week',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_ios, size: 16),
                    SizedBox(width: 4),
                    Text('Back', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title
              const Center(
                child: Text(
                  'Choose training\nlevel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              
              // Level Options
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: levels.length,
                  itemBuilder: (context, index) {
                    final level = levels[index];
                    final isSelected = selectedLevel == level['title'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            selectedLevel = level['title']!;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFB497FF) : const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFB497FF) : Colors.grey[800]!,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                level['title']!,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                level['subtitle']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Continue Button
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedLevel.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a training level')),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrainingPlanScreen(
                          workoutLocation: widget.workoutLocation,
                          equipmentList: widget.equipmentList,
                          focusAreas: widget.focusAreas,
                          workoutFrequency: widget.workoutFrequency,
                          trainingLevel: selectedLevel,
                          onComplete: widget.onComplete,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2BE2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// Screen 5: Training Plan Creation
class TrainingPlanScreen extends StatefulWidget {
  final String workoutLocation;
  final List<String> equipmentList;
  final List<String> focusAreas;
  final int workoutFrequency;
  final String trainingLevel;
  final VoidCallback onComplete;

  const TrainingPlanScreen({
    Key? key,
    required this.workoutLocation,
    required this.equipmentList,
    required this.focusAreas,
    required this.workoutFrequency,
    required this.trainingLevel,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<TrainingPlanScreen> createState() => _TrainingPlanScreenState();
}

class _TrainingPlanScreenState extends State<TrainingPlanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1.0).animate(_controller)
      ..addListener(() {
        setState(() {});
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              
              // Title
              const Text(
                'We create your\ntraining plan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 60),
              
              // Progress Circle
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: _animation.value,
                        strokeWidth: 16,
                        backgroundColor: Colors.grey[800],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFB497FF),
                        ),
                      ),
                    ),
                    Text(
                      '${(_animation.value * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              
              // Description
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'We create a workout according\nto demographic profile, activity\nlevel and interests',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Start Training Button
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _animation.value >= 1.0 ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: _animation.value < 1.0,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Call backend to update profile and complete setup
                        final error = await AuthService().updateProfile({
                          'workout_location': widget.workoutLocation,
                          'equipment_list': jsonEncode(widget.equipmentList),
                          'focus_areas': jsonEncode(widget.focusAreas),
                          'workout_frequency': widget.workoutFrequency,
                          'training_level': widget.trainingLevel,
                          'is_setup_completed': true,
                        });

                        if (context.mounted) {
                          if (error == null) {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                            widget.onComplete();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error)),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8A2BE2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Start Training',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
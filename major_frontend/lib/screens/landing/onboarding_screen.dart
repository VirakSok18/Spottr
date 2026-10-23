import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({Key? key, required this.onComplete}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      image: 'assets/images/Landing_images (1).png',
      title: 'Welcome to Spottr',
      description:
          'The first fitness App Improve your fitness, practice mindfulness, or prepare for new adventures with a series of specially designed workouts and meditations.',
      buttonText: 'Continue',
    ),
    OnboardingData(
      image: 'assets/images/Landing_images (2).png',
      title: 'Find Your Workout Buddy',
      description:
          'Finding compatible workout buddies helps you stay consistent, feel safer, and build lasting fitness habits through shared motivation and accountability.',
      buttonText: 'Continue',
    ),
    OnboardingData(
      image: 'assets/images/Landing_images (3).png',
      title: 'Workout Library',
      description:
          'Explore curated workout plans tailored to your fitness level and goals. From beginner-friendly sessions to advanced training, find routines that match your needs and start immediately.',
      buttonText: 'Start Training',
    ),
  ];

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _completeOnboarding() {
    if (mounted) {
      widget.onComplete();
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PageView for swiping between pages
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _buildPage(_pages[index]);
            },
          ),

          // Bottom section with dots, button, and sign in link
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page indicators (dots)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Continue/Start Training button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        _pages[_currentPage].buttonText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Have an account? Sign in
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Have an account? ',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _completeOnboarding();
                        },
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: Color(0xFFB794F6),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingData data) {
    return Column(
      children: [
        // Background image with overlay
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              // Background image
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(data.image),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Dark overlay gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                      Colors.black,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Text content section
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: _buildTitleSpans(data.title),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<TextSpan> _buildTitleSpans(String title) {
    // Highlight specific words in purple
    final words = title.split(' ');
    final highlightWords = ['Spottr', 'Buddy', 'Library'];

    return words.map((word) {
      final isHighlight = highlightWords.any((hw) => word.contains(hw));
      return TextSpan(
        text: '${word} ',
        style: TextStyle(
          color: isHighlight ? const Color(0xFFB794F6) : Colors.white,
        ),
      );
    }).toList();
  }
}

class OnboardingData {
  final String image;
  final String title;
  final String description;
  final String buttonText;

  OnboardingData({
    required this.image,
    required this.title,
    required this.description,
    required this.buttonText,
  });
}

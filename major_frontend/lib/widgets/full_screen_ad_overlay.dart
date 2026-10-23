import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FullScreenAdOverlay extends StatefulWidget {
  const FullScreenAdOverlay({Key? key}) : super(key: key);

  @override
  State<FullScreenAdOverlay> createState() => _FullScreenAdOverlayState();
}

class _FullScreenAdOverlayState extends State<FullScreenAdOverlay> {
  int _secondsRemaining = 5;
  bool _canSkip = false;
  late Timer _timer;
  late String _adImage;

  final List<String> _adImages = [
    'assets/images/ad_1.png',
    'assets/images/ad_2.png',
    'assets/images/ad_3.png',
  ];

  @override
  void initState() {
    super.initState();
    // Randomly pick an ad image
    _adImage = _adImages[Random().nextInt(_adImages.length)];
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _secondsRemaining = 0;
          _canSkip = true;
          _timer.cancel();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ad Image
          Image.asset(
            _adImage,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          
          // Gradient Overlay for visibility of skip button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Skip Button / Timer
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: GestureDetector(
              onTap: _canSkip ? () => Navigator.of(context).pop() : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_canSkip)
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(right: 8),
                        child: CircularProgressIndicator(
                          value: (5 - _secondsRemaining) / 5,
                          strokeWidth: 2,
                          color: const Color(0xFFB497FF),
                        ),
                      ),
                    Text(
                      _canSkip ? 'Skip Ad' : 'Skip in $_secondsRemaining',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_canSkip) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Premium Badge (Optional but nice)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(128),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  'Remove Ads with Premium',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

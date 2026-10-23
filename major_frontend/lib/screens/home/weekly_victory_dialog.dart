import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WeeklyVictoryDialog extends StatefulWidget {
  final int weekNum;
  final VoidCallback onContinue;

  const WeeklyVictoryDialog({Key? key, required this.weekNum, required this.onContinue}) : super(key: key);

  @override
  State<WeeklyVictoryDialog> createState() => _WeeklyVictoryDialogState();
}

class _WeeklyVictoryDialogState extends State<WeeklyVictoryDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFB794F6), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8A2BE2).withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Column(
                children: [
                   const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 80),
                   const SizedBox(height: 16),
                   Text(
                     'WEEK ${widget.weekNum} CLEARED!',
                     textAlign: TextAlign.center,
                     style: GoogleFonts.poppins(
                       fontSize: 20,
                       fontWeight: FontWeight.w900,
                       color: Colors.white,
                     ),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     'You remain consistent. Pure dedication.',
                     textAlign: TextAlign.center,
                     style: GoogleFonts.poppins(
                       fontSize: 14,
                       color: Colors.white70,
                     ),
                   ),
                   const SizedBox(height: 24),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton(
                       onPressed: widget.onContinue,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: const Color(0xFF8A2BE2),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(12),
                         ),
                       ),
                       child: Text(
                         'CONTINUE',
                         style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                       ),
                     ),
                   )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

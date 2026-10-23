import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumLoading extends StatefulWidget {
  final double size;
  final Color? color;

  const PremiumLoading({Key? key, this.size = 40, this.color}) : super(key: key);

  @override
  State<PremiumLoading> createState() => _PremiumLoadingState();
}

class _PremiumLoadingState extends State<PremiumLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring
          RotationTransition(
            turns: _controller,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (widget.color ?? const Color(0xFFB497FF)).withOpacity(0.2),
                  width: 3,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CircularProgressIndicator(
                  value: 0.25,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.color ?? const Color(0xFFB497FF)),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ),
          // Pulsing center dot
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Container(
                width: widget.size * 0.2 * value,
                height: widget.size * 0.2 * value,
                decoration: BoxDecoration(
                  color: widget.color ?? const Color(0xFFB497FF),
                  shape: BoxShape.circle,
                ),
              );
            },
            onEnd: () {}, // Handled by standard TweenAnimationBuilder repeat if needed, or use controller
          ),
        ],
      ),
    );
  }
}

class AppDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    Widget? content,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => BackdropFilter(
        filter: const ColorFilter.mode(Colors.black26, BlendMode.darken),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1B1B1B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (content != null) content,
            ],
          ),
          actions: actions ??
              [
                _DialogButton(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(context),
                  isPrimary: false,
                ),
                _DialogButton(
                  label: 'OK',
                  onTap: () => Navigator.pop(context, true),
                  isPrimary: true,
                ),
              ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: isPrimary ? const Color(0xFFB497FF) : Colors.white60,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
          fontSize: 16,
        ),
      ),
    );
  }
}

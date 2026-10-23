import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:major_frontend/services/payment_service.dart';
import 'package:major_frontend/widgets/app_theme_widgets.dart';

class PremiumUpgradeScreen extends StatefulWidget {
  const PremiumUpgradeScreen({super.key});

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen> {
  int _selectedPlanIndex = 1; // Default to Yearly
  bool _isLoading = false;

  final List<String> _planTypeNames = ['monthly', 'yearly', 'lifetime'];

  void _handleContinue() async {
    setState(() => _isLoading = true);
    final planType = _planTypeNames[_selectedPlanIndex];
    final success = await PaymentService.createCheckoutSession(planType);
    if (mounted) setState(() => _isLoading = false);
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start payment. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // Content
          Column(
            children: [
              // Flexible Header Image
              Expanded(
                flex: 4,
                child: Stack(
                  children: [
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 20,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Image.asset(
                        'assets/images/plan_image.png',
                        width: double.infinity,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.3, 0.7, 1.0],
                            colors: [
                              const Color(0xFF121212).withOpacity(0.9),
                              Colors.transparent,
                              const Color(0xFF121212).withOpacity(0.8),
                              const Color(0xFF121212),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Text Content
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Spacer(),
                      
                      Text(
                        '– UNLOCK EVERYTHING –',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PREMIUM PLAN',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // Feature Highlights
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFeatureBox(Icons.bolt, 'FAST'),
                          const SizedBox(width: 12),
                          _buildFeatureBox(Icons.star, 'PREMIUM'),
                          const SizedBox(width: 12),
                          _buildFeatureBox(Icons.lock_open, 'UNLOCKED'),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // Plans
                      LayoutBuilder(
                        builder: (context, constraints) {
                          double cardWidth = (constraints.maxWidth - 24) / 3;
                          return IntrinsicHeight(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildPlanCard(
                                  index: 0,
                                  title: '1',
                                  subtitle: 'MONTH',
                                  priceDesc: '\$0.75/WEEK',
                                  total: '\$2.99',
                                  width: cardWidth,
                                  titleFontSize: 24,
                                ),
                                _buildPlanCard(
                                  index: 1,
                                  title: '12',
                                  subtitle: 'MONTH',
                                  priceDesc: '\$0.38/WEEK',
                                  total: '\$19.99',
                                  width: cardWidth,
                                  isBestValue: true,
                                  titleFontSize: 24,
                                ),
                                _buildPlanCard(
                                  index: 2,
                                  title: 'Lifetime',
                                  subtitle: 'ACCESS',
                                  priceDesc: 'ONE TIME',
                                  total: '\$49.99',
                                  width: cardWidth,
                                  titleFontSize: 18,
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                      
                      const Spacer(flex: 2),
                      
                      // Continue Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: const Color(0xFF8B5CF6).withOpacity(0.5),
                          ),
                          child: _isLoading 
                            ? const PremiumLoading(color: Colors.white, size: 24)
                            : Text(
                                'Continue',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        ),
                      ),
                      
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Close Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBox(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFB497FF),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required int index,
    required String title,
    required String subtitle,
    required String priceDesc,
    required String total,
    required double width,
    bool isBestValue = false,
    double titleFontSize = 28,
  }) {
    bool isSelected = _selectedPlanIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFB497FF) : Colors.white10,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    priceDesc,
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFB497FF) : const Color(0xFF353535),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Column(
                children: [
                  Text(
                    total,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    priceDesc,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

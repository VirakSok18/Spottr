import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/location_service.dart';

class PrivacySelectionPage extends StatefulWidget {
  final LatLng location;
  final String initialPrivacy;

  const PrivacySelectionPage({
    Key? key,
    required this.location,
    this.initialPrivacy = 'full',
  }) : super(key: key);

  @override
  State<PrivacySelectionPage> createState() => _PrivacySelectionPageState();
}

class _PrivacySelectionPageState extends State<PrivacySelectionPage> {
  final LocationService _locationService = LocationService();
  late String _privacyLevel;
  bool _isLoading = false;
  Map<String, String>? _locationData;

  @override
  void initState() {
    super.initState();
    _privacyLevel = widget.initialPrivacy;
    _fetchAddress();
  }

  Future<void> _fetchAddress() async {
    setState(() => _isLoading = true);
    final data = await _locationService.reverseGeocode(
      widget.location.latitude,
      widget.location.longitude,
    );
    if (mounted) {
      setState(() {
        _locationData = data;
        _isLoading = false;
      });
    }
  }

  void _saveAndPop() {
    Navigator.pop(context, {
      'latitude': widget.location.latitude,
      'longitude': widget.location.longitude,
      'location_privacy': _privacyLevel,
      'location_data': _locationData, // Hierarchical data for display
    });
  }

  @override
  Widget build(BuildContext context) {
    String displayAddress = 'Loading address...';
    if (_locationData != null) {
      displayAddress = _locationService.getFormattedLabel(
        data: _locationData!,
        privacyLevel: _privacyLevel,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Settings',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2E2E2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFB497FF).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                   Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFB497FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Location',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isLoading ? 'Fetching location...' : displayAddress,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'How should your location appear?',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your privacy level for this address.',
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 32),
            _buildPrivacyOption('full', 'Full Location', 'Area, City, and Province'),
            const SizedBox(height: 16),
            _buildPrivacyOption('province', 'City/Province Only', 'General area (no specific neighborhood)'),
            const SizedBox(height: 16),
            _buildPrivacyOption('distance', 'Distance Only', 'Shows only how many kilometers away you are'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAndPop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB497FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  'Finish',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyOption(String value, String title, String subtitle) {
    bool isSelected = _privacyLevel == value;
    return GestureDetector(
      onTap: () => setState(() => _privacyLevel = value),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB497FF).withOpacity(0.1) : const Color(0xFF2E2E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFFB497FF) : Colors.transparent),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected) 
              const Icon(Icons.check_circle, color: Color(0xFFB497FF), size: 24)
            else 
              const Icon(Icons.circle_outlined, color: Colors.white24, size: 24),
          ],
        ),
      ),
    );
  }
}

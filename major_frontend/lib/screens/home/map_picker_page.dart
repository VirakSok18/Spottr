import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/location_service.dart';

class MapPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerPage({
    Key? key,
    this.initialLat,
    this.initialLng,
  }) : super(key: key);

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> with SingleTickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  
  LatLng? _currentCenter;
  bool _isDragging = false;
  bool _isLoadingAddress = false;
  String _currentAddress = 'Move the map to select';
  
  late AnimationController _animationController;
  late Animation<double> _bounceAnimation;
  
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;

  // Dark Map Style JSON
  final String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#242f3e"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#746855"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#242f3e"}]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#d59563"}]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#d59563"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [{"color": "#263c3f"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#6b9a76"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#38414e"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#212a37"}]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9ca5b3"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#746855"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#1f2835"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#f3d19c"}]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [{"color": "#2f3948"}]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#d59563"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#17263c"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#515c6d"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#17263c"}]
  }
]
''';

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialLat != null && widget.initialLng != null
        ? LatLng(widget.initialLat!, widget.initialLng!)
        : const LatLng(11.5621, 104.9160); // Default to central Phnom Penh

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _bounceAnimation = Tween<double>(begin: 0.0, end: -20.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    if (widget.initialLat != null) {
      _fetchAddress(_currentCenter!);
    } else {
      // For new users, we stay at the default Phnom Penh center.
      // They can click the "My Location" button if they want to jump to GPS.
      _fetchAddress(_currentCenter!);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length > 2) {
        final suggestions = await _locationService.getAutocompleteSuggestions(query);
        setState(() {
          _suggestions = suggestions;
        });
      } else {
        setState(() {
          _suggestions = [];
        });
      }
    });
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    setState(() {
      _suggestions = [];
      _searchController.clear();
      FocusScope.of(context).unfocus();
    });
    
    final placeId = suggestion['place_id'];
    final details = await _locationService.getPlaceDetails(placeId);
    
    if (details != null) {
      final latLng = LatLng(details['lat']!, details['lng']!);
      final controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      setState(() {
        _currentCenter = latLng;
      });
    }
  }

  Future<void> _determinePosition() async {
    try {
      Position? position = await _locationService.getCurrentLocation();
      
      final latLng = position != null 
          ? LatLng(position.latitude, position.longitude)
          : const LatLng(11.5621, 104.9160); // Fallback to Phnom Penh
      
      final controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      
      setState(() {
        _currentCenter = latLng;
      });
      _fetchAddress(latLng);
    } catch (e) {
      debugPrint('Error determining position: $e');
      // If error, we are already at Phnom Penh default from initState, just fetch address
      if (_currentCenter != null) _fetchAddress(_currentCenter!);
    }
  }

  Future<void> _fetchAddress(LatLng position) async {
    setState(() => _isLoadingAddress = true);
    final data = await _locationService.reverseGeocode(position.latitude, position.longitude);
    if (mounted) {
      setState(() {
        if (data != null) {
          _currentAddress = _locationService.getFormattedLabel(data: data, privacyLevel: 'full');
        } else {
          _currentAddress = 'Unknown Location';
        }
        _isLoadingAddress = false;
      });
    }
  }

  void _onCameraMoveStarted() {
    setState(() {
      _isDragging = true;
    });
    _animationController.forward();
  }

  void _onCameraMove(CameraPosition position) {
    _currentCenter = position.target;
  }

  void _onCameraIdle() {
    setState(() {
      _isDragging = false;
    });
    _animationController.reverse();
    if (_currentCenter != null) {
      _fetchAddress(_currentCenter!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            style: _darkMapStyle,
            initialCameraPosition: CameraPosition(
              target: _currentCenter!,
              zoom: 15,
            ),
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            onCameraMoveStarted: _onCameraMoveStarted,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Central Marker with Animation
          Center(
            child: AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _bounceAnimation.value - 20), // -20 to center the tip of the icon
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFFB497FF),
                          size: 45,
                        ),
                      ),
                      // Shadow below the pin
                      Transform.translate(
                        offset: const Offset(0, 5),
                        child: Opacity(
                          opacity: _isDragging ? 0.2 : 0.5,
                          child: Container(
                            width: 12,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.all(Radius.elliptical(12, 4)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Search Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B1B),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search location...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _suggestions = []);
                            },
                          )
                        : const Icon(Icons.search, color: Colors.white24),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B1B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final s = _suggestions[index];
                        return ListTile(
                          title: Text(
                            s['description'], 
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSuggestion(s),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Selection Card
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB497FF).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.place_outlined, color: Color(0xFFB497FF), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Drag pin for precise location',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Coordinates: ${_currentCenter!.latitude.toStringAsFixed(4)}, ${_currentCenter!.longitude.toStringAsFixed(4)}',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isDragging ? null : () {
                        Navigator.pop(context, _currentCenter);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB497FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Confirm Location',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // My Location Button
          Positioned(
            bottom: 240,
            right: 20,
            child: GestureDetector(
              onTap: _determinePosition,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.my_location, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/location_service.dart';
import '../../widgets/app_theme_widgets.dart';
import 'map_picker_page.dart';
import 'privacy_selection_page.dart';

class LocationSelectionPage extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final Function(Map<String, dynamic>) onUpdate;

  const LocationSelectionPage({
    Key? key, 
    required this.initialData,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<LocationSelectionPage> createState() => _LocationSelectionPageState();
}

class _LocationSelectionPageState extends State<LocationSelectionPage> {
  final LocationService _locationService = LocationService();
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  
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

  late double? _latitude;
  late double? _longitude;
  late String _locationLabel;
  late String _privacyLevel;
  List<Map<String, dynamic>> _savedAddresses = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialData['latitude']?.toDouble();
    _longitude = widget.initialData['longitude']?.toDouble();
    _locationLabel = widget.initialData['location_label'] ?? 'Not Set';
    _privacyLevel = widget.initialData['location_privacy'] ?? 'full';
    
    // Parse saved addresses
    final rawSaved = widget.initialData['saved_addresses'];
    if (rawSaved != null) {
      if (rawSaved is String) {
        try {
          _savedAddresses = List<Map<String, dynamic>>.from(jsonDecode(rawSaved));
        } catch (e) {
          _savedAddresses = [];
        }
      } else if (rawSaved is List) {
        _savedAddresses = List<Map<String, dynamic>>.from(rawSaved);
      }
    }
  }

  void _triggerUpdate() {
    widget.onUpdate({
      'latitude': _latitude,
      'longitude': _longitude,
      'location_label': _locationLabel,
      'location_privacy': _privacyLevel,
      'saved_addresses': _savedAddresses,
    });
  }

  Future<void> _animateToLocation(double lat, double lng) async {
    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15));
  }

  Future<void> _openMapPicker({int? editIndex}) async {
    final Map<String, dynamic>? initial = editIndex != null ? _savedAddresses[editIndex] : null;
    
    final LatLng? location = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerPage(
          initialLat: initial?['latitude']?.toDouble() ?? _latitude,
          initialLng: initial?['longitude']?.toDouble() ?? _longitude,
        ),
      ),
    );

    if (location != null && mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrivacySelectionPage(
            location: location,
            initialPrivacy: initial?['location_privacy'] ?? 'full',
          ),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          final newAddr = {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'latitude': result['latitude'],
            'longitude': result['longitude'],
            'location_privacy': result['location_privacy'],
            'location_label': _locationService.getFormattedLabel(
              data: Map<String, String>.from(result['location_data'] ?? {}),
              privacyLevel: result['location_privacy'],
            ),
            'name': initial?['name'] ?? (_savedAddresses.isEmpty ? 'Home' : 'Other'),
          };

          if (editIndex != null) {
            _savedAddresses[editIndex] = newAddr;
            if (_latitude == initial?['latitude'] && _longitude == initial?['longitude']) {
              _latitude = newAddr['latitude'] as double?;
              _longitude = newAddr['longitude'] as double?;
              _locationLabel = newAddr['location_label'] as String;
              _privacyLevel = newAddr['location_privacy'] as String;
              _animateToLocation(_latitude!, _longitude!);
            }
            _triggerUpdate();
          } else {
            _savedAddresses.add(newAddr);
            if (_savedAddresses.length == 1) {
              _selectAddress(0);
            } else {
              _triggerUpdate();
            }
          }
        });
      }
    }
  }

  void _selectAddress(int index) {
    setState(() {
      final addr = _savedAddresses[index];
      _latitude = addr['latitude']?.toDouble();
      _longitude = addr['longitude']?.toDouble();
      _locationLabel = addr['location_label'] ?? 'Not Set';
      _privacyLevel = addr['location_privacy'] ?? 'full';
      if (_latitude != null && _longitude != null) {
        _animateToLocation(_latitude!, _longitude!);
      }
      _triggerUpdate();
    });
  }

  Future<void> _deleteAddress(int index) async {
    final addr = _savedAddresses[index];
    final bool? confirm = await AppDialog.show<bool>(
      context: context,
      title: 'Delete Address',
      subtitle: 'Are you sure you want to delete "${addr['name']}"?',
    );

    if (confirm == true && mounted) {
      final oldAddr = _savedAddresses[index];
      final bool wasActive = _latitude == oldAddr['latitude'] && _longitude == oldAddr['longitude'];
      
      setState(() {
        _savedAddresses.removeAt(index);
        
        if (wasActive) {
          if (_savedAddresses.isNotEmpty) {
            _selectAddress(0);
          } else {
            _latitude = null;
            _longitude = null;
            _locationLabel = 'Not Set';
            _privacyLevel = 'full';
            _animateToLocation(11.5621, 104.9160);
          }
        }
        _triggerUpdate();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Manage Locations',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildMapPreview(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentLocationHeader(),
                  const SizedBox(height: 32),
                  _buildSavedLocationsList(),
                  const SizedBox(height: 32),
                  _buildAddNewButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    Set<Marker> markers = {};
    if (_latitude != null && _longitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_active'),
          position: LatLng(_latitude!, _longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          zIndex: 2,
        ),
      );
    }

    for (var addr in _savedAddresses) {
      final lat = addr['latitude']?.toDouble();
      final lng = addr['longitude']?.toDouble();
      if (lat != null && lng != null && (lat != _latitude || lng != _longitude)) {
        markers.add(
          Marker(
            markerId: MarkerId(addr['id'] ?? lat.toString()),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            alpha: 0.6,
          ),
        );
      }
    }

    return Container(
      height: 180,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2E2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            style: _darkMapStyle,
            initialCameraPosition: CameraPosition(
              target: _latitude != null && _longitude != null
                  ? LatLng(_latitude!, _longitude!)
                  : const LatLng(11.5621, 104.9160), // Default to central Phnom Penh
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController.complete(controller),
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            markers: markers,
          ),
          if (_latitude != null && _longitude != null)
            Positioned(
              bottom: 12,
              right: 12,
              child: FloatingActionButton.small(
                onPressed: () => _animateToLocation(_latitude!, _longitude!),
                backgroundColor: const Color(0xFF1B1B1B),
                child: const Icon(Icons.center_focus_strong, color: Color(0xFFB497FF), size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentLocationHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFFB497FF), size: 20),
            const SizedBox(width: 8),
            Text(
              'Current Location',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _locationLabel != 'Not Set' ? _locationLabel : 'No location selected',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildSavedLocationsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saved Locations',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        if (_savedAddresses.isEmpty)
          Text(
            'No saved locations yet.',
            style: GoogleFonts.poppins(color: Colors.white24, fontSize: 13),
          )
        else
          ..._savedAddresses.asMap().entries.map((entry) {
            final index = entry.key;
            final addr = entry.value;
            final isSelected = _latitude == addr['latitude'] && _longitude == addr['longitude'];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFB497FF).withOpacity(0.05) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFFB497FF).withOpacity(0.3) : Colors.white10,
                ),
              ),
              child: ListTile(
                onTap: () => _selectAddress(index),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFB497FF) : const Color(0xFF2E2E2E),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    addr['name'] == 'Home' ? Icons.home : 
                    addr['name'] == 'Work' ? Icons.work : Icons.place,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  addr['name'] ?? 'Other',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  addr['location_label'] ?? '',
                  style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 18),
                      onPressed: () => _openMapPicker(editIndex: index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      onPressed: () => _deleteAddress(index),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: Color(0xFFB497FF), size: 20),
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildAddNewButton() {
    return GestureDetector(
      onTap: () => _openMapPicker(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2E2E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_location_alt_outlined, color: Color(0xFFB497FF)),
            const SizedBox(width: 12),
            Text(
              'Add New Address',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

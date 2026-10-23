import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  final String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<Map<String, String>?> reverseGeocode(double lat, double lng) async {
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          return _extractLocationData(result['address_components']);
        }
      }
    } catch (e) {
      print('Reverse Geocoding error: $e');
    }
    return null;
  }

  Map<String, String> _extractLocationData(List<dynamic> components) {
    String province = '';
    String city = '';
    String area = '';

    for (var component in components) {
      final types = List<String>.from(component['types']);
      if (types.contains('administrative_area_level_1')) {
        province = component['long_name'];
      } else if (types.contains('locality') || types.contains('administrative_area_level_2')) {
        city = component['long_name'];
      } else if (types.contains('sublocality') || types.contains('sublocality_level_1') || types.contains('neighborhood')) {
        area = component['long_name'];
      }
    }

    // Fallback if some levels are missing
    if (city.isEmpty && area.isNotEmpty) city = area;
    if (province.isEmpty && city.isNotEmpty) province = city;

    return {
      'province': province,
      'city': city,
      'area': area,
    };
  }

  String getFormattedLabel({
    required Map<String, String> data,
    required String privacyLevel,
  }) {
    final province = data['province'] ?? '';
    final city = data['city'] ?? '';
    final area = data['area'] ?? '';

    switch (privacyLevel) {
      case 'full':
        return [area, city, province].where((s) => s.isNotEmpty).join(', ');
      case 'province':
        return [city, province].where((s) => s.isNotEmpty).join(', ');
      case 'distance':
      default:
        return 'Distance Only';
    }
  }

  Future<List<Map<String, dynamic>>> getAutocompleteSuggestions(String input) async {
    if (input.isEmpty) return [];
    final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&types=(cities)&key=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          return List<Map<String, dynamic>>.from(data['predictions']);
        }
      }
    } catch (e) {
      print('Autocomplete error: $e');
    }
    return [];
  }

  Future<Map<String, double>?> getPlaceDetails(String placeId) async {
    final url = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry,address_components&key=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          return {
            'lat': (location['lat'] as num).toDouble(),
            'lng': (location['lng'] as num).toDouble(),
          };
        }
      }
    } catch (e) {
      print('Place Details error: $e');
    }
    return null;
  }

  Future<Map<String, String>?> getPlaceLocationData(String placeId) async {
    final url = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=address_components&key=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          return _extractLocationData(data['result']['address_components']);
        }
      }
    } catch (e) {
      print('Place Location Data error: $e');
    }
    return null;
  }
}

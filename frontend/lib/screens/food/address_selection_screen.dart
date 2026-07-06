// lib/screens/food/address_selection_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'food_home_screen.dart';

class AddressSelectionScreen extends StatefulWidget {
  const AddressSelectionScreen({super.key});

  @override
  State<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
  bool _loadingCurrentLocation = false;
  bool _searchingAddress = false;
  List<Map<String, dynamic>> _savedAddresses = [];
  List<Map<String, dynamic>> _searchResults = [];
  
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('saved_delivery_addresses') ?? '[]';
      final List<dynamic> saved = jsonDecode(savedJson);
      
      setState(() {
        _savedAddresses = saved.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint('Error loading saved addresses: $e');
    }
  }

  Future<void> _saveAddress(Map<String, dynamic> address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove duplicates
      _savedAddresses.removeWhere((a) => 
        a['lat'] == address['lat'] && a['lon'] == address['lon']
      );
      
      // Add to front
      _savedAddresses.insert(0, address);
      
      // Keep only last 5
      if (_savedAddresses.length > 5) {
        _savedAddresses = _savedAddresses.sublist(0, 5);
      }
      
      await prefs.setString(
        'saved_delivery_addresses',
        jsonEncode(_savedAddresses),
      );
      
      // Also save as current selected address
      await prefs.setString('selected_delivery_address', jsonEncode(address));
      
      setState(() {});
    } catch (e) {
      debugPrint('Error saving address: $e');
    }
  }

  Future<void> _deleteAddress(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedAddresses.removeAt(index);
      
      await prefs.setString(
        'saved_delivery_addresses',
        jsonEncode(_savedAddresses),
      );
      
      setState(() {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address deleted'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting address: $e');
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingCurrentLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final address = await _reverseGeocode(position.latitude, position.longitude);

      if (!mounted) return;

      await _saveAddress(address);
      _proceedToRestaurants(address);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    setState(() => _loadingCurrentLocation = false);
  }

  Future<Map<String, dynamic>> _reverseGeocode(double lat, double lon) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?'
      'lat=$lat&lon=$lon&format=json&addressdetails=1&countrycodes=in',
    );

    final response = await http.get(
      url,
      headers: {'User-Agent': 'TRACE-Food-App/1.0'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      return {
        'lat': lat,
        'lon': lon,
        'display_name': data['display_name'] ?? 'Current Location',
        'type': 'gps',
      };
    } else {
      return {
        'lat': lat,
        'lon': lon,
        'display_name': 'Lat: ${lat.toStringAsFixed(4)}, Lon: ${lon.toStringAsFixed(4)}',
        'type': 'gps',
      };
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchAddress(query);
    });
  }

  Future<void> _searchAddress(String query) async {
    setState(() => _searchingAddress = true);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=$query&format=json&addressdetails=1&countrycodes=in&limit=10',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'TRACE-Food-App/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        setState(() {
          _searchResults = data.map((place) {
            return {
              'lat': double.parse(place['lat']),
              'lon': double.parse(place['lon']),
              'display_name': place['display_name'],
              'type': place['type'] ?? 'search',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }

    setState(() => _searchingAddress = false);
  }

  void _proceedToRestaurants(Map<String, dynamic> address) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FoodHomeScreen(selectedAddress: address),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C2C2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C2C2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF4E4C1)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Delivery Address',
          style: TextStyle(
            color: Color(0xFFF4E4C1),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _searchController.text.isNotEmpty && _searchResults.isNotEmpty
                ? _buildSearchResults()
                : _buildSavedAddresses(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1A3A3C),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Color(0xFFF4E4C1)),
            decoration: InputDecoration(
              hintText: 'Search area, street, landmark...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
              suffixIcon: _searchingAddress
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          color: Color(0xFFD4AF37),
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchResults = []);
                          },
                        )
                      : null,
              filled: true,
              fillColor: const Color(0xFF0C2C2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadingCurrentLocation ? null : _useCurrentLocation,
              icon: _loadingCurrentLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.my_location, color: Colors.black),
              label: Text(
                _loadingCurrentLocation
                    ? 'Getting Location...'
                    : 'Use Current Location',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final place = _searchResults[index];
        return _buildAddressCard(
          place: place,
          onTap: () async {
            await _saveAddress(place);
            _proceedToRestaurants(place);
          },
        );
      },
    );
  }

  Widget _buildSavedAddresses() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_savedAddresses.isEmpty) ...[
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.location_off,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No saved addresses',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use current location or search for an address',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else ...[
          const Text(
            'Saved Addresses',
            style: TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_savedAddresses.length, (index) {
            final address = _savedAddresses[index];
            return Dismissible(
              key: Key('${address['lat']}_${address['lon']}'),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _deleteAddress(index),
              background: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerRight,
                child: const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
              ),
              child: _buildAddressCard(
                place: address,
                onTap: () async {
                  await _saveAddress(address);
                  _proceedToRestaurants(address);
                },
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildAddressCard({
    required Map<String, dynamic> place,
    required VoidCallback onTap,
  }) {
    final IconData icon = place['type'] == 'gps'
        ? Icons.my_location
        : Icons.location_on;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A3C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFFD4AF37)),
        title: Text(
          place['display_name'],
          style: const TextStyle(
            color: Color(0xFFF4E4C1),
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Color(0xFFD4AF37),
          size: 18,
        ),
      ),
    );
  }
}
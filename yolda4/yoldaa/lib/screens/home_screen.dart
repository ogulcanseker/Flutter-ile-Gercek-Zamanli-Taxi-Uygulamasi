import 'package:flutter/material.dart';
import '../components/map_widget.dart';
import '../components/custom_bottom_nav_bar.dart';
import '../components/call_taxi_button.dart';
import '../components/search_bar.dart' as custom;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedAddress;
  LatLng? _center;
  Set<Polyline> _polylines = {};
  List<String> _addressSuggestions = [];

  static const LatLng _musteriKonum = LatLng(41.0369, 28.9850); // Taksim
  LatLng _taksiKonum = const LatLng(41.0375, 28.9840); // Taksi ilk konumu
  LatLng? _varisKonum;

  // Taksi ve yolculuk durumu
  TaxiState _taxiState = TaxiState.idle;

  // Animasyon için timer
  Future<void> animateMarker(List<LatLng> route,
      {int durationMs = 3000, required VoidCallback onArrive}) async {
    if (route.length < 2) return;
    int steps = route.length;
    int stepDuration = (durationMs / steps).floor();
    for (int i = 0; i < steps; i++) {
      await Future.delayed(Duration(milliseconds: stepDuration));
      setState(() {
        _taksiKonum = route[i];
      });
    }
    onArrive();
  }

  Future<void> _goToAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final dest =
            LatLng(locations.first.latitude, locations.first.longitude);
        setState(() {
          _center = dest;
          _varisKonum = dest;
        });
        await _drawRoute(_musteriKonum, dest);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adres bulunamadı.')),
      );
    }
  }

  Future<void> _drawRoute(LatLng origin, LatLng dest) async {
    final apiKey = 'API_KEY';
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&key=$apiKey&mode=driving';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final status = data['status'];
      if (status == 'OK' &&
          data['routes'] != null &&
          data['routes'].isNotEmpty) {
        final points = data['routes'][0]['overview_polyline']['points'];
        final polylinePoints = _decodePolyline(points);
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('rota'),
              color: Colors.yellow,
              width: 6,
              points: polylinePoints,
            ),
          };
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Directions API Hatası: $status')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Directions API bağlantı hatası.')),
      );
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }

  void _onSearchChanged(String value) async {
    setState(() {
      _addressSuggestions = value.isNotEmpty
          ? [
              'İstanbul Havalimanı',
              'Kadıköy Rıhtım',
              'Taksim Meydanı',
              'Beşiktaş İskele',
              'Galata Kulesi',
              'Sultanahmet Camii',
              'Dolmabahçe Sarayı',
              'Nişantaşı',
              'Levent',
              'Maslak'
            ]
              .where((s) => s.toLowerCase().contains(value.toLowerCase()))
              .toList()
          : [];
    });
  }

  // Taksi çağırıldığında
  void _callTaxi() async {
    if (_taxiState != TaxiState.idle || _varisKonum == null) return;
    setState(() {
      _taxiState = TaxiState.movingToCustomer;
    });
    // Taksi müşteriye hareket etsin
    final routeToCustomer = await _getRoute(_taksiKonum, _musteriKonum);
    await animateMarker(routeToCustomer, durationMs: 3000, onArrive: () async {
      setState(() {
        _taxiState = TaxiState.movingToDestination;
      });
      // Taksi müşteriden varış noktasına hareket etsin
      if (_varisKonum != null) {
        final routeToDest = await _getRoute(_musteriKonum, _varisKonum!);
        await animateMarker(routeToDest, durationMs: 5000, onArrive: () {
          setState(() {
            _taxiState = TaxiState.arrived;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Taksi varış noktasına ulaştı!')),
          );
        });
      }
    });
  }

  Future<List<LatLng>> _getRoute(LatLng origin, LatLng dest) async {
    final apiKey = 'API_KEY';
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&key=$apiKey&mode=driving';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final status = data['status'];
      if (status == 'OK' &&
          data['routes'] != null &&
          data['routes'].isNotEmpty) {
        final points = data['routes'][0]['overview_polyline']['points'];
        return _decodePolyline(points);
      }
    }
    return [origin, dest];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'YOLDA',
          style: TextStyle(
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
            fontSize: 28,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MapWidget(
                  center: _center,
                  polylines: _polylines,
                  musteriKonum: _musteriKonum,
                  taksiKonum: _taksiKonum,
                ),
                Positioned(
                  top: 24,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      custom.SearchBar(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        hintText: 'Nereye gitmek istiyorsunuz?',
                      ),
                      if (_addressSuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _addressSuggestions.length,
                            itemBuilder: (context, index) {
                              final suggestion = _addressSuggestions[index];
                              return ListTile(
                                leading: const Icon(Icons.location_on,
                                    color: Colors.yellow),
                                title: Text(suggestion),
                                onTap: () {
                                  setState(() {
                                    _selectedAddress = suggestion;
                                    _addressSuggestions = [];
                                  });
                                  _goToAddress(suggestion);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                if (_selectedAddress != null && _selectedAddress!.isNotEmpty)
                  Positioned(
                    top: 120,
                    left: 32,
                    right: 32,
                    child: Card(
                      color: Colors.yellow.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.place, color: Colors.black),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedAddress!,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.location_searching,
                                  color: Colors.black),
                              onPressed: () {
                                if (_selectedAddress != null &&
                                    _selectedAddress!.isNotEmpty) {
                                  _goToAddress(_selectedAddress!);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 32,
                  left: 24,
                  right: 24,
                  child: CallTaxiButton(
                    onPressed: _callTaxi,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

enum TaxiState { idle, movingToCustomer, movingToDestination, arrived }

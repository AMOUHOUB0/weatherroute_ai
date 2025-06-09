  import 'package:flutter/material.dart';
  import 'package:flutter_map/flutter_map.dart';
  import 'package:latlong2/latlong.dart';
  import 'package:http/http.dart' as http;
  import 'dart:convert';
  import 'dart:async';
  import 'package:geolocator/geolocator.dart';
  import 'package:geocoding/geocoding.dart';

  void main() {
    runApp(WeatherRouteApp());
  }

  class WeatherRouteApp extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        title: 'WeatherRoute AI - OpenStreetMap',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
        ),
        home: WeatherRouteScreen(),
        debugShowCheckedModeBanner: false,
      );
    }
  }

  class WeatherData {
    final double temperature;
    final String description;
    final String icon;
    final double windSpeed;
    final int humidity;
    final double visibility;
    final LatLng location;

    WeatherData({
      required this.temperature,
      required this.description,
      required this.icon,
      required this.windSpeed,
      required this.humidity,
      required this.visibility,
      required this.location,
    });

    factory WeatherData.fromJson(Map<String, dynamic> json, LatLng location) {
      return WeatherData(
        temperature: json['main']['temp'].toDouble(),
        description: json['weather'][0]['description'],
        icon: json['weather'][0]['icon'],
        windSpeed: json['wind']['speed'].toDouble(),
        humidity: json['main']['humidity'],
        visibility: json['visibility'].toDouble() / 1000,
        location: location,
      );
    }
  }

  class AIRecommendation {
    final String message;
    final String type;
    final IconData icon;
    final Color color;

    AIRecommendation({
      required this.message,
      required this.type,
      required this.icon,
      required this.color,
    });
  }

  class WeatherRouteScreen extends StatefulWidget {
    @override
    _WeatherRouteScreenState createState() => _WeatherRouteScreenState();
  }

  class _WeatherRouteScreenState extends State<WeatherRouteScreen> {
    final MapController _mapController = MapController();
    
    final TextEditingController _startController = TextEditingController();
    final TextEditingController _endController = TextEditingController();

    List<Marker> _markers = [];
    List<Polyline> _polylines = [];

    List<WeatherData> _weatherData = [];
    List<AIRecommendation> _recommendations = [];

    final String _weatherApiKey = 'VOTRE_CLE_API_ICI';
    bool _isLoading = false;

    static const LatLng _casablancaCenter = LatLng(33.5731, -7.5898);

    @override
    void initState() {
      super.initState();
      _initializeApp();
    }

    Future<void> _initializeApp() async {
      await _checkLocationPermission();
      await _getCurrentLocation();
      _addDefaultMarkersAndRoute();
    }

    void _addDefaultMarkersAndRoute() {
      if (!mounted) return;
      
      setState(() {
        _markers = [
          Marker(
            point: LatLng(33.5731, -7.5898),
            width: 40,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.location_on, color: Colors.white, size: 24),
            ),
          ),
          Marker(
            point: LatLng(34.0209, -6.8416),
            width: 40,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.flag, color: Colors.white, size: 24),
            ),
          ),
        ];

        // Route par défaut Casablanca-Rabat (dotted effect using pattern)
        _polylines = [
          Polyline(
            points: [
              LatLng(33.5731, -7.5898), // Casablanca
              LatLng(33.7031, -7.3898),
              LatLng(33.8331, -7.1898),
              LatLng(33.9631, -6.9898),
              LatLng(34.0209, -6.8416), // Rabat
            ],
            strokeWidth: 4.0,
            color: Colors.blue,
            pattern: const StrokePattern.dotted(),
          ),
        ];
      });
    }

    Future<void> _checkLocationPermission() async {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          print('Services de localisation désactivés');
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            print('Permission de localisation refusée');
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          print('Permission de localisation définitivement refusée');
          return;
        }
      } catch (e) {
        print('Erreur lors de la vérification des permissions: $e');
      }
    }

    Future<void> _getCurrentLocation() async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        );

        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(Duration(seconds: 10));

        if (placemarks.isNotEmpty && mounted) {
          Placemark place = placemarks[0];
          setState(() {
            _startController.text =
                "${place.locality ?? 'Position actuelle'}, ${place.country ?? ''}";
          });
        }
      } catch (e) {
        print('Erreur géolocalisation: $e');
        if (mounted) {
          setState(() {
            _startController.text = "Casablanca, Maroc";
            _endController.text = "Rabat, Maroc";
          });
        }
      }
    }

    final Map<String, LatLng> _moroccanCities = {
      'casablanca': LatLng(33.5731, -7.5898),
      'rabat': LatLng(34.0209, -6.8416),
      'marrakech': LatLng(31.6295, -7.9811),
      'fes': LatLng(34.0181, -5.0078),
      'tangier': LatLng(35.7595, -5.8340),
      'meknes': LatLng(33.8935, -5.5473),
      'oujda': LatLng(34.6867, -1.9114),
      'kenitra': LatLng(34.2610, -6.5802),
      'tetouan': LatLng(35.5889, -5.3626),
      'safi': LatLng(32.2994, -9.2372),
      'mohammedia': LatLng(33.6864, -7.3932),
      'khouribga': LatLng(32.8811, -6.9063),
      'el jadida': LatLng(33.2316, -8.5007),
      'taza': LatLng(34.2133, -4.0180),
      'settat': LatLng(33.0027, -7.6169),
      'larache': LatLng(35.1932, -6.1557),
      'agadir': LatLng(30.4278, -9.5981),
      'essaouira': LatLng(31.5085, -9.7595),
    };

    LatLng? _findCityCoordinates(String cityName) {
      String searchTerm = cityName
          .toLowerCase()
          .replaceAll('é', 'e')
          .replaceAll('è', 'e')
          .replaceAll('ç', 'c')
          .replaceAll(RegExp(r'[^a-z\s]'), '');

      if (_moroccanCities.containsKey(searchTerm)) {
        return _moroccanCities[searchTerm];
      }

      for (String city in _moroccanCities.keys) {
        if (city.contains(searchTerm) || searchTerm.contains(city)) {
          return _moroccanCities[city];
        }
      }
      return null;
    }

    Future<List<LatLng>> _getRouteCoordinates(String start, String end) async {
      try {
        LatLng? startPoint = _findCityCoordinates(start);
        LatLng? endPoint = _findCityCoordinates(end);

        if (startPoint == null || endPoint == null) {
          try {
            List<Location> startLocs = await locationFromAddress(start).timeout(Duration(seconds: 8));
            List<Location> endLocs = await locationFromAddress(end).timeout(Duration(seconds: 8));

            if (startLocs.isNotEmpty && startPoint == null) {
              startPoint = LatLng(startLocs[0].latitude, startLocs[0].longitude);
            }
            if (endLocs.isNotEmpty && endPoint == null) {
              endPoint = LatLng(endLocs[0].latitude, endLocs[0].longitude);
            }
          } catch (e) {
            startPoint ??= _casablancaCenter;
            endPoint ??= LatLng(34.0209, -6.8416);
            _showMessage('Utilisation de coordonnées par défaut');
          }
        }

        startPoint ??= _casablancaCenter;
        endPoint ??= LatLng(34.0209, -6.8416);

        List<LatLng> waypoints = [];
        for (int i = 0; i <= 4; i++) {
          double lat = startPoint.latitude + (endPoint.latitude - startPoint.latitude) * i / 4;
          double lng = startPoint.longitude + (endPoint.longitude - startPoint.longitude) * i / 4;
          waypoints.add(LatLng(lat, lng));
        }

        return waypoints;
      } catch (e) {
        print('Erreur dans _getRouteCoordinates: $e');
        return [
          LatLng(33.5731, -7.5898),
          LatLng(33.7031, -7.3898),
          LatLng(33.8331, -7.1898),
          LatLng(33.9631, -6.9898),
          LatLng(34.0209, -6.8416),
        ];
      }
    }

    WeatherData _generateDemoWeatherData(LatLng location) {
      final random = (location.latitude + location.longitude).abs() % 100;

      return WeatherData(
        temperature: 20 + (random % 15),
        description: ['Ensoleillé', 'Nuageux', 'Pluvieux', 'Venteux'][random.toInt() % 4],
        icon: ['01d', '02d', '10d', '50d'][random.toInt() % 4],
        windSpeed: 2 + (random % 8),
        humidity: 40 + (random % 40).toInt(),
        visibility: 8 + (random % 12),
        location: location,
      );
    }

    List<AIRecommendation> _generateAIRecommendations(List<WeatherData> weatherData) {
      List<AIRecommendation> recommendations = [];

      if (weatherData.isEmpty) return recommendations;

      double avgTemp = weatherData.map((w) => w.temperature).reduce((a, b) => a + b) / weatherData.length;

      if (avgTemp < 10) {
        recommendations.add(AIRecommendation(
          message: "🥶 Températures froides sur le trajet (${avgTemp.toStringAsFixed(1)}°C). Prévoyez des vêtements chauds.",
          type: 'warning',
          icon: Icons.ac_unit,
          color: Colors.blue,
        ));
      } else if (avgTemp > 35) {
        recommendations.add(AIRecommendation(
          message: "🔥 Températures élevées (${avgTemp.toStringAsFixed(1)}°C). Hydratez-vous régulièrement.",
          type: 'warning',
          icon: Icons.whatshot,
          color: Colors.orange,
        ));
      }

      double maxWind = weatherData.map((w) => w.windSpeed).reduce((a, b) => a > b ? a : b);
      if (maxWind > 10) {
        recommendations.add(AIRecommendation(
          message: "💨 Vents forts prévus (${maxWind.toStringAsFixed(1)} m/s). Réduisez votre vitesse.",
          type: 'warning',
          icon: Icons.air,
          color: Colors.grey,
        ));
      }

      if (avgTemp >= 15 && avgTemp <= 25 && maxWind < 5) {
        recommendations.add(AIRecommendation(
          message: "✅ Conditions météo idéales pour votre trajet ! 🌞",
          type: 'good',
          icon: Icons.wb_sunny,
          color: Colors.green,
        ));
      }

      return recommendations;
    }

    Future<void> _calculateRoute() async {
      if (_startController.text.isEmpty || _endController.text.isEmpty) {
        _showMessage('Veuillez remplir les champs de départ et destination');
        return;
      }

      setState(() {
        _isLoading = true;
        _markers.clear();
        _polylines.clear();
        _weatherData.clear();
        _recommendations.clear();
      });

      try {
        List<LatLng> routeCoordinates = await _getRouteCoordinates(
          _startController.text,
          _endController.text,
        );

        if (routeCoordinates.isEmpty) {
          throw Exception('Impossible de calculer l\'itinéraire');
        }

        if (mounted) {
          setState(() {
            _polylines = [
              Polyline(
                points: routeCoordinates,
                strokeWidth: 4.0,
                color: Colors.blue,
                pattern: const StrokePattern.dotted(),
              )
            ];
          });
        }

        // Génération des données météo et marqueurs
        for (int i = 0; i < routeCoordinates.length; i++) {
          if (!mounted) return;

          WeatherData weather = _generateDemoWeatherData(routeCoordinates[i]);
          _weatherData.add(weather);

          Widget icon = _getWeatherIcon(weather.icon);
          setState(() {
            _markers.add(Marker(
              point: routeCoordinates[i],
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _showWeatherInfo(weather),
                child: icon,
              ),
            ));
          });
        }

        if (mounted) {
          setState(() {
            _recommendations = _generateAIRecommendations(_weatherData);
          });
        }

        // Centrage de la carte
        if (routeCoordinates.isNotEmpty) {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(routeCoordinates),
              padding: EdgeInsets.all(50),
            ),
          );
        }

        _showMessage('Itinéraire calculé avec succès !', isSuccess: true);
      } catch (e) {
        _showMessage('Erreur: $e');
        print('Erreur détaillée: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }

    Widget _getWeatherIcon(String iconCode) {
      IconData iconData;
      Color iconColor;
      
      switch (iconCode) {
        case '01d':
        case '01n':
          iconData = Icons.wb_sunny;
          iconColor = Colors.orange;
          break;
        case '02d':
        case '02n':
        case '03d':
        case '03n':
        case '04d':
        case '04n':
          iconData = Icons.cloud;
          iconColor = Colors.grey;
          break;
        case '09d':
        case '09n':
        case '10d':
        case '10n':
          iconData = Icons.grain;
          iconColor = Colors.blue;
          break;
        default:
          iconData = Icons.wb_cloudy;
          iconColor = Colors.blueGrey;
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: iconColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(iconData, color: iconColor, size: 24),
      );
    }

    void _showWeatherInfo(WeatherData weather) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Météo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🌡️ Température: ${weather.temperature.toStringAsFixed(1)}°C'),
                Text('📝 Conditions: ${weather.description}'),
                Text('💨 Vent: ${weather.windSpeed.toStringAsFixed(1)} m/s'),
                Text('💧 Humidité: ${weather.humidity}%'),
                Text('👁️ Visibilité: ${weather.visibility.toStringAsFixed(1)} km'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Fermer'),
              ),
            ],
          );
        },
      );
    }

    void _showMessage(String message, {bool isSuccess = false}) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isSuccess ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('WeatherRoute AI 🌦️🚘'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        body: Column(
          children: [
            // Interface de saisie
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _startController,
                    decoration: InputDecoration(
                      labelText: 'Point de départ',
                      hintText: 'Ex: Casablanca, Rabat, Marrakech...',
                      prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _endController,
                    decoration: InputDecoration(
                      labelText: 'Destination',
                      hintText: 'Ex: Fes, Agadir, Tanger...',
                      prefixIcon: const Icon(Icons.flag, color: Colors.red),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _calculateRoute,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.search, color: Colors.white),
                      label: Text(
                        _isLoading ? 'Analyse en cours...' : 'Analyser l\'itinéraire',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Carte OpenStreetMap avec flutter_map
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _casablancaCenter,
                      initialZoom: 8.0,
                      minZoom: 5.0,
                      maxZoom: 18.0,
                      interactionOptions: InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      // Couche de tuiles OpenStreetMap
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.weatherroute',
                        maxZoom: 19,
                      ),
                      
                      // Couche des polylines (routes)
                      PolylineLayer(
                        polylines: _polylines,
                      ),
                      
                      // Couche des marqueurs
                      MarkerLayer(
                        markers: _markers,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Recommandations IA
            if (_recommendations.isNotEmpty)
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recommandations IA 🤖',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _recommendations.length,
                          itemBuilder: (context, index) {
                            AIRecommendation rec = _recommendations[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 2,
                              child: ListTile(
                                leading: Icon(rec.icon, color: rec.color, size: 28),
                                title: Text(
                                  rec.message,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                dense: true,
                                tileColor: rec.color.withOpacity(0.05),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        // Bouton d'actions flottant
        floatingActionButton: _weatherData.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () => _showWeatherDetails(context),
                label: const Text('Détails météo'),
                icon: const Icon(Icons.cloud),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              )
            : FloatingActionButton(
                onPressed: () {
                  _mapController.move(_casablancaCenter, 10);
                },
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                child: const Icon(Icons.my_location),
              ),
      );
    }

    void _showWeatherDetails(BuildContext context) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🌤️ Conditions météo détaillées',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _weatherData.length,
                  itemBuilder: (context, index) {
                    WeatherData weather = _weatherData[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Point ${index + 1} sur l\'itinéraire',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('🌡️ Température: ${weather.temperature.toStringAsFixed(1)}°C'),
                                    Text('📝 Conditions: ${weather.description}'),
                                    Text('💨 Vent: ${weather.windSpeed.toStringAsFixed(1)} m/s'),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('💧 Humidité: ${weather.humidity}%'),
                                    Text('👁️ Visibilité: ${weather.visibility.toStringAsFixed(1)} km'),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    @override
    void dispose() {
      _startController.dispose();
      _endController.dispose();
      super.dispose();
    }
  }
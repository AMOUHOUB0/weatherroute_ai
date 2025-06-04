import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

void main() {
  runApp(WeatherRouteApp());
}
late GoogleMapController _mapController;
class WeatherRouteApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeatherRoute AI',
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
      visibility: json['visibility'].toDouble() / 1000, // Convert to km
      location: location,
    );
  }
}

class AIRecommendation {
  final String message;
  final String type; // 'warning', 'info', 'good'
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
  GoogleMapController? _mapController;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  Set<Marker> _markers = {
    Marker(
      markerId: MarkerId('start'),
      position: LatLng(33.5731, -7.5898), // Casablanca
      infoWindow: InfoWindow(title: 'Départ'),
    ),
    Marker(
      markerId: MarkerId('end'),
      position: LatLng(34.0209, -6.8416), // Rabat
      infoWindow: InfoWindow(title: 'Arrivée'),
    ),
  };
    Set<Polyline> _polylines = {
    Polyline(
      polylineId: PolylineId("route"),
      color: Colors.green, // Change dynamiquement selon météo
      width: 5,
      points: [
        LatLng(33.5731, -7.5898), // Casablanca
        LatLng(34.0209, -6.8416), // Rabat
      ],
    ),
  };

  List<WeatherData> _weatherData = [];
  List<AIRecommendation> _recommendations = [];

  // REMPLACEZ PAR VOTRE CLÉ OPENWEATHERMAP
  final String _weatherApiKey = 'a08c63daf8a569834c3a9b1c069a33a5';
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
  }

  Future<void> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Les services de localisation sont désactivés');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage('Permission de localisation refusée');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage('Permission de localisation définitivement refusée');
        return;
      }
    } catch (e) {
      print('Erreur lors de la vérification des permissions: $e');
      _showMessage('Erreur lors de la vérification des permissions');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10), // Add timeout
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(Duration(seconds: 10)); // Add timeout

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
        });
      }
    }
  }

  // Base de données des villes marocaines avec coordonnées
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
    'ksar el kebir': LatLng(35.0157, -5.9078),
    'khemisset': LatLng(33.8244, -6.0658),
    'guelmim': LatLng(28.9870, -10.0574),
    'berrechid': LatLng(33.2741, -7.5881),
    'wazzane': LatLng(34.7906, -5.5718),
    'tiznit': LatLng(29.6974, -9.7316),
    'taroudant': LatLng(30.4778, -8.8716),
    'ouarzazate': LatLng(30.9335, -6.9370),
    'nador': LatLng(35.1681, -2.9287),
    'al hoceima': LatLng(35.2517, -3.9372),
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

    // Recherche exacte
    if (_moroccanCities.containsKey(searchTerm)) {
      return _moroccanCities[searchTerm];
    }

    // Recherche partielle
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

      // Fallback to geocoding if city not found in our database
      if (startPoint == null || endPoint == null) {
        try {
          List<Location> startLocs = await locationFromAddress(
            start,
          ).timeout(Duration(seconds: 8));
          List<Location> endLocs = await locationFromAddress(
            end,
          ).timeout(Duration(seconds: 8));

          if (startLocs.isNotEmpty && startPoint == null) {
            startPoint = LatLng(startLocs[0].latitude, startLocs[0].longitude);
          }
          if (endLocs.isNotEmpty && endPoint == null) {
            endPoint = LatLng(endLocs[0].latitude, endLocs[0].longitude);
          }
        } on TimeoutException {
          // Si timeout, utiliser des coordonnées par défaut
          startPoint ??= _casablancaCenter;
          endPoint ??= LatLng(34.0209, -6.8416); // Rabat par défaut
          _showMessage(
            'Utilisation de coordonnées approximatives (problème réseau)',
          );
        } catch (e) {
          startPoint ??= _casablancaCenter;
          endPoint ??= LatLng(34.0209, -6.8416);
          _showMessage(
            'Adresses non trouvées, utilisation de coordonnées par défaut',
          );
        }
      }

      // Si on n'a toujours pas de coordonnées, utiliser des valeurs par défaut
      startPoint ??= _casablancaCenter;
      endPoint ??= LatLng(34.0209, -6.8416);

      // Création de waypoints intermédiaires pour simulation
      List<LatLng> waypoints = [];
      for (int i = 0; i <= 4; i++) {
        double lat =
            startPoint.latitude +
            (endPoint.latitude - startPoint.latitude) * i / 4;
        double lng =
            startPoint.longitude +
            (endPoint.longitude - startPoint.longitude) * i / 4;
        waypoints.add(LatLng(lat, lng));
      }

      return waypoints;
    } catch (e) {
      print('Erreur dans _getRouteCoordinates: $e');
      // Retourner un itinéraire par défaut Casablanca-Rabat
      return [
        LatLng(33.5731, -7.5898), // Casablanca
        LatLng(33.7031, -7.3898), // Point intermédiaire 1
        LatLng(33.8331, -7.1898), // Point intermédiaire 2
        LatLng(33.9631, -6.9898), // Point intermédiaire 3
        LatLng(34.0209, -6.8416), // Rabat
      ];
    }
  }

  Future<WeatherData?> _getWeatherData(LatLng location) async {
    if (_weatherApiKey == 'a08c63daf8a569834c3a9b1c069a33a5') {
      // Mode démo avec données fictives
      return _generateDemoWeatherData(location);
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.openweathermap.org/data/2.5/weather?'
              'lat=${location.latitude}&lon=${location.longitude}'
              '&appid=$_weatherApiKey&units=metric&lang=fr',
            ),
          )
          .timeout(Duration(seconds: 10)); // Add timeout

      if (response.statusCode == 200) {
        return WeatherData.fromJson(json.decode(response.body), location);
      } else {
        throw Exception('Erreur API météo: ${response.statusCode}');
      }
    } on TimeoutException {
      print('Timeout API météo');
      return _generateDemoWeatherData(location);
    } catch (e) {
      print('Erreur API météo: $e');
      return _generateDemoWeatherData(location);
    }
  }

  WeatherData _generateDemoWeatherData(LatLng location) {
    // Données météo fictives pour démonstration
    final random = (location.latitude + location.longitude).abs() % 100;

    return WeatherData(
      temperature: 20 + (random % 15),
      description: [
        'Ensoleillé',
        'Nuageux',
        'Pluvieux',
        'Venteux',
      ][random.toInt() % 4],
      icon: ['01d', '02d', '10d', '50d'][random.toInt() % 4],
      windSpeed: 2 + (random % 8),
      humidity: 40 + (random % 40).toInt(),
      visibility: 8 + (random % 12),
      location: location,
    );
  }

  List<AIRecommendation> _generateAIRecommendations(
    List<WeatherData> weatherData,
  ) {
    List<AIRecommendation> recommendations = [];

    if (weatherData.isEmpty) return recommendations;

    // Analyse de la température moyenne
    double avgTemp =
        weatherData.map((w) => w.temperature).reduce((a, b) => a + b) /
        weatherData.length;

    if (avgTemp < 10) {
      recommendations.add(
        AIRecommendation(
          message:
              "🥶 Températures froides sur le trajet (${avgTemp.toStringAsFixed(1)}°C). Prévoyez des vêtements chauds et vérifiez l'état des routes.",
          type: 'warning',
          icon: Icons.ac_unit,
          color: Colors.blue,
        ),
      );
    } else if (avgTemp > 35) {
      recommendations.add(
        AIRecommendation(
          message:
              "🔥 Températures élevées (${avgTemp.toStringAsFixed(1)}°C). Hydratez-vous régulièrement et évitez les heures les plus chaudes.",
          type: 'warning',
          icon: Icons.whatshot,
          color: Colors.orange,
        ),
      );
    }

    // Analyse du vent
    double maxWind = weatherData
        .map((w) => w.windSpeed)
        .reduce((a, b) => a > b ? a : b);
    if (maxWind > 10) {
      recommendations.add(
        AIRecommendation(
          message:
              "💨 Vents forts prévus (${maxWind.toStringAsFixed(1)} m/s). Réduisez votre vitesse et tenez fermement le volant.",
          type: 'warning',
          icon: Icons.air,
          color: Colors.grey,
        ),
      );
    }

    // Analyse de la visibilité
    double minVisibility = weatherData
        .map((w) => w.visibility)
        .reduce((a, b) => a < b ? a : b);
    if (minVisibility < 5) {
      recommendations.add(
        AIRecommendation(
          message:
              "👁️ Visibilité réduite sur certaines portions (${minVisibility.toStringAsFixed(1)} km). Allumez vos feux et gardez vos distances.",
          type: 'warning',
          icon: Icons.visibility_off,
          color: Colors.red,
        ),
      );
    }

    // Recommandation positive si conditions bonnes
    if (avgTemp >= 15 && avgTemp <= 25 && maxWind < 5 && minVisibility > 10) {
      recommendations.add(
        AIRecommendation(
          message:
              "✅ Conditions météo idéales pour votre trajet ! Profitez de la route en toute sécurité. 🌞",
          type: 'good',
          icon: Icons.wb_sunny,
          color: Colors.green,
        ),
      );
    }

    // Recommandation horaire
    DateTime now = DateTime.now();
    if (now.hour >= 7 && now.hour <= 9) {
      recommendations.add(
        AIRecommendation(
          message:
              "⏰ Heure de pointe matinale. Prévoyez 20-30% de temps supplémentaire pour votre trajet.",
          type: 'info',
          icon: Icons.schedule,
          color: Colors.amber,
        ),
      );
    } else if (now.hour >= 17 && now.hour <= 19) {
      recommendations.add(
        AIRecommendation(
          message:
              "🚗 Trafic intense en soirée. Considérez un départ décalé si possible.",
          type: 'info',
          icon: Icons.traffic,
          color: Colors.amber,
        ),
      );
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

      // Création de la polyline pour l'itinéraire
      if (mounted) {
        setState(() {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: routeCoordinates,
              color: Colors.blue,
              width: 4,
              patterns: [PatternItem.dash(10), PatternItem.gap(5)],
            ),
          );
        });
      }

      // Récupération des données météo pour chaque waypoint
      for (int i = 0; i < routeCoordinates.length; i++) {
        if (!mounted) return; // Check if widget is still mounted

        WeatherData? weather = await _getWeatherData(routeCoordinates[i]);
        if (weather != null && mounted) {
          _weatherData.add(weather);

          // Création du marqueur météo
          BitmapDescriptor icon = await _getWeatherIcon(weather.icon);
          setState(() {
            _markers.add(
              Marker(
                markerId: MarkerId('weather_$i'),
                position: routeCoordinates[i],
                icon: icon,
                infoWindow: InfoWindow(
                  title: '${weather.temperature.toStringAsFixed(1)}°C',
                  snippet: weather.description,
                ),
              ),
            );
          });
        }
      }

      // Génération des recommandations IA
      if (mounted) {
        setState(() {
          _recommendations = _generateAIRecommendations(_weatherData);
        });
      }

      // Centrage de la carte sur l'itinéraire
      if (routeCoordinates.isNotEmpty && _mapController != null && mounted) {
        LatLngBounds bounds = _getBounds(routeCoordinates);
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
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

  Future<BitmapDescriptor> _getWeatherIcon(String iconCode) async {
    switch (iconCode) {
      case '01d':
      case '01n':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow,
        );
      case '02d':
      case '02n':
      case '03d':
      case '03n':
      case '04d':
      case '04n':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case '09d':
      case '09n':
      case '10d':
      case '10n':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
      case '11d':
      case '11n':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        );
      case '13d':
      case '13n':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    double maxLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    double minLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    double maxLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
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
                    prefixIcon: const Icon(
                      Icons.location_on,
                      color: Colors.green,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.search, color: Colors.white),
                    label: Text(
                      _isLoading
                          ? 'Analyse en cours...'
                          : 'Analyser l\'itinéraire',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Carte Google Maps
Expanded(
  flex: 3,
  child: GoogleMap(
    onMapCreated: (GoogleMapController controller) {
      _mapController = controller;
    },
    initialCameraPosition: const CameraPosition(
      target: LatLng(33.5731, -7.5898), // Casablanca
      zoom: 10,
    ),
    markers: _markers,
    polylines: _polylines,
    mapType: MapType.normal,
    myLocationEnabled: true,
    myLocationButtonEnabled: true,
    zoomControlsEnabled: true,
    compassEnabled: true,
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
                      'Recommandations',
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
                              leading: Icon(
                                rec.icon,
                                color: rec.color,
                                size: 28,
                              ),
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
          : null,
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
                                  Text(
                                    '🌡️ Température: ${weather.temperature.toStringAsFixed(1)}°C',
                                  ),
                                  Text('📝 Conditions: ${weather.description}'),
                                  Text(
                                    '💨 Vent: ${weather.windSpeed.toStringAsFixed(1)} m/s',
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('💧 Humidité: ${weather.humidity}%'),
                                  Text(
                                    '👁️ Visibilité: ${weather.visibility.toStringAsFixed(1)} km',
                                  ),
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
